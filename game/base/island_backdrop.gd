extends Control
class_name IslandBackdrop
## The island map's painted background. The sky and cloud sea are code-drawn;
## the home landmass draws as delivered art with a code fallback. The islets
## render their own art in IslandIsletNode (the drawn bridges were retired
## 2026-10-15: decorative only, and they never read well at map angles). A
## full hand-painted vista at VISTA_PATH overrides the layers entirely.

const VISTA_PATH := "res://game/art/regions/island_vista.png"
const ISLAND_PATH := "res://game/art/buildings/island_home.png"

var _vista: Texture2D = null
var _island: Texture2D = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(VISTA_PATH):
		_vista = load(VISTA_PATH)
	if ResourceLoader.exists(ISLAND_PATH):
		_island = load(ISLAND_PATH)


func _draw() -> void:
	if _vista != null:
		draw_texture_rect(_vista, Rect2(Vector2.ZERO, size), false)
		return
	# Sky: a vertical gradient from deep day blue to a warm horizon.
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
		PackedColorArray([Color(0.45, 0.65, 0.9), Color(0.45, 0.65, 0.9),
			Color(0.85, 0.8, 0.75), Color(0.85, 0.8, 0.75)]))
	# The home plateau behind the plots (grass carries the pads; the rocky
	# rim lands under the crew band).
	if _island != null:
		draw_texture_rect(_island, Rect2(25, 60, 670, 860), false)
	else:
		draw_polygon(_island_points(Vector2(360, 490), 335.0, 430.0),
			PackedColorArray([Color(0.45, 0.58, 0.38)]))
	# The cloud sea closes the bottom of the map.
	draw_rect(Rect2(0, size.y - 160, size.x, 160), Color(0.92, 0.93, 0.96, 0.9))


func _island_points(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 20:
		var angle := TAU * float(i) / 20.0
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points
