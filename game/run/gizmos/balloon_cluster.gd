extends GizmoBase
## Balloon Cluster (spec 3.3): bumper-bounces the pod up and away from the
## cluster's center; pops after N hits per run. Gizmos are re-instantiated
## per expedition, so hits reset naturally each run.

const BASE_TEXTURE := preload("res://game/art/gizmos/balloon_cluster.png")
const SPENT_TEXTURE := preload("res://game/art/gizmos/balloon_cluster_spent.png")

# Blend of straight-up vs away-from-center in the bounce direction, and the
# minimum sideways fraction so a dead-center hit never yo-yos in place.
const UP_WEIGHT := 0.6
const AWAY_WEIGHT := 0.4
const MIN_SIDE_FRACTION := 0.35

var _hits_left := 0
var _impulse := 0.0
var _fallback_side := 1.0

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
	var dir := _bounce_direction(body)
	body.linear_velocity = Vector2(body.linear_velocity.x, 0.0)
	body.apply_central_impulse(dir * _impulse)
	if _hits_left <= 0:
		$Visual.texture = SPENT_TEXTURE
		$Visual.modulate.a = 0.25
		zone.set_deferred("monitoring", false)


func _bounce_direction(body: Node2D) -> Vector2:
	var offset: Vector2 = body.global_position - global_position
	var away := offset.normalized() if offset.length() > 0.001 else Vector2.ZERO
	var dir := (Vector2.UP * UP_WEIGHT + away * AWAY_WEIGHT).normalized()
	if absf(dir.x) >= MIN_SIDE_FRACTION:
		return dir
	var side := signf(dir.x)
	if side == 0.0:
		side = signf(body.linear_velocity.x)
	if side == 0.0:
		side = _fallback_side
		_fallback_side = -_fallback_side
	return Vector2(side * MIN_SIDE_FRACTION, -sqrt(1.0 - MIN_SIDE_FRACTION * MIN_SIDE_FRACTION))


func recharge() -> void:
	_hits_left = int(defs.get("max_hits", 3))
	$Visual.texture = BASE_TEXTURE
	$Visual.modulate.a = 1.0
	zone.set_deferred("monitoring", true)
