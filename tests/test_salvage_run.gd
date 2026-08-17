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

func test_ready_installs_loadout_gizmos() -> void:
	GameState.data["gizmos"]["owned"]["test_gizmo"] = 1
	DataDefs.gizmos["defs"]["test_gizmo"] = {"name": "Test Gizmo", "scene": "res://tests/fixtures/test_gizmo.tscn"}
	GizmoLoadout.set_slot(GameState.data["gizmos"], "region_1", "slot_0", "test_gizmo")
	var second = add_child_autofree(RunScene.instantiate())
	assert_eq(second.get_node("Skyfield/Gizmos").get_child_count(), 1,
		"the run scene installs the persisted loadout at boot")
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
