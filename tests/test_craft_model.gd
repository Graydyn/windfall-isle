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


func with_annex(level: int) -> void:
	state.data["island"]["plots"]["islet_foundry_0"] = {"building": "foundry_annex", "level": level}


func test_effective_cost_is_the_raw_cost_without_an_annex() -> void:
	var def: Dictionary = DataDefs.gizmos["defs"]["wind_fan"]
	assert_eq(int(CraftModel.effective_cost(def, state.data["island"], DataDefs.buildings)["scrap"]), 80)
	assert_eq(int(CraftModel.effective_cost(def, state.data["island"], {})["scrap"]), 80,
		"empty building defs never discount")

func test_effective_cost_discounts_and_ceils() -> void:
	with_annex(1)
	var def := {"craft_cost": {"scrap": 85, "brasswork": 3}}
	var cost := CraftModel.effective_cost(def, state.data["island"], DataDefs.buildings)
	assert_eq(int(cost["scrap"]), 77, "ceil(85 x 0.9) = 77")
	assert_eq(int(cost["brasswork"]), 3, "ceil(3 x 0.9) = 3")
	with_annex(2)
	var cost2 := CraftModel.effective_cost(def, state.data["island"], DataDefs.buildings)
	assert_eq(int(cost2["scrap"]), 68, "ceil(85 x 0.8) = 68")

func test_effective_cost_never_reaches_zero() -> void:
	with_annex(2)
	var cost := CraftModel.effective_cost({"craft_cost": {"brasswork": 1}}, state.data["island"], DataDefs.buildings)
	assert_eq(int(cost["brasswork"]), 1, "no craft is ever free")

func test_start_craft_pays_the_discounted_price_it_checked() -> void:
	with_annex(1)
	assert_true(CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan", 1000, DataDefs.buildings))
	assert_eq(econ.balance("scrap"), 5000 - 72, "ceil(80 x 0.9) = 72: pay what was checked")

func test_discount_unlocks_a_craft_at_the_margin() -> void:
	with_annex(1)
	state.data["currencies"]["scrap"] = 72
	assert_true(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan", DataDefs.buildings),
		"72 scrap affords the discounted 72 price")
	assert_false(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan"),
		"without building defs the raw 80 price applies")
