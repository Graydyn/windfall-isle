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


func test_builds_map_nodes_for_plots_islets_and_crew() -> void:
	assert_eq(screen.get_node("MapScroll/Map/Plots").get_child_count(),
		int(DataDefs.buildings["plot_count"]), "fresh save: one pad per home plot")
	assert_eq(screen.get_node("MapScroll/Map/Islets").get_child_count(),
		IsletModel.islets(DataDefs.islets).size(), "one marker per islet")
	assert_null(screen.get_node_or_null("MapScroll/Map/CrewBand"),
		"crew left the map for the crew sheet (owner request, 2026-10-16)")

func test_choose_opens_the_modal_on_the_first_candidate() -> void:
	screen._open_build_modal("plot_0")
	assert_true(screen.get_node("BuildModal").visible)
	assert_eq(screen._modal_building(), "workshop", "first def id")
	var def: Dictionary = (DataDefs.buildings["defs"] as Dictionary)["workshop"]
	assert_eq(String(screen.get_node("BuildModal/VBox/ModalTitle").text), String(def["name"]))
	assert_eq(String(screen.get_node("BuildModal/VBox/ModalFlavor").text), String(def["flavor"]))
	assert_eq(String(screen.get_node("BuildModal/VBox/ModalDescription").text), String(def["description"]))
	assert_string_contains(String(screen.get_node("BuildModal/VBox/ModalCost").text), "60 scrap")
	assert_not_null(screen.get_node("BuildModal/VBox/ModalPicture").texture,
		"the modal picture carries the building's illustration")
	assert_eq(String(screen.get_node("BuildModal/VBox/ModalPicture/PictureLetter").text), "",
		"the lettered placeholder is only a fallback for missing art")

func test_modal_browsing_wraps_both_ways() -> void:
	screen._open_build_modal("plot_0")
	screen._on_modal_next_pressed()
	assert_eq(screen._modal_building(), "wind_still")
	screen._on_modal_prev_pressed()
	screen._on_modal_prev_pressed()
	assert_eq(screen._modal_building(), screen._modal_ids[screen._modal_ids.size() - 1],
		"prev from the first candidate wraps to the last")

func test_modal_confirm_starts_construction_through_model() -> void:
	screen._open_build_modal("plot_0")
	screen._on_modal_confirm_pressed()
	assert_true(TimerService.active_timers().has("build_plot_0"))
	assert_eq(Economy.balance("scrap"), 2000 - 60)
	assert_false(screen.get_node("BuildModal").visible, "a successful build closes the modal")

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
	screen._open_build_modal("plot_1")
	assert_false((screen._modal_ids as Array).has("workshop"))

func test_built_observatory_shows_its_teaser_in_the_sheet() -> void:
	GameState.data["island"]["plots"]["plot_3"] = {"building": "observatory", "level": 1}
	screen._rebuild()
	screen._on_plot_tapped("plot_3")
	assert_string_contains(String(screen.get_node("PlotSheet/VBox/SheetInfo").text), "Brasswork Reach",
		"spec 4.1: the Observatory reveals upcoming regions")

func test_plot_sheet_carries_the_building_flavor_and_description() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	screen._rebuild()
	screen._on_plot_tapped("plot_0")
	var def: Dictionary = (DataDefs.buildings["defs"] as Dictionary)["workshop"]
	assert_eq(String(screen.get_node("PlotSheet/VBox/SheetFlavor").text), String(def["flavor"]))
	assert_eq(String(screen.get_node("PlotSheet/VBox/SheetDescription").text), String(def["description"]))
	assert_true(screen.get_node("PlotSheet/VBox/SheetFlavor").visible)
	assert_true(screen.get_node("PlotSheet/VBox/SheetDescription").visible)

func test_upgrade_modal_leaves_lore_to_the_sheet() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	screen._open_build_modal("plot_0")
	assert_false(screen.get_node("BuildModal/VBox/ModalFlavor").visible,
		"the sheet already told the story; the upgrade modal is just for upgrading")
	assert_false(screen.get_node("BuildModal/VBox/ModalDescription").visible)

func test_build_modal_still_shows_lore_for_an_empty_plot() -> void:
	screen._open_build_modal("plot_0")
	assert_true(screen.get_node("BuildModal/VBox/ModalFlavor").visible,
		"an empty plot has no sheet before the modal, so the lore stays")
	assert_true(screen.get_node("BuildModal/VBox/ModalDescription").visible)

func test_islet_sheet_hides_building_lore_labels() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	screen._rebuild()
	screen._on_plot_tapped("plot_0")
	screen._on_islet_tapped("lantern_shoal")
	assert_false(screen.get_node("PlotSheet/VBox/SheetFlavor").visible,
		"the shared sheet must not leak the last building's lore onto an islet")
	assert_false(screen.get_node("PlotSheet/VBox/SheetDescription").visible)

func test_gardens_tap_collects_the_trickle() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	GameState.data["trickle"]["last_collect"] = TimeUtil.now() - 3600
	screen._rebuild()
	var scrap_before := Economy.balance("scrap")
	screen._on_plot_tapped("plot_2")
	assert_eq(Economy.balance("scrap"), scrap_before + 20)
	assert_eq(TrickleModel.pending(GameState.data, DataDefs.buildings, TimeUtil.now()), 0)
	assert_false(screen.get_node("PlotSheet").visible,
		"the tap collects; the vanishing bubble is the receipt (owner request, 2026-10-17)")

func test_gardens_tap_with_nothing_pending_opens_the_sheet() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	GameState.data["trickle"]["last_collect"] = TimeUtil.now()
	screen._rebuild()
	screen._on_plot_tapped("plot_2")
	assert_true(screen.get_node("PlotSheet").visible, "collected out: the next tap talks shop")

func test_gardens_bubble_carries_the_pending_scrap() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	GameState.data["trickle"]["last_collect"] = TimeUtil.now() - 3600
	screen._rebuild()
	assert_eq(String(screen._plot_state("plot_2", TimeUtil.now()).get("bubble", "")), "+20 scrap")
	GameState.data["trickle"]["last_collect"] = TimeUtil.now()
	assert_eq(String(screen._plot_state("plot_2", TimeUtil.now()).get("bubble", "")), "",
		"nothing pending, no bubble")

func test_trickle_bubble_appears_on_a_plain_tick() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	GameState.data["trickle"]["last_collect"] = TimeUtil.now()
	screen._rebuild()
	var node: IslandPlotNode = screen._plot_nodes["plot_2"]
	assert_false(node._bubble.visible)
	GameState.data["trickle"]["last_collect"] = TimeUtil.now() - 3600
	screen._refresh_tick()
	assert_true(node._bubble.visible,
		"pending scrap is not structural; the label refresh path must carry the bubble")

func test_done_gardens_batch_outranks_the_trickle_on_one_tap() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	GameState.data["trickle"]["last_collect"] = TimeUtil.now() - 3600
	screen._rebuild()
	screen._on_batch_start_pressed("gardens", "put_up_provisions")
	TimerService._state.data["timers"]["convert_gardens"]["ends_at"] = 0
	var scrap_before := Economy.balance("scrap")
	screen._on_plot_tapped("plot_2")
	assert_eq(Economy.balance("provisions"), 2, "the finished batch collects first")
	assert_eq(Economy.balance("scrap"), scrap_before, "the trickle stays for the next tap")

func test_crate_claims_once() -> void:
	GameState.data["daily_crate"]["last_claim_day"] = 0
	var scrap_before := Economy.balance("scrap")
	var crystals_before := Economy.balance("crystals")
	screen._on_crate_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 40)
	assert_eq(Economy.balance("crystals"), crystals_before + 1)
	screen._on_crate_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 40, "second claim same day is a no-op")

func test_crate_opens_a_reward_modal_with_the_payout() -> void:
	# A silent crate reads as a broken button; a status line read as a debug
	# log. The reward gets a proper modal (owner request, 2026-10-17).
	GameState.data["daily_crate"]["last_claim_day"] = 0
	screen._on_crate_pressed()
	assert_true(screen.get_node("RewardModal").visible)
	assert_true(screen.get_node("ModalBlock").visible, "the modal blocks the map under it")
	var body: String = screen.get_node("RewardModal/VBox/RewardBody").text
	assert_string_contains(body, "+40 scrap")
	assert_string_contains(body, "+1 crystals")

func test_reward_modal_closes() -> void:
	GameState.data["daily_crate"]["last_claim_day"] = 0
	screen._on_crate_pressed()
	screen._on_reward_close_pressed()
	assert_false(screen.get_node("RewardModal").visible)
	assert_false(screen.get_node("ModalBlock").visible)

func test_bonus_crate_opens_the_reward_modal_too() -> void:
	screen._on_bonus_crate_pressed()
	assert_true(screen.get_node("RewardModal").visible)
	assert_string_contains(screen.get_node("RewardModal/VBox/RewardBody").text, "+40 scrap")

func test_modal_offers_the_second_slot_when_builders_are_busy() -> void:
	GameState.data["currencies"]["crystals"] = 30
	screen._open_build_modal("plot_0")
	screen._on_modal_confirm_pressed()
	screen._open_build_modal("plot_1")
	var offer: Button = screen.get_node("BuildModal/VBox/ModalSlotButton")
	assert_true(offer.visible, "every builder busy and a slot still for sale")
	assert_string_contains(offer.text, "20 crystals")
	screen._on_modal_slot_pressed()
	assert_eq(int(GameState.data["island"]["build_slots"]), 2)
	assert_eq(Economy.balance("crystals"), 10)
	assert_false(offer.visible, "bought: the offer leaves the modal")
	assert_true(screen.get_node("BuildModal").visible, "the player carries on building")

func test_modal_slot_offer_disabled_when_crystals_are_short() -> void:
	GameState.data["currencies"]["crystals"] = 0
	screen._open_build_modal("plot_0")
	screen._on_modal_confirm_pressed()
	screen._open_build_modal("plot_1")
	assert_true(screen.get_node("BuildModal/VBox/ModalSlotButton").visible)
	assert_true(screen.get_node("BuildModal/VBox/ModalSlotButton").disabled)

func test_modal_hides_the_slot_offer_while_a_builder_is_free() -> void:
	screen._open_build_modal("plot_0")
	assert_false(screen.get_node("BuildModal/VBox/ModalSlotButton").visible)

func test_modal_never_offers_a_third_slot() -> void:
	GameState.data["island"]["build_slots"] = 2
	GameState.data["currencies"]["crystals"] = 30
	screen._open_build_modal("plot_0")
	screen._on_modal_confirm_pressed()
	screen._open_build_modal("plot_1")
	screen._on_modal_confirm_pressed()
	screen._open_build_modal("plot_2")
	assert_false(screen.get_node("BuildModal/VBox/ModalSlotButton").visible,
		"both builders busy but there is no third slot to sell")

func test_crate_icons_float_only_while_claimable() -> void:
	GameState.data["daily_crate"]["last_claim_day"] = 0
	screen._rebuild()
	assert_true(screen.get_node("DailyCrateIcon").visible)
	assert_true(screen.get_node("BonusCrateIcon").visible)
	screen._on_crate_pressed()
	assert_false(screen.get_node("DailyCrateIcon").visible, "claimed today: the icon leaves the sky")
	screen._on_bonus_crate_pressed()
	assert_false(screen.get_node("BonusCrateIcon").visible, "the ad crate obeys its daily limit")

func test_the_hud_row_is_gone() -> void:
	for gone in ["GardensButton", "CrateButton", "BonusCrateButton", "SlotButton", "WorkshopButton", "CrewButton"]:
		assert_null(screen.get_node_or_null(String(gone)),
			"%s dissolved into the map (owner request, 2026-10-17)" % String(gone))

func test_skip_completes_a_construction_timer() -> void:
	screen._open_build_modal("plot_0")
	screen._on_modal_confirm_pressed()
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

func test_tick_without_state_change_keeps_map_nodes_alive() -> void:
	var node_before: Node = screen.get_node("MapScroll/Map/Plots").get_child(0)
	screen._refresh_tick()
	assert_true(is_instance_valid(node_before) and not node_before.is_queued_for_deletion(),
		"per-second ticks must not free a pad under the player's finger")

func test_tick_rebuilds_when_a_timer_finishes() -> void:
	screen._open_build_modal("plot_0")
	screen._on_modal_confirm_pressed()
	screen._refresh_tick()
	var running_signature: String = screen._last_signature
	TimerService._state.data["timers"]["build_plot_0"]["ends_at"] = 0
	screen._refresh_tick()
	assert_ne(screen._last_signature, running_signature,
		"done is structural: the Complete! button must appear")

func test_rejected_build_explains_itself_inside_the_modal() -> void:
	GameState.data["currencies"]["scrap"] = 0
	screen._open_build_modal("plot_0")
	screen._on_modal_confirm_pressed()
	assert_true(screen.get_node("BuildModal").visible, "a rejected build keeps the modal open")
	assert_string_contains(String(screen.get_node("BuildModal/VBox/ModalStatus").text), "Not enough")

func test_retry_after_rejection_builds_and_closes() -> void:
	GameState.data["currencies"]["scrap"] = 0
	screen._open_build_modal("plot_0")
	screen._on_modal_confirm_pressed()
	GameState.data["currencies"]["scrap"] = 2000
	screen._on_modal_confirm_pressed()
	assert_true(TimerService.active_timers().has("build_plot_0"))
	assert_false(screen.get_node("BuildModal").visible)

func test_any_completion_reapplies_fuel_effects() -> void:
	GameState.data["fuel"]["cap"] = 99
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 0}
	TimerService.start("build_plot_0", "construction", 10, 1000, {"plot": "plot_0", "building": "workshop", "to_level": 1})
	TimerService._state.data["timers"]["build_plot_0"]["ends_at"] = 0
	screen._on_collect_pressed("plot_0")
	assert_eq(int(GameState.data["fuel"]["cap"]), 5,
		"apply_fuel is unconditional and idempotent; a mangled cap heals at any collect")

func test_reopening_the_modal_clears_stale_status() -> void:
	GameState.data["currencies"]["scrap"] = 0
	screen._open_build_modal("plot_0")
	screen._on_modal_confirm_pressed()
	screen._on_modal_cancel_pressed()
	assert_false(screen.get_node("BuildModal").visible)
	screen._open_build_modal("plot_0")
	assert_eq(String(screen.get_node("BuildModal/VBox/ModalStatus").text), "",
		"a stale rejection must not outlive the visit it judged")

func test_browsing_clears_stale_status() -> void:
	GameState.data["currencies"]["scrap"] = 0
	screen._open_build_modal("plot_0")
	screen._on_modal_confirm_pressed()
	screen._on_modal_next_pressed()
	assert_eq(String(screen.get_node("BuildModal/VBox/ModalStatus").text), "",
		"the rejection judged another card")

func test_upgrade_opens_a_locked_modal() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	GameState.data["currencies"]["cloudsilk"] = 20
	screen._rebuild()
	screen._open_build_modal("plot_0")
	assert_eq((screen._modal_ids as Array).size(), 1, "an occupied plot browses nothing")
	assert_false(screen.get_node("BuildModal/VBox/NavRow").visible)
	assert_string_contains(String(screen.get_node("BuildModal/VBox/ActionRow/ConfirmButton").text), "Upgrade to Lv 2")
	assert_string_contains(String(screen.get_node("BuildModal/VBox/ModalCost").text), "240 scrap")
	screen._on_modal_confirm_pressed()
	assert_true(TimerService.active_timers().has("build_plot_0"))
	assert_eq(Economy.balance("scrap"), 2000 - 240)

func test_max_level_disables_the_confirm() -> void:
	GameState.data["island"]["plots"]["plot_3"] = {"building": "observatory", "level": 2}
	screen._rebuild()
	screen._open_build_modal("plot_3")
	assert_true(screen.get_node("BuildModal/VBox/ActionRow/ConfirmButton").disabled)
	assert_string_contains(String(screen.get_node("BuildModal/VBox/ModalCost").text), "Max level")

func restore_lantern() -> void:
	(GameState.data["islets"]["restored"] as Dictionary)["lantern_shoal"] = true
	screen._rebuild()


func test_restore_pays_and_starts_the_restoration_timer() -> void:
	GameState.data["currencies"]["cloudsilk"] = 10
	screen._on_restore_pressed("lantern_shoal")
	assert_true(TimerService.active_timers().has("restore_lantern_shoal"))
	assert_eq(Economy.balance("scrap"), 2000 - 600)

func test_rejected_restore_is_a_noop() -> void:
	# The sheet's own restore button explains refusals in SheetInfo; the
	# handler guard just refuses quietly (StatusLabel removed 2026-10-17).
	GameState.data["currencies"]["scrap"] = 0
	screen._on_restore_pressed("lantern_shoal")
	assert_false(TimerService.active_timers().has("restore_lantern_shoal"))

func test_out_of_order_restore_is_rejected() -> void:
	GameState.data["currencies"]["brasswork"] = 50
	screen._on_restore_pressed("foundry_rock")
	assert_false(TimerService.active_timers().has("restore_foundry_rock"))

func test_restore_collect_marks_restored_and_opens_the_letter() -> void:
	GameState.data["currencies"]["cloudsilk"] = 10
	screen._on_restore_pressed("lantern_shoal")
	TimerService._state.data["timers"]["restore_lantern_shoal"]["ends_at"] = 0
	screen._on_restore_collect_pressed("lantern_shoal")
	assert_true(IsletModel.is_restored(GameState.data, "lantern_shoal"))
	assert_true(screen.get_node("LetterPanel").visible)
	assert_string_contains(String(screen.get_node("LetterPanel/VBox/LetterScroll/LetterBody").text), "lanterns were never for us")

func test_islet_sheet_names_what_restoring_unlocks() -> void:
	screen._on_islet_tapped("lantern_shoal")
	assert_string_contains(String(screen.get_node("PlotSheet/VBox/SheetInfo").text),
		"Unlocks a plot for the Lens Array.")

func test_letter_names_what_the_islet_unlocked() -> void:
	restore_lantern()
	screen._on_read_letter_pressed("lantern_shoal")
	assert_string_contains(String(screen.get_node("LetterPanel/VBox/LetterScroll/LetterBody").text),
		"Unlocks a plot for the Lens Array.")

func test_letter_close_records_letters_seen() -> void:
	restore_lantern()
	screen._on_read_letter_pressed("lantern_shoal")
	assert_true(screen.get_node("LetterPanel").visible, "letters stay re-readable forever")
	screen._on_letter_close_pressed()
	assert_false(screen.get_node("LetterPanel").visible)
	assert_true(bool((GameState.data["islets"]["letters_seen"] as Dictionary)["lantern_shoal"]))

func test_restored_islet_contributes_its_plot_pad() -> void:
	restore_lantern()
	assert_eq(screen.get_node("MapScroll/Map/Plots").get_child_count(),
		int(DataDefs.buildings["plot_count"]) + 1,
		"the restored islet's plot joins the map")

func test_islet_plot_offers_only_its_islet_building() -> void:
	restore_lantern()
	screen._open_build_modal("islet_lantern_0")
	assert_eq(screen._modal_ids as Array, ["lens_array"], "the islet plot offers exactly its own building")
	screen._on_modal_next_pressed()
	assert_eq(screen._modal_building(), "lens_array", "browsing a single card is a no-op")

func test_home_plot_never_offers_islet_buildings() -> void:
	var offered: Array[String] = screen._unbuilt_ids("plot_0")
	assert_false("lens_array" in offered)
	assert_false("foundry_annex" in offered)

func test_building_on_an_islet_plot_goes_through_the_model() -> void:
	restore_lantern()
	GameState.data["currencies"]["cloudsilk"] = 10
	screen._open_build_modal("islet_lantern_0")
	screen._on_modal_confirm_pressed()
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


func open_crew_sheet() -> void:
	screen._open_crew_sheet()


func test_crew_sheet_lists_the_whole_cast() -> void:
	open_crew_sheet()
	assert_eq(screen.get_node("CrewSheet/VBox/CrewRows").get_child_count(),
		CrewModel.members(DataDefs.crew).size(), "every crew def gets a row, rescued or not")


func test_unrescued_crew_show_as_disabled_silhouettes() -> void:
	var state: Dictionary = screen._crew_visual_state(CrewModel.entry(DataDefs.crew, "odo"))
	assert_eq(String(state["name"]), "???")
	assert_false(bool(state["rescued"]))
	open_crew_sheet()
	var button: Button = screen._crew_rows["odo"]
	assert_true(button.disabled, "an unrescued crewmember cannot be assigned")


func test_rescued_crew_show_name_and_specialty() -> void:
	rescue_and_rebuild(["odo"])
	var state: Dictionary = screen._crew_visual_state(CrewModel.entry(DataDefs.crew, "odo"))
	assert_eq(String(state["name"]), "Odo")
	assert_string_contains(String(state["line"]), "Gardens")
	open_crew_sheet()
	var button: Button = screen._crew_rows["odo"]
	assert_false(button.disabled)


func test_crew_sheet_assign_button_cycles_the_assignment() -> void:
	rescue_and_rebuild(["odo"])
	open_crew_sheet()
	(screen._crew_rows["odo"] as Button).pressed.emit()
	assert_eq(CrewModel.building_of(GameState.data, "odo"), "gardens",
		"the row button drives the same assign cycle as the old shore tap")
	assert_true(screen.get_node("CrewSheet").visible, "the sheet stays open to keep cycling")

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

func test_worker_badge_rides_the_building_pad() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	rescue_and_rebuild(["odo"])
	screen._on_assign_pressed("odo")
	var state: Dictionary = screen._plot_state("plot_2", TimeUtil.now())
	assert_string_contains(String(state.get("worker_portrait", "")), "odo",
		"the assigned worker's portrait badges the pad")

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
	screen._on_plot_tapped("plot_2")
	assert_eq(Economy.balance("scrap"), scrap_before + 30, "20/hour x 1.5 specialist")

func with_smeltery(level: int) -> void:
	GameState.data["island"]["plots"]["plot_1"] = {"building": "smeltery", "level": level}
	GameState.data["currencies"]["scrap"] = 2000
	screen._rebuild()


func test_batch_start_pays_and_starts() -> void:
	with_smeltery(1)
	screen._on_batch_start_pressed("smeltery", "smelt")
	assert_true(TimerService.active_timers().has("convert_smeltery"))
	assert_eq(Economy.balance("scrap"), 2000 - 40)

func test_batch_collect_credits_scaled_outputs() -> void:
	with_smeltery(2)
	screen._on_batch_start_pressed("smeltery", "smelt")
	TimerService._state.data["timers"]["convert_smeltery"]["ends_at"] = 0
	screen._on_batch_collect_pressed("smeltery")
	assert_eq(Economy.balance("parts"), 2, "level 2 pays double")
	assert_false(TimerService.active_timers().has("convert_smeltery"))

func test_batch_start_persists() -> void:
	with_smeltery(1)
	screen._on_batch_start_pressed("smeltery", "smelt")
	var saved := SaveIO.new(TEST_SAVE).read()
	assert_true((saved["timers"] as Dictionary).has("convert_smeltery"),
		"a paid batch must survive an OS kill")

func test_running_batch_joins_the_signature_and_row_text() -> void:
	with_smeltery(1)
	screen._refresh_tick()
	var idle_signature: String = screen._last_signature
	screen._on_batch_start_pressed("smeltery", "smelt")
	screen._refresh_tick()
	assert_ne(screen._last_signature, idle_signature, "a starting batch is structural")
	var running_signature: String = screen._last_signature
	assert_string_contains(String(screen._plot_state("plot_1", TimeUtil.now()).get("status", "")), "batch",
		"the countdown rides the pad's status label")
	TimerService._state.data["timers"]["convert_smeltery"]["ends_at"] = 0
	screen._refresh_tick()
	assert_ne(screen._last_signature, running_signature, "done is structural: Collect must appear")

func test_zero_input_gardens_batch_starts_broke() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	GameState.data["currencies"]["scrap"] = 0
	screen._rebuild()
	screen._on_batch_start_pressed("gardens", "put_up_provisions")
	assert_true(TimerService.active_timers().has("convert_gardens"))

func test_balloonworks_row_offers_all_three_recipes() -> void:
	GameState.data["island"]["plots"]["plot_3"] = {"building": "balloonworks", "level": 1}
	screen._rebuild()
	assert_string_contains(screen._batch_button_text("balloonworks", "charged_ballast"), "Charged Ballast (")
	assert_string_contains(screen._batch_button_text("balloonworks", "wind_charm"), "Wind Charm (")
	assert_string_contains(screen._batch_button_text("balloonworks", "storm_oil"), "Storm Oil (")
	GameState.data["currencies"]["cloudsilk"] = 5
	GameState.data["currencies"]["parts"] = 5
	screen._on_batch_start_pressed("balloonworks", "storm_oil")
	assert_true(TimerService.active_timers().has("convert_balloonworks"))
	assert_eq(Economy.balance("parts"), 5 - 2)

func test_workshop_bubble_counts_distinct_craftable_gizmos() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	GameState.data["currencies"]["parts"] = 2
	screen._rebuild()
	assert_eq(String(screen._plot_state("plot_0", TimeUtil.now()).get("bubble", "")), "3 craftable",
		"2 parts afford wind_fan, balloon_cluster and cargo_net at workshop level 1")
	GameState.data["currencies"]["parts"] = 0
	assert_eq(String(screen._plot_state("plot_0", TimeUtil.now()).get("bubble", "")), "",
		"no resources means no bubble, never a zero")

func test_workshop_sheet_offers_the_enter_button() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	screen._rebuild()
	screen._on_plot_tapped("plot_0")
	var first: Button = screen.get_node("PlotSheet/VBox/SheetActions").get_child(0)
	assert_eq(first.text, "Enter the workshop",
		"the HUD Workshop button moved into the workshop's own sheet")

func test_non_workshop_sheet_has_no_enter_button() -> void:
	with_smeltery(1)
	screen._on_plot_tapped("plot_1")
	var first: Button = screen.get_node("PlotSheet/VBox/SheetActions").get_child(0)
	assert_string_contains(first.text, "Upgrade")

func test_crew_quarters_tap_opens_the_crew_sheet() -> void:
	GameState.data["island"]["plots"]["plot_7"] = {"building": "crew_quarters", "level": 1}
	screen._rebuild()
	screen._on_plot_tapped("plot_7")
	assert_true(screen.get_node("CrewSheet").visible,
		"the quarters' sheet IS the crew sheet (owner request, 2026-10-17)")
	assert_false(screen.get_node("PlotSheet").visible)

func test_constructing_crew_quarters_tap_opens_the_plot_sheet() -> void:
	screen._open_build_modal("plot_7")
	while screen._modal_building() != "crew_quarters":
		screen._on_modal_next_pressed()
	screen._on_modal_confirm_pressed()
	screen._on_plot_tapped("plot_7")
	assert_true(screen.get_node("PlotSheet").visible, "a countdown, not a roster")
	assert_false(screen.get_node("CrewSheet").visible)

func test_built_plot_without_art_states_its_letter() -> void:
	GameState.data["island"]["plots"]["plot_7"] = {"building": "crew_quarters", "level": 1}
	screen._rebuild()
	assert_eq(String(screen._plot_state("plot_7", TimeUtil.now()).get("letter", "")), "C",
		"the lettered fallback carries the Crew Quarters until its art lands")

func test_legacy_batch_payload_still_offers_a_plain_collect() -> void:
	with_smeltery(1)
	TimerService.start("convert_smeltery", "convert", 10, 1000, {"building": "smeltery"})
	TimerService._state.data["timers"]["convert_smeltery"]["ends_at"] = 0
	screen._rebuild()
	screen._on_batch_collect_pressed("smeltery")
	assert_eq(Economy.balance("parts"), 1, "the legacy fallback credits through the screen")

func test_modal_stats_are_computed_from_the_defs() -> void:
	var defs: Dictionary = DataDefs.buildings["defs"]
	assert_eq(screen._stats_text("wind_still", defs["wind_still"]),
		"• +1 fuel cap per level\n• 120s faster fuel regen per level")
	assert_eq(screen._stats_text("workshop", defs["workshop"]), "• 1 craft slot per level")
	assert_eq(screen._stats_text("lens_array", defs["lens_array"]), "• +5% expedition payout per level")
	assert_eq(screen._stats_text("observatory", defs["observatory"]),
		"• Lv 1: Brasswork Reach fuel 2 -> 1\n• Lv 2: Rimefall Shallows fuel 3 -> 2",
		"the observatory's discounts come straight from the region rows")
	assert_eq(screen._stats_text("dock", defs["dock"]), "",
		"the dock's unlocks live in the region rows, its modal stays flavor")
	assert_eq(screen._stats_text("gardens", defs["gardens"]),
		"• 20 scrap per hour per level, banks up to 8h\n• Makes: Put up provisions (free -> 2 provisions, 60m)\n• Batch outputs scale with building level")
	assert_eq(screen._stats_text("smeltery", defs["smeltery"]),
		"• Makes: Smelt (40 scrap -> 1 parts, 10m)\n• Batch outputs scale with building level")

func test_balloonworks_stats_list_all_three_recipes() -> void:
	var text: String = screen._stats_text("balloonworks", (DataDefs.buildings["defs"] as Dictionary)["balloonworks"])
	assert_string_contains(text, "+1 pod drop per run per level")
	assert_string_contains(text, "Charged Ballast (1 cloudsilk, 1 parts -> 1 ballast, 15m)")
	assert_string_contains(text, "Wind Charm (2 cloudsilk, 1 parts -> 1 wind_charm, 20m)")
	assert_string_contains(text, "Storm Oil (1 cloudsilk, 2 parts -> 1 storm_oil, 15m)")

func test_modal_renders_the_stats_line() -> void:
	screen._open_build_modal("plot_0")
	assert_eq(String(screen.get_node("BuildModal/VBox/ModalStats").text), "• 1 craft slot per level",
		"the first candidate is the workshop")
	assert_true(screen.get_node("BuildModal/VBox/ModalStats").visible)
	screen._on_modal_next_pressed()
	assert_string_contains(String(screen.get_node("BuildModal/VBox/ModalStats").text), "fuel cap")

func test_stats_hide_when_a_building_has_none() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "dock", "level": 1}
	screen._rebuild()
	screen._open_build_modal("plot_0")
	assert_false(screen.get_node("BuildModal/VBox/ModalStats").visible)

func test_flavor_reads_as_a_different_voice() -> void:
	assert_almost_eq(screen.get_node("BuildModal/VBox/ModalFlavor").modulate.a, 0.7, 0.01,
		"flavor dims so function stands out")


func test_empty_plot_tap_opens_the_build_browser() -> void:
	screen._on_plot_tapped("plot_0")
	assert_true(screen.get_node("BuildModal").visible)
	assert_eq(screen._modal_building(), "workshop")


func test_done_construction_tap_collects_directly() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 0}
	TimerService.start("build_plot_0", "construction", 10, 1000, {"plot": "plot_0", "building": "workshop", "to_level": 1})
	TimerService._state.data["timers"]["build_plot_0"]["ends_at"] = 0
	screen._rebuild()
	screen._on_plot_tapped("plot_0")
	assert_eq(IslandModel.building_level(GameState.data["island"], "workshop"), 1)
	assert_false(screen.get_node("PlotSheet").visible, "a done build collects on the tap itself")


func test_built_plot_tap_opens_the_sheet() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	screen._rebuild()
	screen._on_plot_tapped("plot_0")
	assert_true(screen.get_node("PlotSheet").visible)
	assert_string_contains(String(screen.get_node("PlotSheet/VBox/SheetTitle").text), "Workshop Lv 1")


func test_constructing_plot_tap_opens_the_sheet_with_countdown() -> void:
	screen._open_build_modal("plot_0")
	screen._on_modal_confirm_pressed()
	screen._on_plot_tapped("plot_0")
	assert_true(screen.get_node("PlotSheet").visible)
	assert_string_contains(String(screen.get_node("PlotSheet/VBox/SheetTitle").text), "Building Workshop")


func test_done_batch_tap_collects_directly() -> void:
	with_smeltery(1)
	screen._on_batch_start_pressed("smeltery", "smelt")
	TimerService._state.data["timers"]["convert_smeltery"]["ends_at"] = 0
	screen._rebuild()
	screen._on_plot_tapped("plot_1")
	assert_eq(Economy.balance("parts"), 1)
	assert_false(screen.get_node("PlotSheet").visible)


func test_construction_done_outranks_batch_done_on_one_tap() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	screen._rebuild()
	screen._on_batch_start_pressed("gardens", "put_up_provisions")
	TimerService.start("build_plot_2", "construction", 10, 1000, {"plot": "plot_2", "building": "gardens", "to_level": 2})
	TimerService._state.data["timers"]["build_plot_2"]["ends_at"] = 0
	TimerService._state.data["timers"]["convert_gardens"]["ends_at"] = 0
	screen._on_plot_tapped("plot_2")
	assert_eq(int((GameState.data["island"]["plots"]["plot_2"] as Dictionary)["level"]), 2,
		"the construction collects first")
	assert_true(TimerService.active_timers().has("convert_gardens"), "the batch stays for the next tap")


func test_plot_pads_sit_at_their_authored_positions() -> void:
	var node: Control = screen._plot_nodes["plot_0"]
	var pos: Array = (DataDefs.island_layout["plots"] as Dictionary)["plot_0"]
	assert_eq(node.position + node.custom_minimum_size / 2.0, Vector2(float(pos[0]), float(pos[1])))


func test_constructing_plot_shows_the_scaffold_overlay() -> void:
	screen._open_build_modal("plot_0")
	screen._on_modal_confirm_pressed()
	var node: IslandPlotNode = screen._plot_nodes["plot_0"]
	assert_true(node._overlay.visible, "construction_overlay.png wired (audit 4.2)")


func test_unknown_plot_position_falls_back_to_origin_without_crashing() -> void:
	assert_eq(screen._layout_pos([]), Vector2.ZERO)
	assert_eq(screen._layout_pos(null), Vector2.ZERO)


func test_islet_tap_opens_a_restore_confirm_without_spending() -> void:
	GameState.data["currencies"]["cloudsilk"] = 10
	screen._on_islet_tapped("lantern_shoal")
	assert_false(TimerService.active_timers().has("restore_lantern_shoal"),
		"a map tap must never spend by itself (owner report, 2026-10-15)")
	assert_true(screen.get_node("PlotSheet").visible)
	assert_string_contains(String(screen.get_node("PlotSheet/VBox/SheetTitle").text), "Lantern Shoal")
	var restore: Button = screen.get_node("PlotSheet/VBox/SheetActions").get_child(0)
	assert_string_contains(restore.text, "Restore (")
	restore.pressed.emit()
	assert_true(TimerService.active_timers().has("restore_lantern_shoal"))
	assert_false(screen.get_node("PlotSheet").visible)


func test_unaffordable_restore_explains_in_the_sheet() -> void:
	GameState.data["currencies"]["scrap"] = 0
	screen._on_islet_tapped("lantern_shoal")
	var restore: Button = screen.get_node("PlotSheet/VBox/SheetActions").get_child(0)
	restore.pressed.emit()
	assert_false(TimerService.active_timers().has("restore_lantern_shoal"))
	assert_true(screen.get_node("PlotSheet").visible, "the sheet stays open to explain")
	assert_string_contains(String(screen.get_node("PlotSheet/VBox/SheetInfo").text), "Not enough")


func test_islet_tap_is_a_noop_while_locked() -> void:
	screen._on_islet_tapped("foundry_rock")
	assert_false(TimerService.active_timers().has("restore_foundry_rock"))
	assert_false(screen.get_node("PlotSheet").visible, "a locked islet tap does not even complain")


func test_islet_tap_collects_a_done_restoration_and_opens_the_letter() -> void:
	GameState.data["currencies"]["cloudsilk"] = 10
	screen._on_restore_pressed("lantern_shoal")
	TimerService._state.data["timers"]["restore_lantern_shoal"]["ends_at"] = 0
	screen._refresh_tick()
	screen._on_islet_tapped("lantern_shoal")
	assert_true(IsletModel.is_restored(GameState.data, "lantern_shoal"))
	assert_true(screen.get_node("LetterPanel").visible)


func test_islet_tap_rereads_the_letter_when_restored() -> void:
	restore_lantern()
	screen._on_islet_tapped("lantern_shoal")
	assert_true(screen.get_node("LetterPanel").visible)


func test_locked_islet_dims_on_the_map() -> void:
	var node: Control = screen._islet_nodes["foundry_rock"]
	assert_almost_eq(node.modulate.a, 0.4, 0.01, "Plan 8 polish: locked islets finally dim")


func test_modal_block_shades_the_map_behind_overlays() -> void:
	assert_false(screen.get_node("ModalBlock").visible)
	screen._open_build_modal("plot_0")
	assert_true(screen.get_node("ModalBlock").visible, "map taps cannot leak through the modal")
	screen._on_modal_cancel_pressed()
	assert_false(screen.get_node("ModalBlock").visible)


func test_sheet_close_hides_sheet_and_block() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	screen._rebuild()
	screen._on_plot_tapped("plot_0")
	screen._on_sheet_close_pressed()
	assert_false(screen.get_node("PlotSheet").visible)
	assert_false(screen.get_node("ModalBlock").visible)


func test_sheet_upgrade_opens_the_locked_modal() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	GameState.data["currencies"]["cloudsilk"] = 20
	screen._rebuild()
	screen._on_plot_tapped("plot_0")
	var upgrade: Button = screen.get_node("PlotSheet/VBox/SheetActions").get_child(1)
	assert_eq(upgrade.text, "Upgrade...")
	upgrade.pressed.emit()
	assert_false(screen.get_node("PlotSheet").visible, "the sheet yields to the modal")
	assert_true(screen.get_node("BuildModal").visible)
	assert_eq((screen._modal_ids as Array).size(), 1, "locked on the plot's own building")
	assert_string_contains(String(screen.get_node("BuildModal/VBox/ActionRow/ConfirmButton").text), "Upgrade to Lv 2")


func test_sheet_max_level_disables_upgrade() -> void:
	GameState.data["island"]["plots"]["plot_3"] = {"building": "observatory", "level": 2}
	screen._rebuild()
	screen._on_plot_tapped("plot_3")
	var upgrade: Button = screen.get_node("PlotSheet/VBox/SheetActions").get_child(0)
	assert_true(upgrade.disabled)
	assert_eq(upgrade.text, "Max level")


func test_sheet_lists_batch_buttons_and_starts_one() -> void:
	with_smeltery(1)
	screen._on_plot_tapped("plot_1")
	var actions: VBoxContainer = screen.get_node("PlotSheet/VBox/SheetActions")
	assert_eq(actions.get_child_count(), 2, "Upgrade plus the smelt recipe")
	var smelt: Button = actions.get_child(1)
	assert_string_contains(smelt.text, "Smelt (")
	smelt.pressed.emit()
	assert_true(TimerService.active_timers().has("convert_smeltery"))
	assert_eq(Economy.balance("scrap"), 2000 - 40)


func test_sheet_rerenders_to_collect_when_the_batch_finishes() -> void:
	with_smeltery(1)
	screen._on_batch_start_pressed("smeltery", "smelt")
	screen._on_plot_tapped("plot_1")
	assert_true(screen.get_node("PlotSheet").visible)
	TimerService._state.data["timers"]["convert_smeltery"]["ends_at"] = 0
	screen._refresh_tick()
	var actions: VBoxContainer = screen.get_node("PlotSheet/VBox/SheetActions")
	var collect: Button = actions.get_child(actions.get_child_count() - 1)
	assert_string_contains(collect.text, "Collect")
	collect.pressed.emit()
	assert_eq(Economy.balance("parts"), 1)


func test_sheet_skip_ad_completes_the_construction() -> void:
	screen._open_build_modal("plot_0")
	screen._on_modal_confirm_pressed()
	screen._on_plot_tapped("plot_0")
	var skip: Button = screen.get_node("PlotSheet/VBox/SheetActions").get_child(0)
	assert_eq(skip.text, "Skip (ad)")
	skip.pressed.emit()
	assert_true(TimerService.is_done("build_plot_0", TimeUtil.now()),
		"spec 6 placement 1: an ad skips the timer; the player still collects")


func test_affordable_upgrade_flags_the_pad() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	GameState.data["currencies"]["cloudsilk"] = 20
	screen._rebuild()
	assert_true(bool(screen._plot_state("plot_0", TimeUtil.now()).get("upgrade", false)),
		"scrap 2000 + cloudsilk 20 affords Lv 2 (owner request, 2026-10-15)")
	GameState.data["currencies"]["scrap"] = 0
	assert_false(bool(screen._plot_state("plot_0", TimeUtil.now()).get("upgrade", false)),
		"broke means no badge")


func test_maxed_building_never_flags_an_upgrade() -> void:
	GameState.data["island"]["plots"]["plot_3"] = {"building": "observatory", "level": 1}
	screen._rebuild()
	assert_false(bool(screen._plot_state("plot_3", TimeUtil.now()).get("upgrade", false)))


func test_sheet_shows_the_building_picture() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	screen._rebuild()
	screen._on_plot_tapped("plot_0")
	assert_not_null(screen.get_node("PlotSheet/VBox/SheetPicture").texture,
		"the sheet leads with the building illustration")


func test_sheet_buttons_carry_the_pill_style() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	screen._rebuild()
	screen._on_plot_tapped("plot_0")
	var upgrade: Button = screen.get_node("PlotSheet/VBox/SheetActions").get_child(0)
	assert_true(upgrade.has_theme_stylebox_override("normal"), "ui/button.png wired on sheet buttons")
	assert_true(screen.get_node("PlotSheet/VBox/SheetClose").has_theme_stylebox_override("normal"))


func test_map_mist_softens_the_fold_without_eating_taps() -> void:
	var mist: TextureRect = screen.get_node("MapMist")
	assert_not_null(mist.texture, "the cloud fade marks that the map continues below")
	assert_eq(mist.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the mist never blocks map taps or scrolling")


func test_map_buttons_pass_drags_to_the_scroll() -> void:
	assert_eq((screen._plot_nodes["plot_0"] as Control).mouse_filter, Control.MOUSE_FILTER_PASS,
		"pads PASS so a pan can start on them")
	assert_eq((screen._islet_nodes["lantern_shoal"] as Control).mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(screen.get_node("MapScroll/Map").mouse_filter, Control.MOUSE_FILTER_PASS,
		"the map itself must not swallow the drag before the ScrollContainer")


func test_modal_and_letter_buttons_carry_the_pill_style() -> void:
	assert_true(screen.get_node("BuildModal/VBox/ActionRow/ConfirmButton").has_theme_stylebox_override("normal"))
	assert_true(screen.get_node("BuildModal/VBox/NavRow/PrevButton").has_theme_stylebox_override("normal"))
	assert_true(screen.get_node("LetterPanel/VBox/LetterClose").has_theme_stylebox_override("normal"))


func test_long_letters_scroll_inside_the_parchment() -> void:
	restore_lantern()
	screen._on_read_letter_pressed("lantern_shoal")
	var scroll: ScrollContainer = screen.get_node("LetterPanel/VBox/LetterScroll")
	assert_true(scroll.custom_minimum_size.y > 0, "Plan 8 parked polish: long letters scroll at last")


func test_sheet_panel_nine_slices_only_the_painted_art() -> void:
	# panel.png carries transparent jig padding (wider on the right), so a
	# stylebox without a used-rect region draws the frame off-center and lets
	# the top content overlap the painted border.
	for node_path in ["BuildModal", "PlotSheet"]:
		var style: StyleBoxTexture = screen.get_node(node_path).get_theme_stylebox("panel")
		var used := Rect2(style.texture.get_image().get_used_rect())
		assert_eq(style.region_rect, used, "%s panel 9-slice starts from the painted art" % node_path)
		assert_eq(style.texture_margin_left, style.texture_margin_right,
			"%s frame slices stay symmetric so content centers in the frame" % node_path)


func test_back_arrow_and_resource_readout_sit_in_the_top_bar() -> void:
	assert_not_null(screen.get_node("BackButton").texture_normal,
		"back wears the main menu's left-arrow art")
	assert_not_null(screen.get_node("ResourceBar/ScrapIcon").texture, "scrap icon art")
	assert_not_null(screen.get_node("ResourceBar/CloudsilkIcon").texture, "cloudsilk icon art")
	assert_eq(String(screen.get_node("ResourceBar/ScrapLabel").text), "2000")
	assert_eq(String(screen.get_node("ResourceBar/CloudsilkLabel").text), "0")
	Economy.add("scrap", 5)
	assert_eq(String(screen.get_node("ResourceBar/ScrapLabel").text), "2005",
		"the readout follows balance changes live")

func test_back_button_wears_the_painted_art() -> void:
	var tex: Texture2D = screen.get_node("BackButton").texture_normal
	assert_not_null(tex, "back button carries arrow art, not the grey Button chrome")
	assert_eq(tex.resource_path, "res://game/art/ui/arrow_left.png",
		"back reuses the main menu's region arrow")
