extends GutTest
## The island-rework arc's closing proof (run-kit spec): the Balloonworks
## crafts a Charged Ballast, the setup phase elects it plus provisioning, and
## the started run carries +2 drops and 1.15x payouts. Fixed clock, no RNG.

const RunScene := preload("res://game/run/salvage_run.tscn")
const TEST_SAVE := "user://test_kit_integration.json"
const T0 := 1_800_000_000


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	GameState.data["created_at"] = T0
	GameState.data["fuel"]["updated_at"] = T0
	GameState.data["currencies"]["cloudsilk"] = 4
	GameState.data["currencies"]["parts"] = 4
	GameState.data["currencies"]["provisions"] = 5
	GameState.data["island"]["plots"]["plot_3"] = {"building": "balloonworks", "level": 1}


func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_kit_integration.json", "test_kit_integration.json.tmp", "test_kit_integration.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings, DataDefs.crew)


func test_craft_elect_and_run_with_the_kit() -> void:
	# 1. The Balloonworks crafts a Charged Ballast on a fake clock.
	assert_true(ConvertModel.start_batch(GameState.data, DataDefs.buildings, Economy, TimerService, "balloonworks", "charged_ballast", T0))
	ConvertModel.complete_batch(GameState.data, DataDefs.buildings, Economy, TimerService.collect("convert_balloonworks", T0 + 900))
	assert_eq(Economy.balance("ballast"), 1)
	# 2. The setup phase elects the ballast and provisioning; Start consumes both.
	var scene = add_child_autofree(RunScene.instantiate())
	scene._refresh_kit_panel()
	scene._on_kit_toggled(true, "ballast")
	scene._on_kit_toggled(true, "provision")
	var base_drops: int = scene.model.drops_remaining()
	scene._on_start_pressed()
	assert_eq(Economy.balance("ballast"), 0, "island output spent on the run")
	assert_eq(Economy.balance("provisions"), 2)
	# 3. The run carries the kit: more drops, richer catches.
	assert_eq(scene.model.drops_remaining(), base_drops + 2)
	assert_eq(scene._compute_payout(null, {"scrap": 20}), {"scrap": 23},
		"the arc closes: the island provisions the sky")

func test_kit_free_run_is_byte_identical_to_before() -> void:
	var scene = add_child_autofree(RunScene.instantiate())
	scene._on_start_pressed()
	assert_eq(scene._compute_payout(null, {"scrap": 20}), {"scrap": 20},
		"no kit, no change: the multiplier identity holds")
	assert_eq(scene._free_rerolls, 0)
