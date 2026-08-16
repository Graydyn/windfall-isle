class_name MagnetBuoy
extends GizmoBase
## Magnet Buoy (spec 3.3): curves pod trajectories toward itself with a
## steady radial pull inside its radius.

var _force := 240.0

@onready var zone: Area2D = $Zone


func _configure() -> void:
	_force = scaled(float(defs.get("force", 240.0)))
	var circle := CircleShape2D.new()
	circle.radius = float(defs.get("radius", 160.0))
	$Zone/Shape.shape = circle
	var visual: Polygon2D = $Visual
	visual.polygon = Geometry.circle_points(16.0, 8)
	visual.color = Color(0.55, 0.65, 0.9)


func _physics_process(_delta: float) -> void:
	for body in zone.get_overlapping_bodies():
		if body is RigidBody2D:
			var offset: Vector2 = global_position - body.global_position
			if offset.length() > 1.0:
				body.apply_central_force(offset.normalized() * _force)
