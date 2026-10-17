extends GutTest
## Run-side rescue (crew spec section 6): a survivor drifts across the board,
## pod contact rescues and persists instantly, the banner announces, and the
## whole channel stays out of the payout pipeline.

const RunScene := preload("res://game/run/salvage_run.tscn")
const TEST_SAVE := "user://test_survivor_rescue.json"

var scene


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	GameState.data["created_at"] = 1000
	GameState.data["fuel"]["updated_at"] = 1000
	GameState.data["island"]["plots"]["plot_7"] = {"building": "crew_quarters", "level": 1}
	scene = add_child_autofree(RunScene.instantiate())


func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_survivor_rescue.json", "test_survivor_rescue.json.tmp", "test_survivor_rescue.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings, DataDefs.crew)


func force_spawn(id: String) -> Node:
	scene._survivor_id = id
	scene._survivor_from_left = true
	var timer := Timer.new()
	scene.add_child(timer)
	scene._spawn_survivor(timer)
	var survivors: Array = get_tree().get_nodes_in_group("survivors")
	return survivors[0] if survivors.size() > 0 else null


func test_no_spawn_scheduling_when_everyone_is_home() -> void:
	for row_v in CrewModel.members(DataDefs.crew):
		CrewModel.rescue(GameState.data, String((row_v as Dictionary).get("id", "")))
	scene._on_start_pressed()
	scene._rng.seed = 1
	scene._maybe_schedule_survivor()
	assert_eq(scene._survivor_id, "", "a complete cast schedules nothing")

func test_spawn_is_seed_deterministic() -> void:
	# Force the roll to always draw and clear any survivor the natural Start
	# roll may have picked, so the assertion sees only the seeded draw.
	var survivor_defs: Dictionary = DataDefs.crew["survivor"]
	var old_chance: float = float(survivor_defs["chance_per_run"])
	survivor_defs["chance_per_run"] = 1.0
	scene._on_start_pressed()
	scene._survivor_id = ""
	scene._rng.seed = 7
	scene._maybe_schedule_survivor()
	var first := String(scene._survivor_id)
	assert_ne(first, "", "chance 1.0 always draws")
	var again = add_child_autofree(RunScene.instantiate())
	again._on_start_pressed()
	again._survivor_id = ""
	again._rng.seed = 7
	again._maybe_schedule_survivor()
	assert_eq(String(again._survivor_id), first, "same seed, same draw")
	survivor_defs["chance_per_run"] = old_chance

func test_spawn_timer_is_a_noop_outside_running() -> void:
	scene._survivor_id = "odo"
	var timer := Timer.new()
	scene.add_child(timer)
	scene._spawn_survivor(timer)
	assert_eq(get_tree().get_nodes_in_group("survivors").size(), 0,
		"still in SETUP: the survivor never appears")

func test_pod_contact_rescues_persists_and_banners() -> void:
	scene._on_start_pressed()
	var survivor := force_spawn("odo")
	assert_not_null(survivor)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	survivor._on_body(pod)
	assert_true(CrewModel.is_rescued(GameState.data, "odo"))
	var saved := SaveIO.new(TEST_SAVE).read()
	assert_true(bool((saved["crew"]["rescued"] as Dictionary).get("odo", false)),
		"a rescue must survive an OS kill the same frame")
	assert_true(scene.get_node("UI/RescueBanner").visible)
	assert_string_contains(String(scene.get_node("UI/RescueBanner").text), "Odo")
	assert_string_contains(String(scene.get_node("UI/RescueBanner").text), "Soil remembers")
	await wait_physics_frames(2)
	assert_eq(get_tree().get_nodes_in_group("survivors").size(), 0, "the raft leaves with them")

func test_contact_rescues_only_once() -> void:
	scene._on_start_pressed()
	var survivor := force_spawn("odo")
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	survivor._on_body(pod)
	survivor._on_body(pod)
	assert_eq((CrewModel.rescued_ids(GameState.data, DataDefs.crew) as Array).size(), 1,
		"a double contact in one frame claims one rescue")

func test_non_pod_contact_is_ignored() -> void:
	scene._on_start_pressed()
	var survivor := force_spawn("odo")
	survivor._on_body(autofree(Area2D.new()))
	assert_false(CrewModel.is_rescued(GameState.data, "odo"))

func test_run_over_sweeps_the_survivor() -> void:
	scene.model = RunModel.new({"drops_per_run": 1, "max_active_pods": 4})
	scene.model.run_over.connect(scene._on_run_over)
	scene._on_start_pressed()
	force_spawn("odo")
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(pod, {"scrap": 3})
	await wait_physics_frames(2)
	assert_eq(get_tree().get_nodes_in_group("survivors").size(), 0, "run over clears the board")
	assert_false(CrewModel.is_rescued(GameState.data, "odo"), "no rescue happened")

func test_survivor_drifts_and_frees_itself_offscreen() -> void:
	scene._on_start_pressed()
	var survivor := force_spawn("odo")
	survivor.position.x = 1000.0
	await wait_physics_frames(2)
	assert_eq(get_tree().get_nodes_in_group("survivors").size(), 0,
		"past the far edge the raft cleans itself up")

func test_no_spawn_scheduling_without_crew_quarters() -> void:
	# Crew gate (owner request, 2026-10-17): castaways only sign on once
	# there is somewhere for them to sleep.
	(GameState.data["island"]["plots"] as Dictionary).erase("plot_7")
	var survivor_defs: Dictionary = DataDefs.crew["survivor"]
	var old_chance: float = float(survivor_defs["chance_per_run"])
	survivor_defs["chance_per_run"] = 1.0
	scene._on_start_pressed()
	scene._maybe_schedule_survivor()
	assert_eq(scene._survivor_id, "", "no quarters, no castaways, even at chance 1.0")
	survivor_defs["chance_per_run"] = old_chance
