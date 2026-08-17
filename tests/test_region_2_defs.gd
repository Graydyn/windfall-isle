extends GutTest

const SkyfieldScene := preload("res://game/run/skyfield.tscn")

var run_defs := {"sea_payout": {"scrap": 1}, "pod": {"radius": 12.0, "bounce": 0.55, "friction": 0.2}}


func test_region_2_parses_with_required_keys() -> void:
	var region := DataDefs.skyfield("region_2")
	assert_eq(String(region.get("name", "")), "Brasswork Reach")
	assert_has(region, "board")
	assert_eq((region.get("gizmo_slots", []) as Array).size(), 8, "spec: 8 slots, up from 6")
	assert_eq((region.get("barges", []) as Array).size(), 5)
	assert_eq((region.get("drift_zones", []) as Array).size(), 2)
	assert_eq(int((region.get("sea_payout", {}) as Dictionary).get("scrap", 0)), 2)

func test_region_2_barge_ids_are_unique() -> void:
	var region := DataDefs.skyfield("region_2")
	assert_eq(Skyfield.duplicate_barge_ids(region.get("barges", [])), [])

func test_region_2_quota_tiers_are_well_formed() -> void:
	var region := DataDefs.skyfield("region_2")
	var tiers: Array = region.get("quota_tiers", [])
	assert_eq(tiers.size(), 2)
	for tier in tiers:
		assert_true(int((tier as Dictionary).get("scrap_quota", 0)) > 0)
		assert_true(float((tier as Dictionary).get("payout_multiplier", 0.0)) > 1.0)

func test_region_2_drops_brasswork_on_outer_barges() -> void:
	var region := DataDefs.skyfield("region_2")
	var brasswork_total := 0
	for barge in region.get("barges", []):
		brasswork_total += int(((barge as Dictionary).get("payout", {}) as Dictionary).get("brasswork", 0))
	assert_true(brasswork_total >= 3, "spec 3.4: the region drops its distinctive material")

func test_region_2_board_builds() -> void:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	board.build(DataDefs.skyfield("region_2"), run_defs)
	assert_eq(board.get_node("Pegs").get_child_count(), 39)
	assert_eq(board.get_node("GizmoSlots").get_child_count(), 8)
	assert_eq(board.get_node("DriftZones").get_child_count(), 2)
	assert_eq(int(board.sea_payout.get("scrap", 0)), 2)
	var zones := board.get_node("DriftZones")
	assert_true((zones.get_child(0) as DriftZone).force_vector.x > 0.0, "upper zone pushes right")
	assert_true((zones.get_child(1) as DriftZone).force_vector.x < 0.0, "lower zone pushes left")

func test_starting_balances_carry_brasswork() -> void:
	assert_eq(int((DataDefs.economy["starting_balances"] as Dictionary).get("brasswork", -1)), 0)
