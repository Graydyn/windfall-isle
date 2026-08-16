extends GutTest

const SkyfieldScene := preload("res://game/run/skyfield.tscn")

var run_defs := {"sea_payout": {"scrap": 1}, "pod": {"radius": 12.0, "bounce": 0.55, "friction": 0.2}}


func build_board(region: Dictionary) -> Skyfield:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	board.build(region, run_defs)
	return board


func test_builds_region_1_from_data() -> void:
	var board := build_board(DataDefs.skyfield("region_1"))
	assert_eq(board.get_node("Pegs").get_child_count(), 32)
	assert_eq(board.get_node("Barges").get_child_count(), 5)
	assert_eq(board.get_node("Walls").get_child_count(), 2)
	assert_eq(board.get_node("GizmoSlots").get_child_count(), 6)
	assert_not_null(board.get_node_or_null("Sea"))

func test_peg_positions_come_from_data() -> void:
	var board := build_board(DataDefs.skyfield("region_1"))
	var first_peg: Node2D = board.get_node("Pegs").get_child(0)
	assert_eq(first_peg.position, Vector2(100, 280))

func test_gizmo_slots_are_named_markers() -> void:
	var board := build_board(DataDefs.skyfield("region_1"))
	var slots := board.get_node("GizmoSlots")
	for i in slots.get_child_count():
		var slot: Node = slots.get_child(i)
		assert_true(slot is Marker2D)
		assert_eq(slot.name, "slot_%d" % i)

func test_sea_payout_exposed() -> void:
	var board := build_board(DataDefs.skyfield("region_1"))
	assert_eq(board.sea_payout, {"scrap": 1})

func drop_pod_over(board: Skyfield, x: float) -> Pod:
	var pod: Pod = preload("res://game/run/pod.tscn").instantiate()
	pod.position = Vector2(x, 160)
	pod.setup(run_defs["pod"])
	board.add_child(pod)
	return pod

func test_falling_pod_is_caught_by_barge() -> void:
	var board := build_board(DataDefs.load_json("res://tests/fixtures/test_region.json"))
	watch_signals(board)
	drop_pod_over(board, 360.0)
	var emitted: bool = await wait_for_signal(board.pod_caught, 5.0)
	assert_true(emitted, "pod should fall into the catch-all barge within 5s")
	var params: Array = get_signal_parameters(board, "pod_caught")
	assert_eq(int(params[1]["scrap"]), 12)

func test_pod_missing_all_barges_reaches_the_sea() -> void:
	var board := build_board(DataDefs.load_json("res://tests/fixtures/test_region_empty.json"))
	watch_signals(board)
	drop_pod_over(board, 360.0)
	var emitted: bool = await wait_for_signal(board.pod_caught, 5.0)
	assert_true(emitted, "sea must catch every miss (spec 3.1: never zero)")
	var params: Array = get_signal_parameters(board, "pod_caught")
	assert_eq(int(params[1]["scrap"]), 1)

const TEST_GIZMO_DEFS := {
	"defs": {
		"test_gizmo": {"name": "Test Gizmo", "scene": "res://tests/fixtures/test_gizmo.tscn", "power": 10.0}
	}
}


func test_install_gizmos_places_scene_at_marker() -> void:
	var board := build_board(DataDefs.skyfield("region_1"))
	board.install_gizmos({"slot_1": "test_gizmo"}, TEST_GIZMO_DEFS, {"test_gizmo": 3}, self)
	var gizmos: Node = board.get_node("Gizmos")
	assert_eq(gizmos.get_child_count(), 1)
	var gizmo: GizmoBase = gizmos.get_child(0)
	assert_eq(gizmo.position, board.get_node("GizmoSlots/slot_1").position)
	assert_eq(gizmo.level, 3)
	assert_eq(float(gizmo.defs["power"]), 10.0)
	assert_true(gizmo.context == self)
	assert_true(gizmo.configured, "_configure must run during setup")

func test_install_gizmos_skips_unknown_entries() -> void:
	var board := build_board(DataDefs.skyfield("region_1"))
	board.install_gizmos(
		{"slot_0": "no_such_gizmo", "slot_99": "test_gizmo", "slot_2": "test_gizmo"},
		TEST_GIZMO_DEFS, {"test_gizmo": 1}, self)
	assert_eq(board.get_node("Gizmos").get_child_count(), 1, "only the valid entry installs")

func test_gizmo_base_scaled() -> void:
	var gizmo: GizmoBase = autofree(GizmoBase.new())
	gizmo.level = 1
	assert_almost_eq(gizmo.scaled(100.0), 100.0, 0.001)
	gizmo.level = 3
	assert_almost_eq(gizmo.scaled(100.0), 150.0, 0.001)

func test_pod_caught_carries_source_tag() -> void:
	var board := build_board(DataDefs.load_json("res://tests/fixtures/test_region.json"))
	watch_signals(board)
	drop_pod_over(board, 360.0)
	var emitted: bool = await wait_for_signal(board.pod_caught, 5.0)
	assert_true(emitted)
	var params: Array = get_signal_parameters(board, "pod_caught")
	assert_eq(params[2], "barge")
