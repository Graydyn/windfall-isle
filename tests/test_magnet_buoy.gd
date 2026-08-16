extends GutTest

const BuoyScene := preload("res://game/run/gizmos/magnet_buoy.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var buoy_defs: Dictionary


func before_each() -> void:
	buoy_defs = (DataDefs.gizmos["defs"]["magnet_buoy"] as Dictionary).duplicate()


func test_configure_builds_radius_zone() -> void:
	var buoy: MagnetBuoy = add_child_autofree(BuoyScene.instantiate())
	buoy.setup(buoy_defs, 1, self)
	assert_almost_eq((buoy.get_node("Zone/Shape").shape as CircleShape2D).radius, 160.0, 0.001)

func test_pod_beside_buoy_is_pulled_toward_it() -> void:
	var buoy: MagnetBuoy = add_child_autofree(BuoyScene.instantiate())
	buoy.position = Vector2(360, 500)
	buoy.setup(buoy_defs, 1, self)
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	pod.position = Vector2(240, 500)
	pod.setup({"radius": 12.0, "bounce": 0.55, "friction": 0.2})
	await wait_seconds(0.4)
	assert_true(pod.linear_velocity.x > 5.0, "the pod left of the buoy accelerates toward +x")

func test_level_scales_force() -> void:
	var buoy: MagnetBuoy = add_child_autofree(BuoyScene.instantiate())
	buoy.setup(buoy_defs, 3, self)
	assert_almost_eq(buoy._force, 240.0 * 1.5, 0.001)
