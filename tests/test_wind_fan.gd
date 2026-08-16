extends GutTest

const WindFanScene := preload("res://game/run/gizmos/wind_fan.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var fan_defs: Dictionary


func before_each() -> void:
	fan_defs = (DataDefs.gizmos["defs"]["wind_fan"] as Dictionary).duplicate()


func test_configure_builds_column_from_defs() -> void:
	var fan: WindFan = add_child_autofree(WindFanScene.instantiate())
	fan.setup(fan_defs, 1, self)
	var shape: RectangleShape2D = fan.get_node("Zone/Shape").shape
	assert_almost_eq(shape.size.x, 90.0, 0.001)
	assert_almost_eq(shape.size.y, 420.0, 0.001)

func test_pod_in_column_gains_lateral_velocity() -> void:
	var fan: WindFan = add_child_autofree(WindFanScene.instantiate())
	fan.position = Vector2(360, 600)
	fan.setup(fan_defs, 1, self)
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	pod.position = Vector2(360, 250)
	pod.setup({"radius": 12.0, "bounce": 0.55, "friction": 0.2})
	await wait_seconds(0.5)
	assert_true(pod.linear_velocity.x > 10.0,
		"a pod falling through the column must be pushed in +x (direction 1)")

func test_level_scales_force() -> void:
	var fan: WindFan = add_child_autofree(WindFanScene.instantiate())
	fan.setup(fan_defs, 3, self)
	assert_almost_eq(fan._force_vector.x, 260.0 * 1.5, 0.001)
