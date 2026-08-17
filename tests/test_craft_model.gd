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
	state.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	econ = autofree(EconomyScript.new())
	econ.setup(state)
	timers = autofree(TimerServiceScript.new())
	timers.setup(state)


func test_no_workshop_no_crafting() -> void:
	state.data["island"]["plots"].clear()
	assert_false(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan"))

func test_start_craft_pays_and_starts_timer() -> void:
	assert_true(CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan", 1000))
	assert_eq(econ.balance("scrap"), 5000 - 80)
	assert_eq(timers.remaining("craft_wind_fan", 1000), 120)

func test_complete_craft_merges_into_level() -> void:
	CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan", 1000)
	CraftModel.complete_craft(state.data, timers.collect("craft_wind_fan", 1200))
	assert_eq(int(state.data["gizmos"]["owned"]["wind_fan"]), 2,
		"crafted duplicates merge into upgrades (spec 3.3)")

func test_slots_equal_workshop_level() -> void:
	assert_eq(CraftModel.craft_slots(state.data["island"]), 1)
	CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan", 1000)
	assert_false(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "chime_bell"),
		"level 1 workshop crafts one at a time")
	state.data["island"]["plots"]["plot_0"]["level"] = 2
	assert_true(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "chime_bell"))

func test_craft_max_level_respected() -> void:
	state.data["gizmos"]["owned"]["wind_fan"] = 5
	assert_false(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan"))

func test_unowned_gizmo_craft_grants_level_one() -> void:
	state.data["gizmos"]["owned"].erase("wind_fan")
	assert_true(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan"),
		"recipes are craft-to-acquire; resources are the gate (spec 3.3)")
	CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan", 1000)
	CraftModel.complete_craft(state.data, timers.collect("craft_wind_fan", 1200))
	assert_eq(int(state.data["gizmos"]["owned"]["wind_fan"]), 1)

func test_unknown_gizmo_id_cannot_be_crafted() -> void:
	assert_false(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "no_such_gizmo"))

func test_brasswork_gates_the_brass_recipes() -> void:
	assert_false(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "gyro_damper"),
		"5000 scrap but zero brasswork: locked")
	state.data["currencies"]["brasswork"] = 2
	assert_true(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "gyro_damper"))
