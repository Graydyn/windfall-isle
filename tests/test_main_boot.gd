extends GutTest

const MainScene := preload("res://game/main.tscn")

var main


func before_each() -> void:
	GameState.data = SaveSchema.default_data(DataDefs.economy)
	GameState.data["created_at"] = 1000
	GameState.data["fuel"]["updated_at"] = 1000
	main = add_child_autofree(MainScene.instantiate())
	await wait_physics_frames(1)

func after_all() -> void:
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos)


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
