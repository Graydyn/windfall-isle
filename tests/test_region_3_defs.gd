extends GutTest

const SkyfieldScene := preload("res://game/run/skyfield.tscn")

var run_defs := {"sea_payout": {"scrap": 1}, "pod": {"radius": 12.0, "bounce": 0.55, "friction": 0.2}}


func test_region_3_parses_with_required_keys() -> void:
	var region := DataDefs.skyfield("region_3")
	assert_eq(String(region.get("name", "")), "Rimefall Shallows")
	assert_has(region, "board")
	assert_eq((region.get("gizmo_slots", []) as Array).size(), 9, "spec: 9 slots")
	assert_eq((region.get("barges", []) as Array).size(), 5)
	assert_eq(int((region.get("sea_payout", {}) as Dictionary).get("scrap", 0)), 3)


func test_region_3_barge_ids_are_unique() -> void:
	assert_eq(Skyfield.duplicate_barge_ids(DataDefs.skyfield("region_3").get("barges", [])), [])


func test_region_3_quota_tiers_are_three_and_ascending() -> void:
	var tiers: Array = DataDefs.skyfield("region_3").get("quota_tiers", [])
	assert_eq(tiers.size(), 3, "the first 3-tier region (tripwire fixes landed in this plan)")
	var previous := 0
	for tier in tiers:
		var quota := int((tier as Dictionary).get("scrap_quota", 0))
		assert_true(quota > previous)
		assert_true(float((tier as Dictionary).get("payout_multiplier", 0.0)) > 1.0)
		previous = quota


func test_region_3_drops_rimeglass_on_right_barges() -> void:
	var total := 0
	for barge in DataDefs.skyfield("region_3").get("barges", []):
		total += int(((barge as Dictionary).get("payout", {}) as Dictionary).get("rimeglass", 0))
	assert_true(total >= 3, "spec 3.4: the region drops its distinctive material")


func test_region_3_peg_types_are_known_and_icy() -> void:
	var ice := 0
	for peg in DataDefs.skyfield("region_3").get("pegs", []):
		var type := String((peg as Dictionary).get("type", ""))
		assert_true(type == "" or type == "ice", "region 3 uses only ice hazards")
		if type == "ice":
			ice += 1
	assert_eq(ice, 8)


func test_region_3_board_builds() -> void:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	var region := DataDefs.skyfield("region_3")
	board.build(region, run_defs)
	assert_eq(board.get_node("Pegs").get_child_count(), (region.get("pegs", []) as Array).size())
	assert_eq(board.get_node("GizmoSlots").get_child_count(), 9)
	assert_eq(int(board.sea_payout.get("scrap", 0)), 3)
