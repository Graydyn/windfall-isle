extends GutTest
## Authoring guards for conversion recipes (chains spec sections 2-5).


func recipe_buildings() -> Dictionary:
	var out := {}
	for id in DataDefs.buildings.get("defs", {}):
		var def: Dictionary = (DataDefs.buildings["defs"] as Dictionary)[id]
		if def.has("recipe"):
			out[String(id)] = def["recipe"]
	return out


func test_exactly_the_three_recipe_buildings() -> void:
	var found := recipe_buildings()
	assert_eq(found.size(), 3)
	for id in ["smeltery", "foundry_annex", "gardens"]:
		assert_has(found, id)

func test_recipes_are_well_formed() -> void:
	var known: Array = (DataDefs.economy.get("starting_balances", {}) as Dictionary).keys()
	for id in recipe_buildings():
		var conversion: Dictionary = recipe_buildings()[id]
		assert_true(String(conversion.get("id", "")) != "", "recipe id missing: %s" % id)
		assert_true(String(conversion.get("name", "")) != "", "recipe display name missing: %s" % id)
		assert_true(float(conversion.get("seconds", 0)) > 0.0, "recipe seconds missing: %s" % id)
		assert_true((conversion.get("outputs", {}) as Dictionary).size() > 0, "recipe outputs empty: %s" % id)
		for currency in conversion.get("inputs", {}):
			assert_true(known.has(String(currency)), "unknown input currency %s: %s" % [currency, id])
		for currency in conversion.get("outputs", {}):
			assert_true(known.has(String(currency)), "unknown output currency %s: %s" % [currency, id])

func test_new_currencies_start_at_zero() -> void:
	var balances: Dictionary = DataDefs.economy.get("starting_balances", {})
	assert_eq(int(balances.get("parts", -1)), 0)
	assert_eq(int(balances.get("provisions", -1)), 0)

func test_smeltery_is_workable_and_reya_specializes() -> void:
	assert_true((DataDefs.crew.get("workable", []) as Array).has("smeltery"))
	assert_eq(String(CrewModel.entry(DataDefs.crew, "reya").get("specialty", "")), "smeltery",
		"chains spec section 5: Reya moves to the Smeltery; Petch keeps the Balloonworks")
	assert_eq(String(CrewModel.entry(DataDefs.crew, "petch").get("specialty", "")), "balloonworks")

func test_smeltery_def_shape() -> void:
	var def: Dictionary = (DataDefs.buildings.get("defs", {}) as Dictionary).get("smeltery", {})
	assert_eq(int(def.get("max_level", 0)), 3)
	assert_eq((def.get("levels", []) as Array).size(), 3)
	assert_eq(int(DataDefs.buildings.get("plot_count", 0)), 7, "seventh plot: no softlock")

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
