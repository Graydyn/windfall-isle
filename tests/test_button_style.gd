extends GutTest
## The shared painted-button helper (extracted from the island screen's
## sheet styling) that every screen's buttons go through.


func test_apply_wires_the_button_art_on_all_states() -> void:
	var button := Button.new()
	autofree(button)
	ButtonStyle.apply(button)
	for state in ["normal", "hover", "pressed", "disabled"]:
		assert_true(button.has_theme_stylebox_override(state), state)
		var style := button.get_theme_stylebox(state)
		assert_true(style is StyleBoxTexture, state + " uses the painted art")
		assert_string_contains((style as StyleBoxTexture).texture.resource_path, "button")

func test_apply_sets_navy_text_and_pill_minimum() -> void:
	var button := Button.new()
	autofree(button)
	ButtonStyle.apply(button)
	assert_eq(button.get_theme_color("font_color"), Color(0.12, 0.16, 0.3))
	assert_eq(button.custom_minimum_size, Vector2(280, 60))

func test_apply_takes_a_custom_minimum_width() -> void:
	var button := Button.new()
	autofree(button)
	ButtonStyle.apply(button, 210.0)
	assert_eq(button.custom_minimum_size, Vector2(210, 60))
