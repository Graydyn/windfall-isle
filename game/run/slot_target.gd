class_name SlotTarget
extends Control
## Drop target for gizmo drags. A real slot (slot_id "slot_N") accepts any
## gizmo payload and draws its outline; the removal tray (slot_id "") accepts
## only placed gizmos (payloads with a from_slot). All drops delegate to one
## salvage_run callback so every mutation flows through a single function.

const SOCKET_TEXTURE := preload("res://game/art/run/slot_socket.png")
const SOCKET_HOVER_TEXTURE := preload("res://game/art/run/slot_socket_hover.png")

var slot_id := ""
var _on_drop: Callable = Callable()
var _drag_hover := false


func setup(id: String, on_drop: Callable) -> void:
	slot_id = id
	_on_drop = on_drop
	mouse_filter = Control.MOUSE_FILTER_STOP


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var payload := data as Dictionary
	if String(payload.get("gizmo", "")) == "":
		return false
	if slot_id == "":
		return String(payload.get("from_slot", "")) != ""
	return true


func _drop_data(_at: Vector2, data: Variant) -> void:
	if _on_drop.is_valid():
		_on_drop.call(data as Dictionary, slot_id)


func _process(_delta: float) -> void:
	# "Drop here" highlight: Godot has no drag-exit callback, so poll while a
	# drag is live. Real slots only; the removal tray stays undecorated.
	if slot_id == "":
		return
	var hovering := get_viewport().gui_is_dragging() and get_global_rect().has_point(get_global_mouse_position())
	if hovering != _drag_hover:
		_drag_hover = hovering
		queue_redraw()


func _draw() -> void:
	if slot_id != "":
		var texture := SOCKET_HOVER_TEXTURE if _drag_hover else SOCKET_TEXTURE
		draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
