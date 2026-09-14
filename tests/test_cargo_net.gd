extends GutTest

const NetScene := preload("res://game/run/gizmos/cargo_net.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var net
var net_defs: Dictionary


func before_each() -> void:
	net_defs = (DataDefs.gizmos["defs"]["cargo_net"] as Dictionary).duplicate()
	net = add_child_autofree(NetScene.instantiate())
	net.position = Vector2(200, 500)
	net.setup(net_defs, 1, self)


func make_pod(at: Vector2 = Vector2(200, 490)) -> Pod:
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	pod.position = at
	pod.setup({"radius": 12.0, "bounce": 0.55, "friction": 0.2})
	return pod


func test_catch_freezes_pod() -> void:
	var pod := make_pod()
	net._on_body_entered(pod)
	await wait_physics_frames(2)
	assert_true(pod.freeze, "the netted pod hangs frozen")

func test_release_relaunches_toward_center() -> void:
	var pod := make_pod()
	net._on_body_entered(pod)
	await wait_physics_frames(2)
	net._release(weakref(pod), add_child_autofree(Timer.new()))
	await wait_physics_frames(2)
	assert_false(pod.freeze)
	assert_true(pod.linear_velocity.x > 0.0, "a net left of center relaunches toward +x")
	assert_true(pod.linear_velocity.y < 0.0, "the relaunch arcs upward")

func test_single_use() -> void:
	net._on_body_entered(make_pod())
	var second := make_pod(Vector2(200, 470))
	net._on_body_entered(second)
	await wait_physics_frames(2)
	assert_false(second.freeze, "a spent net catches nothing")

func test_release_of_freed_pod_is_harmless() -> void:
	var pod := make_pod()
	net._on_body_entered(pod)
	pod.free()
	net._release(weakref(pod), add_child_autofree(Timer.new()))
	assert_true(true, "no error path reached")

func test_caught_pod_is_ignored() -> void:
	var pod := make_pod()
	pod.set_meta("caught", true)
	net._on_body_entered(pod)
	await wait_physics_frames(2)
	assert_false(pod.freeze)

func test_recharge_restores_the_net() -> void:
	net._uses_left = 0
	net.get_node("Visual").modulate.a = 0.4
	net.recharge()
	assert_eq(net._uses_left, int(DataDefs.gizmos["defs"]["cargo_net"]["uses"]))
	assert_almost_eq(net.get_node("Visual").modulate.a, 1.0, 0.001)

func make_net(level: int) -> Node:
	var scaled_net = add_child_autofree(NetScene.instantiate())
	scaled_net.position = Vector2(200, 500)
	scaled_net.setup(net_defs, level, self)
	return scaled_net

func test_uses_scale_with_level() -> void:
	assert_eq(make_net(2)._uses_left, 2, "uses = base uses x level (Plan 13 rebalance)")
	assert_eq(make_net(5)._uses_left, 5)

func test_recharge_restores_level_scaled_uses() -> void:
	var lv3 = make_net(3)
	lv3._uses_left = 0
	lv3.get_node("Visual").modulate.a = 0.4
	lv3.recharge()
	assert_eq(lv3._uses_left, 3)
	assert_almost_eq(lv3.get_node("Visual").modulate.a, 1.0, 0.001)

func test_relaunch_speed_is_level_independent() -> void:
	var lv5 = make_net(5)
	var pod := make_pod()
	lv5._on_body_entered(pod)
	await wait_physics_frames(2)
	lv5._release(weakref(pod), add_child_autofree(Timer.new()))
	assert_almost_eq(pod.linear_velocity.length(), float(net_defs["redrop_speed"]), 1.0,
		"level scaling moved from speed to uses; the relaunch speed is the raw defs value")
