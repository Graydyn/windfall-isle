extends GutTest
## Authoring guards for conversion recipes (chains spec sections 2-5; recipes
## arrays per the run-kit spec section 2).


func recipe_buildings() -> Dictionary:
	var out := {}
	for id in DataDefs.buildings.get("defs", {}):
		var def: Dictionary = (DataDefs.buildings["defs"] as Dictionary)[id]
		if def.has("recipes"):
			out[String(id)] = def["recipes"]
	return out


func test_exactly_the_four_recipe_buildings() -> void:
	var found := recipe_buildings()
	assert_eq(found.size(), 4)
	for id in ["smeltery", "foundry_annex", "gardens", "balloonworks"]:
		assert_has(found, id)
	assert_eq((found["balloonworks"] as Array).size(), 3, "the run-kit consumables")

func test_recipes_are_well_formed() -> void:
	var known: Array = (DataDefs.economy.get("starting_balances", {}) as Dictionary).keys()
	for id in recipe_buildings():
		for row_v in recipe_buildings()[id]:
			var conversion := row_v as Dictionary
			assert_true(String(conversion.get("id", "")) != "", "recipe id missing: %s" % id)
			assert_true(String(conversion.get("name", "")) != "", "recipe display name missing: %s" % id)
			assert_true(float(conversion.get("seconds", 0)) > 0.0, "recipe seconds missing: %s" % id)
			assert_true((conversion.get("outputs", {}) as Dictionary).size() > 0, "recipe outputs empty: %s" % id)
			for currency in conversion.get("inputs", {}):
				assert_true(known.has(String(currency)), "unknown input currency %s: %s" % [currency, id])
			for currency in conversion.get("outputs", {}):
				assert_true(known.has(String(currency)), "unknown output currency %s: %s" % [currency, id])

func test_recipe_ids_are_globally_unique() -> void:
	var seen := {}
	for id in recipe_buildings():
		for row_v in recipe_buildings()[id]:
			var recipe_id := String((row_v as Dictionary).get("id", ""))
			assert_false(seen.has(recipe_id), "duplicate recipe id: %s" % recipe_id)
			seen[recipe_id] = true

func test_new_currencies_start_at_zero() -> void:
	var balances: Dictionary = DataDefs.economy.get("starting_balances", {})
	for currency in ["parts", "provisions", "ballast", "wind_charm", "storm_oil"]:
		assert_eq(int(balances.get(currency, -1)), 0, "missing starting balance: %s" % currency)

func test_smeltery_is_workable_and_reya_specializes() -> void:
	assert_true((DataDefs.crew.get("workable", []) as Array).has("smeltery"))
	assert_eq(String(CrewModel.entry(DataDefs.crew, "reya").get("specialty", "")), "smeltery",
		"chains spec section 5: Reya moves to the Smeltery; Petch keeps the Balloonworks")
	assert_eq(String(CrewModel.entry(DataDefs.crew, "petch").get("specialty", "")), "balloonworks")

func test_smeltery_def_shape() -> void:
	var def: Dictionary = (DataDefs.buildings.get("defs", {}) as Dictionary).get("smeltery", {})
	assert_eq(int(def.get("max_level", 0)), 3)
	assert_eq((def.get("levels", []) as Array).size(), 3)
	assert_eq(int(DataDefs.buildings.get("plot_count", 0)), 8, "eighth plot: every home building keeps a pad")

func test_gizmo_repricing_table_is_pinned() -> void:
	var expected := {
		"wind_fan": {"parts": 2},
		"balloon_cluster": {"parts": 2},
		"cargo_net": {"parts": 2},
		"magnet_buoy": {"parts": 3},
		"chime_bell": {"parts": 3},
		"lightning_jar": {"parts": 3, "cloudsilk": 1},
		"crystal_prism": {"parts": 3, "cloudsilk": 1},
		"splitter_vane": {"parts": 4, "cloudsilk": 2},
		"piston_kicker": {"parts": 4, "brasswork": 1},
		"gyro_damper": {"parts": 5, "brasswork": 2},
	}
	for gizmo_id in expected:
		var cost: Dictionary = ((DataDefs.gizmos.get("defs", {}) as Dictionary)[gizmo_id] as Dictionary).get("craft_cost", {})
		var want: Dictionary = expected[gizmo_id]
		assert_eq(cost.size(), want.size(), "cost shape drifted: %s" % gizmo_id)
		for currency in want:
			assert_eq(int(cost.get(currency, -1)), int(want[currency]),
				"repricing table drifted (chains spec section 4): %s %s" % [gizmo_id, currency])

func test_crew_quarters_def_shape() -> void:
	var def: Dictionary = (DataDefs.buildings.get("defs", {}) as Dictionary).get("crew_quarters", {})
	assert_eq(String(def.get("name", "")), "Crew Quarters")
	assert_eq(int(def.get("max_level", 0)), 1, "a pure unlock: nothing to upgrade")
	var rows: Array = def.get("levels", [])
	assert_eq(rows.size(), 1)
	assert_eq(int(((rows[0] as Dictionary).get("cost", {}) as Dictionary).get("scrap", 0)), 40,
		"cheap on purpose: crew should unlock early (owner request, 2026-10-17)")
	assert_true(int((rows[0] as Dictionary).get("build_seconds", 0)) <= 60, "a quick first build")
	assert_eq(String(def.get("islet", "")), "", "a home building")
	assert_false(def.has("recipes"), "the bunkhouse converts nothing")
	assert_false((DataDefs.crew.get("workable", []) as Array).has("crew_quarters"),
		"no one works the bunkhouse")
	assert_true((DataDefs.island_layout.get("plots", {}) as Dictionary).has("plot_7"),
		"the new plot has a map position")
