extends GutTest

const TimerServiceScript := preload("res://game/autoload/timer_service.gd")
const GameStateScript := preload("res://game/autoload/game_state.gd")

var timers
var state


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.data = {"timers": {}}
	timers = autofree(TimerServiceScript.new())
	timers.setup(state)


func test_start_and_remaining() -> void:
	assert_true(timers.start("build_workshop", "construction", 600, 1000))
	assert_eq(timers.remaining("build_workshop", 1300), 300)
	assert_eq(timers.remaining("build_workshop", 2000), 0)

func test_start_emits_signal() -> void:
	watch_signals(timers)
	timers.start("t1", "craft", 600, 1000)
	assert_signal_emitted_with_parameters(timers, "timer_started", ["t1"])

func test_duplicate_id_rejected() -> void:
	timers.start("t1", "craft", 600, 1000)
	assert_false(timers.start("t1", "craft", 600, 1000))

func test_collect_only_when_done() -> void:
	timers.start("t1", "craft", 600, 1000, {"gizmo": "wind_fan"})
	assert_eq(timers.collect("t1", 1599), {})
	assert_true(timers.active_timers().has("t1"), "early collect must not consume the timer")
	assert_eq(timers.collect("t1", 1600), {"gizmo": "wind_fan"})
	assert_false(timers.active_timers().has("t1"))

func test_collect_emits_signal() -> void:
	timers.start("t1", "craft", 600, 1000, {"gizmo": "wind_fan"})
	watch_signals(timers)
	timers.collect("t1", 2000)
	assert_signal_emitted_with_parameters(timers, "timer_collected", ["t1", {"gizmo": "wind_fan"}])

func test_skip_completes_immediately() -> void:
	timers.start("t1", "construction", 99999, 1000)
	timers.skip("t1")
	assert_true(timers.is_done("t1", 1001))

func test_unknown_ids_are_safe() -> void:
	assert_eq(timers.remaining("nope", 1000), 0)
	assert_false(timers.is_done("nope", 1000))
	assert_eq(timers.collect("nope", 1000), {})

func test_timers_land_in_state_dict() -> void:
	timers.start("t1", "craft", 600, 1000)
	assert_true(state.data["timers"].has("t1"),
		"TimerService must mutate GameState.data so saves capture it")
