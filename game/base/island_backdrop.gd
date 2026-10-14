extends Control
class_name IslandBackdrop
## The island map's painted background. The sky, cloud sea and layout are
## code-drawn; the landmass, islet rocks and bridges draw as delivered art
## with code fallbacks so the map reads as a place even art-less. A full
## hand-painted vista at VISTA_PATH overrides the layered pieces entirely.
## Bridges render here because they span between map nodes rather than
## belonging to any one of them.

const VISTA_PATH := "res://game/art/regions/island_vista.png"
const ISLAND_PATH := "res://game/art/buildings/island_home.png"
const ROCK_PATH := "res://game/art/buildings/islet_rock.png"
const BRIDGE_PATHS := {
	"broken": "res://game/art/buildings/bridge_broken.png",
	"scaffold": "res://game/art/buildings/bridge_scaffold.png",
	"restored": "res://game/art/buildings/bridge_restored.png",
}

var _bridges: Array = []
var _vista: Texture2D = null
var _island: Texture2D = null
var _rock: Texture2D = null
var _bridge_art: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(VISTA_PATH):
		_vista = load(VISTA_PATH)
	if ResourceLoader.exists(ISLAND_PATH):
		_island = load(ISLAND_PATH)
	if ResourceLoader.exists(ROCK_PATH):
		_rock = load(ROCK_PATH)
	for state in BRIDGE_PATHS:
		var path := String(BRIDGE_PATHS[state])
		if ResourceLoader.exists(path):
			_bridge_art[state] = load(path)


func set_bridges(bridges: Array) -> void:
	_bridges = bridges
	queue_redraw()


func _draw() -> void:
	if _vista != null:
		draw_texture_rect(_vista, Rect2(Vector2.ZERO, size), false)
	else:
		_draw_fallback()
	for bridge_v in _bridges:
		_draw_bridge(bridge_v as Dictionary)


func _draw_fallback() -> void:
	# Sky: a vertical gradient from deep day blue to a warm horizon.
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
		PackedColorArray([Color(0.45, 0.65, 0.9), Color(0.45, 0.65, 0.9),
			Color(0.85, 0.8, 0.75), Color(0.85, 0.8, 0.75)]))
	# The home plateau behind the plots (grass carries the pads; the rocky
	# rim lands under the crew band).
	if _island != null:
		draw_texture_rect(_island, Rect2(25, 150, 670, 860), false)
	else:
		draw_polygon(_island_points(Vector2(360, 580), 335.0, 430.0),
			PackedColorArray([Color(0.45, 0.58, 0.38)]))
	# Islet rocks.
	if _rock != null:
		draw_texture_rect(_rock, Rect2(70, 1130, 240, 340), false)
		draw_texture_rect(_rock, Rect2(410, 1470, 260, 360), false)
	else:
		draw_polygon(_island_points(Vector2(190, 1300), 120.0, 170.0),
			PackedColorArray([Color(0.5, 0.52, 0.45)]))
		draw_polygon(_island_points(Vector2(540, 1650), 130.0, 180.0),
			PackedColorArray([Color(0.48, 0.46, 0.44)]))
	# The cloud sea closes the bottom of the map.
	draw_rect(Rect2(0, size.y - 160, size.x, 160), Color(0.92, 0.93, 0.96, 0.9))


func _island_points(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 20:
		var angle := TAU * float(i) / 20.0
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points


func _draw_bridge(bridge: Dictionary) -> void:
	var from_point: Vector2 = bridge.get("from", Vector2.ZERO)
	var to_point: Vector2 = bridge.get("to", Vector2.ZERO)
	var state := String(bridge.get("state", "broken"))
	var art: Texture2D = _bridge_art.get(state)
	if art != null:
		# The art is a horizontal span; rotate it onto the segment and give
		# both ends a little overlap so the planks tuck into the land.
		var span := to_point - from_point
		var length := span.length() + 80.0
		var height := length * 0.4
		draw_set_transform((from_point + to_point) / 2.0, span.angle(), Vector2.ONE)
		draw_texture_rect(art, Rect2(-length / 2.0, -height / 2.0, length, height), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	match state:
		"restored":
			draw_line(from_point, to_point, Color(0.55, 0.4, 0.25), 6.0)
			draw_line(from_point, to_point, Color(0.75, 0.6, 0.4), 2.0)
		"scaffold":
			draw_dashed_line(from_point, to_point, Color(0.7, 0.65, 0.5), 4.0, 12.0)
		_:
			# Broken: two stubs reaching toward each other across the gap.
			var dir := (to_point - from_point).normalized()
			draw_line(from_point, from_point + dir * 36.0, Color(0.5, 0.38, 0.28), 5.0)
			draw_line(to_point, to_point - dir * 36.0, Color(0.5, 0.38, 0.28), 5.0)
