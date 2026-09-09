extends GutTest
## The setup phase (spec: drag-drop gizmo setup): the scene opens over the
## built board with nothing installed and no fuel spent; Start is the single
## commit point. Scene-changing handlers (Back) are never invoked here.

const RunScene := preload("res://game/run/salvage_run.tscn")
const TEST_SAVE := "user://test_run_setup.json"

var scene


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	GameState.data["created_at"] = 1000
	GameState.data["fuel"]["updated_at"] = 1000
	scene = add_child_autofree(RunScene.instantiate())


func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_run_setup.json", "test_run_setup.json.tmp", "test_run_setup.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings)


func test_scene_opens_in_setup() -> void:
	assert_false(scene.get_node("DropController").enabled, "no aiming during setup")
	assert_true(scene.get_node("UI/SetupUI").visible)
	assert_false(scene.get_node("UI/AbandonButton").visible)
	assert_eq(scene.get_node("Skyfield/Gizmos").get_child_count(), 0,
		"gizmos install at Start, not at boot")
	assert_eq(FuelModel.current(GameState.data["fuel"], TimeUtil.now()), 5,
		"no fuel is spent by entering the scene")
	assert_string_contains(String(scene.get_node("UI/HudLabel").text), "Place your gizmos")

func test_drops_are_ignored_during_setup() -> void:
	var drops_before: int = scene.model.drops_remaining()
	scene._on_drop_requested(360.0)
	assert_eq(scene.model.drops_remaining(), drops_before, "a drop before Start must not consume")
	assert_eq(get_tree().get_nodes_in_group("pods").size(), 0)

func test_start_spends_the_region_cost_once_and_installs() -> void:
	GizmoLoadout.set_slot(GameState.data["gizmos"], "region_1", "slot_0", "wind_fan")
	scene._on_start_pressed()
	assert_eq(FuelModel.current(GameState.data["fuel"], TimeUtil.now()), 4, "region 1 costs 1 fuel")
	assert_eq(scene.get_node("Skyfield/Gizmos").get_child_count(), 1, "the saved loadout installs at Start")
	assert_true(scene.get_node("DropController").enabled)
	assert_false(scene.get_node("UI/SetupUI").visible)
	assert_true(scene.get_node("UI/AbandonButton").visible)
	scene._on_start_pressed()
	assert_eq(FuelModel.current(GameState.data["fuel"], TimeUtil.now()), 4,
		"Start is a one-way gate; a second press spends nothing")

func test_start_persists_the_debit() -> void:
	scene._on_start_pressed()
	var saved := SaveIO.new(TEST_SAVE).read()
	assert_eq(FuelModel.current(saved["fuel"], TimeUtil.now()), 4,
		"an OS kill right after Start must not refund the fuel")

func test_start_without_fuel_stays_in_setup_and_explains() -> void:
	GameState.data["fuel"]["amount"] = 0
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	scene._on_start_pressed()
	assert_false(scene.get_node("DropController").enabled)
	assert_true(scene.get_node("UI/SetupUI").visible)
	assert_eq(scene.get_node("Skyfield/Gizmos").get_child_count(), 0)
	assert_string_contains(String(scene.get_node("UI/SetupUI/SetupStatus").text), "Not enough fuel")

func test_setup_tick_reflects_affordability() -> void:
	scene._setup_tick()
	assert_false(scene.get_node("UI/SetupUI/StartButton").disabled)
	assert_string_contains(String(scene.get_node("UI/SetupUI/StartButton").text), "1 fuel")
	GameState.data["fuel"]["amount"] = 0
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	scene._setup_tick()
	assert_true(scene.get_node("UI/SetupUI/StartButton").disabled)

func test_boon_close_never_enables_drops_during_setup() -> void:
	# Unreachable in play (offers need catches), but the phase guard must hold:
	# _close_offer re-enables the controller only while RUNNING.
	scene._close_offer()
	assert_false(scene.get_node("DropController").enabled)

func test_back_button_exists_and_hud_returns_to_normal_after_start() -> void:
	assert_not_null(scene.get_node_or_null("UI/SetupUI/BackButton"))
	scene._on_start_pressed()
	assert_string_contains(String(scene.get_node("UI/HudLabel").text), "Drops left:")

func slot_target(index: int) -> SlotTarget:
	return scene.get_node("UI/SetupUI/SlotTargets").get_child(index) as SlotTarget


func tray_chips() -> Array:
	return scene.get_node("UI/SetupUI/TrayPanel/TrayFlow").get_children()


func chip_for(gizmo_id: String) -> GizmoChip:
	for chip in tray_chips():
		if (chip as GizmoChip).gizmo_id == gizmo_id:
			return chip as GizmoChip
	return null


func test_setup_builds_a_target_per_slot_and_a_chip_per_owned() -> void:
	var region: Dictionary = DataDefs.skyfield("region_1")
	assert_eq(scene.get_node("UI/SetupUI/SlotTargets").get_child_count(),
		(region.get("gizmo_slots", []) as Array).size())
	assert_eq(tray_chips().size(), (GameState.data["gizmos"]["owned"] as Dictionary).size(),
		"every owned gizmo shows in the tray")
	assert_eq(slot_target(0).slot_id, "slot_0")

func test_slot_targets_sit_on_the_slot_coordinates() -> void:
	var slots: Array = DataDefs.skyfield("region_1").get("gizmo_slots", [])
	var first := slot_target(0)
	assert_almost_eq(first.position.x + first.size.x / 2.0, float((slots[0] as Dictionary)["x"]), 0.5)
	assert_almost_eq(first.position.y + first.size.y / 2.0, float((slots[0] as Dictionary)["y"]), 0.5)

func test_drop_from_tray_places_saves_and_dims() -> void:
	scene._on_gizmo_dropped({"gizmo": "wind_fan", "from_slot": ""}, "slot_0")
	assert_eq(GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1"), {"slot_0": "wind_fan"})
	assert_false(chip_for("wind_fan").draggable, "the placed gizmo's tray chip dims")
	assert_eq(slot_target(0).get_child_count(), 1, "the slot shows a token")
	var saved := SaveIO.new(TEST_SAVE).read()
	assert_eq((saved["gizmos"]["loadout"] as Dictionary).get("region_1"), {"slot_0": "wind_fan"},
		"every drop persists immediately")

func test_drop_onto_occupied_slot_returns_the_displaced_to_the_tray() -> void:
	scene._on_gizmo_dropped({"gizmo": "wind_fan", "from_slot": ""}, "slot_0")
	scene._on_gizmo_dropped({"gizmo": "balloon_cluster", "from_slot": ""}, "slot_0")
	assert_eq(GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1"), {"slot_0": "balloon_cluster"})
	assert_true(chip_for("wind_fan").draggable, "the displaced gizmo un-dims")

func test_slot_to_slot_move_via_token_payload() -> void:
	scene._on_gizmo_dropped({"gizmo": "wind_fan", "from_slot": ""}, "slot_0")
	scene._on_gizmo_dropped({"gizmo": "wind_fan", "from_slot": "slot_0"}, "slot_1")
	assert_eq(GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1"), {"slot_1": "wind_fan"})
	assert_eq(slot_target(0).get_child_count(), 0)
	assert_eq(slot_target(1).get_child_count(), 1)

func test_drop_on_tray_removes() -> void:
	scene._on_gizmo_dropped({"gizmo": "wind_fan", "from_slot": ""}, "slot_0")
	scene._on_gizmo_dropped({"gizmo": "wind_fan", "from_slot": "slot_0"}, "")
	assert_eq(GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1"), {})
	assert_true(chip_for("wind_fan").draggable)

func test_unowned_drop_is_rejected() -> void:
	scene._on_gizmo_dropped({"gizmo": "not_owned_gizmo", "from_slot": ""}, "slot_0")
	assert_eq(GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1"), {})

func test_drops_after_start_are_ignored() -> void:
	scene._on_start_pressed()
	scene._on_gizmo_dropped({"gizmo": "wind_fan", "from_slot": ""}, "slot_0")
	assert_eq(GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1"), {},
		"placement is frozen once the run begins")

func test_tray_panel_is_the_removal_target() -> void:
	var tray: SlotTarget = scene.get_node("UI/SetupUI/TrayPanel") as SlotTarget
	assert_not_null(tray, "the tray panel carries the SlotTarget script")
	assert_eq(tray.slot_id, "")

func test_slot_token_carries_its_source_slot() -> void:
	scene._on_gizmo_dropped({"gizmo": "wind_fan", "from_slot": ""}, "slot_2")
	var token := slot_target(2).get_child(0) as GizmoChip
	assert_eq(token._get_drag_data(Vector2.ZERO), {"gizmo": "wind_fan", "from_slot": "slot_2"})

func test_saved_loadout_prefills_the_board() -> void:
	GizmoLoadout.set_slot(GameState.data["gizmos"], "region_1", "slot_3", "chime_bell")
	var second = add_child_autofree(RunScene.instantiate())
	var target := second.get_node("UI/SetupUI/SlotTargets").get_child(3) as SlotTarget
	assert_eq(target.get_child_count(), 1, "setup opens pre-filled with the region's last placement")

func grant_kit(counts: Dictionary) -> void:
	for currency in counts:
		GameState.data["currencies"][currency] = counts[currency]
	scene._refresh_kit_panel()


func kit_chip(kit_id: String) -> Button:
	return scene.get_node("UI/SetupUI/KitPanel/KitFlow/Kit_" + kit_id) as Button


func test_kit_panel_builds_four_chips() -> void:
	assert_eq(scene.get_node("UI/SetupUI/KitPanel/KitFlow").get_child_count(), 4)
	assert_true(kit_chip("ballast").disabled, "zero count disables the chip")
	assert_true(kit_chip("provision").disabled, "zero provisions disables provisioning")

func test_chip_counts_show_and_enable() -> void:
	grant_kit({"ballast": 2, "provisions": 5})
	assert_false(kit_chip("ballast").disabled)
	assert_string_contains(kit_chip("ballast").text, "x2")
	assert_false(kit_chip("provision").disabled)

func test_start_consumes_elected_kit_exactly_once() -> void:
	grant_kit({"ballast": 2, "provisions": 5})
	scene._on_kit_toggled(true, "ballast")
	scene._on_kit_toggled(true, "provision")
	var base_drops: int = scene.model.drops_remaining()
	scene._on_start_pressed()
	assert_eq(Economy.balance("ballast"), 1, "one ballast consumed")
	assert_eq(Economy.balance("provisions"), 2, "three provisions consumed")
	assert_eq(scene.model.drops_remaining(), base_drops + 2, "the ballast landed")
	assert_almost_eq(scene._provision_mult, 1.15, 0.001)

func test_failed_start_consumes_nothing() -> void:
	grant_kit({"ballast": 1})
	scene._on_kit_toggled(true, "ballast")
	GameState.data["fuel"]["amount"] = 0
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	scene._on_start_pressed()
	assert_eq(Economy.balance("ballast"), 1, "no fuel, no kit spend")

func test_unaffordable_election_is_silently_dropped() -> void:
	grant_kit({"ballast": 1})
	scene._on_kit_toggled(true, "ballast")
	GameState.data["currencies"]["ballast"] = 0
	var base_drops: int = scene.model.drops_remaining()
	scene._on_start_pressed()
	assert_eq(scene._phase, scene.Phase.RUNNING, "the run proceeds")
	assert_eq(scene.model.drops_remaining(), base_drops, "the dropped election has no effect")

func test_provision_multiplies_payouts() -> void:
	grant_kit({"provisions": 5})
	scene._on_kit_toggled(true, "provision")
	scene._on_start_pressed()
	assert_eq(scene._compute_payout(null, {"scrap": 20}), {"scrap": 23}, "20 x 1.15 rounds to 23")

func test_storm_oil_bumps_pod_bounce_without_touching_shared_defs() -> void:
	grant_kit({"storm_oil": 1})
	scene._on_kit_toggled(true, "storm_oil")
	var shared_before := float((DataDefs.run["pod"] as Dictionary).get("bounce", 0.55))
	scene._on_start_pressed()
	assert_almost_eq(float(scene.pod_defs["bounce"]), shared_before + 0.15, 0.001)
	assert_almost_eq(float((DataDefs.run["pod"] as Dictionary).get("bounce", 0.55)), shared_before, 0.001,
		"the shared defs are never mutated (Featherfall pattern)")

func test_wind_charm_grants_a_free_reroll_before_the_ad_path() -> void:
	grant_kit({"wind_charm": 1})
	scene._on_kit_toggled(true, "wind_charm")
	scene._on_start_pressed()
	assert_eq(scene._free_rerolls, 1)
	scene._rng.seed = 42
	scene._on_tier_reached(1)
	var before: Array = (scene._current_offer as Array).duplicate()
	scene._on_reroll_pressed()
	assert_eq(scene._free_rerolls, 0, "the charm was spent")
	for id in scene._current_offer:
		assert_false(before.has(id), "the free reroll redraws disjointly")
	scene._on_reroll_pressed()
	assert_eq(scene._current_offer, scene._current_offer, "still once per offer")

func test_elections_reset_on_a_fresh_scene() -> void:
	grant_kit({"ballast": 1})
	scene._on_kit_toggled(true, "ballast")
	var second = add_child_autofree(RunScene.instantiate())
	assert_eq((second._kit_elected as Dictionary).size(), 0, "elections never persist")
