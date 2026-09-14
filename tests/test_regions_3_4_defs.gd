extends GutTest
## Regions 3 and 4 unlock data pins (Plan 14): currencies, dock levels, and
## the run.json region rows. The skyfield JSONs have their own defs tests.


func test_starting_balances_carry_the_new_materials() -> void:
	var balances: Dictionary = DataDefs.economy["starting_balances"]
	assert_eq(int(balances.get("rimeglass", -1)), 0)
	assert_eq(int(balances.get("stormglass", -1)), 0)


func test_dock_reaches_level_four() -> void:
	var dock: Dictionary = (DataDefs.buildings["defs"] as Dictionary)["dock"]
	assert_eq(int(dock.get("max_level", 0)), 4)
	var levels: Array = dock.get("levels", [])
	assert_eq(levels.size(), 4)
	assert_eq(int(((levels[2] as Dictionary).get("cost", {}) as Dictionary).get("brasswork", 0)), 6,
		"region 2's material funds the region 3 unlock")
	assert_eq(int(((levels[3] as Dictionary).get("cost", {}) as Dictionary).get("rimeglass", 0)), 6,
		"region 3's material funds the region 4 unlock")


func test_region_rows_are_pinned() -> void:
	var r3: Dictionary = RegionModel.entry(DataDefs.run, "region_3")
	assert_eq(String(r3.get("name", "")), "Rimefall Shallows")
	assert_eq(int(r3.get("min_dock_level", 0)), 3)
	assert_eq(int(r3.get("fuel_cost", 0)), 3)
	assert_eq(int(r3.get("reduced_fuel_cost", 0)), 2)
	assert_eq(int(r3.get("reduced_at_dock_level", 0)), 4)
	var r4: Dictionary = RegionModel.entry(DataDefs.run, "region_4")
	assert_eq(String(r4.get("name", "")), "Stormglass Verge")
	assert_eq(int(r4.get("min_dock_level", 0)), 4)
	assert_eq(int(r4.get("fuel_cost", 0)), 3)
	assert_false(r4.has("reduced_fuel_cost"),
		"no reduction row until a dock level 5 exists (spec section 8)")


func test_dock_gating_truth_table() -> void:
	var expectations := {
		0: {"region_1": true, "region_2": false, "region_3": false, "region_4": false},
		1: {"region_1": true, "region_2": true, "region_3": false, "region_4": false},
		2: {"region_1": true, "region_2": true, "region_3": false, "region_4": false},
		3: {"region_1": true, "region_2": true, "region_3": true, "region_4": false},
		4: {"region_1": true, "region_2": true, "region_3": true, "region_4": true},
	}
	for dock_level in expectations:
		var island := {"plots": {}, "build_slots": 1}
		if int(dock_level) > 0:
			island["plots"] = {"plot_0": {"building": "dock", "level": int(dock_level)}}
		var expected: Dictionary = expectations[dock_level]
		for region_id in expected:
			assert_eq(RegionModel.unlocked(RegionModel.entry(DataDefs.run, String(region_id)), island),
				bool(expected[region_id]),
				"dock lv %d vs %s" % [int(dock_level), String(region_id)])


func test_region_3_fuel_discount_at_dock_four() -> void:
	var entry := RegionModel.entry(DataDefs.run, "region_3")
	var island := {"plots": {"plot_0": {"building": "dock", "level": 3}}, "build_slots": 1}
	assert_eq(RegionModel.fuel_cost(entry, island), 3)
	(island["plots"]["plot_0"] as Dictionary)["level"] = 4
	assert_eq(RegionModel.fuel_cost(entry, island), 2)


func test_old_saves_read_missing_materials_as_zero() -> void:
	# No migration ships with the new currencies (spec section 7): an old
	# save simply lacks the keys until the first add.
	var state = autofree(preload("res://game/autoload/game_state.gd").new())
	state.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	(state.data["currencies"] as Dictionary).erase("rimeglass")
	(state.data["currencies"] as Dictionary).erase("stormglass")
	var econ = autofree(preload("res://game/autoload/economy.gd").new())
	econ.setup(state)
	assert_eq(econ.balance("rimeglass"), 0)
	econ.add("stormglass", 2)
	assert_eq(econ.balance("stormglass"), 2)
