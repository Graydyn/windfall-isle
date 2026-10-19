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


func test_main_scene_boots_and_shows_fuel_only() -> void:
	assert_null(main.get_node_or_null("DebugLabel"),
		"the currency dump is gone; only fuel matters on the launcher")
	var text: String = main.get_node("FuelRow/FuelLabel").text
	assert_string_contains(text, "/")

func test_fuel_label_is_readable() -> void:
	var label: Label = main.get_node("FuelRow/FuelLabel")
	assert_true(label.get_theme_font_size("font_size") >= 28, "larger than the default")
	assert_ne(label.get_theme_color("font_color"), Color.WHITE, "not white on the sky art")

func test_fuel_icon_shows_the_fuel_art() -> void:
	assert_string_contains(main.get_node("FuelRow/FuelIcon").texture.resource_path, "fuel")

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

func test_refill_button_is_gone() -> void:
	assert_null(main.get_node_or_null("RefillButton"),
		"the grey button became the ad-badged icon plus a confirm modal")

func test_refill_icon_hidden_at_full_tank() -> void:
	main._refresh()
	assert_false(main.get_node("FuelRefillIcon").visible, "tank starts full")

func test_refill_icon_visible_when_fuel_is_down() -> void:
	GameState.data["fuel"]["amount"] = 0
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	main._refresh()
	assert_true(main.get_node("FuelRefillIcon").visible,
		"GrantAdService makes every placement available")
	assert_string_contains(main.get_node("FuelRefillIcon/AdBadge").texture.resource_path, "ad_badge")

func test_refill_press_opens_the_ad_modal_without_granting() -> void:
	GameState.data["fuel"]["amount"] = 0
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	main._refresh()
	main._on_refill_pressed()
	assert_true(main.get_node("AdModal").visible,
		"the player must be told an ad will play before it does")
	assert_true(main.get_node("ModalBlock").visible)
	assert_eq(FuelModel.current(GameState.data["fuel"], TimeUtil.now()), 0,
		"opening the modal grants nothing")

func test_refill_watch_grants_full_tank_counts_the_use_and_closes() -> void:
	GameState.data["fuel"]["amount"] = 0
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	main._on_refill_pressed()
	main._on_refill_watch_pressed()
	assert_eq(FuelModel.current(GameState.data["fuel"], TimeUtil.now()), int(GameState.data["fuel"]["cap"]))
	assert_eq(AdLimits.used(GameState.data, "fuel_refill", TimeUtil.now()), 1)
	assert_false(main.get_node("AdModal").visible)
	assert_false(main.get_node("ModalBlock").visible)

func test_refill_cancel_closes_without_granting() -> void:
	GameState.data["fuel"]["amount"] = 0
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	main._on_refill_pressed()
	main._on_refill_cancel_pressed()
	assert_false(main.get_node("AdModal").visible)
	assert_eq(FuelModel.current(GameState.data["fuel"], TimeUtil.now()), 0)
	assert_eq(AdLimits.used(GameState.data, "fuel_refill", TimeUtil.now()), 0)

func test_refill_stops_at_the_daily_limit() -> void:
	var limit := int((DataDefs.retention["ads"] as Dictionary)["fuel_refills_per_day"])
	GameState.data["ads"] = {"day": DailyCrate.day_of(TimeUtil.now()), "counts": {"fuel_refill": limit}}
	GameState.data["fuel"]["amount"] = 0
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	main._refresh()
	assert_false(main.get_node("FuelRefillIcon").visible, "the icon hides at the limit")
	main._on_refill_pressed()
	main._on_refill_watch_pressed()
	assert_eq(FuelModel.current(GameState.data["fuel"], TimeUtil.now()), 0,
		"spec 6: fuel refills are limited per day")

func test_region_button_is_gone() -> void:
	assert_null(main.get_node_or_null("RegionButton"),
		"the selector became the background plus arrow buttons")

func test_region_label_shows_the_home_region_name_only() -> void:
	main._refresh()
	assert_string_contains(main.get_node("RegionLabel").text, "Home Skies")
	assert_false(main.get_node("RegionLabel").text.contains("fuel"),
		"the cost moved into the launch button")

func test_region_label_is_readable() -> void:
	var label: Label = main.get_node("RegionLabel")
	assert_true(label.get_theme_font_size("font_size") >= 36, "larger than the default")
	assert_ne(label.get_theme_color("font_color"), Color.WHITE, "not white on the sky art")

func test_region_emblem_is_gone() -> void:
	assert_null(main.get_node_or_null("RegionEmblem"))

func test_buttons_wear_the_painted_art() -> void:
	for path in ["LaunchButton", "IslandButton", "AdModal/VBox/AdWatch", "AdModal/VBox/AdCancel"]:
		assert_true(main.get_node(path).has_theme_stylebox_override("normal"),
			path + " uses ui/button.png, not the grey default")

func test_region_arrows_wear_the_arrow_art() -> void:
	assert_string_contains(main.get_node("RegionPrev").texture_normal.resource_path, "arrow_left")
	assert_string_contains(main.get_node("RegionNext").texture_normal.resource_path, "arrow_right")

func test_launch_button_carries_the_fuel_cost() -> void:
	main._refresh()
	assert_string_contains(main.get_node("LaunchButton").text, "(1 fuel)")

func test_region_background_shows_the_selected_region() -> void:
	main._refresh()
	assert_not_null(main.get_node("RegionBackground").texture)
	assert_string_contains(main.get_node("RegionBackground").texture.resource_path, "region_1_bg")

func test_arrows_hidden_without_a_dock() -> void:
	main._refresh()
	assert_false(main.get_node("RegionPrev").visible,
		"a single unlocked region has nothing to cycle")
	assert_false(main.get_node("RegionNext").visible)

func test_arrows_visible_with_a_dock() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "dock", "level": 1}
	main._refresh()
	assert_true(main.get_node("RegionPrev").visible)
	assert_true(main.get_node("RegionNext").visible)

func test_cycling_without_a_dock_stays_home() -> void:
	main._on_region_next_pressed()
	assert_eq(String(GameState.data["expedition"]["region"]), "region_1",
		"region 2 is locked until the Dock exists (spec 4.1)")

func test_next_with_a_dock_selects_brasswork_reach_and_persists() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "dock", "level": 1}
	main._on_region_next_pressed()
	assert_eq(String(GameState.data["expedition"]["region"]), "region_2")
	assert_string_contains(main.get_node("RegionLabel").text, "Brasswork Reach")
	assert_string_contains(main.get_node("LaunchButton").text, "(2 fuel)")
	assert_string_contains(main.get_node("RegionBackground").texture.resource_path, "region_2_bg")
	var saved := SaveIO.new(TEST_SAVE).read()
	assert_eq(String((saved["expedition"] as Dictionary)["region"]), "region_2",
		"the selection survives an OS kill")

func test_prev_with_a_dock_wraps_to_brasswork_reach() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "dock", "level": 1}
	main._on_region_prev_pressed()
	assert_eq(String(GameState.data["expedition"]["region"]), "region_2",
		"prev from the first unlocked region wraps to the last")

func test_observatory_shows_the_discount() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "dock", "level": 1}
	GameState.data["island"]["plots"]["plot_3"] = {"building": "observatory", "level": 1}
	GameState.data["expedition"]["region"] = "region_2"
	main._refresh()
	assert_string_contains(main.get_node("LaunchButton").text, "(1 fuel)")

func test_launch_disabled_when_fuel_below_region_cost() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "dock", "level": 1}
	GameState.data["expedition"]["region"] = "region_2"
	GameState.data["fuel"]["amount"] = 1
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	main._refresh()
	assert_true(main.get_node("LaunchButton").disabled, "region 2 costs 2 fuel")

