extends GutTest

const LoadoutScene := preload("res://game/ui/loadout_screen.tscn")
const TEST_SAVE := "user://test_loadout.json"

var screen


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	screen = add_child_autofree(LoadoutScene.instantiate())
	await wait_frames(1)

func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_loadout.json", "test_loadout.json.tmp", "test_loadout.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos)


func test_builds_one_row_per_region_slot() -> void:
	assert_eq(screen.get_node("Rows").get_child_count(), 6, "region_1 has 6 gizmo slots")

func test_tapping_a_row_cycles_the_slot() -> void:
	screen._on_slot_pressed("slot_0")
	var loadout := GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1")
	assert_true(loadout.has("slot_0"))
	assert_true(GizmoLoadout.owned(GameState.data["gizmos"]).has(loadout["slot_0"]))

func test_cycling_past_all_options_returns_to_empty() -> void:
	var owned_count: int = GizmoLoadout.owned(GameState.data["gizmos"]).size()
	for i in owned_count + 1:
		screen._on_slot_pressed("slot_0")
	assert_eq(GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1"), {},
		"one full cycle lands back on empty")

func test_same_gizmo_cannot_occupy_two_slots() -> void:
	screen._on_slot_pressed("slot_0")
	var first: String = GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1")["slot_0"]
	screen._on_slot_pressed("slot_1")
	var second: String = GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1").get("slot_1", "")
	assert_ne(first, second, "slot_1's first option skips what slot_0 holds")
