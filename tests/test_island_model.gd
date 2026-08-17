extends GutTest

const TimerServiceScript := preload("res://game/autoload/timer_service.gd")
const EconomyScript := preload("res://game/autoload/economy.gd")
const GameStateScript := preload("res://game/autoload/game_state.gd")

var state: Node
var econ: Node
var timers: Node
var island: Dictionary
var defs: Dictionary


func before_each() -> void:
	defs = DataDefs.buildings
	state = autofree(GameStateScript.new())
	state.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	state.data["currencies"]["scrap"] = 2000
	state.data["currencies"]["cloudsilk"] = 20
	state.data["currencies"]["crystals"] = 30
	island = state.data["island"]
	econ = autofree(EconomyScript.new())
	econ.setup(state)
	timers = autofree(TimerServiceScript.new())
	timers.setup(state)


func test_fresh_island_has_no_buildings() -> void:
	assert_eq(IslandModel.building_level(island, "workshop"), 0)
	assert_eq(IslandModel.plot_of(island, "workshop"), "")

func test_start_build_pays_and_starts_timer() -> void:
	assert_true(IslandModel.start_build(island, defs, econ, timers, "plot_0", "workshop", 1000))
	assert_eq(econ.balance("scrap"), 2000 - 60)
	assert_eq(timers.remaining("build_plot_0", 1000), 60)
	assert_eq(IslandModel.building_level(island, "workshop"), 0, "not leveled until collected")

func test_complete_build_applies_level() -> void:
	IslandModel.start_build(island, defs, econ, timers, "plot_0", "workshop", 1000)
	var payload: Dictionary = timers.collect("build_plot_0", 1061)
	IslandModel.complete_build(island, payload, state.data, 1061)
	assert_eq(IslandModel.building_level(island, "workshop"), 1)
	assert_eq(IslandModel.plot_of(island, "workshop"), "plot_0")

func test_one_construction_slot_by_default() -> void:
	IslandModel.start_build(island, defs, econ, timers, "plot_0", "workshop", 1000)
	assert_false(IslandModel.can_start_build(island, defs, econ, timers, "plot_1", "gardens", 1000),
		"spec 4.1: one free build slot")

func test_unlock_second_slot_costs_crystals_and_allows_parallel() -> void:
	assert_true(IslandModel.unlock_second_slot(island, defs, econ))
	assert_eq(econ.balance("crystals"), 30 - 20)
	assert_eq(int(island["build_slots"]), 2)
	assert_false(IslandModel.unlock_second_slot(island, defs, econ), "capped at max")
	IslandModel.start_build(island, defs, econ, timers, "plot_0", "workshop", 1000)
	assert_true(IslandModel.can_start_build(island, defs, econ, timers, "plot_1", "gardens", 1000))

func test_same_building_cannot_occupy_two_plots() -> void:
	IslandModel.start_build(island, defs, econ, timers, "plot_0", "workshop", 1000)
	IslandModel.complete_build(island, timers.collect("build_plot_0", 1100), state.data, 1100)
	assert_false(IslandModel.can_start_build(island, defs, econ, timers, "plot_1", "workshop", 1100))

func test_upgrade_uses_next_level_row_and_respects_max() -> void:
	IslandModel.start_build(island, defs, econ, timers, "plot_0", "dock", 1000)
	IslandModel.complete_build(island, timers.collect("build_plot_0", 1200), state.data, 1200)
	var scrap_before: int = econ.balance("scrap")
	assert_true(IslandModel.start_build(island, defs, econ, timers, "plot_0", "dock", 1200))
	assert_eq(econ.balance("scrap"), scrap_before - 500, "level 2 cost row")
	IslandModel.complete_build(island, timers.collect("build_plot_0", 3200), state.data, 3200)
	assert_eq(IslandModel.building_level(island, "dock"), 2)
	assert_false(IslandModel.can_start_build(island, defs, econ, timers, "plot_0", "dock", 3200),
		"dock max_level is 2")

func test_gardens_completion_stamps_trickle_clock() -> void:
	IslandModel.start_build(island, defs, econ, timers, "plot_2", "gardens", 5000)
	IslandModel.complete_build(island, timers.collect("build_plot_2", 5200), state.data, 5200)
	assert_eq(int(state.data["trickle"]["last_collect"]), 5200,
		"the trickle counts from the moment gardens first exist")

func test_gardens_upgrade_preserves_pending_trickle_value() -> void:
	IslandModel.start_build(island, defs, econ, timers, "plot_2", "gardens", 1000)
	IslandModel.complete_build(island, timers.collect("build_plot_2", 1200), state.data, 1200, defs)
	var later := 1200 + 3600
	assert_eq(TrickleModel.pending(state.data, defs, later), 20, "1h at Lv1")
	IslandModel.start_build(island, defs, econ, timers, "plot_2", "gardens", later)
	var done := later + 1201
	var pending_before_upgrade := TrickleModel.pending(state.data, defs, done)
	assert_eq(pending_before_upgrade, 26,
		"1.3336h elapsed at Lv1's 20/hr since the last_collect stamp at 1200 (floor(20 * 4801/3600) = 26)")
	IslandModel.complete_build(island, timers.collect("build_plot_2", done), state.data, done, defs)
	assert_eq(TrickleModel.pending(state.data, defs, done), pending_before_upgrade,
		"pending immediately after the upgrade equals pending immediately before it: no retroactive re-rating")
	var after := done + 3600
	assert_eq(TrickleModel.pending(state.data, defs, after), pending_before_upgrade + 40,
		"accrual after the upgrade runs at the new Lv2 rate of 40/hr")

func test_insufficient_funds_rejected() -> void:
	state.data["currencies"]["scrap"] = 10
	assert_false(IslandModel.start_build(island, defs, econ, timers, "plot_0", "workshop", 1000))
	assert_eq(timers.active_timers().size(), 0)

func test_build_rejection_empty_when_buildable() -> void:
	assert_eq(IslandModel.build_rejection(island, defs, econ, timers, "plot_0", "workshop", 1000), "")

func test_build_rejection_names_busy_slots() -> void:
	IslandModel.start_build(island, defs, econ, timers, "plot_0", "workshop", 1000)
	assert_string_contains(
		IslandModel.build_rejection(island, defs, econ, timers, "plot_1", "gardens", 1000),
		"slots are busy")

func test_build_rejection_names_the_cost_shortfall() -> void:
	state.data["currencies"]["scrap"] = 0
	assert_string_contains(
		IslandModel.build_rejection(island, defs, econ, timers, "plot_0", "workshop", 1000),
		"Not enough")

func test_build_rejection_rejects_an_occupied_timer_plot() -> void:
	IslandModel.start_build(island, defs, econ, timers, "plot_0", "workshop", 1000)
	assert_string_contains(
		IslandModel.build_rejection(island, defs, econ, timers, "plot_0", "workshop", 1000),
		"under construction")

func test_build_rejection_rejects_an_impossible_target() -> void:
	island["plots"]["plot_0"] = {"building": "workshop", "level": 3}
	assert_string_contains(
		IslandModel.build_rejection(island, defs, econ, timers, "plot_0", "workshop", 1000),
		"cannot be built")
