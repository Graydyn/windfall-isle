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
