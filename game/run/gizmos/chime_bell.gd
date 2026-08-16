class_name ChimeBell
extends GizmoBase
## Chime Bell (spec 3.3): rings on contact; the next barge payout is doubled.
## The run scene keeps the strongest pending ring (non-stacking).

var _uses_left := 0
var _multiplier := 2.0

@onready var zone: Area2D = $Zone


func _configure() -> void:
	_uses_left = int(defs.get("uses_per_run", 2))
	_multiplier = scaled(float(defs.get("barge_multiplier", 2.0)))
	var circle := CircleShape2D.new()
	circle.radius = float(defs.get("radius", 26.0))
	$Zone/Shape.shape = circle
	var visual: Polygon2D = $Visual
	visual.polygon = PackedVector2Array([
		Vector2(-20, 18), Vector2(20, 18), Vector2(12, -20), Vector2(-12, -20),
	])
	visual.color = Color(0.9, 0.75, 0.35)
	zone.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _uses_left <= 0 or not (body is RigidBody2D) or body.has_meta("caught"):
		return
	var guard := "bell_%d" % get_instance_id()
	if body.has_meta(guard):
		return
	body.set_meta(guard, true)
	_uses_left -= 1
	context.set_next_barge_multiplier(_multiplier)
	if _uses_left <= 0:
		$Visual.modulate.a = 0.25
