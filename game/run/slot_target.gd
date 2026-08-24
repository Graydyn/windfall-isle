class_name SlotTarget
extends Control
## Drop target for gizmo drags. A real slot (slot_id "slot_N") accepts any
## gizmo payload and draws its outline; the removal tray (slot_id "") accepts
## only placed gizmos (payloads with a from_slot). All drops delegate to one
## salvage_run callback so every mutation flows through a single function.

var slot_id := ""
var _on_drop: Callable = Callable()


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


func _draw() -> void:
	if slot_id != "":
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5), false, 2.0)
