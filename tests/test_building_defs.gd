extends GutTest


func test_buildings_load_with_eight_defs() -> void:
	assert_eq((DataDefs.buildings["defs"] as Dictionary).size(), 8,
		"six home buildings plus the two islet buildings")
	for id in ["workshop", "wind_still", "dock", "balloonworks", "observatory", "gardens", "lens_array", "foundry_annex"]:
		assert_has(DataDefs.buildings["defs"], id)
	for id in DataDefs.buildings["defs"]:
		var def: Dictionary = DataDefs.buildings["defs"][id]
		assert_eq((def["levels"] as Array).size(), int(def["max_level"]),
			"every level needs a cost/time row: %s" % id)

func test_islet_buildings_declare_their_islet() -> void:
	assert_eq(String((DataDefs.buildings["defs"]["lens_array"] as Dictionary)["islet"]), "lantern_shoal")
	assert_eq(String((DataDefs.buildings["defs"]["foundry_annex"] as Dictionary)["islet"]), "foundry_rock")
	for id in ["workshop", "wind_still", "dock", "balloonworks", "observatory", "gardens"]:
		assert_false((DataDefs.buildings["defs"][id] as Dictionary).has("islet"),
			"home buildings carry no islet field: %s" % id)

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
