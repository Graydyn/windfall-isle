class_name DropController
extends Node2D
## Timed-release drop aiming: the drop marker sweeps back and forth along the
## top edge at constant speed; a tap releases the pod at the marker's current
## position. Pure input; the run scene decides whether a drop is actually allowed.

signal drop_requested(x: float)

var enabled := true:
	set(value):
		enabled = value
		queue_redraw()
var drop_y := 100.0
var min_x := 44.0
var max_x := 676.0
var sweep_speed := 400.0

var _aim_x := 360.0
var _dir := 1.0


func configure(board: Dictionary, pod_radius: float) -> void:
	min_x = float(board.get("left", 20)) + pod_radius * 2.0
	max_x = float(board.get("right", 700)) - pod_radius * 2.0
	drop_y = float(board.get("top", 140)) - 40.0
	_aim_x = (min_x + max_x) / 2.0
	_dir = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if not enabled:
		return
	_aim_x += _dir * sweep_speed * delta
	if _aim_x >= max_x:
		_aim_x = max_x
		_dir = -1.0
	elif _aim_x <= min_x:
		_aim_x = min_x
		_dir = 1.0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch and event.pressed:
		drop_requested.emit(_aim_x)


func _draw() -> void:
	if enabled:
		draw_circle(Vector2(_aim_x, drop_y), 8.0, Color(1, 1, 1, 0.5))
