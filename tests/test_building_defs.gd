extends GutTest


func test_buildings_load_with_six_defs() -> void:
	assert_eq((DataDefs.buildings["defs"] as Dictionary).size(), 6, "spec 4.1 lists six buildings")
	for id in ["workshop", "wind_still", "dock", "balloonworks", "observatory", "gardens"]:
		assert_has(DataDefs.buildings["defs"], id)
	for id in DataDefs.buildings["defs"]:
		var def: Dictionary = DataDefs.buildings["defs"][id]
		assert_eq((def["levels"] as Array).size(), int(def["max_level"]),
			"every level needs a cost/time row: %s" % id)

func test_slots_and_retention() -> void:
	assert_eq(int(DataDefs.buildings["build_slots"]["free"]), 1, "spec 4.1: one free build slot")
	assert_true(int(DataDefs.buildings["build_slots"]["second_slot_crystal_cost"]) > 0)
	assert_true(int(DataDefs.retention["daily_crate"]["scrap"]) > 0)

func test_every_gizmo_has_craft_tuning() -> void:
	assert_eq(int(DataDefs.gizmos["craft_max_level"]), 5)
	for id in DataDefs.gizmos["defs"]:
		var def: Dictionary = DataDefs.gizmos["defs"][id]
		assert_true((def["craft_cost"] as Dictionary).size() > 0, "craft_cost missing: %s" % id)
		assert_true(int(def["craft_seconds"]) > 0, "craft_seconds missing: %s" % id)
