extends GutTest

const ControllerScript := preload("res://game/run/drop_controller.gd")

var controller: DropController


func before_each() -> void:
	controller = add_child_autofree(ControllerScript.new())
	controller.configure({"left": 20, "right": 700, "top": 140}, 12.0)
	# configure() gives min_x 44, max_x 676, so the marker starts centered at 360.


func touch(pos: Vector2, pressed: bool, index: int = 0) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.position = pos
	event.pressed = pressed
	event.index = index
	return event

func drag_to(pos: Vector2, index: int = 0) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.position = pos
	event.index = index
	return event


func test_marker_starts_centered() -> void:
	assert_eq(controller._aim_x, 360.0)

func test_sweep_advances_with_time() -> void:
	controller._process(0.1)
	assert_eq(controller._aim_x, 360.0 + controller.sweep_speed * 0.1)

func test_sweep_reverses_at_right_wall() -> void:
	controller._process(1.0)
	assert_eq(controller._aim_x, 676.0)
	controller._process(0.1)
	assert_eq(controller._aim_x, 676.0 - controller.sweep_speed * 0.1)

func test_sweep_reverses_at_left_wall() -> void:
	controller._process(1.0)
	controller._process(2.0)
	assert_eq(controller._aim_x, 44.0)
	controller._process(0.1)
	assert_eq(controller._aim_x, 44.0 + controller.sweep_speed * 0.1)

func test_tap_drops_at_current_marker_position() -> void:
	watch_signals(controller)
	controller._process(0.1)
	var expected := controller._aim_x
	controller._unhandled_input(touch(Vector2(50, 900), true))
	assert_signal_emitted_with_parameters(controller, "drop_requested", [expected])

func test_touch_release_does_not_drop() -> void:
	watch_signals(controller)
	controller._unhandled_input(touch(Vector2(300, 80), false))
	assert_signal_not_emitted(controller, "drop_requested")

func test_drag_does_not_move_marker() -> void:
	controller._unhandled_input(drag_to(Vector2(600, 90)))
	assert_eq(controller._aim_x, 360.0)

func test_disabled_controller_does_not_sweep() -> void:
	controller.enabled = false
	controller._process(0.1)
	assert_eq(controller._aim_x, 360.0)

func test_disabled_controller_ignores_taps() -> void:
	controller.enabled = false
	watch_signals(controller)
	controller._unhandled_input(touch(Vector2(300, 80), true))
	assert_signal_not_emitted(controller, "drop_requested")
