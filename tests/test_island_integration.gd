extends GutTest

const TimerServiceScript := preload("res://game/autoload/timer_service.gd")
const EconomyScript := preload("res://game/autoload/economy.gd")
const GameStateScript := preload("res://game/autoload/game_state.gd")

var state
var econ
var timers


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	state.data["currencies"]["scrap"] = 5000
	state.data["currencies"]["cloudsilk"] = 50
	state.data["currencies"]["crystals"] = 40
	econ = autofree(EconomyScript.new())
	econ.setup(state)
	timers = autofree(TimerServiceScript.new())
	timers.setup(state)


func test_flywheel_build_craft_upgrade_with_fake_clock() -> void:
	var island: Dictionary = state.data["island"]
	var t := 1000
	assert_true(IslandModel.start_build(island, DataDefs.buildings, econ, timers, "plot_0", "workshop", t))
	t += 61
	IslandModel.complete_build(island, timers.collect("build_plot_0", t), state.data, t)
	assert_eq(IslandModel.building_level(island, "workshop"), 1)
	assert_true(CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "splitter_vane", t))
	t += 361
	CraftModel.complete_craft(state.data, timers.collect("craft_splitter_vane", t))
	assert_eq(int(state.data["gizmos"]["owned"]["splitter_vane"]), 2,
		"the flywheel: runs feed the base, the base upgrades the board (spec 5)")

func test_wind_still_completion_raises_effective_fuel() -> void:
	var island: Dictionary = state.data["island"]
	var t := 1000
	IslandModel.start_build(island, DataDefs.buildings, econ, timers, "plot_0", "wind_still", t)
	t += 121
	IslandModel.complete_build(island, timers.collect("build_plot_0", t), state.data, t)
	IslandEffects.apply_fuel(state.data, DataDefs.economy, DataDefs.buildings)
	assert_eq(int(state.data["fuel"]["cap"]), 6)
	assert_eq(int(state.data["fuel"]["regen_seconds"]), 1080)

func test_offline_return_pays_trickle_and_crate_and_regen() -> void:
	var island: Dictionary = state.data["island"]
	var t := 86400 * 50
	IslandModel.start_build(island, DataDefs.buildings, econ, timers, "plot_2", "gardens", t)
	IslandModel.complete_build(island, timers.collect("build_plot_2", t + 121), state.data, t + 121)
	var away_until := t + 121 + 3600 * 10
	assert_eq(TrickleModel.pending(state.data, DataDefs.buildings, away_until), 160,
		"10h away, capped at 8h x 20")
	assert_true(DailyCrate.can_claim(state.data, away_until))
	state.data["fuel"]["amount"] = 0
	state.data["fuel"]["updated_at"] = t
	assert_eq(FuelModel.current(state.data["fuel"], away_until), 5,
		"fuel refilled while away (spec 5 return hooks)")

func test_second_slot_enables_parallel_construction() -> void:
	var island: Dictionary = state.data["island"]
	assert_true(IslandModel.unlock_second_slot(island, DataDefs.buildings, econ))
	assert_true(IslandModel.start_build(island, DataDefs.buildings, econ, timers, "plot_0", "workshop", 1000))
	assert_true(IslandModel.start_build(island, DataDefs.buildings, econ, timers, "plot_1", "gardens", 1000))
	assert_eq(IslandModel.active_constructions(timers, 1000), 2)
