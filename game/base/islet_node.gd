extends Button
class_name IslandIsletNode
## One tappable islet marker on the island map. Pure presentation; the
## screen computes the state and routes the tap by islet state.

signal islet_tapped(islet_id: String)

var islet_id := ""

var _art: TextureRect


func _init(id: String) -> void:
	islet_id = id
	flat = true
	# PASS, not STOP: drags must climb to the ScrollContainer so a pan can
	# start on a button (same ancestor-walk rule as the Plan 9/12 DnD lesson).
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(200.0, 220.0)
	size = custom_minimum_size
	pressed.connect(func() -> void: islet_tapped.emit(islet_id))
	_art = TextureRect.new()
	_art.position = Vector2(12, 0)
	_art.size = Vector2(176, 176)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)


func render(state: Dictionary) -> void:
	var art_path := String(state.get("art", ""))
	if art_path != "" and ResourceLoader.exists(art_path):
		_art.texture = load(art_path)
	else:
		_art.texture = null
	modulate.a = 0.4 if bool(state.get("dim", false)) else 1.0
