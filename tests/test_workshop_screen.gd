extends GutTest

const WorkshopScene := preload("res://game/base/workshop_screen.tscn")
const TEST_SAVE := "user://test_workshop_screen.json"

var screen


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	GameState.data["currencies"]["scrap"] = 5000
	GameState.data["currencies"]["parts"] = 50
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


func _modal() -> PanelContainer:
	return screen.get_node("CraftModal")

func _action() -> Button:
	return screen.get_node("CraftModal/VBox/ActionRow/ActionButton")


func test_one_tile_per_recipe() -> void:
	assert_eq(screen.get_node("Tiles").get_child_count(), (DataDefs.gizmos["defs"] as Dictionary).size(),
		"every recipe shows, owned or not (craft-to-acquire)")

func test_every_gizmo_def_has_a_description() -> void:
	for gizmo_id in DataDefs.gizmos["defs"]:
		var def: Dictionary = DataDefs.gizmos["defs"][gizmo_id]
		assert_true(String(def.get("description", "")).length() > 0,
			"gizmo '%s' needs an authored description for the craft modal" % gizmo_id)

func test_tile_press_opens_modal_with_def_content() -> void:
	screen._on_tile_pressed("wind_fan")
	assert_true(_modal().visible, "pressing a tile opens the craft modal")
	assert_string_contains(screen.get_node("CraftModal/VBox/ModalTitle").text, "Wind Fan")
	assert_not_null(screen.get_node("CraftModal/VBox/ModalPicture").texture,
		"the modal shows the gizmo sprite")
	var def: Dictionary = (DataDefs.gizmos["defs"] as Dictionary)["wind_fan"]
	assert_eq(screen.get_node("CraftModal/VBox/ModalDescription").text, String(def["description"]))
	assert_string_contains(screen.get_node("CraftModal/VBox/ModalCost").text, "2 parts",
		"the modal shows the price the Craft tap will pay")

func test_modal_title_shows_rarity_and_level() -> void:
	screen._on_tile_pressed("wind_fan")
	var title: String = screen.get_node("CraftModal/VBox/ModalTitle").text
	assert_string_contains(title, "[Common]")
	assert_string_contains(title, "Lv 1")

func test_modal_close_hides_it() -> void:
	screen._on_tile_pressed("wind_fan")
	screen._on_modal_close_pressed()
	assert_false(_modal().visible)

func test_modal_craft_starts_through_model() -> void:
	screen._on_tile_pressed("wind_fan")
	screen._on_modal_action_pressed()
	assert_true(TimerService.active_timers().has("craft_wind_fan"))
	assert_eq(Economy.balance("parts"), 50 - 2)
	assert_true(_modal().visible, "the modal stays open showing the running craft")

func test_modal_shows_skip_while_running() -> void:
	screen._on_tile_pressed("wind_fan")
	screen._on_modal_action_pressed()
	assert_eq(_action().text, "Skip (ad)", "a running craft offers the ad skip")

func test_modal_skip_then_collect_merges_level() -> void:
	screen._on_tile_pressed("wind_fan")
	screen._on_modal_action_pressed()
	screen._on_modal_action_pressed()
	assert_true(TimerService.is_done("craft_wind_fan", TimeUtil.now()),
		"the stub ad service grants the skip instantly")
	assert_eq(_action().text, "Collect!")
	screen._on_modal_action_pressed()
	assert_eq(int(GameState.data["gizmos"]["owned"]["wind_fan"]), 2,
		"skip then collect merges the level like any finished craft")

func test_modal_collect_after_timer_finishes() -> void:
	screen._on_tile_pressed("wind_fan")
	screen._on_modal_action_pressed()
	TimerService._state.data["timers"]["craft_wind_fan"]["ends_at"] = 0
	screen._refresh_tick()
	assert_eq(_action().text, "Collect!", "a tick while the modal is open flips Skip to Collect")
	screen._on_modal_action_pressed()
	assert_eq(int(GameState.data["gizmos"]["owned"]["wind_fan"]), 2)

func test_modal_craft_failure_sets_status() -> void:
	GameState.data["currencies"]["parts"] = 0
	screen._rebuild()
	screen._on_tile_pressed("wind_fan")
	screen._on_modal_action_pressed()
	assert_false(TimerService.active_timers().has("craft_wind_fan"))
	assert_true(String(screen.get_node("CraftModal/VBox/ModalStatus").text).length() > 0,
		"a refused craft tells the player why instead of doing nothing")

func test_modal_at_max_level_disables_craft() -> void:
	GameState.data["gizmos"]["owned"]["wind_fan"] = int(DataDefs.gizmos["craft_max_level"])
	screen._rebuild()
	screen._on_tile_pressed("wind_fan")
	assert_true(_action().disabled, "no crafting past craft_max_level")
	assert_string_contains(screen.get_node("CraftModal/VBox/ModalCost").text, "Max level")

func test_no_workshop_blocks_crafting() -> void:
	GameState.data["island"]["plots"].clear()
	screen._on_tile_pressed("wind_fan")
	screen._on_modal_action_pressed()
	assert_false(TimerService.active_timers().has("craft_wind_fan"))

func test_locked_rarity_tile_is_disabled_and_dimmed() -> void:
	var tile: Button = screen._tiles["crystal_prism"]
	assert_true(tile.disabled, "a rarity-locked gizmo cannot open the craft modal")
	assert_almost_eq(tile.modulate.a, 0.5, 0.001, "locked tiles render dimmed")
	assert_string_contains(screen._tile_labels["crystal_prism"].text, "Requires Workshop Lv 2")

func test_unlocked_tile_is_enabled() -> void:
	var tile: Button = screen._tiles["wind_fan"]
	assert_false(tile.disabled)

func test_unowned_recipe_is_labeled_and_craftable() -> void:
	GameState.data["island"]["plots"]["plot_0"]["level"] = 3
	GameState.data["currencies"]["brasswork"] = 2
	screen._rebuild()
	assert_string_contains(screen._tile_labels["gyro_damper"].text, "not owned")
	screen._on_tile_pressed("gyro_damper")
	screen._on_modal_action_pressed()
	assert_true(TimerService.active_timers().has("craft_gyro_damper"))
	TimerService._state.data["timers"]["craft_gyro_damper"]["ends_at"] = 0
	screen._refresh_tick()
	screen._on_modal_action_pressed()
	assert_eq(int(GameState.data["gizmos"]["owned"]["gyro_damper"]), 1,
		"first craft grants ownership at level 1")

func test_tick_without_state_change_keeps_tile_nodes_alive() -> void:
	var tile_before: Node = screen.get_node("Tiles").get_child(0)
	screen._refresh_tick()
	assert_true(is_instance_valid(tile_before) and not tile_before.is_queued_for_deletion(),
		"per-second ticks must not free a button under the player's finger")

func test_tick_updates_the_countdown_in_place() -> void:
	screen._on_tile_pressed("wind_fan")
	screen._on_modal_action_pressed()
	screen._refresh_tick()
	var label: Label = screen._tile_labels["wind_fan"]
	var text_before: String = label.text
	TimerService._state.data["timers"]["craft_wind_fan"]["ends_at"] = \
		int(TimerService._state.data["timers"]["craft_wind_fan"]["ends_at"]) - 5
	screen._refresh_tick()
	assert_true(is_instance_valid(label), "the label survives the tick")
	assert_ne(label.text, text_before, "the countdown advanced without a rebuild")

func test_tick_rebuilds_when_a_craft_finishes() -> void:
	screen._on_tile_pressed("wind_fan")
	screen._on_modal_action_pressed()
	screen._refresh_tick()
	var running_signature: String = screen._last_signature
	TimerService._state.data["timers"]["craft_wind_fan"]["ends_at"] = 0
	screen._refresh_tick()
	assert_ne(screen._last_signature, running_signature,
		"done is structural: the Ready! state must appear")

func test_locked_craft_press_is_refused() -> void:
	GameState.data["currencies"]["cloudsilk"] = 50
	screen._craft("crystal_prism")
	assert_false(TimerService.active_timers().has("craft_crystal_prism"),
		"the model gate holds even if a Craft press sneaks through")

func test_workshop_upgrade_is_structural_for_the_signature() -> void:
	screen._refresh_tick()
	var locked_signature: String = screen._last_signature
	GameState.data["island"]["plots"]["plot_0"]["level"] = 2
	screen._refresh_tick()
	assert_ne(screen._last_signature, locked_signature,
		"unlocking a rarity must rebuild tiles, not just relabel them")

func test_inflight_craft_on_a_now_locked_gizmo_still_collects() -> void:
	GameState.data["island"]["plots"]["plot_0"]["level"] = 2
	GameState.data["currencies"]["cloudsilk"] = 50
	screen._rebuild()
	screen._on_tile_pressed("crystal_prism")
	screen._on_modal_action_pressed()
	GameState.data["island"]["plots"]["plot_0"]["level"] = 1
	TimerService._state.data["timers"]["craft_crystal_prism"]["ends_at"] = 0
	screen._rebuild()
	var tile: Button = screen._tiles["crystal_prism"]
	assert_false(tile.disabled, "a grandfathered in-flight craft keeps its tile tappable")
	screen._on_tile_pressed("crystal_prism")
	screen._on_modal_action_pressed()
	assert_eq(int(GameState.data["gizmos"]["owned"]["crystal_prism"]), 1,
		"the craft the player already paid for completes")
