extends GutTest

const MainScene := preload("res://game/main.tscn")
const TEST_SAVE := "user://test_main_boot.json"

var main


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy)
	GameState.data["created_at"] = 1000
	GameState.data["fuel"]["updated_at"] = 1000
	main = add_child_autofree(MainScene.instantiate())
	await wait_physics_frames(1)

func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_main_boot.json", "test_main_boot.json.tmp", "test_main_boot.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings)


func test_main_scene_boots_and_shows_balances() -> void:
	var text: String = main.get_node("DebugLabel").text
	assert_string_contains(text, "Scrap: ")
	assert_string_contains(text, "Fuel: ")

func test_launch_enabled_with_full_tank() -> void:
	assert_false(main.get_node("LaunchButton").disabled)

func test_launch_disabled_when_fuel_empty() -> void:
	GameState.data["fuel"]["amount"] = 0
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	main._refresh()
	assert_true(main.get_node("LaunchButton").disabled)

func test_gizmos_button_exists() -> void:
	assert_not_null(main.get_node_or_null("GizmosButton"))

func test_island_button_exists() -> void:
	assert_not_null(main.get_node_or_null("IslandButton"))

func test_refill_button_visible_with_grant_service() -> void:
	assert_true(main.get_node("RefillButton").visible,
		"GrantAdService makes every placement available")

func test_refill_button_disabled_at_full_tank() -> void:
	main._refresh()
	assert_true(main.get_node("RefillButton").disabled, "tank starts full")

func test_refill_grants_full_tank_and_counts_the_use() -> void:
	GameState.data["fuel"]["amount"] = 0
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	main._on_refill_pressed()
	assert_eq(FuelModel.current(GameState.data["fuel"], TimeUtil.now()), int(GameState.data["fuel"]["cap"]))
	assert_eq(AdLimits.used(GameState.data, "fuel_refill", TimeUtil.now()), 1)

func test_refill_stops_at_the_daily_limit() -> void:
	var limit := int((DataDefs.retention["ads"] as Dictionary)["fuel_refills_per_day"])
	for i in limit:
		GameState.data["fuel"]["amount"] = 0
		GameState.data["fuel"]["updated_at"] = TimeUtil.now()
		main._on_refill_pressed()
	GameState.data["fuel"]["amount"] = 0
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	main._on_refill_pressed()
	assert_eq(FuelModel.current(GameState.data["fuel"], TimeUtil.now()), 0,
		"spec 6: fuel refills are limited per day")
