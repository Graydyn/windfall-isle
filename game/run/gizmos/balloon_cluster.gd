extends GizmoBase
## Balloon Cluster (spec 3.3): bounces the pod sharply upward; pops after N
## hits per run. Gizmos are re-instantiated per expedition, so hits reset
## naturally each run.

const BASE_TEXTURE := preload("res://game/art/gizmos/balloon_cluster.png")
const SPENT_TEXTURE := preload("res://game/art/gizmos/balloon_cluster_spent.png")

var _hits_left := 0
var _impulse := 0.0

@onready var zone: Area2D = $Zone


func _configure() -> void:
	_impulse = scaled(float(defs.get("impulse", 420.0)))
	_hits_left = int(defs.get("max_hits", 3))
	var circle := CircleShape2D.new()
	circle.radius = float(defs.get("radius", 26.0))
	$Zone/Shape.shape = circle
	zone.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _hits_left <= 0 or not (body is RigidBody2D):
		return
	_hits_left -= 1
	body.linear_velocity = Vector2(body.linear_velocity.x, 0.0)
	body.apply_central_impulse(Vector2(0.0, -_impulse))
	if _hits_left <= 0:
		$Visual.texture = SPENT_TEXTURE
		$Visual.modulate.a = 0.25
		zone.set_deferred("monitoring", false)


func recharge() -> void:
	_hits_left = int(defs.get("max_hits", 3))
	$Visual.texture = BASE_TEXTURE
	$Visual.modulate.a = 1.0
	zone.set_deferred("monitoring", true)
