extends Button
class_name IslandPlotNode
## One tappable building pad on the island map. Pure presentation: the
## island screen computes a state dictionary from the models and this node
## only renders it. Children all ignore the mouse so the Button receives
## every tap (repo lesson: never block the input walk with child filters).

signal plot_tapped(plot_id: String)

const PAD_ART := "res://game/art/buildings/plot_pad.png"
const OVERLAY_ART := "res://game/art/buildings/construction_overlay.png"
const GLOW_ART := "res://game/art/ui/ready_glow.png"
const PLOT_SIZE := 128.0

var plot_id := ""
var _empty := true

var _art: TextureRect
var _overlay: TextureRect
var _name_label: Label
var _status_label: Label
var _worker_badge: TextureRect
var _ready_glow: TextureRect
var _ready_badge: Label


func _init(id: String) -> void:
	plot_id = id
	flat = true
	custom_minimum_size = Vector2(PLOT_SIZE, PLOT_SIZE + 44.0)
	size = custom_minimum_size
	pressed.connect(func() -> void: plot_tapped.emit(plot_id))
	_art = _child_texture_rect(Rect2(16, 4, 96, 96))
	_overlay = _child_texture_rect(Rect2(16, 4, 96, 96))
	if ResourceLoader.exists(OVERLAY_ART):
		_overlay.texture = load(OVERLAY_ART)
	_overlay.visible = false
	_worker_badge = _child_texture_rect(Rect2(92, 68, 32, 32))
	_worker_badge.visible = false
	_name_label = _child_label(Rect2(0, 100, 128, 22), 13)
	_status_label = _child_label(Rect2(0, 122, 128, 20), 12)
	_status_label.modulate.a = 0.85
	_ready_glow = _child_texture_rect(Rect2(76, -8, 52, 52))
	if ResourceLoader.exists(GLOW_ART):
		_ready_glow.texture = load(GLOW_ART)
	_ready_glow.visible = false
	_ready_badge = _child_label(Rect2(96, 0, 28, 28), 26)
	# The starburst badge art replaces the lettered fallback when delivered.
	_ready_badge.text = "" if _ready_glow.texture != null else "!"
	_ready_badge.modulate = Color(1.0, 0.85, 0.2)
	_ready_badge.visible = false


func render(state: Dictionary) -> void:
	var kind := String(state.get("kind", "empty"))
	_empty = kind == "empty"
	var art_path := String(state.get("art", ""))
	if _empty:
		art_path = PAD_ART
	if art_path != "" and ResourceLoader.exists(art_path):
		_art.texture = load(art_path)
	else:
		_art.texture = null
	_art.modulate.a = 0.5 if kind == "constructing" else 1.0
	_overlay.visible = kind == "constructing" and _overlay.texture != null
	_name_label.text = String(state.get("name", ""))
	_status_label.text = String(state.get("status", ""))
	var worker_path := String(state.get("worker_portrait", ""))
	if worker_path != "" and ResourceLoader.exists(worker_path):
		_worker_badge.texture = load(worker_path)
		_worker_badge.visible = true
	else:
		_worker_badge.texture = null
		_worker_badge.visible = false
	_ready_badge.visible = bool(state.get("ready", false))
	_ready_glow.visible = _ready_badge.visible and _ready_glow.texture != null
	queue_redraw()


func _draw() -> void:
	# Pad-art fallback: an empty plot with no delivered pad sprite still
	# reads as a build site.
	if _empty and _art.texture == null:
		draw_rect(Rect2(18, 6, 92, 92), Color(1, 1, 1, 0.5), false, 2.0)


func _child_texture_rect(rect: Rect2) -> TextureRect:
	var tr := TextureRect.new()
	tr.position = rect.position
	tr.size = rect.size
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	return tr


func _child_label(rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
