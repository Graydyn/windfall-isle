class_name WindFan
extends GizmoBase
## Wind Fan (spec 3.3): steady lateral push on any pod inside its column.

var _force_vector := Vector2.ZERO

@onready var zone: Area2D = $Zone


func _configure() -> void:
	var force := scaled(float(defs.get("force", 260.0)))
	_force_vector = Vector2(force * float(defs.get("direction", 1.0)), 0.0)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(float(defs.get("column_width", 90.0)), float(defs.get("column_height", 420.0)))
	$Zone/Shape.shape = rect
	zone.position = Vector2(0.0, -rect.size.y / 2.0)
	var visual: Polygon2D = $Visual
	visual.polygon = PackedVector2Array([
		Vector2(-22, -12), Vector2(22, -12), Vector2(22, 12), Vector2(-22, 12),
	])
	visual.color = Color(0.6, 0.8, 0.95)


func _physics_process(_delta: float) -> void:
	for body in zone.get_overlapping_bodies():
		if body is RigidBody2D:
			body.apply_central_force(_force_vector)
