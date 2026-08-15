extends GutTest


func test_main_scene_boots_and_shows_balances() -> void:
	var main: Control = add_child_autofree(preload("res://game/main.tscn").instantiate())
	await wait_frames(1)
	var text: String = main.get_node("DebugLabel").text
	assert_string_contains(text, "Scrap: ")
	assert_string_contains(text, "Fuel: ")
