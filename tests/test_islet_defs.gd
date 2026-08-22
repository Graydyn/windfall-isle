extends GutTest

const DataDefsScript := preload("res://game/autoload/data_defs.gd")


func islet_defs() -> Dictionary:
	return DataDefsScript.load_json("res://game/data/islets.json")


func test_islets_load_in_order_with_required_keys() -> void:
	var defs := islet_defs()
	var rows: Array = defs.get("islets", [])
	assert_eq(rows.size(), 2, "this plan ships Lantern Shoal and Foundry Rock")
	assert_eq(String((rows[0] as Dictionary)["id"]), "lantern_shoal", "array order gates offering")
	assert_eq(String((rows[1] as Dictionary)["id"]), "foundry_rock")
	for row_v in rows:
		var row := row_v as Dictionary
		assert_true(String(row.get("name", "")) != "", "islet needs a display name: %s" % row.get("id"))
		assert_true((row.get("cost", {}) as Dictionary).size() > 0, "islet needs a cost: %s" % row.get("id"))
		assert_true(int(row.get("restore_seconds", 0)) > 0, "islet needs a duration: %s" % row.get("id"))
		assert_true((row.get("plots", []) as Array).size() > 0, "islet needs plots: %s" % row.get("id"))
		var vignette: Dictionary = row.get("vignette", {})
		assert_true(String(vignette.get("title", "")) != "", "vignette needs a title: %s" % row.get("id"))
		assert_true((vignette.get("lines", []) as Array).size() > 0, "vignette needs lines: %s" % row.get("id"))

func test_foundry_rock_is_the_brasswork_sink() -> void:
	var rows: Array = islet_defs().get("islets", [])
	var foundry := rows[1] as Dictionary
	assert_true(int((foundry["cost"] as Dictionary).get("brasswork", 0)) > 0,
		"spec: the late islet gates on Region 2 currency")

func test_islet_plot_ids_avoid_the_home_namespace() -> void:
	for row_v in islet_defs().get("islets", []):
		var row := row_v as Dictionary
		for plot in row.get("plots", []):
			assert_false(String(plot).begins_with("plot_"),
				"islet plots must never collide with home plots: %s" % String(plot))

func test_islet_ids_are_unique() -> void:
	var seen := {}
	for row_v in islet_defs().get("islets", []):
		var id := String((row_v as Dictionary).get("id", ""))
		assert_false(seen.has(id), "duplicate islet id: %s" % id)
		seen[id] = true

func test_autoload_exposes_islets() -> void:
	assert_true((DataDefs.islets.get("islets", []) as Array).size() > 0,
		"DataDefs must load islets.json at boot")
