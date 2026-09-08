extends GutTest

const IslandScene := preload("res://game/base/island_screen.tscn")
const TEST_SAVE := "user://test_island_screen.json"

var screen


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	GameState.data["currencies"]["scrap"] = 2000
	GameState.data["created_at"] = 1000
	GameState.data["fuel"]["updated_at"] = 1000
	screen = add_child_autofree(IslandScene.instantiate())
	await wait_physics_frames(1)

func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_island_screen.json", "test_island_screen.json.tmp", "test_island_screen.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings)


func test_builds_one_row_per_plot_plus_islets_plus_crew() -> void:
	assert_eq(screen.get_node("Rows").get_child_count(),
		int(DataDefs.buildings["plot_count"]) + IsletModel.islets(DataDefs.islets).size()
			+ CrewModel.members(DataDefs.crew).size(),
		"fresh save: home plots, one status row per islet, one row per crew def")

func test_select_cycles_unbuilt_buildings() -> void:
	screen._on_select_pressed("plot_0")
	assert_eq(String(screen._selection["plot_0"]), "workshop", "first def id")
	screen._on_select_pressed("plot_0")
	assert_eq(String(screen._selection["plot_0"]), "wind_still")

func test_build_starts_construction_through_model() -> void:
	screen._on_select_pressed("plot_0")
	screen._on_build_pressed("plot_0")
	assert_true(TimerService.active_timers().has("build_plot_0"))
	assert_eq(Economy.balance("scrap"), 2000 - 60)

func test_collect_applies_completion_and_reapplies_fuel_effects() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "wind_still", "level": 0}
	TimerService.start("build_plot_0", "construction", 10, 1000, {"plot": "plot_0", "building": "wind_still", "to_level": 1})
	TimerService._state.data["timers"]["build_plot_0"]["ends_at"] = 0
	screen._on_collect_pressed("plot_0")
	assert_eq(IslandModel.building_level(GameState.data["island"], "wind_still"), 1)
	assert_eq(int(GameState.data["fuel"]["cap"]), 6, "wind still completion re-applies fuel effects")

func test_built_building_no_longer_offered_for_empty_plots() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	screen._rebuild()
	screen._on_select_pressed("plot_1")
	assert_ne(String(screen._selection["plot_1"]), "workshop")

func test_built_observatory_shows_its_teaser() -> void:
	GameState.data["island"]["plots"]["plot_3"] = {"building": "observatory", "level": 1}
	var text: String = screen._row_text("plot_3", GameState.data["island"], TimeUtil.now())
	assert_string_contains(text, "Brasswork Reach",
		"spec 4.1: the Observatory reveals upcoming regions")

func test_gardens_collect_credits_scrap() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	GameState.data["trickle"]["last_collect"] = TimeUtil.now() - 3600
	var scrap_before := Economy.balance("scrap")
	screen._on_gardens_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 20)
	assert_eq(TrickleModel.pending(GameState.data, DataDefs.buildings, TimeUtil.now()), 0)

func test_crate_claims_once() -> void:
	GameState.data["daily_crate"]["last_claim_day"] = 0
	var scrap_before := Economy.balance("scrap")
	var crystals_before := Economy.balance("crystals")
	screen._on_crate_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 40)
	assert_eq(Economy.balance("crystals"), crystals_before + 1)
	screen._on_crate_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 40, "second claim same day is a no-op")

func test_slot_button_unlocks_second_slot() -> void:
	GameState.data["currencies"]["crystals"] = 30
	screen._on_slot_pressed()
	assert_eq(int(GameState.data["island"]["build_slots"]), 2)
	assert_eq(Economy.balance("crystals"), 10)

func test_skip_completes_a_construction_timer() -> void:
	screen._on_select_pressed("plot_0")
	screen._on_build_pressed("plot_0")
	assert_true(TimerService.active_timers().has("build_plot_0"))
	screen._on_skip_pressed("build_plot_0")
	assert_true(TimerService.is_done("build_plot_0", TimeUtil.now()),
		"spec 6 placement 1: an ad skips the timer; the player still collects")

func test_bonus_crate_pays_and_respects_the_daily_limit() -> void:
	var scrap_before := Economy.balance("scrap")
	screen._on_bonus_crate_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 40)
	GameState.data["ads"]["day"] = DailyCrate.day_of(TimeUtil.now())
	screen._on_bonus_crate_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 40, "bonus crate is once per day")

func test_bonus_crate_is_independent_of_the_free_crate() -> void:
	GameState.data["daily_crate"]["last_claim_day"] = 0
	var scrap_before := Economy.balance("scrap")
	screen._on_crate_pressed()
	screen._on_bonus_crate_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 80,
		"the free crate and the ad crate are separate faucets (spec 6 placement 4)")

func test_first_construction_completion_requests_notification_permission() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 0}
	TimerService.start("build_plot_0", "construction", 10, 1000, {"plot": "plot_0", "building": "workshop", "to_level": 1})
	TimerService._state.data["timers"]["build_plot_0"]["ends_at"] = 0
	screen._on_collect_pressed("plot_0")
	assert_true(bool(GameState.data["notifications"]["permission_requested"]),
		"spec 5: permission asked at the first construction completion, not at launch")

func test_tick_without_state_change_keeps_row_nodes_alive() -> void:
	var row_before: Node = screen.get_node("Rows").get_child(0)
	screen._refresh_tick()
	assert_true(is_instance_valid(row_before) and not row_before.is_queued_for_deletion(),
		"per-second ticks must not free a button under the player's finger")

func test_tick_rebuilds_when_a_timer_finishes() -> void:
	screen._on_select_pressed("plot_0")
	screen._on_build_pressed("plot_0")
	screen._refresh_tick()
	var running_signature: String = screen._last_signature
	TimerService._state.data["timers"]["build_plot_0"]["ends_at"] = 0
	screen._refresh_tick()
	assert_ne(screen._last_signature, running_signature,
		"done is structural: the Complete! button must appear")

func test_slot_button_disabled_when_crystals_are_short() -> void:
	GameState.data["currencies"]["crystals"] = 0
	screen._rebuild()
	assert_true(screen.get_node("SlotButton").disabled)

func test_rejected_build_explains_itself() -> void:
	GameState.data["currencies"]["scrap"] = 0
	screen._on_select_pressed("plot_0")
	screen._on_build_pressed("plot_0")
	assert_string_contains(screen.get_node("StatusLabel").text, "Not enough")

func test_successful_build_clears_the_status() -> void:
	GameState.data["currencies"]["scrap"] = 0
	screen._on_select_pressed("plot_0")
	screen._on_build_pressed("plot_0")
	GameState.data["currencies"]["scrap"] = 2000
	screen._on_build_pressed("plot_0")
	assert_eq(screen.get_node("StatusLabel").text, "")

func test_any_completion_reapplies_fuel_effects() -> void:
	GameState.data["fuel"]["cap"] = 99
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 0}
	TimerService.start("build_plot_0", "construction", 10, 1000, {"plot": "plot_0", "building": "workshop", "to_level": 1})
	TimerService._state.data["timers"]["build_plot_0"]["ends_at"] = 0
	screen._on_collect_pressed("plot_0")
	assert_eq(int(GameState.data["fuel"]["cap"]), 5,
		"apply_fuel is unconditional and idempotent; a mangled cap heals at any collect")

func test_selection_change_clears_stale_status() -> void:
	screen.get_node("StatusLabel").text = "Not enough resources."
	screen._on_select_pressed("plot_0")
	assert_eq(screen.get_node("StatusLabel").text, "", "a stale rejection must not outlive the selection it judged")

func restore_lantern() -> void:
	(GameState.data["islets"]["restored"] as Dictionary)["lantern_shoal"] = true
	screen._rebuild()


func test_restore_pays_and_starts_the_restoration_timer() -> void:
	GameState.data["currencies"]["cloudsilk"] = 10
	screen._on_restore_pressed("lantern_shoal")
	assert_true(TimerService.active_timers().has("restore_lantern_shoal"))
	assert_eq(Economy.balance("scrap"), 2000 - 600)
	assert_eq(screen.get_node("StatusLabel").text, "")

func test_rejected_restore_explains_itself() -> void:
	GameState.data["currencies"]["scrap"] = 0
	screen._on_restore_pressed("lantern_shoal")
	assert_false(TimerService.active_timers().has("restore_lantern_shoal"))
	assert_string_contains(screen.get_node("StatusLabel").text, "Not enough")

func test_out_of_order_restore_is_rejected_with_a_reason() -> void:
	GameState.data["currencies"]["brasswork"] = 50
	screen._on_restore_pressed("foundry_rock")
	assert_false(TimerService.active_timers().has("restore_foundry_rock"))
	assert_string_contains(screen.get_node("StatusLabel").text, "Another islet")

func test_restore_collect_marks_restored_and_opens_the_letter() -> void:
	GameState.data["currencies"]["cloudsilk"] = 10
	screen._on_restore_pressed("lantern_shoal")
	TimerService._state.data["timers"]["restore_lantern_shoal"]["ends_at"] = 0
	screen._on_restore_collect_pressed("lantern_shoal")
	assert_true(IsletModel.is_restored(GameState.data, "lantern_shoal"))
	assert_true(screen.get_node("LetterPanel").visible)
	assert_string_contains(String(screen.get_node("LetterPanel/VBox/LetterBody").text), "lanterns were never for us")

func test_letter_close_records_letters_seen() -> void:
	restore_lantern()
	screen._on_read_letter_pressed("lantern_shoal")
	assert_true(screen.get_node("LetterPanel").visible, "letters stay re-readable forever")
	screen._on_letter_close_pressed()
	assert_false(screen.get_node("LetterPanel").visible)
	assert_true(bool((GameState.data["islets"]["letters_seen"] as Dictionary)["lantern_shoal"]))

func test_restored_islet_contributes_its_plot_row() -> void:
	restore_lantern()
	assert_eq(screen.get_node("Rows").get_child_count(),
		int(DataDefs.buildings["plot_count"]) + 1 + IsletModel.islets(DataDefs.islets).size()
			+ CrewModel.members(DataDefs.crew).size(),
		"the restored islet's plot joins the list")

func test_islet_plot_offers_only_its_islet_building() -> void:
	restore_lantern()
	screen._on_select_pressed("islet_lantern_0")
	assert_eq(String(screen._selection["islet_lantern_0"]), "lens_array")
	screen._on_select_pressed("islet_lantern_0")
	assert_eq(String(screen._selection["islet_lantern_0"]), "lens_array",
		"the cycle contains exactly the one islet building")

func test_home_plot_never_offers_islet_buildings() -> void:
	var offered: Array[String] = screen._unbuilt_ids("plot_0")
	assert_false("lens_array" in offered)
	assert_false("foundry_annex" in offered)

func test_building_on_an_islet_plot_goes_through_the_model() -> void:
	restore_lantern()
	GameState.data["currencies"]["cloudsilk"] = 10
	screen._on_select_pressed("islet_lantern_0")
	screen._on_build_pressed("islet_lantern_0")
	assert_true(TimerService.active_timers().has("build_islet_lantern_0"))

func test_finishing_a_restoration_changes_the_signature() -> void:
	GameState.data["currencies"]["cloudsilk"] = 10
	screen._on_restore_pressed("lantern_shoal")
	screen._refresh_tick()
	var running_signature: String = screen._last_signature
	TimerService._state.data["timers"]["restore_lantern_shoal"]["ends_at"] = 0
	screen._refresh_tick()
	assert_ne(screen._last_signature, running_signature,
		"done is structural: the collect button must appear")


func rescue_and_rebuild(ids: Array) -> void:
	for id in ids:
		CrewModel.rescue(GameState.data, String(id))
	screen._rebuild()


func crew_row_count() -> int:
	return screen.get_node("Rows").get_child_count()


func test_crew_rows_exist_for_the_whole_cast() -> void:
	var base := int(DataDefs.buildings["plot_count"]) + IsletModel.islets(DataDefs.islets).size()
	assert_eq(crew_row_count(), base + CrewModel.members(DataDefs.crew).size(),
		"every crew def gets a row, rescued or not")

func test_unrescued_crew_show_as_silhouettes() -> void:
	assert_string_contains(screen._crew_row_text(CrewModel.entry(DataDefs.crew, "odo")),
		"still out there")

func test_rescued_crew_show_name_and_specialty() -> void:
	rescue_and_rebuild(["odo"])
	var text: String = screen._crew_row_text(CrewModel.entry(DataDefs.crew, "odo"))
	assert_string_contains(text, "Odo")
	assert_string_contains(text, "Gardens")

func test_assign_cycle_walks_workable_then_idle() -> void:
	rescue_and_rebuild(["odo"])
	screen._on_assign_pressed("odo")
	assert_eq(CrewModel.building_of(GameState.data, "odo"), "gardens", "first workable")
	screen._on_assign_pressed("odo")
	assert_eq(CrewModel.building_of(GameState.data, "odo"), "workshop")
	for i in 4:
		screen._on_assign_pressed("odo")
	assert_eq(CrewModel.building_of(GameState.data, "odo"), "smeltery", "last workable")
	screen._on_assign_pressed("odo")
	assert_eq(CrewModel.building_of(GameState.data, "odo"), "", "then back to idle")

func test_assignment_persists() -> void:
	rescue_and_rebuild(["odo"])
	screen._on_assign_pressed("odo")
	var saved := SaveIO.new(TEST_SAVE).read()
	assert_eq(String((saved["crew"]["assignments"] as Dictionary).get("gardens", "")), "odo")

func test_wind_still_assignment_reapplies_fuel_effects() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "wind_still", "level": 1}
	rescue_and_rebuild(["brisa"])
	screen._on_assign_pressed("brisa")
	screen._on_assign_pressed("brisa")
	screen._on_assign_pressed("brisa")
	assert_eq(CrewModel.building_of(GameState.data, "brisa"), "wind_still")
	assert_eq(int(GameState.data["fuel"]["regen_seconds"]), 720,
		"(1200 - 120) / 1.5: the handler re-applies fuel effects")

func test_worker_suffix_on_building_rows() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	rescue_and_rebuild(["odo"])
	screen._on_assign_pressed("odo")
	assert_string_contains(screen._row_text("plot_2", GameState.data["island"], TimeUtil.now()),
		"Odo working")

func test_rescue_and_assignment_are_structural_signature_changes() -> void:
	screen._refresh_tick()
	var before: String = screen._last_signature
	CrewModel.rescue(GameState.data, "odo")
	screen._refresh_tick()
	assert_ne(screen._last_signature, before, "a rescue rebuilds the rows")
	var mid: String = screen._last_signature
	screen._on_assign_pressed("odo")
	screen._refresh_tick()
	assert_ne(screen._last_signature, mid, "an assignment rebuilds too")

func test_gardens_collect_pays_the_crewed_rate() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	rescue_and_rebuild(["odo"])
	var now := TimeUtil.now()
	CrewModel.assign(GameState.data, DataDefs.crew, "gardens", "odo", DataDefs.buildings, now - 3600)
	GameState.data["trickle"]["last_collect"] = now - 3600
	var scrap_before := Economy.balance("scrap")
	screen._on_gardens_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 30, "20/hour x 1.5 specialist")

func with_smeltery(level: int) -> void:
	GameState.data["island"]["plots"]["plot_1"] = {"building": "smeltery", "level": level}
	GameState.data["currencies"]["scrap"] = 2000
	screen._rebuild()


func test_batch_start_pays_and_starts() -> void:
	with_smeltery(1)
	screen._on_batch_start_pressed("smeltery")
	assert_true(TimerService.active_timers().has("convert_smeltery"))
	assert_eq(Economy.balance("scrap"), 2000 - 40)

func test_batch_collect_credits_scaled_outputs() -> void:
	with_smeltery(2)
	screen._on_batch_start_pressed("smeltery")
	TimerService._state.data["timers"]["convert_smeltery"]["ends_at"] = 0
	screen._on_batch_collect_pressed("smeltery")
	assert_eq(Economy.balance("parts"), 2, "level 2 pays double")
	assert_false(TimerService.active_timers().has("convert_smeltery"))

func test_batch_start_persists() -> void:
	with_smeltery(1)
	screen._on_batch_start_pressed("smeltery")
	var saved := SaveIO.new(TEST_SAVE).read()
	assert_true((saved["timers"] as Dictionary).has("convert_smeltery"),
		"a paid batch must survive an OS kill")

func test_running_batch_joins_the_signature_and_row_text() -> void:
	with_smeltery(1)
	screen._refresh_tick()
	var idle_signature: String = screen._last_signature
	screen._on_batch_start_pressed("smeltery")
	screen._refresh_tick()
	assert_ne(screen._last_signature, idle_signature, "a starting batch is structural")
	var running_signature: String = screen._last_signature
	assert_string_contains(screen._row_text("plot_1", GameState.data["island"], TimeUtil.now()), "batch",
		"the countdown rides the row label")
	TimerService._state.data["timers"]["convert_smeltery"]["ends_at"] = 0
	screen._refresh_tick()
	assert_ne(screen._last_signature, running_signature, "done is structural: Collect must appear")

func test_zero_input_gardens_batch_starts_broke() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	GameState.data["currencies"]["scrap"] = 0
	screen._rebuild()
	screen._on_batch_start_pressed("gardens")
	assert_true(TimerService.active_timers().has("convert_gardens"))
