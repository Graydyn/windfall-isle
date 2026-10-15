extends Button
class_name IslandCrewToken
## One crewmember standing on the island shore. Unrescued crew are disabled
## silhouettes; rescued crew tap to cycle their assignment.

signal crew_tapped(crew_id: String)

var crew_id := ""

var _portrait: TextureRect
var _name_label: Label
var _line_label: Label


func _init(id: String) -> void:
	crew_id = id
	flat = true
	# PASS, not STOP: drags must climb to the ScrollContainer so a pan can
	# start on a button (same ancestor-walk rule as the Plan 9/12 DnD lesson).
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(72.0, 104.0)
	size = custom_minimum_size
	pressed.connect(func() -> void: crew_tapped.emit(crew_id))
	_portrait = TextureRect.new()
	_portrait.position = Vector2(4, 0)
	_portrait.size = Vector2(64, 64)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait)
	_name_label = _make_label(Rect2(0, 64, 72, 20), 12)
	_line_label = _make_label(Rect2(0, 84, 72, 20), 10)
	_line_label.modulate.a = 0.8


func render(state: Dictionary) -> void:
	var portrait_path := String(state.get("portrait", ""))
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		_portrait.texture = load(portrait_path)
	else:
		_portrait.texture = null
	var rescued := bool(state.get("rescued", false))
	disabled = not rescued
	_portrait.modulate.a = 1.0 if rescued else 0.5
	_name_label.text = String(state.get("name", ""))
	_line_label.text = String(state.get("line", ""))


func _make_label(rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
