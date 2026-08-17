extends GutTest

const KickerScene := preload("res://game/run/gizmos/piston_kicker.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var kicker_defs: Dictionary
var kicker: PistonKicker


func before_each() -> void:
	kicker_defs = (DataDefs.gizmos["defs"]["piston_kicker"] as Dictionary).duplicate()
	kicker = add_child_autofree(KickerScene.instantiate())
	kicker.position = Vector2(360, 500)
	kicker.setup(kicker_defs, 1, self)


func make_pod() -> RigidBody2D:
	var pod := RigidBody2D.new()
	add_child_autofree(pod)
	return pod


func test_configure_builds_zone_and_impulse() -> void:
	assert_almost_eq((kicker.get_node("Zone/Shape").shape as CircleShape2D).radius, 24.0, 0.001)
	assert_almost_eq(kicker._impulse_vector.x, 520.0, 0.001)

func test_level_scales_the_kick() -> void:
	var strong: PistonKicker = add_child_autofree(KickerScene.instantiate())
	strong.setup(kicker_defs, 3, self)
	assert_almost_eq(strong._impulse_vector.x, 520.0 * 1.5, 0.001)

func test_kicks_each_pod_exactly_once() -> void:
	var pod := make_pod()
	kicker._on_body_entered(pod)
	kicker._on_body_entered(pod)
	await wait_physics_frames(2)
	assert_almost_eq(pod.linear_velocity.x, 520.0, 60.0,
		"the second contact must not stack a second impulse")
	assert_true(pod.has_meta("piston_kicked"))

func test_caught_pods_are_ignored() -> void:
	var pod := make_pod()
	pod.set_meta("caught", true)
	kicker._on_body_entered(pod)
	await wait_physics_frames(2)
	assert_almost_eq(pod.linear_velocity.x, 0.0, 5.0)

func test_falling_pod_is_kicked_on_real_contact() -> void:
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	pod.position = Vector2(360, 420)
	pod.setup({"radius": 12.0, "bounce": 0.55, "friction": 0.2})
	await wait_seconds(0.6)
	assert_true(pod.linear_velocity.x > 200.0,
		"real contact with the piston fires the pod sideways")
