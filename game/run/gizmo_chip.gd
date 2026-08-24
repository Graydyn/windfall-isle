class_name GizmoChip
extends Label
## One draggable gizmo in the setup phase: a tray chip (from_slot == "") or a
## slot token (from_slot == its slot). Dimmed chips are inert; the placed
## gizmo is dragged from its slot token instead.

var gizmo_id := ""
var from_slot := ""
var draggable := true


func setup(id: String, display: String, source_slot: String) -> void:
	gizmo_id = id
	from_slot = source_slot
	text = display
	# PASS, not STOP: a chip must receive the drag press itself, yet let a
	# DROP released over it fall through Godot's ancestor walk to the
	# SlotTarget or tray beneath (STOP would terminate the walk and block
	# replacing an occupied slot or removing over a tray chip).
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_dimmed(dimmed: bool) -> void:
	draggable = not dimmed
	modulate.a = 0.4 if dimmed else 1.0


func _get_drag_data(_at: Vector2) -> Variant:
	if not draggable:
		return null
	# set_drag_preview is only legal while the viewport's drag is active
	# (true when the engine calls this hook; false when tests call it
	# directly, where an unguarded call pushes an engine error).
	if is_inside_tree() and get_viewport().gui_is_dragging():
		var preview := Label.new()
		preview.text = text
		set_drag_preview(preview)
	return {"gizmo": gizmo_id, "from_slot": from_slot}
