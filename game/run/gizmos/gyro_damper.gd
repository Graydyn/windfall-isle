class_name GyroDamper
extends GizmoBase
## Gyro Damper (region 2 counterplay, spec 3.4): a passive stabilizing field
## in which drift currents cannot push pods. Drift zones do the checking
## (they ask the "gyro_dampers" group); the damper just exists and exposes
## field_radius. No Zone Area2D: it never reacts to contact itself.

var field_radius := 140.0


func _configure() -> void:
	field_radius = scaled(float(defs.get("field_radius", 140.0)))
	add_to_group("gyro_dampers")
	# The field disc stays code-drawn: its radius scales with level, and no
	# scalable field art has been delivered yet.
	var field := Polygon2D.new()
	field.polygon = Geometry.circle_points(field_radius, 24)
	field.color = Color(0.85, 0.7, 0.35, 0.12)
	add_child(field)
