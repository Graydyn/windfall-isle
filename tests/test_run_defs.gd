extends GutTest


func test_run_defs_load_with_required_keys() -> void:
	assert_has(DataDefs.run, "fuel_cost")
	assert_has(DataDefs.run, "drops_per_run")
	assert_has(DataDefs.run, "max_active_pods")
	assert_has(DataDefs.run, "pod_timeout_seconds")
	assert_has(DataDefs.run, "pod")
	assert_has(DataDefs.run, "sea_payout")
	assert_true(int(DataDefs.run["fuel_cost"]) > 0)
	assert_true(int(DataDefs.run["drops_per_run"]) >= 8, "spec 3.2: 8-12 drops")
	assert_true(int(DataDefs.run["sea_payout"]["scrap"]) >= 1, "sea payout is never zero (spec 3.1)")

func test_region_1_layout() -> void:
	var region: Dictionary = DataDefs.skyfield("region_1")
	assert_has(region, "board")
	for key in ["left", "right", "top", "bottom"]:
		assert_has(region["board"], key)
	assert_eq(region["pegs"].size(), 32)
	assert_eq(region["barges"].size(), 5, "spec 3.1: 3-5 collection barges")
	for barge in region["barges"]:
		assert_has(barge, "payout")
		assert_true((barge["payout"] as Dictionary).size() > 0)
	assert_eq(region["gizmo_slots"].size(), 6, "spec MVP: ~6 gizmo slots")

func test_unknown_skyfield_returns_empty() -> void:
	assert_eq(DataDefs.skyfield("region_nope"), {})
	assert_push_error_count(1)
