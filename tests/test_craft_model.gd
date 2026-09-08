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
	state.data["currencies"]["parts"] = 50
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
	assert_eq(econ.balance("parts"), 50 - 2)
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
		"50 parts but zero brasswork: locked")
	state.data["currencies"]["brasswork"] = 2
	assert_true(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "gyro_damper"))


func test_crewed_workshop_crafts_faster_and_locks_at_start() -> void:
	CrewModel.rescue(state.data, "maren")
	(state.data["crew"]["assignments"] as Dictionary)["workshop"] = "maren"
	assert_true(CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan", 1000, DataDefs.crew))
	assert_eq(timers.remaining("craft_wind_fan", 1000), 80,
		"120s divided by Maren's 1.5 specialist bonus")
	(state.data["crew"]["assignments"] as Dictionary).erase("workshop")
	assert_eq(timers.remaining("craft_wind_fan", 1000), 80,
		"the duration locked at start; reassignment does not stretch a running craft")


func test_uncrewed_craft_duration_is_baseline() -> void:
	assert_true(CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan", 1000, DataDefs.crew))
	assert_eq(timers.remaining("craft_wind_fan", 1000), 120)


func test_crafts_cost_parts_not_scrap() -> void:
	state.data["currencies"]["parts"] = 0
	assert_false(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan"),
		"5000 scrap buys nothing at the workshop anymore")
	state.data["currencies"]["parts"] = 2
	assert_true(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan"))
