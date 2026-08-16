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

func test_insufficient_funds_rejected() -> void:
	state.data["currencies"]["scrap"] = 10
	assert_false(IslandModel.start_build(island, defs, econ, timers, "plot_0", "workshop", 1000))
	assert_eq(timers.active_timers().size(), 0)
