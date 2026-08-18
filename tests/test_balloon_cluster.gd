extends GutTest

const BalloonScene := preload("res://game/run/gizmos/balloon_cluster.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var balloon
var balloon_defs: Dictionary


func before_each() -> void:
	balloon_defs = (DataDefs.gizmos["defs"]["balloon_cluster"] as Dictionary).duplicate()
	balloon = add_child_autofree(BalloonScene.instantiate())
	balloon.setup(balloon_defs, 1, self)


func make_falling_pod() -> Pod:
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	pod.setup({"radius": 12.0, "bounce": 0.55, "friction": 0.2})
	pod.linear_velocity = Vector2(0, 300)
	return pod


func test_contact_bounces_pod_upward() -> void:
	var pod := make_falling_pod()
	balloon._on_body_entered(pod)
	await wait_physics_frames(2)
	assert_true(pod.linear_velocity.y < 0.0, "pod must be moving up after the bounce")

func test_pops_after_max_hits() -> void:
	for i in int(balloon_defs["max_hits"]):
		balloon._on_body_entered(make_falling_pod())
		await wait_physics_frames(2)
	assert_eq(balloon._hits_left, 0)
	var late_pod := make_falling_pod()
	balloon._on_body_entered(late_pod)
	await wait_physics_frames(2)
	assert_true(late_pod.linear_velocity.y > 0.0, "a popped balloon must not bounce")
	assert_almost_eq(balloon.get_node("Visual").modulate.a, 0.25, 0.001)

func test_level_scales_impulse() -> void:
	var strong = add_child_autofree(BalloonScene.instantiate())
	strong.setup(balloon_defs, 2, self)
	assert_almost_eq(strong._impulse, 420.0 * 1.25, 0.001)

func test_recharge_restores_hits_and_visual() -> void:
	balloon._hits_left = 0
	balloon.get_node("Visual").modulate.a = 0.25
	balloon.recharge()
	assert_eq(balloon._hits_left, int(DataDefs.gizmos["defs"]["balloon_cluster"]["max_hits"]))
	assert_almost_eq(balloon.get_node("Visual").modulate.a, 1.0, 0.001)
	await wait_physics_frames(1)
	assert_true(balloon.get_node("Zone").monitoring)
