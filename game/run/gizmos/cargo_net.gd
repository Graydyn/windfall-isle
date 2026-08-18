class_name CargoNet
extends GizmoBase
## Cargo Net (spec 3.3): catches a falling pod once and re-drops it at a
## chosen angle toward the board center. The hold Timer is a child of the net
## (dies with the scene) and binds a weakref (survives the pod being freed),
## per the project's timer-lifetime rule.

var _uses_left := 0

@onready var zone: Area2D = $Zone


func _configure() -> void:
	_uses_left = int(defs.get("uses", 1))
	var circle := CircleShape2D.new()
	circle.radius = float(defs.get("radius", 34.0))
	$Zone/Shape.shape = circle
	var visual: Polygon2D = $Visual
	visual.polygon = PackedVector2Array([
		Vector2(-30, -6), Vector2(30, -6), Vector2(22, 22), Vector2(-22, 22),
	])
	visual.color = Color(0.7, 0.55, 0.4)
	zone.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _uses_left <= 0 or not (body is RigidBody2D) or body.has_meta("caught"):
		return
	_uses_left -= 1
	body.set_deferred("freeze", true)
	var hold := Timer.new()
	hold.one_shot = true
	hold.wait_time = float(defs.get("hold_seconds", 0.8))
	add_child(hold)
	hold.timeout.connect(_release.bind(weakref(body), hold))
	hold.start()
	if _uses_left <= 0:
		$Visual.modulate.a = 0.4


func _release(pod_ref: WeakRef, hold: Timer) -> void:
	hold.queue_free()
	var pod: Node = pod_ref.get_ref()
	if pod == null or pod.has_meta("caught"):
		return
	pod.freeze = false
	var angle := deg_to_rad(float(defs.get("redrop_angle_degrees", 60.0)))
	var speed := scaled(float(defs.get("redrop_speed", 420.0)))
	var direction := 1.0 if global_position.x < float(defs.get("board_center_x", 360.0)) else -1.0
	pod.linear_velocity = Vector2(cos(angle) * speed * direction, -sin(angle) * speed)


func recharge() -> void:
	_uses_left = int(defs.get("uses", 1))
	$Visual.modulate.a = 1.0
