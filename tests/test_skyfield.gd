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
	assert_eq(params[1], {"scrap": 12})

func test_pod_missing_all_barges_reaches_the_sea() -> void:
	var board := build_board(DataDefs.load_json("res://tests/fixtures/test_region_empty.json"))
	watch_signals(board)
	drop_pod_over(board, 360.0)
	var emitted: bool = await wait_for_signal(board.pod_caught, 5.0)
	assert_true(emitted, "sea must catch every miss (spec 3.1: never zero)")
	var params: Array = get_signal_parameters(board, "pod_caught")
	assert_eq(params[1], {"scrap": 1})
