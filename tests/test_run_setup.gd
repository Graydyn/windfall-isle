extends GutTest
## The setup phase (spec: drag-drop gizmo setup): the scene opens over the
## built board with nothing installed and no fuel spent; Start is the single
## commit point. Scene-changing handlers (Back) are never invoked here.

const RunScene := preload("res://game/run/salvage_run.tscn")
const TEST_SAVE := "user://test_run_setup.json"

var scene


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	GameState.data["created_at"] = 1000
	GameState.data["fuel"]["updated_at"] = 1000
	scene = add_child_autofree(RunScene.instantiate())


func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_run_setup.json", "test_run_setup.json.tmp", "test_run_setup.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings)


func test_scene_opens_in_setup() -> void:
	assert_false(scene.get_node("DropController").enabled, "no aiming during setup")
	assert_true(scene.get_node("UI/SetupUI").visible)
	assert_false(scene.get_node("UI/AbandonButton").visible)
	assert_eq(scene.get_node("Skyfield/Gizmos").get_child_count(), 0,
		"gizmos install at Start, not at boot")
	assert_eq(FuelModel.current(GameState.data["fuel"], TimeUtil.now()), 5,
		"no fuel is spent by entering the scene")
	assert_string_contains(String(scene.get_node("UI/HudLabel").text), "Place your gizmos")

func test_drops_are_ignored_during_setup() -> void:
	var drops_before: int = scene.model.drops_remaining()
	scene._on_drop_requested(360.0)
	assert_eq(scene.model.drops_remaining(), drops_before, "a drop before Start must not consume")
	assert_eq(get_tree().get_nodes_in_group("pods").size(), 0)

func test_start_spends_the_region_cost_once_and_installs() -> void:
	GizmoLoadout.set_slot(GameState.data["gizmos"], "region_1", "slot_0", "wind_fan")
	scene._on_start_pressed()
	assert_eq(FuelModel.current(GameState.data["fuel"], TimeUtil.now()), 4, "region 1 costs 1 fuel")
	assert_eq(scene.get_node("Skyfield/Gizmos").get_child_count(), 1, "the saved loadout installs at Start")
	assert_true(scene.get_node("DropController").enabled)
	assert_false(scene.get_node("UI/SetupUI").visible)
	assert_true(scene.get_node("UI/AbandonButton").visible)
	scene._on_start_pressed()
	assert_eq(FuelModel.current(GameState.data["fuel"], TimeUtil.now()), 4,
		"Start is a one-way gate; a second press spends nothing")

func test_start_persists_the_debit() -> void:
	scene._on_start_pressed()
	var saved := SaveIO.new(TEST_SAVE).read()
	assert_eq(FuelModel.current(saved["fuel"], TimeUtil.now()), 4,
		"an OS kill right after Start must not refund the fuel")

func test_start_without_fuel_stays_in_setup_and_explains() -> void:
	GameState.data["fuel"]["amount"] = 0
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	scene._on_start_pressed()
	assert_false(scene.get_node("DropController").enabled)
	assert_true(scene.get_node("UI/SetupUI").visible)
	assert_eq(scene.get_node("Skyfield/Gizmos").get_child_count(), 0)
	assert_string_contains(String(scene.get_node("UI/SetupUI/SetupStatus").text), "Not enough fuel")

func test_setup_tick_reflects_affordability() -> void:
	scene._setup_tick()
	assert_false(scene.get_node("UI/SetupUI/StartButton").disabled)
	assert_string_contains(String(scene.get_node("UI/SetupUI/StartButton").text), "1 fuel")
	GameState.data["fuel"]["amount"] = 0
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	scene._setup_tick()
	assert_true(scene.get_node("UI/SetupUI/StartButton").disabled)

func test_boon_close_never_enables_drops_during_setup() -> void:
	# Unreachable in play (offers need catches), but the phase guard must hold:
	# _close_offer re-enables the controller only while RUNNING.
	scene._close_offer()
	assert_false(scene.get_node("DropController").enabled)

func test_back_button_exists_and_hud_returns_to_normal_after_start() -> void:
	assert_not_null(scene.get_node_or_null("UI/SetupUI/BackButton"))
	scene._on_start_pressed()
	assert_string_contains(String(scene.get_node("UI/HudLabel").text), "Drops left:")
