extends GutTest

const LoadoutScene := preload("res://game/ui/loadout_screen.tscn")
const TEST_SAVE := "user://test_loadout.json"

var screen


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	screen = add_child_autofree(LoadoutScene.instantiate())
	await wait_physics_frames(1)

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

func test_slot_edit_persists_without_pressing_back() -> void:
	screen._on_slot_pressed("slot_0")
	var saved := SaveIO.new(TEST_SAVE).read()
	var loadout: Dictionary = ((saved["gizmos"] as Dictionary)["loadout"] as Dictionary).get("region_1", {})
	assert_true(loadout.has("slot_0"),
		"an OS kill right after a tap must not lose the edit (save-anywhere)")

func test_region_cycle_without_a_dock_is_a_no_op() -> void:
	screen._on_region_pressed()
	assert_eq(screen.region_id, "region_1")
	assert_eq(screen.get_node("Rows").get_child_count(), 6)

func test_region_cycle_with_a_dock_edits_brasswork_reach() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "dock", "level": 1}
	screen._on_region_pressed()
	assert_eq(screen.region_id, "region_2")
	assert_eq(screen.get_node("Rows").get_child_count(), 8, "region 2 has 8 slots")
	assert_string_contains(screen.get_node("RegionButton").text, "Brasswork Reach")
	var saved := SaveIO.new(TEST_SAVE).read()
	assert_eq(String((saved["expedition"] as Dictionary)["region"]), "region_2")

func test_slot_edits_land_in_the_cycled_region() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "dock", "level": 1}
	screen._on_region_pressed()
	screen._on_slot_pressed("slot_7")
	var loadout := GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_2")
	assert_true(loadout.has("slot_7"), "the edit belongs to region 2, not region 1")
	assert_eq(GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1"), {})
