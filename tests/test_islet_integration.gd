extends GutTest
## End-to-end proof of the island expansion flywheel on a fixed clock:
## restore Lantern Shoal, build the Lens Array on the opened plot, and a
## salvage-run catch pays the multiplied payout. No RNG is involved.

const RunScene := preload("res://game/run/salvage_run.tscn")
const TEST_SAVE := "user://test_islet_integration.json"
const T0 := 1_800_000_000


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	GameState.data["created_at"] = T0
	GameState.data["fuel"]["updated_at"] = T0
	GameState.data["currencies"]["scrap"] = 5000
	GameState.data["currencies"]["cloudsilk"] = 20


func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_islet_integration.json", "test_islet_integration.json.tmp", "test_islet_integration.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings)


func test_restore_build_and_run_pays_the_lens_bonus() -> void:
	# 1. Pay for the bridge and wait out the 4-hour repair on a fake clock.
	assert_true(IsletModel.start_restore(GameState.data, DataDefs.islets, Economy, TimerService, "lantern_shoal", T0))
	assert_eq(Economy.balance("scrap"), 5000 - 600)
	var payload := TimerService.collect("restore_lantern_shoal", T0 + 14400)
	IsletModel.complete_restore(GameState.data, payload)
	assert_true(IsletModel.is_restored(GameState.data, "lantern_shoal"))
	# 2. The opened plot accepts exactly its own building.
	assert_true(IslandModel.start_build(GameState.data["island"], DataDefs.buildings, Economy, TimerService,
		"islet_lantern_0", "lens_array", T0 + 14400, DataDefs.islets, GameState.data["islets"]))
	var build_payload := TimerService.collect("build_islet_lantern_0", T0 + 14400 + 1800)
	IslandModel.complete_build(GameState.data["island"], build_payload, GameState.data, T0 + 16200)
	assert_eq(IslandModel.building_level(GameState.data["island"], "lens_array"), 1)
	# 3. A run built from this island multiplies every catch by 1.05.
	var scene = add_child_autofree(RunScene.instantiate())
	assert_eq(scene._compute_payout(null, {"scrap": 20}), {"scrap": 21},
		"20 scrap x 1.05 rounds to 21: the flywheel feeds back")

func test_restoration_survives_a_save_reload_cycle() -> void:
	IsletModel.start_restore(GameState.data, DataDefs.islets, Economy, TimerService, "lantern_shoal", T0)
	GameState.save_game()
	GameState.load_game(DataDefs.economy, T0 + 100, DataDefs.gizmos, DataDefs.buildings)
	assert_true(TimerService.active_timers().has("restore_lantern_shoal"),
		"a running restoration persists like any other timer")
	assert_eq(TimerService.remaining("restore_lantern_shoal", T0 + 100), 14300)
