extends GutTest
## End-to-end crew loop (crew spec): a run rescues a drifting survivor, the
## island assigns them, and the Gardens trickle measurably speeds up on an
## injected clock. Fixed rng seeds; no wall-clock dependence beyond the
## scene's own TimeUtil stamps.

const RunScene := preload("res://game/run/salvage_run.tscn")
const TEST_SAVE := "user://test_crew_integration.json"
const T0 := 1_800_000_000


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	GameState.data["created_at"] = T0
	GameState.data["fuel"]["updated_at"] = T0
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}


func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_crew_integration.json", "test_crew_integration.json.tmp", "test_crew_integration.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings, DataDefs.crew)


func test_rescue_assign_and_the_gardens_speed_up() -> void:
	# 1. A run with a forced survivor: pod contact rescues and persists.
	var scene = add_child_autofree(RunScene.instantiate())
	scene._on_start_pressed()
	scene._survivor_id = "odo"
	scene._survivor_from_left = true
	var timer := Timer.new()
	scene.add_child(timer)
	scene._spawn_survivor(timer)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	var survivor: Node = get_tree().get_nodes_in_group("survivors")[0]
	survivor._on_body(pod)
	assert_true(CrewModel.is_rescued(GameState.data, "odo"))
	# 2. Assign Odo to the Gardens on a fixed clock; the rate rises 1.5x and
	#    already-accrued value is preserved by the rebase.
	GameState.data["trickle"]["last_collect"] = T0
	var mid := T0 + 3600
	assert_eq(TrickleModel.pending(GameState.data, DataDefs.buildings, mid, DataDefs.crew), 20)
	assert_true(CrewModel.assign(GameState.data, DataDefs.crew, "gardens", "odo", DataDefs.buildings, mid))
	assert_eq(TrickleModel.pending(GameState.data, DataDefs.buildings, mid, DataDefs.crew), 20,
		"assignment preserves the accrued hour")
	assert_eq(TrickleModel.pending(GameState.data, DataDefs.buildings, mid + 3600, DataDefs.crew), 50,
		"20 baseline + 30 crewed for the second hour")

func test_rescue_survives_a_full_save_reload_cycle() -> void:
	CrewModel.rescue(GameState.data, "brisa")
	CrewModel.assign(GameState.data, DataDefs.crew, "wind_still", "brisa", DataDefs.buildings, T0)
	GameState.save_game()
	GameState.load_game(DataDefs.economy, T0 + 100, DataDefs.gizmos, DataDefs.buildings, DataDefs.crew)
	assert_true(CrewModel.is_rescued(GameState.data, "brisa"))
	assert_eq(CrewModel.crew_at(GameState.data, "wind_still"), "brisa")
	assert_eq(int(GameState.data["fuel"]["regen_seconds"]), 800,
		"load re-applies crew effects: 1200 / 1.5 with no wind still built")
