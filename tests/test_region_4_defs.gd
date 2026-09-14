extends GutTest

const SkyfieldScene := preload("res://game/run/skyfield.tscn")

var run_defs := {"sea_payout": {"scrap": 1}, "pod": {"radius": 12.0, "bounce": 0.55, "friction": 0.2}}


func test_region_4_parses_with_required_keys() -> void:
	var region := DataDefs.skyfield("region_4")
	assert_eq(String(region.get("name", "")), "Stormglass Verge")
	assert_has(region, "board")
	assert_eq((region.get("gizmo_slots", []) as Array).size(), 10, "spec: 10 slots")
	assert_eq((region.get("barges", []) as Array).size(), 5)
	assert_eq(int((region.get("sea_payout", {}) as Dictionary).get("scrap", 0)), 3)


func test_region_4_barge_ids_are_unique() -> void:
	assert_eq(Skyfield.duplicate_barge_ids(DataDefs.skyfield("region_4").get("barges", [])), [])


func test_region_4_quota_tiers_are_three_and_ascending() -> void:
	var tiers: Array = DataDefs.skyfield("region_4").get("quota_tiers", [])
	assert_eq(tiers.size(), 3)
	var previous := 0
	for tier in tiers:
		var quota := int((tier as Dictionary).get("scrap_quota", 0))
		assert_true(quota > previous)
		assert_true(float((tier as Dictionary).get("payout_multiplier", 0.0)) > 1.0)
		previous = quota


func test_region_4_drops_stormglass_on_right_barges() -> void:
	var total := 0
	for barge in DataDefs.skyfield("region_4").get("barges", []):
		total += int(((barge as Dictionary).get("payout", {}) as Dictionary).get("stormglass", 0))
	assert_true(total >= 3, "spec 3.4: the region drops its distinctive material")


func test_region_4_peg_types_are_known_and_stormy() -> void:
	var storm := 0
	for peg in DataDefs.skyfield("region_4").get("pegs", []):
		var type := String((peg as Dictionary).get("type", ""))
		assert_true(type == "" or type == "storm", "region 4 uses only storm hazards")
		if type == "storm":
			storm += 1
	assert_eq(storm, 6)


func test_region_4_board_builds_with_storm_pegs() -> void:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	var region := DataDefs.skyfield("region_4")
	board.build(region, run_defs)
	assert_eq(board.get_node("Pegs").get_child_count(), (region.get("pegs", []) as Array).size())
	assert_eq(board.get_node("GizmoSlots").get_child_count(), 10)
	assert_eq(get_tree().get_nodes_in_group("storm_pegs").size(), 6)
