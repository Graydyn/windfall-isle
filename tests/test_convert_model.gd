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
	state.data["currencies"]["scrap"] = 1000
	state.data["currencies"]["brasswork"] = 10
	state.data["island"]["plots"]["plot_1"] = {"building": "smeltery", "level": 1}
	econ = autofree(EconomyScript.new())
	econ.setup(state)
	timers = autofree(TimerServiceScript.new())
	timers.setup(state)


func test_unbuilt_building_cannot_convert() -> void:
	state.data["island"]["plots"].clear()
	assert_false(ConvertModel.can_start(state.data, DataDefs.buildings, econ, timers, "smeltery"))
	assert_eq(ConvertModel.outputs_for(DataDefs.buildings, state.data["island"], "smeltery"), {})

func test_recipe_less_building_cannot_convert() -> void:
	state.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	assert_false(ConvertModel.can_start(state.data, DataDefs.buildings, econ, timers, "workshop"))

func test_start_batch_pays_and_starts_the_convert_timer() -> void:
	assert_true(ConvertModel.start_batch(state.data, DataDefs.buildings, econ, timers, "smeltery", 1000))
	assert_eq(econ.balance("scrap"), 1000 - 40)
	assert_eq(timers.remaining("convert_smeltery", 1000), 600)
	assert_eq(String((timers.active_timers()["convert_smeltery"] as Dictionary)["kind"]), "convert")

func test_one_batch_per_building() -> void:
	ConvertModel.start_batch(state.data, DataDefs.buildings, econ, timers, "smeltery", 1000)
	assert_false(ConvertModel.can_start(state.data, DataDefs.buildings, econ, timers, "smeltery"))

func test_zero_input_recipe_starts_for_free() -> void:
	state.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	state.data["currencies"]["scrap"] = 0
	assert_true(ConvertModel.start_batch(state.data, DataDefs.buildings, econ, timers, "gardens", 1000))
	assert_eq(timers.remaining("convert_gardens", 1000), 3600)

func test_outputs_scale_with_building_level() -> void:
	assert_eq(ConvertModel.outputs_for(DataDefs.buildings, state.data["island"], "smeltery"), {"parts": 1})
	state.data["island"]["plots"]["plot_1"]["level"] = 3
	assert_eq(ConvertModel.outputs_for(DataDefs.buildings, state.data["island"], "smeltery"), {"parts": 3})

func test_complete_batch_credits_at_collect_time_level() -> void:
	ConvertModel.start_batch(state.data, DataDefs.buildings, econ, timers, "smeltery", 1000)
	state.data["island"]["plots"]["plot_1"]["level"] = 2
	var payload: Dictionary = timers.collect("convert_smeltery", 1000 + 600)
	ConvertModel.complete_batch(state.data, DataDefs.buildings, econ, payload)
	assert_eq(econ.balance("parts"), 2,
		"outputs are read at collect time; the mid-batch upgrade pays the new level")

func test_complete_batch_ignores_junk_payloads() -> void:
	ConvertModel.complete_batch(state.data, DataDefs.buildings, econ, {})
	ConvertModel.complete_batch(state.data, DataDefs.buildings, econ, {"building": "no_such"})
	assert_eq(econ.balance("parts"), 0)

func test_crew_divides_the_duration_and_locks_at_start() -> void:
	CrewModel.rescue(state.data, "reya")
	(state.data["crew"]["assignments"] as Dictionary)["smeltery"] = "reya"
	assert_true(ConvertModel.start_batch(state.data, DataDefs.buildings, econ, timers, "smeltery", 1000, DataDefs.crew))
	assert_eq(timers.remaining("convert_smeltery", 1000), 400, "600s / Reya's 1.5 specialist bonus")
	(state.data["crew"]["assignments"] as Dictionary).erase("smeltery")
	assert_eq(timers.remaining("convert_smeltery", 1000), 400, "duration locked at start")

func test_missing_currency_key_defaults_to_zero_and_add_creates() -> void:
	(state.data["currencies"] as Dictionary).erase("parts")
	assert_eq(econ.balance("parts"), 0, "a pre-parts save reads zero")
	econ.add("parts", 3)
	assert_eq(econ.balance("parts"), 3, "the first add creates the key")

func test_brass_smelt_consumes_both_inputs() -> void:
	state.data["island"]["plots"]["islet_foundry_0"] = {"building": "foundry_annex", "level": 1}
	assert_true(ConvertModel.start_batch(state.data, DataDefs.buildings, econ, timers, "foundry_annex", 1000))
	assert_eq(econ.balance("scrap"), 1000 - 30)
	assert_eq(econ.balance("brasswork"), 10 - 1)
	ConvertModel.complete_batch(state.data, DataDefs.buildings, econ, timers.collect("convert_foundry_annex", 1000 + 600))
	assert_eq(econ.balance("parts"), 2, "the efficient late-game converter")
