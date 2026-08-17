class_name PistonKicker
extends GizmoBase
## Piston Kicker (region 2 offense): fires the pod sideways with a sharp
## impulse on contact, once per pod per drop ("piston_kicked" meta; split
## clones carry no meta, so each clone earns its own kick). Impulse inside
## body_entered is safe per the Balloon Cluster precedent.

var _impulse_vector := Vector2.ZERO

@onready var zone: Area2D = $Zone


func _configure() -> void:
	var force := scaled(float(defs.get("force", 520.0)))
	_impulse_vector = Vector2(force * float(defs.get("direction", 1.0)), 0.0)
	var circle := CircleShape2D.new()
	circle.radius = float(defs.get("radius", 24.0))
	$Zone/Shape.shape = circle
	var visual: Polygon2D = $Visual
	visual.polygon = PackedVector2Array([
		Vector2(-24, -10), Vector2(10, -10), Vector2(24, 0), Vector2(10, 10), Vector2(-24, 10),
	])
	visual.color = Color(0.8, 0.55, 0.3)
	zone.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not (body is RigidBody2D) or body.has_meta("caught") or body.has_meta("piston_kicked"):
		return
	body.set_meta("piston_kicked", true)
	body.apply_central_impulse(_impulse_vector)
