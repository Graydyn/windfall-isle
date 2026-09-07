extends GutTest

const DataDefsScript := preload("res://game/autoload/data_defs.gd")


func crew_defs() -> Dictionary:
	return DataDefsScript.load_json("res://game/data/crew.json")


func test_crew_load_with_required_keys() -> void:
	var defs := crew_defs()
	assert_eq((defs.get("crew", []) as Array).size(), 8, "the authored cast is eight")
	assert_almost_eq(float(defs.get("generalist_bonus", 0.0)), 1.25, 0.001)
	var survivor: Dictionary = defs.get("survivor", {})
	assert_true(float(survivor.get("chance_per_run", 0.0)) > 0.0)
	assert_true(float(survivor.get("drift_speed", 0.0)) > 0.0)
	for row_v in defs.get("crew", []):
		var row := row_v as Dictionary
		assert_true(String(row.get("id", "")) != "")
		assert_true(String(row.get("name", "")) != "")
		assert_true(String(row.get("line", "")) != "", "every rescue needs a line: %s" % row.get("id"))
		assert_true(float(row.get("bonus", 0.0)) > 1.0, "a specialist must beat a generalist: %s" % row.get("id"))

func test_crew_ids_are_unique() -> void:
	var seen := {}
	for row_v in crew_defs().get("crew", []):
		var id := String((row_v as Dictionary).get("id", ""))
		assert_false(seen.has(id), "duplicate crew id: %s" % id)
		seen[id] = true

func test_specialties_are_workable_and_workable_ids_are_real_buildings() -> void:
	var defs := crew_defs()
	var workable: Array = defs.get("workable", [])
	assert_true(workable.size() > 0)
	for building_v in workable:
		assert_has(DataDefs.buildings.get("defs", {}), String(building_v),
			"workable entry is not a building def: %s" % String(building_v))
	for row_v in defs.get("crew", []):
		var row := row_v as Dictionary
		assert_true(workable.has(String(row.get("specialty", ""))),
			"specialty outside workable: %s" % row.get("id"))

func test_autoload_exposes_crew() -> void:
	assert_eq((DataDefs.crew.get("crew", []) as Array).size(), 8,
		"DataDefs must load crew.json at boot")
