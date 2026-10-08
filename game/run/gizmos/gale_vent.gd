class_name GaleVent
extends GizmoBase
## Gale Vent (region 4, stormglass): one sharp upward kick per pod per vent,
## a re-loft tool for dodging storm pegs. The per-pod meta key carries this
## vent's instance id so two vents each land their own kick on the same pod.
## Impulse inside body_entered is safe per the Piston Kicker precedent.

var _impulse := 0.0

@onready var zone: Area2D = $Zone


func _configure() -> void:
	_impulse = scaled(float(defs.get("impulse", 380.0)))
	var circle := CircleShape2D.new()
	circle.radius = float(defs.get("radius", 28.0))
	$Zone/Shape.shape = circle
	zone.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var meta_key := "gale_vented_%d" % get_instance_id()
	if not (body is RigidBody2D) or body.has_meta("caught") or body.has_meta(meta_key):
		return
	body.set_meta(meta_key, true)
	body.apply_central_impulse(Vector2(0.0, -_impulse))
