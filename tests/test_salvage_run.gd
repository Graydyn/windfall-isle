extends GutTest

const RunScene := preload("res://game/run/salvage_run.tscn")
const TEST_SAVE := "user://test_run_scene.json"

var scene


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	GameState.data["created_at"] = 1000
	GameState.data["fuel"]["updated_at"] = 1000
	scene = add_child_autofree(RunScene.instantiate())
	scene._on_start_pressed()

func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_run_scene.json", "test_run_scene.json.tmp", "test_run_scene.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos)


func test_drop_spawns_pod_and_consumes_drop() -> void:
	var drops_before: int = scene.model.drops_remaining()
	scene._on_drop_requested(360.0)
	assert_eq(scene.model.drops_remaining(), drops_before - 1)
	assert_eq(get_tree().get_nodes_in_group("pods").size(), 1)

func test_catch_credits_economy_immediately() -> void:
	var scrap_before := Economy.balance("scrap")
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(pod, {"scrap": 12})
	assert_eq(Economy.balance("scrap"), scrap_before + 12,
		"loot banks the moment it is caught (spec: no run ever loses loot)")
	assert_eq(scene.model.loot, {"scrap": 12})

func test_run_over_shows_results_and_saves() -> void:
	scene.model = RunModel.new({"drops_per_run": 1, "max_active_pods": 4})
	scene.model.run_over.connect(scene._on_run_over)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(pod, {"scrap": 3})
	assert_true(scene.get_node("UI/Results").visible)
	assert_false(scene.get_node("DropController").enabled)
	var saved := SaveIO.new(TEST_SAVE).read()
	assert_eq(int(saved["currencies"]["scrap"]), Economy.balance("scrap"),
		"run end must persist the banked loot")

func test_abandon_shows_results_and_frees_pods() -> void:
	scene._on_drop_requested(360.0)
	scene._on_abandon_pressed()
	assert_true(scene.model.is_over())
	assert_true(scene.get_node("UI/Results").visible)
	await wait_physics_frames(2)
	assert_eq(get_tree().get_nodes_in_group("pods").size(), 0, "live pods freed on abandon")

func test_pod_timeout_pays_sea_minimum() -> void:
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	var scrap_before := Economy.balance("scrap")
	scene._on_pod_timeout(weakref(pod), add_child_autofree(Timer.new()))
	assert_eq(Economy.balance("scrap"), scrap_before + 1, "stuck pod resolves as a sea miss")
	scene._on_pod_timeout(weakref(pod), add_child_autofree(Timer.new()))
	assert_eq(Economy.balance("scrap"), scrap_before + 1, "timeout after resolution is a no-op")

func test_watchdog_is_harmless_after_pod_is_freed() -> void:
	# Regression: the watchdog used to bind the raw pod into a typed Node
	# parameter; a pod freed before the 12s timer fired failed argument
	# marshalling with "Cannot convert argument 1 from Object to Object".
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	var scrap_before := Economy.balance("scrap")
	pod.free()
	scene._on_pod_timeout(weakref(pod), add_child_autofree(Timer.new()))
	assert_eq(Economy.balance("scrap"), scrap_before, "freed pod must credit nothing, silently")

func test_watchdog_timer_dies_with_the_scene() -> void:
	# A SceneTreeTimer would outlive the scene and error at a freed target;
	# the watchdog must be a child Timer node instead.
	var timers_before: int = scene.get_children().filter(func(c: Node) -> bool: return c is Timer).size()
	scene._on_drop_requested(360.0)
	var timers_after: int = scene.get_children().filter(func(c: Node) -> bool: return c is Timer).size()
	assert_eq(timers_after, timers_before + 1, "each drop parents its watchdog Timer to the scene")

func test_run_over_marks_swept_pods_caught() -> void:
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_abandon_pressed()
	assert_true(pod.has_meta("caught"),
		"swept pods must be marked so no catcher or watchdog can resolve them later")

func test_start_installs_loadout_gizmos() -> void:
	GameState.data["gizmos"]["owned"]["test_gizmo"] = 1
	DataDefs.gizmos["defs"]["test_gizmo"] = {"name": "Test Gizmo", "scene": "res://tests/fixtures/test_gizmo.tscn"}
	GizmoLoadout.set_slot(GameState.data["gizmos"], "region_1", "slot_0", "test_gizmo")
	var second = add_child_autofree(RunScene.instantiate())
	assert_eq(second.get_node("Skyfield/Gizmos").get_child_count(), 0,
		"nothing installs at boot; placement is still editable")
	second._on_start_pressed()
	assert_eq(second.get_node("Skyfield/Gizmos").get_child_count(), 1,
		"the run scene installs the persisted loadout at Start")
	DataDefs.gizmos["defs"].erase("test_gizmo")

func test_compute_payout_applies_pod_value_mult() -> void:
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	pod.set_meta("value_mult", 1.5)
	assert_eq(scene._compute_payout(pod, {"scrap": 2, "cloudsilk": 1}), {"scrap": 3, "cloudsilk": 2})

func test_catch_credits_multiplied_payout() -> void:
	var scrap_before := Economy.balance("scrap")
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	pod.set_meta("value_mult", 2.0)
	scene._on_pod_caught(pod, {"scrap": 5})
	assert_eq(Economy.balance("scrap"), scrap_before + 10)
	assert_eq(scene.model.loot, {"scrap": 10}, "the model banks the multiplied value too")

func test_add_bonus_credits_and_banks() -> void:
	var scrap_before := Economy.balance("scrap")
	scene.add_bonus({"scrap": 6})
	assert_eq(Economy.balance("scrap"), scrap_before + 6)
	assert_eq(scene.model.loot, {"scrap": 6})

func test_next_barge_multiplier_applies_to_barge_only_and_once() -> void:
	# The await after each catch lets the freed pod leave the "pods" group
	# before the next drop's group lookup (queue_free defers to frame end).
	var scrap_before := Economy.balance("scrap")
	scene.set_next_barge_multiplier(2.0)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(pod, {"scrap": 5}, "sea")
	await wait_physics_frames(1)
	assert_eq(Economy.balance("scrap"), scrap_before + 5, "sea catches never consume the chime")
	scene._on_drop_requested(360.0)
	var second: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(second, {"scrap": 5}, "barge")
	await wait_physics_frames(1)
	assert_eq(Economy.balance("scrap"), scrap_before + 5 + 10, "the barge catch doubles once")
	scene._on_drop_requested(360.0)
	var third: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(third, {"scrap": 5}, "barge")
	assert_eq(Economy.balance("scrap"), scrap_before + 5 + 10 + 5, "the multiplier is consumed")

func test_chime_does_not_stack() -> void:
	scene.set_next_barge_multiplier(2.0)
	scene.set_next_barge_multiplier(2.0)
	assert_almost_eq(scene._next_barge_multiplier, 2.0, 0.001)

func test_request_split_spawns_mirrored_clone() -> void:
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	pod.linear_velocity = Vector2(120, 200)
	pod.set_meta("value_mult", 0.5)
	assert_true(scene.request_split(pod))
	await wait_physics_frames(1)
	var pods: Array = get_tree().get_nodes_in_group("pods")
	assert_eq(pods.size(), 2)
	assert_eq(scene.model.pods_in_flight, 2)
	assert_eq(scene.model.drops_remaining(), int(DataDefs.run["drops_per_run"]) - 1,
		"the split consumed no extra drop")
	var clone: Node = pods[1] if pods[0] == pod else pods[0]
	assert_almost_eq(float(clone.get_meta("value_mult")), 0.5, 0.001)
	assert_true(clone.has_meta("split"))
	assert_almost_eq(clone.linear_velocity.x, -120.0, 2.0)

func test_run_drops_include_balloonworks_bonus() -> void:
	GameState.data["island"]["plots"]["plot_1"] = {"building": "balloonworks", "level": 1}
	var second = add_child_autofree(RunScene.instantiate())
	assert_eq(second.model.drops_remaining(), int(DataDefs.run["drops_per_run"]) + 1)

func test_tier_multiplier_applies_to_later_catches_only() -> void:
	scene.model = RunModel.new({
		"drops_per_run": 8, "max_active_pods": 4,
		"quota_tiers": [{"scrap_quota": 10, "payout_multiplier": 2.0}],
	})
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(pod, {"scrap": 10})
	assert_eq(scene.model.loot, {"scrap": 10}, "the crossing catch pays at the old tier")
	await wait_physics_frames(1)
	scene._on_drop_requested(300.0)
	var pod2: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(pod2, {"scrap": 10})
	assert_eq(int(scene.model.loot["scrap"]), 30, "tier 1 doubles the second catch")

func test_scene_reads_quota_tiers_from_region_data() -> void:
	assert_false(scene.model.tiers.is_empty(),
		"region_1 quota tiers must reach the run model")

func test_double_payout_credits_loot_again_exactly_once() -> void:
	scene.model = RunModel.new({"drops_per_run": 1, "max_active_pods": 4})
	scene.model.run_over.connect(scene._on_run_over)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	var scrap_before := Economy.balance("scrap")
	scene._on_pod_caught(pod, {"scrap": 9})
	assert_eq(Economy.balance("scrap"), scrap_before + 9)
	assert_true(scene.get_node("UI/Results/VBox/DoubleButton").visible)
	scene._on_double_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 18, "double credits the run loot once more")
	scene._on_double_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 18, "double is once per run")
	assert_true(scene.get_node("UI/Results/VBox/DoubleButton").disabled)

func test_double_button_hidden_when_nothing_was_salvaged() -> void:
	scene.model = RunModel.new({"drops_per_run": 1, "max_active_pods": 4})
	scene.model.run_over.connect(scene._on_run_over)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	pod.set_meta("value_mult", 0.0)
	scene._on_pod_caught(pod, {"scrap": 1})
	assert_true(scene.get_node("UI/Results").visible)
	assert_false(scene.get_node("UI/Results/VBox/DoubleButton").visible,
		"nothing to double")

func test_scene_builds_the_selected_region() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "dock", "level": 1}
	GameState.data["expedition"]["region"] = "region_2"
	var second = add_child_autofree(RunScene.instantiate())
	await wait_physics_frames(1)
	assert_eq(second.get_node("Skyfield/DriftZones").get_child_count(), 2)
	assert_eq(int((second.model.tiers[0] as Dictionary)["scrap_quota"]), 35,
		"the run model carries region 2's quota tiers")

func test_locked_selection_falls_back_to_region_1() -> void:
	GameState.data["expedition"]["region"] = "region_2"
	var second = add_child_autofree(RunScene.instantiate())
	await wait_physics_frames(1)
	assert_eq(second.get_node("Skyfield/DriftZones").get_child_count(), 0,
		"no Dock, no Brasswork Reach; the scene falls back, never crashes")

func test_tier_reached_shows_an_offer_and_pauses_drops() -> void:
	scene._rng.seed = 42
	scene._on_tier_reached(1)
	assert_true(scene.get_node("UI/BoonOffer").visible)
	assert_false(scene.get_node("DropController").enabled, "new drops gate while the offer is up")
	assert_eq((scene._current_offer as Array).size(), 3)

func test_picking_a_boon_applies_and_resumes() -> void:
	scene._rng.seed = 42
	scene._on_tier_reached(1)
	var picked := String(scene._current_offer[0])
	scene._on_boon_picked(0)
	assert_true(scene.model.has_boon(picked))
	assert_false(scene.get_node("UI/BoonOffer").visible)
	assert_true(scene.get_node("DropController").enabled)

func test_skip_forfeits_without_applying() -> void:
	scene._rng.seed = 42
	scene._on_tier_reached(1)
	scene._on_boon_skipped()
	assert_eq((scene.model.boons as Array).size(), 0, "spec: skip forfeits, no banking")
	assert_false(scene.get_node("UI/BoonOffer").visible)
	assert_true(scene.get_node("DropController").enabled)

func test_reroll_redraws_disjoint_and_is_once_per_offer() -> void:
	scene._rng.seed = 42
	scene._on_tier_reached(1)
	var before: Array = (scene._current_offer as Array).duplicate()
	scene._on_reroll_pressed()
	var after: Array = scene._current_offer
	for id in after:
		assert_false(before.has(id), "the reroll never returns the same trio")
	assert_false(scene.get_node("UI/BoonOffer/VBox/RerollButton").visible, "one reroll per offer")
	scene._on_reroll_pressed()
	assert_eq(scene._current_offer, after, "a second reroll is a no-op")

func test_crossing_two_tiers_queues_two_offers() -> void:
	scene._rng.seed = 42
	scene._on_tier_reached(1)
	scene._on_tier_reached(2)
	scene._on_boon_picked(0)
	assert_true(scene.get_node("UI/BoonOffer").visible, "the queued second offer serves immediately")
	assert_false(scene.get_node("DropController").enabled)
	scene._on_boon_skipped()
	assert_true(scene.get_node("DropController").enabled)
	assert_eq((scene.model.boons as Array).size(), 1)

func test_run_over_closes_an_open_offer_unpicked() -> void:
	scene.model = RunModel.new({"drops_per_run": 1, "max_active_pods": 4})
	scene.model.run_over.connect(scene._on_run_over)
	scene._rng.seed = 42
	scene._on_tier_reached(1)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(pod, {"scrap": 3})
	assert_false(scene.get_node("UI/BoonOffer").visible, "run end closes the offer, nothing lost")
	assert_true(scene.get_node("UI/Results").visible)
	assert_eq((scene.model.boons as Array).size(), 0)

func test_featherfall_bumps_only_subsequent_pod_defs() -> void:
	var bounce_before := float(scene.pod_defs.get("bounce", 0.55))
	scene._current_offer = ["featherfall", "rich_seas", "heavy_loot"]
	scene._on_boon_picked(0)
	assert_almost_eq(float(scene.pod_defs["bounce"]), bounce_before + 0.2, 0.001)
	assert_almost_eq(float((DataDefs.run["pod"] as Dictionary)["bounce"]), bounce_before, 0.001,
		"the shared defs are never mutated; the scene copies before bumping")

func test_barge_bounty_boosts_barge_catches() -> void:
	scene._current_offer = ["barge_bounty", "rich_seas", "heavy_loot"]
	scene._on_boon_picked(0)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	var scrap_before := Economy.balance("scrap")
	scene._on_pod_caught(pod, {"scrap": 10}, "barge")
	assert_eq(Economy.balance("scrap"), scrap_before + 15, "10 x 1.5 barge bounty")

func test_barge_bounty_composes_with_the_chime_bell() -> void:
	scene._current_offer = ["barge_bounty", "rich_seas", "heavy_loot"]
	scene._on_boon_picked(0)
	scene.set_next_barge_multiplier(2.0)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	var scrap_before := Economy.balance("scrap")
	scene._on_pod_caught(pod, {"scrap": 10}, "barge")
	assert_eq(Economy.balance("scrap"), scrap_before + 30, "10 x 1.5 boon x 2.0 bell")

func test_rich_seas_boosts_sea_catches_only() -> void:
	scene._current_offer = ["rich_seas", "barge_bounty", "heavy_loot"]
	scene._on_boon_picked(0)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	var scrap_before := Economy.balance("scrap")
	scene._on_pod_caught(pod, {"scrap": 2}, "sea")
	assert_eq(Economy.balance("scrap"), scrap_before + 6, "2 x 3.0 rich seas")
	scene._on_drop_requested(300.0)
	var pod2: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(pod2, {"scrap": 10}, "barge")
	assert_eq(Economy.balance("scrap"), scrap_before + 6 + 10, "barge catches are untouched by rich seas")

func test_heavy_loot_adds_flat_scrap_after_multipliers() -> void:
	scene._current_offer = ["heavy_loot", "rich_seas", "barge_bounty"]
	scene._on_boon_picked(0)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	var scrap_before := Economy.balance("scrap")
	scene._on_pod_caught(pod, {"cloudsilk": 1}, "barge")
	assert_eq(Economy.balance("scrap"), scrap_before + 2, "the bonus lands even on non-scrap catches")
	assert_eq(int(scene.model.loot.get("cloudsilk", 0)), 1)

func test_heavy_loot_skips_empty_payouts() -> void:
	scene._current_offer = ["heavy_loot", "rich_seas", "barge_bounty"]
	scene._on_boon_picked(0)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	pod.set_meta("value_mult", 0.0)
	var scrap_before := Economy.balance("scrap")
	scene._on_pod_caught(pod, {"scrap": 1}, "barge")
	assert_eq(Economy.balance("scrap"), scrap_before, "a zero-value catch stays worth nothing")


func test_lens_array_multiplies_every_catch_payout() -> void:
	GameState.data["island"]["plots"]["islet_lantern_0"] = {"building": "lens_array", "level": 1}
	var boosted = add_child_autofree(RunScene.instantiate())
	assert_eq(boosted._compute_payout(null, {"scrap": 20}), {"scrap": 21},
		"20 scrap x 1.05 lens bonus rounds to 21")
	assert_eq(scene._compute_payout(null, {"scrap": 20}), {"scrap": 20},
		"the before_each scene was built without a lens array and stays neutral")


func test_queued_offer_exhaustion_reenables_the_controller() -> void:
	var pool: Array = (DataDefs.boons.get("defs", {}) as Dictionary).keys()
	# Leave exactly 3 boons untaken so the first offer succeeds.
	for i in range(3, pool.size()):
		scene.model.add_boon(String(pool[i]), DataDefs.boons)
	scene._on_tier_reached(1)
	assert_true(scene.get_node("UI/BoonOffer").visible)
	assert_false(scene.controller.enabled)
	scene._on_tier_reached(2)
	for i in range(3):
		scene.model.add_boon(String(pool[i]), DataDefs.boons)
	scene._on_boon_picked(0)
	assert_false(scene.get_node("UI/BoonOffer").visible,
		"the queued empty draw must not leave the panel showing stale content")
	assert_true(scene.controller.enabled,
		"a queued offer exhausting the pool must not leave the controller locked (Plan 7 tripwire)")


func test_reroll_hidden_when_pool_has_no_disjoint_candidate() -> void:
	var pool: Array = (DataDefs.boons.get("defs", {}) as Dictionary).keys()
	scene._current_offer = [pool[0], pool[1], pool[2]]
	for i in range(3, pool.size()):
		scene.model.add_boon(String(pool[i]), DataDefs.boons)
	scene._render_offer()
	assert_false(scene.get_node("UI/BoonOffer/VBox/RerollButton").visible,
		"a reroll that cannot redraw anything is hidden (Plan 7 tripwire)")


func test_reroll_press_with_no_candidates_consumes_nothing() -> void:
	var pool: Array = (DataDefs.boons.get("defs", {}) as Dictionary).keys()
	scene._current_offer = [pool[0], pool[1], pool[2]]
	for i in range(3, pool.size()):
		scene.model.add_boon(String(pool[i]), DataDefs.boons)
	scene._free_rerolls = 1
	scene._on_reroll_pressed()
	assert_eq(scene._free_rerolls, 1, "the wind charm survives a pointless reroll press")
	assert_false(scene._offer_rerolled)
