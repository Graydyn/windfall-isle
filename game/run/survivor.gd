class_name Survivor
extends Area2D
## A stranded crewmember drifting across the run board on a raft (crew spec
## section 6). Any live pod touching the raft rescues them; the scene owns
## persistence and the banner. Frees itself past the far edge. Never touches
## the payout pipeline.

signal rescued(crew_id: String)

var crew_id := ""
var _speed := 60.0
var _direction := 1.0
var _exit_x := 800.0
var _claimed := false


func setup(id: String, survivor_defs: Dictionary, from_left: bool, board: Dictionary) -> void:
	crew_id = id
	_speed = float(survivor_defs.get("drift_speed", 60.0))
	_direction = 1.0 if from_left else -1.0
	var left := float(board.get("left", 20.0))
	var right := float(board.get("right", 700.0))
	_exit_x = right + 60.0 if from_left else left - 60.0
	position = Vector2(left - 60.0 if from_left else right + 60.0, float(survivor_defs.get("drift_y", 480.0)))
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = float(survivor_defs.get("radius", 26.0))
	shape.shape = circle
	add_child(shape)
	var visual := Sprite2D.new()
	visual.texture = load("res://game/art/run/survivor_raft.png")
	visual.scale = Vector2.ONE * 0.5
	# Raft art faces right; mirror it when drifting in from the right edge.
	visual.flip_h = not from_left
	add_child(visual)
	add_to_group("survivors")
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	position.x += _speed * _direction * delta
	if (_direction > 0.0 and position.x > _exit_x) or (_direction < 0.0 and position.x < _exit_x):
		queue_free()


func _on_body(body: Node2D) -> void:
	# One rescue per raft: two pods in one physics frame claim once.
	if _claimed or not (body is RigidBody2D):
		return
	_claimed = true
	rescued.emit(crew_id)
	queue_free()
