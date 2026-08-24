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

func test_gizmos_button_is_gone() -> void:
	assert_null(main.get_node_or_null("GizmosButton"),
		"placement lives in the run scene's setup phase now")

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
	GameState.data["ads"] = {"day": DailyCrate.day_of(TimeUtil.now()), "counts": {"fuel_refill": limit}}
	GameState.data["fuel"]["amount"] = 0
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	main._on_refill_pressed()
	assert_eq(FuelModel.current(GameState.data["fuel"], TimeUtil.now()), 0,
		"spec 6: fuel refills are limited per day")

func test_region_button_shows_the_home_region() -> void:
	main._refresh()
	assert_string_contains(main.get_node("RegionButton").text, "Home Skies")
	assert_string_contains(main.get_node("RegionButton").text, "(1 fuel)")

func test_cycling_without_a_dock_stays_home() -> void:
	main._on_region_pressed()
	assert_eq(String(GameState.data["expedition"]["region"]), "region_1",
		"region 2 is locked until the Dock exists (spec 4.1)")

func test_cycling_with_a_dock_selects_brasswork_reach_and_persists() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "dock", "level": 1}
	main._on_region_pressed()
	assert_eq(String(GameState.data["expedition"]["region"]), "region_2")
	assert_string_contains(main.get_node("RegionButton").text, "Brasswork Reach")
	assert_string_contains(main.get_node("RegionButton").text, "(2 fuel)")
	var saved := SaveIO.new(TEST_SAVE).read()
	assert_eq(String((saved["expedition"] as Dictionary)["region"]), "region_2",
		"the selection survives an OS kill")

func test_dock_level_2_shows_the_discount() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "dock", "level": 2}
	GameState.data["expedition"]["region"] = "region_2"
	main._refresh()
	assert_string_contains(main.get_node("RegionButton").text, "(1 fuel)")

func test_launch_disabled_when_fuel_below_region_cost() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "dock", "level": 1}
	GameState.data["expedition"]["region"] = "region_2"
	GameState.data["fuel"]["amount"] = 1
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	main._refresh()
	assert_true(main.get_node("LaunchButton").disabled, "region 2 costs 2 fuel")

func test_debug_label_shows_brasswork() -> void:
	assert_string_contains(main.get_node("DebugLabel").text, "Brasswork: ")
