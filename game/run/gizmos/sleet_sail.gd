class_name SleetSail
extends GizmoBase
## Sleet Sail (region 3, rimeglass): pods inside its column fall at reduced
## gravity, drifting long enough to rack up more peg hits. The column WIDTH
## scales with level; the gravity factor is level-independent. gravity_scale
## restores on exit; a pod freed inside the zone exits via body_exited, so
## the is_instance_valid guard keeps the restore safe.

@onready var zone: Area2D = $Zone


func _configure() -> void:
	var rect := RectangleShape2D.new()
	rect.size = Vector2(scaled(float(defs.get("column_width", 80.0))), float(defs.get("column_height", 420.0)))
	$Zone/Shape.shape = rect
	zone.position = Vector2(0.0, -rect.size.y / 2.0)
	var visual: Polygon2D = $Visual
	visual.polygon = PackedVector2Array([
		Vector2(-20, -14), Vector2(20, -14), Vector2(20, 14), Vector2(-20, 14),
	])
	visual.color = Color(0.75, 0.9, 1.0)
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body is RigidBody2D and not body.has_meta("caught"):
		body.gravity_scale = float(defs.get("gravity_factor", 0.5))


func _on_body_exited(body: Node2D) -> void:
	if is_instance_valid(body) and body is RigidBody2D:
		body.gravity_scale = 1.0
