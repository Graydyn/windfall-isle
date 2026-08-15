extends GutTest

const PodScene := preload("res://game/run/pod.tscn")
const POD_DEFS := {"radius": 15.0, "bounce": 0.7, "friction": 0.1}


func test_setup_applies_physics_defs() -> void:
	var pod: Pod = autofree(PodScene.instantiate())
	pod.setup(POD_DEFS)
	assert_eq((pod.get_node("CollisionShape2D").shape as CircleShape2D).radius, 15.0)
	assert_almost_eq(pod.physics_material_override.bounce, 0.7, 0.001)
	assert_almost_eq(pod.physics_material_override.friction, 0.1, 0.001)

func test_each_pod_gets_its_own_shape() -> void:
	var a: Pod = autofree(PodScene.instantiate())
	var b: Pod = autofree(PodScene.instantiate())
	a.setup(POD_DEFS)
	b.setup({"radius": 9.0, "bounce": 0.5, "friction": 0.2})
	assert_eq((a.get_node("CollisionShape2D").shape as CircleShape2D).radius, 15.0,
		"mutating one pod's shape must not affect another (no shared resource)")

func test_pod_joins_pods_group_in_tree() -> void:
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	assert_true(pod.is_in_group("pods"))

func test_geometry_circle_points() -> void:
	var pts := Geometry.circle_points(10.0, 8)
	assert_eq(pts.size(), 8)
	assert_almost_eq(pts[0].x, 10.0, 0.001)
	assert_almost_eq(pts[0].y, 0.0, 0.001)
