class_name SplitterVane
extends GizmoBase
## Splitter Vane (spec 3.3): splits the pod into two half-value pods, once
## per drop. Halve first so the context's clone copies the halved value;
## revert if the split is rejected (pod cap), so a failed split costs nothing.

var _value_multiplier := 0.5

@onready var zone: Area2D = $Zone


func _configure() -> void:
	_value_multiplier = scaled(float(defs.get("value_multiplier", 0.5)))
	var circle := CircleShape2D.new()
	circle.radius = float(defs.get("radius", 24.0))
	$Zone/Shape.shape = circle
	zone.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not (body is RigidBody2D) or body.has_meta("caught") or body.has_meta("split"):
		return
	var previous := float(body.get_meta("value_mult", 1.0))
	body.set_meta("value_mult", previous * _value_multiplier)
	if not context.request_split(body):
		body.set_meta("value_mult", previous)
		return
	body.set_meta("split", true)
