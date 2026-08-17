class_name DriftZone
extends Area2D
## One drift current (spec 3.4 hazard; region JSON "drift_zones"): a hostile
## wind column pushing pods sideways every physics frame, the board-owned
## twin of the Wind Fan. A board feature, not a gizmo: no level, no defs
## lookup, no context. Gyro Dampers (group "gyro_dampers") null the push for
## any pod inside their field; the zone asks, the damper just exists.

var force_vector := Vector2.ZERO


func setup(zone_defs: Dictionary) -> void:
	position = Vector2(float(zone_defs.get("x", 0)), float(zone_defs.get("y", 0)))
	force_vector = Vector2(float(zone_defs.get("force", 220.0)) * float(zone_defs.get("direction", 1.0)), 0.0)
	var half := Vector2(float(zone_defs.get("half_width", 100)), float(zone_defs.get("half_height", 60)))
	var shape := RectangleShape2D.new()
	shape.size = half * 2.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	visual.color = Color(0.8, 0.7, 0.5, 0.22)
	add_child(visual)
	add_to_group("drift_zones")


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is RigidBody2D and not _damped(body):
			body.apply_central_force(force_vector)


func _damped(body: Node2D) -> bool:
	for damper in get_tree().get_nodes_in_group("gyro_dampers"):
		if body.global_position.distance_to((damper as Node2D).global_position) <= float(damper.field_radius):
			return true
	return false
