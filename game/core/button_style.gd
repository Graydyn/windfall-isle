class_name ButtonStyle
## The painted pill every screen's buttons share, extracted from the island
## screen's sheet styling so the launcher, run and workshop chrome match.

const BUTTON_ART := "res://game/art/ui/button.png"

static var _styles: Dictionary = {}


static func apply(button: Button, min_width := 280.0) -> void:
	if _styles.is_empty():
		_build()
	if _styles.is_empty():
		return
	for state in _styles:
		button.add_theme_stylebox_override(String(state), _styles[state])
	button.add_theme_color_override("font_color", Color(0.12, 0.16, 0.3))
	button.add_theme_color_override("font_hover_color", Color(0.12, 0.16, 0.3))
	button.add_theme_color_override("font_pressed_color", Color(0.12, 0.16, 0.3))
	button.add_theme_color_override("font_disabled_color", Color(0.12, 0.16, 0.3, 0.5))
	# Pills hold a modest width and center; edge-to-edge buttons crowd the
	# painted frame (owner request, 2026-10-16).
	button.custom_minimum_size = Vector2(min_width, 60)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


static func _build() -> void:
	if not ResourceLoader.exists(BUTTON_ART):
		return
	var art: Texture2D = load(BUTTON_ART)
	var tints := {
		"normal": Color.WHITE,
		"hover": Color(1.06, 1.06, 1.06),
		"pressed": Color(0.88, 0.88, 0.88),
		"disabled": Color(0.72, 0.72, 0.72, 0.9),
	}
	for state in tints:
		var style := StyleBoxTexture.new()
		style.texture = art
		# button.png is a small rounded square centered on a mostly
		# transparent 384x112 canvas (jig centers its subjects), so the
		# nine-patch must slice the PAINTED region, not the whole canvas,
		# and its margins must stay under half the smallest drawn button.
		style.region_rect = Rect2(136, 2, 112, 108)
		style.texture_margin_left = 34.0
		style.texture_margin_right = 34.0
		style.texture_margin_top = 26.0
		style.texture_margin_bottom = 30.0
		style.set_content_margin_all(10.0)
		style.content_margin_left = 24.0
		style.content_margin_right = 24.0
		style.modulate_color = tints[state]
		_styles[String(state)] = style
