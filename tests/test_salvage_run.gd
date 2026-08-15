extends GutTest

const RunScene := preload("res://game/run/salvage_run.tscn")
const TEST_SAVE := "user://test_run_scene.json"

var scene


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy)
	GameState.data["created_at"] = 1000
	GameState.data["fuel"]["updated_at"] = 1000
	scene = add_child_autofree(RunScene.instantiate())

func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_run_scene.json", "test_run_scene.json.tmp", "test_run_scene.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now())


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
	await wait_frames(2)
	assert_eq(get_tree().get_nodes_in_group("pods").size(), 0, "live pods freed on abandon")

func test_pod_timeout_pays_sea_minimum() -> void:
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	var scrap_before := Economy.balance("scrap")
	scene._on_pod_timeout(pod)
	assert_eq(Economy.balance("scrap"), scrap_before + 1, "stuck pod resolves as a sea miss")
	scene._on_pod_timeout(pod)
	assert_eq(Economy.balance("scrap"), scrap_before + 1, "timeout after resolution is a no-op")
