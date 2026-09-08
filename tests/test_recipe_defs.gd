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
