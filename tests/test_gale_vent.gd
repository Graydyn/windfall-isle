extends GutTest

const VentScene := preload("res://game/run/gizmos/gale_vent.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var vent_defs: Dictionary


func before_each() -> void:
	vent_defs = (DataDefs.gizmos["defs"]["gale_vent"] as Dictionary).duplicate()


func make_vent(level: int) -> Node:
	var vent = add_child_autofree(VentScene.instantiate())
	vent.position = Vector2(360, 500)
	vent.setup(vent_defs, level, self)
	return vent


func make_pod() -> Pod:
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	pod.position = Vector2(360, 480)
	pod.setup({"radius": 12.0, "bounce": 0.55, "friction": 0.2})
	return pod


func test_kick_applies_upward_impulse_once_per_vent() -> void:
	var vent = make_vent(1)
	var pod := make_pod()
	vent._on_body_entered(pod)
	await wait_physics_frames(2)
	var vy_after_kick: float = pod.linear_velocity.y
	assert_true(vy_after_kick < 0.0, "the vent kicks the pod upward")
	vent._on_body_entered(pod)
	await wait_physics_frames(2)
	assert_true(pod.linear_velocity.y >= vy_after_kick,
		"a second contact with the SAME vent adds no second kick")


func test_two_vents_each_get_their_own_kick() -> void:
	var first = make_vent(1)
	var second = make_vent(1)
	var pod := make_pod()
	first._on_body_entered(pod)
	second._on_body_entered(pod)
	assert_true(pod.has_meta("gale_vented_%d" % first.get_instance_id()))
	assert_true(pod.has_meta("gale_vented_%d" % second.get_instance_id()))


func test_impulse_scales_with_level() -> void:
	var lv3 = make_vent(3)
	assert_almost_eq(lv3._impulse, 570.0, 0.001, "380 base x 1.5 at level 3")


func test_caught_pod_is_ignored() -> void:
	var vent = make_vent(1)
	var pod := make_pod()
	pod.set_meta("caught", true)
	vent._on_body_entered(pod)
	assert_false(pod.has_meta("gale_vented_%d" % vent.get_instance_id()))
