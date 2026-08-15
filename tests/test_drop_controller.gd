extends GutTest

const ControllerScript := preload("res://game/run/drop_controller.gd")

var controller: DropController


func before_each() -> void:
	controller = add_child_autofree(ControllerScript.new())
	controller.configure({"left": 20, "right": 700, "top": 140}, 12.0)


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


func test_tap_release_drops_at_tap_x() -> void:
	watch_signals(controller)
	controller._unhandled_input(touch(Vector2(300, 80), true))
	controller._unhandled_input(touch(Vector2(300, 80), false))
	assert_signal_emitted_with_parameters(controller, "drop_requested", [300.0])

func test_drag_updates_aim_before_release() -> void:
	watch_signals(controller)
	controller._unhandled_input(touch(Vector2(300, 80), true))
	controller._unhandled_input(drag_to(Vector2(500, 90)))
	controller._unhandled_input(touch(Vector2(500, 90), false))
	assert_signal_emitted_with_parameters(controller, "drop_requested", [500.0])

func test_aim_is_clamped_inside_walls() -> void:
	watch_signals(controller)
	controller._unhandled_input(touch(Vector2(2, 80), true))
	controller._unhandled_input(touch(Vector2(2, 80), false))
	assert_signal_emitted_with_parameters(controller, "drop_requested", [44.0])

func test_disabled_controller_ignores_input() -> void:
	controller.enabled = false
	watch_signals(controller)
	controller._unhandled_input(touch(Vector2(300, 80), true))
	controller._unhandled_input(touch(Vector2(300, 80), false))
	assert_signal_not_emitted(controller, "drop_requested")

func test_release_without_press_does_not_drop() -> void:
	watch_signals(controller)
	controller._unhandled_input(touch(Vector2(300, 80), false))
	assert_signal_not_emitted(controller, "drop_requested")

func test_second_finger_press_does_not_steal_aim() -> void:
	watch_signals(controller)
	controller._unhandled_input(touch(Vector2(300, 80), true, 0))
	controller._unhandled_input(touch(Vector2(600, 80), true, 1))
	controller._unhandled_input(touch(Vector2(300, 80), false, 0))
	assert_signal_emitted_with_parameters(controller, "drop_requested", [300.0])
	assert_signal_emit_count(controller, "drop_requested", 1)

func test_second_finger_drag_ignored() -> void:
	watch_signals(controller)
	controller._unhandled_input(touch(Vector2(300, 80), true, 0))
	controller._unhandled_input(drag_to(Vector2(600, 90), 1))
	controller._unhandled_input(touch(Vector2(300, 80), false, 0))
	assert_signal_emitted_with_parameters(controller, "drop_requested", [300.0])

func test_second_finger_release_does_not_drop() -> void:
	watch_signals(controller)
	controller._unhandled_input(touch(Vector2(300, 80), true, 0))
	controller._unhandled_input(touch(Vector2(600, 80), false, 1))
	assert_signal_not_emitted(controller, "drop_requested")
	controller._unhandled_input(touch(Vector2(300, 80), false, 0))
	assert_signal_emitted_with_parameters(controller, "drop_requested", [300.0])
