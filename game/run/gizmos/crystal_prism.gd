extends GizmoBase
## Crystal Prism (spec 3.3): multiplies the value of everything the pod
## collects below it. Implemented as a pod-carried multiplier consumed by the
## run scene's _compute_payout at resolution. Applies once per pod per prism.

var _multiplier := 1.5

@onready var zone: Area2D = $Zone


func _configure() -> void:
	_multiplier = scaled(float(defs.get("multiplier", 1.5)))
	var circle := CircleShape2D.new()
	circle.radius = float(defs.get("radius", 30.0))
	$Zone/Shape.shape = circle
	var visual: Polygon2D = $Visual
	visual.polygon = PackedVector2Array([Vector2(0, -34), Vector2(30, 20), Vector2(-30, 20)])
	visual.color = Color(0.75, 0.6, 0.95, 0.85)
	zone.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not (body is RigidBody2D):
		return
	var guard := "prism_%d" % get_instance_id()
	if body.has_meta(guard):
		return
	body.set_meta(guard, true)
	body.set_meta("value_mult", float(body.get_meta("value_mult", 1.0)) * _multiplier)
