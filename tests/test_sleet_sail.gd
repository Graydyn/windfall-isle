extends GutTest

const SailScene := preload("res://game/run/gizmos/sleet_sail.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var sail_defs: Dictionary


func before_each() -> void:
	sail_defs = (DataDefs.gizmos["defs"]["sleet_sail"] as Dictionary).duplicate()


func make_sail(level: int) -> Node:
	var sail = add_child_autofree(SailScene.instantiate())
	sail.position = Vector2(360, 500)
	sail.setup(sail_defs, level, self)
	return sail


func make_pod() -> Pod:
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	pod.position = Vector2(360, 300)
	pod.setup({"radius": 12.0, "bounce": 0.55, "friction": 0.2})
	return pod


func test_pod_falls_slower_inside_the_column() -> void:
	var sail = make_sail(1)
	var pod := make_pod()
	sail._on_body_entered(pod)
	assert_almost_eq(pod.gravity_scale, 0.5, 0.001, "gravity halves inside the sail's column")


func test_gravity_restored_on_exit() -> void:
	var sail = make_sail(1)
	var pod := make_pod()
	sail._on_body_entered(pod)
	sail._on_body_exited(pod)
	assert_almost_eq(pod.gravity_scale, 1.0, 0.001)


func test_caught_pod_is_ignored() -> void:
	var sail = make_sail(1)
	var pod := make_pod()
	pod.set_meta("caught", true)
	sail._on_body_entered(pod)
	assert_almost_eq(pod.gravity_scale, 1.0, 0.001)


func test_column_width_scales_with_level() -> void:
	var lv5 = make_sail(5)
	var shape: RectangleShape2D = lv5.get_node("Zone/Shape").shape as RectangleShape2D
	assert_almost_eq(shape.size.x, 160.0, 0.001, "80 base x 2.0 at level 5; the gravity factor never scales")
