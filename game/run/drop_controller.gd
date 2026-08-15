class_name DropController
extends Node2D
## One-thumb drop aiming (spec 3.2): touch anywhere to start aiming, drag to
## slide the drop point along the top edge, release to drop. Pure input; the
## run scene decides whether a drop is actually allowed.
## Only the finger that started aiming can move or end it; other fingers are ignored.

signal drop_requested(x: float)

var enabled := true
var drop_y := 100.0
var min_x := 44.0
var max_x := 676.0

var _aiming := false
var _aim_x := 360.0
var _touch_index := -1


func configure(board: Dictionary, pod_radius: float) -> void:
	min_x = float(board.get("left", 20)) + pod_radius * 2.0
	max_x = float(board.get("right", 700)) - pod_radius * 2.0
	drop_y = float(board.get("top", 140)) - 40.0
	_aim_x = (min_x + max_x) / 2.0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if not _aiming:
				_aiming = true
				_touch_index = event.index
				_aim_x = clampf(event.position.x, min_x, max_x)
			elif event.index != _touch_index:
				return
		elif _aiming and event.index == _touch_index:
			_aiming = false
			_touch_index = -1
			drop_requested.emit(_aim_x)
	elif event is InputEventScreenDrag and _aiming and event.index == _touch_index:
		_aim_x = clampf(event.position.x, min_x, max_x)
	queue_redraw()


func _draw() -> void:
	if enabled:
		draw_circle(Vector2(_aim_x, drop_y), 8.0, Color(1, 1, 1, 0.5))
