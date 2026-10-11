extends Button
class_name IslandIsletNode
## One tappable islet marker on the island map. Pure presentation; the
## screen computes the state and routes the tap by islet state.

signal islet_tapped(islet_id: String)

var islet_id := ""

var _art: TextureRect
var _name_label: Label
var _status_label: Label


func _init(id: String) -> void:
	islet_id = id
	flat = true
	custom_minimum_size = Vector2(160.0, 164.0)
	size = custom_minimum_size
	pressed.connect(func() -> void: islet_tapped.emit(islet_id))
	_art = TextureRect.new()
	_art.position = Vector2(24, 0)
	_art.size = Vector2(112, 112)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_name_label = _make_label(Rect2(0, 112, 160, 24), 14)
	_status_label = _make_label(Rect2(0, 136, 160, 26), 12)
	_status_label.modulate.a = 0.85


func render(state: Dictionary) -> void:
	var art_path := String(state.get("art", ""))
	if art_path != "" and ResourceLoader.exists(art_path):
		_art.texture = load(art_path)
	else:
		_art.texture = null
	_name_label.text = String(state.get("name", ""))
	_status_label.text = String(state.get("status", ""))
	modulate.a = 0.4 if bool(state.get("dim", false)) else 1.0


func _make_label(rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
