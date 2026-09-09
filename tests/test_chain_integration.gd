extends GutTest
## End-to-end chain proof (chains spec): scrap smelts into parts at a crewed
## Smeltery, and the parts price a gizmo craft. Fixed clock, no RNG.

const TEST_SAVE := "user://test_chain_integration.json"
const T0 := 1_800_000_000


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	GameState.data["created_at"] = T0
	GameState.data["fuel"]["updated_at"] = T0
	GameState.data["currencies"]["scrap"] = 500
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	GameState.data["island"]["plots"]["plot_1"] = {"building": "smeltery", "level": 1}


func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_chain_integration.json", "test_chain_integration.json.tmp", "test_chain_integration.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings, DataDefs.crew)


func test_smelt_then_craft_end_to_end() -> void:
	# 1. Reya works the Smeltery: the batch runs at the specialist rate.
	CrewModel.rescue(GameState.data, "reya")
	assert_true(CrewModel.assign(GameState.data, DataDefs.crew, "smeltery", "reya", DataDefs.buildings, T0))
	assert_true(ConvertModel.start_batch(GameState.data, DataDefs.buildings, Economy, TimerService, "smeltery", "smelt", T0, DataDefs.crew))
	assert_eq(Economy.balance("scrap"), 500 - 40)
	assert_eq(TimerService.remaining("convert_smeltery", T0), 400, "600s / 1.5 specialist")
	# 2. Collect the parts.
	var payload := TimerService.collect("convert_smeltery", T0 + 400)
	ConvertModel.complete_batch(GameState.data, DataDefs.buildings, Economy, payload)
	assert_eq(Economy.balance("parts"), 1)
	# 3. Parts price the craft: one short, then enough.
	assert_false(CraftModel.can_craft(GameState.data, DataDefs.gizmos, Economy, TimerService, "wind_fan"),
		"one part is not two")
	Economy.add("parts", 1)
	assert_true(CraftModel.start_craft(GameState.data, DataDefs.gizmos, Economy, TimerService, "wind_fan", T0 + 400))
	assert_eq(Economy.balance("parts"), 0, "the chain's output is the craft's input")
	CraftModel.complete_craft(GameState.data, TimerService.collect("craft_wind_fan", T0 + 400 + 120))
	assert_eq(int(GameState.data["gizmos"]["owned"]["wind_fan"]), 2, "the loop closes: island production upgrades the board")

func test_provisions_accumulate_for_plan_12() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	assert_true(ConvertModel.start_batch(GameState.data, DataDefs.buildings, Economy, TimerService, "gardens", "put_up_provisions", T0))
	ConvertModel.complete_batch(GameState.data, DataDefs.buildings, Economy, TimerService.collect("convert_gardens", T0 + 3600))
	assert_eq(Economy.balance("provisions"), 2, "the stock builds ahead of the run kit")
