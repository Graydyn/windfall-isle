extends GizmoBase
## Balloon Cluster (spec 3.3): bounces the pod sharply upward; pops after N
## hits per run. Gizmos are re-instantiated per expedition, so hits reset
## naturally each run.

var _hits_left := 0
var _impulse := 0.0

@onready var zone: Area2D = $Zone


func _configure() -> void:
	_impulse = scaled(float(defs.get("impulse", 420.0)))
	_hits_left = int(defs.get("max_hits", 3))
	var circle := CircleShape2D.new()
	circle.radius = float(defs.get("radius", 26.0))
	$Zone/Shape.shape = circle
	var visual: Polygon2D = $Visual
	visual.polygon = Geometry.circle_points(circle.radius)
	visual.color = Color(0.95, 0.5, 0.55)
	zone.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _hits_left <= 0 or not (body is RigidBody2D):
		return
	_hits_left -= 1
	body.linear_velocity = Vector2(body.linear_velocity.x, -_impulse)
	if _hits_left <= 0:
		$Visual.modulate.a = 0.25
		zone.set_deferred("monitoring", false)
