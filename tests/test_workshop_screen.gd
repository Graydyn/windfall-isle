extends GutTest

const WorkshopScene := preload("res://game/base/workshop_screen.tscn")
const TEST_SAVE := "user://test_workshop_screen.json"

var screen


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	GameState.data["currencies"]["scrap"] = 5000
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	screen = add_child_autofree(WorkshopScene.instantiate())
	await wait_physics_frames(1)

func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_workshop_screen.json", "test_workshop_screen.json.tmp", "test_workshop_screen.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings)


func test_one_row_per_owned_gizmo() -> void:
	assert_eq(screen.get_node("Rows").get_child_count(), 8, "all eight starters owned")

func test_craft_starts_through_model() -> void:
	screen._on_craft_pressed("wind_fan")
	assert_true(TimerService.active_timers().has("craft_wind_fan"))
	assert_eq(Economy.balance("scrap"), 5000 - 80)

func test_collect_merges_level() -> void:
	screen._on_craft_pressed("wind_fan")
	TimerService._state.data["timers"]["craft_wind_fan"]["ends_at"] = 0
	screen._on_collect_pressed("wind_fan")
	assert_eq(int(GameState.data["gizmos"]["owned"]["wind_fan"]), 2)

func test_no_workshop_blocks_crafting() -> void:
	GameState.data["island"]["plots"].clear()
	screen._on_craft_pressed("wind_fan")
	assert_false(TimerService.active_timers().has("craft_wind_fan"))

func test_skip_completes_a_craft_timer_then_collect_merges() -> void:
	screen._on_craft_pressed("wind_fan")
	screen._on_skip_pressed("craft_wind_fan")
	assert_true(TimerService.is_done("craft_wind_fan", TimeUtil.now()))
	screen._on_collect_pressed("wind_fan")
	assert_eq(int(GameState.data["gizmos"]["owned"]["wind_fan"]), 2,
		"skip then collect merges the level like any finished craft")

func test_tick_without_state_change_keeps_row_nodes_alive() -> void:
	var row_before: Node = screen.get_node("Rows").get_child(0)
	screen._refresh_tick()
	assert_true(is_instance_valid(row_before) and not row_before.is_queued_for_deletion(),
		"per-second ticks must not free a button under the player's finger")

func test_tick_updates_the_countdown_in_place() -> void:
	screen._on_craft_pressed("wind_fan")
	var label: Label = screen._gizmo_labels["wind_fan"]
	var text_before: String = label.text
	TimerService._state.data["timers"]["craft_wind_fan"]["ends_at"] = \
		int(TimerService._state.data["timers"]["craft_wind_fan"]["ends_at"]) - 5
	screen._refresh_tick()
	assert_true(is_instance_valid(label), "the label survives the tick")
	assert_ne(label.text, text_before, "the countdown advanced without a rebuild")

func test_tick_rebuilds_when_a_craft_finishes() -> void:
	screen._on_craft_pressed("wind_fan")
	screen._refresh_tick()
	var running_signature: String = screen._last_signature
	TimerService._state.data["timers"]["craft_wind_fan"]["ends_at"] = 0
	screen._refresh_tick()
	assert_ne(screen._last_signature, running_signature,
		"done is structural: the Collect! button must appear")
