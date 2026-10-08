class_name ChimeBell
extends GizmoBase
## Chime Bell (spec 3.3): rings on contact; the next barge payout is doubled.
## The run scene keeps the strongest pending ring (non-stacking).

const BASE_TEXTURE := preload("res://game/art/gizmos/chime_bell.png")
const SPENT_TEXTURE := preload("res://game/art/gizmos/chime_bell_spent.png")

var _uses_left := 0
var _multiplier := 2.0

@onready var zone: Area2D = $Zone


func _configure() -> void:
	_uses_left = int(defs.get("uses_per_run", 2))
	_multiplier = scaled(float(defs.get("barge_multiplier", 2.0)))
	var circle := CircleShape2D.new()
	circle.radius = float(defs.get("radius", 26.0))
	$Zone/Shape.shape = circle
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
		$Visual.texture = SPENT_TEXTURE
		$Visual.modulate.a = 0.25


func recharge() -> void:
	_uses_left = int(defs.get("uses_per_run", 2))
	$Visual.texture = BASE_TEXTURE
	$Visual.modulate.a = 1.0
