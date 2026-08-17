extends GutTest

const DamperScene := preload("res://game/run/gizmos/gyro_damper.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var damper_defs: Dictionary


func before_each() -> void:
	damper_defs = (DataDefs.gizmos["defs"]["gyro_damper"] as Dictionary).duplicate()


func test_configure_registers_group_and_radius() -> void:
	var damper: GyroDamper = add_child_autofree(DamperScene.instantiate())
	damper.setup(damper_defs, 1, self)
	assert_true(damper.is_in_group("gyro_dampers"))
	assert_almost_eq(damper.field_radius, 140.0, 0.001)

func test_level_scales_the_field() -> void:
	var damper: GyroDamper = add_child_autofree(DamperScene.instantiate())
	damper.setup(damper_defs, 3, self)
	assert_almost_eq(damper.field_radius, 140.0 * 1.5, 0.001)

func test_damper_nulls_the_drift_push() -> void:
	var zone := DriftZone.new()
	zone.setup({"x": 360, "y": 400, "half_width": 300, "half_height": 200, "force": 220.0, "direction": 1.0})
	add_child_autofree(zone)
	var damper: GyroDamper = add_child_autofree(DamperScene.instantiate())
	damper.position = Vector2(360, 400)
	damper.setup(damper_defs, 1, self)
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	pod.position = Vector2(360, 300)
	pod.setup({"radius": 12.0, "bounce": 0.55, "friction": 0.2})
	await wait_seconds(0.4)
	assert_true(absf(pod.linear_velocity.x) < 5.0,
		"inside the damper field the drift current cannot push the pod")

func test_craft_recipe_costs_brasswork() -> void:
	assert_eq(int((damper_defs["craft_cost"] as Dictionary)["brasswork"]), 2,
		"spec 3.4: new recipes are gated on the regional material")
