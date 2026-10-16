extends GutTest

const TimerServiceScript := preload("res://game/autoload/timer_service.gd")
const EconomyScript := preload("res://game/autoload/economy.gd")
const GameStateScript := preload("res://game/autoload/game_state.gd")

var state: Node
var econ: Node
var timers: Node
var defs: Dictionary


func before_each() -> void:
	defs = DataDefs.islets
	state = autofree(GameStateScript.new())
	state.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	state.data["currencies"]["scrap"] = 5000
	state.data["currencies"]["cloudsilk"] = 20
	state.data["currencies"]["brasswork"] = 30
	econ = autofree(EconomyScript.new())
	econ.setup(state)
	timers = autofree(TimerServiceScript.new())
	timers.setup(state)


func test_fresh_save_offers_the_first_islet_only() -> void:
	assert_eq(IsletModel.next_offered(state.data, defs), "lantern_shoal")
	assert_ne(IsletModel.restore_rejection(state.data, defs, econ, timers, "foundry_rock"), "",
		"islets restore in array order")

func test_start_restore_pays_and_starts_its_own_timer_lane() -> void:
	assert_true(IsletModel.start_restore(state.data, defs, econ, timers, "lantern_shoal", 1000))
	assert_eq(econ.balance("scrap"), 5000 - 600)
	assert_eq(econ.balance("cloudsilk"), 20 - 4)
	assert_eq(timers.remaining("restore_lantern_shoal", 1000), 14400)
	assert_eq(String((timers.active_timers()["restore_lantern_shoal"] as Dictionary)["kind"]), "restoration",
		"spec: restoration never rides the construction lane")

func test_restoration_does_not_consume_a_build_slot() -> void:
	IsletModel.start_restore(state.data, defs, econ, timers, "lantern_shoal", 1000)
	assert_eq(IslandModel.active_constructions(timers, 1000), 0,
		"a running restoration must leave the free build slot open")
	assert_true(IslandModel.can_start_build(state.data["island"], DataDefs.buildings, econ, timers, "plot_0", "workshop", 1000))

func test_one_restoration_at_a_time() -> void:
	IsletModel.start_restore(state.data, defs, econ, timers, "lantern_shoal", 1000)
	assert_string_contains(
		IsletModel.restore_rejection(state.data, defs, econ, timers, "lantern_shoal"),
		"already underway")

func test_rejection_names_the_cost_shortfall() -> void:
	state.data["currencies"]["scrap"] = 0
	assert_string_contains(
		IsletModel.restore_rejection(state.data, defs, econ, timers, "lantern_shoal"),
		"Not enough")

func test_complete_restore_marks_restored_and_opens_plots() -> void:
	IsletModel.start_restore(state.data, defs, econ, timers, "lantern_shoal", 1000)
	var payload: Dictionary = timers.collect("restore_lantern_shoal", 1000 + 14400)
	IsletModel.complete_restore(state.data, payload)
	assert_true(IsletModel.is_restored(state.data, "lantern_shoal"))
	assert_eq(IsletModel.open_plots(state.data, defs), ["islet_lantern_0"] as Array[String])
	assert_eq(IsletModel.next_offered(state.data, defs), "foundry_rock",
		"restoring the first islet offers the second")

func test_complete_restore_is_idempotent_and_ignores_junk() -> void:
	IsletModel.complete_restore(state.data, {})
	IsletModel.complete_restore(state.data, {"islet": "no_such_islet"})
	IsletModel.complete_restore(state.data, {"islet": "lantern_shoal"})
	IsletModel.complete_restore(state.data, {"islet": "lantern_shoal"})
	assert_true(IsletModel.is_restored(state.data, "lantern_shoal"))
	assert_eq(((state.data["islets"] as Dictionary)["restored"] as Dictionary).size(), 2,
		"junk ids do not crash; unknown ids are recorded harmlessly or skipped")

func test_complete_restore_heals_a_wrong_typed_section() -> void:
	state.data["islets"] = 7
	IsletModel.complete_restore(state.data, {"islet": "lantern_shoal"})
	assert_true(IsletModel.is_restored(state.data, "lantern_shoal"),
		"write-back discipline: a mangled islets section is rebuilt, never mutated detached")

func test_already_restored_is_rejected() -> void:
	IsletModel.complete_restore(state.data, {"islet": "lantern_shoal"})
	assert_string_contains(
		IsletModel.restore_rejection(state.data, defs, econ, timers, "lantern_shoal"),
		"already restored")

func test_unknown_islet_is_rejected() -> void:
	assert_ne(IsletModel.restore_rejection(state.data, defs, econ, timers, "atlantis"), "")

func test_islet_of_plot_maps_both_ways() -> void:
	assert_eq(IsletModel.islet_of_plot(defs, "islet_lantern_0"), "lantern_shoal")
	assert_eq(IsletModel.islet_of_plot(defs, "plot_0"), "")

func test_unlock_text_names_the_islet_building() -> void:
	assert_eq(IsletModel.unlock_text(DataDefs.buildings, "lantern_shoal"),
		"Unlocks a plot for the Lens Array.")
	assert_eq(IsletModel.unlock_text(DataDefs.buildings, "foundry_rock"),
		"Unlocks a plot for the Foundry Annex.")
	assert_eq(IsletModel.unlock_text(DataDefs.buildings, "atlantis"), "",
		"an islet with no exclusive building stays silent")

func test_shipped_data_has_no_duplicate_plot_ids() -> void:
	assert_eq(IsletModel.duplicate_plot_ids(DataDefs.islets), [],
		"authoring guard, mirrors the barge-id uniqueness check")
