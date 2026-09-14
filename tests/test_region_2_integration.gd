extends GutTest
## End-to-end region 2 flywheel on a fake clock: build the Dock, unlock and
## select Brasswork Reach, bank brasswork through the run model, craft the
## Gyro Damper with it, slot it in region 2's loadout, and roundtrip the v6
## save. Spec: 2026-08-17-region-2-brasswork-reach-design.md sections 2-7.

const TimerServiceScript := preload("res://game/autoload/timer_service.gd")
const EconomyScript := preload("res://game/autoload/economy.gd")
const GameStateScript := preload("res://game/autoload/game_state.gd")
const TEST_PATH := "user://test_region_2.json"
const T0 := 1_900_000_000

var state: Node
var econ: Node
var timers: Node


func before_each() -> void:
	_delete_test_files()
	state = autofree(GameStateScript.new())
	state._io = SaveIO.new(TEST_PATH)
	state.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	state.data["created_at"] = T0
	state.data["fuel"]["updated_at"] = T0
	state.data["currencies"]["scrap"] = 5000
	econ = autofree(EconomyScript.new())
	econ.setup(state)
	timers = autofree(TimerServiceScript.new())
	timers.setup(state)

func after_all() -> void:
	_delete_test_files()

func _delete_test_files() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_region_2.json", "test_region_2.json.tmp", "test_region_2.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)


func test_dock_unlock_to_brass_craft_flywheel() -> void:
	# Locked at first: the selection falls back home.
	assert_eq(RegionModel.selected_id(state.data, DataDefs.run, state.data["island"]), "region_1")
	# Build the Dock (120 scrap, 180 s) and collect it.
	assert_true(IslandModel.start_build(state.data["island"], DataDefs.buildings, econ, timers, "plot_0", "dock", T0))
	IslandModel.complete_build(state.data["island"], timers.collect("build_plot_0", T0 + 181), state.data, T0 + 181, DataDefs.buildings)
	var region_2 := RegionModel.entry(DataDefs.run, "region_2")
	assert_true(RegionModel.unlocked(region_2, state.data["island"]))
	assert_eq(RegionModel.fuel_cost(region_2, state.data["island"]), 2)
	# Select it and spend a region-2 expedition's fuel.
	(state.data["expedition"] as Dictionary)["region"] = "region_2"
	assert_eq(RegionModel.selected_id(state.data, DataDefs.run, state.data["island"]), "region_2")
	assert_true(FuelModel.spend(state.data["fuel"], 2, T0 + 200))
	# A scripted run on region 2's tiers banks scrap and brasswork.
	var region_defs := DataDefs.skyfield("region_2")
	var model := RunModel.new({"drops_per_run": 8, "max_active_pods": 4, "quota_tiers": region_defs.get("quota_tiers", [])})
	model.begin_drop()
	model.resolve_pod({"scrap": 35, "brasswork": 2})
	assert_eq(model.tier, 1, "region 2's first quota lifts at 35 scrap")
	econ.add("scrap", 35)
	econ.add("brasswork", 2)
	econ.add("parts", 5)
	# Build the Workshop, then craft the Gyro Damper with the brasswork.
	assert_true(IslandModel.start_build(state.data["island"], DataDefs.buildings, econ, timers, "plot_1", "workshop", T0 + 300))
	IslandModel.complete_build(state.data["island"], timers.collect("build_plot_1", T0 + 361), state.data, T0 + 361, DataDefs.buildings)
	# Rarity gate (Plan 13): the Gyro Damper is rare and needs Workshop Lv 3.
	(state.data["island"]["plots"]["plot_1"] as Dictionary)["level"] = 3
	assert_true(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "gyro_damper"))
	assert_true(CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "gyro_damper", T0 + 400))
	assert_eq(econ.balance("brasswork"), 0, "the recipe consumed the regional material")
	CraftModel.complete_craft(state.data, timers.collect("craft_gyro_damper", T0 + 400 + 421))
	assert_eq(int(state.data["gizmos"]["owned"]["gyro_damper"]), 1, "first craft grants ownership")
	# Slot it on Brasswork Reach and roundtrip the save.
	GizmoLoadout.set_slot(state.data["gizmos"], "region_2", "slot_4", "gyro_damper")
	assert_eq(state.save_game(), OK)
	var reloaded := SaveIO.new(TEST_PATH).read()
	assert_eq(int(reloaded["version"]), SaveSchema.CURRENT_VERSION)
	assert_eq(String((reloaded["expedition"] as Dictionary)["region"]), "region_2")
	assert_eq(String(((reloaded["gizmos"]["loadout"] as Dictionary)["region_2"] as Dictionary)["slot_4"]), "gyro_damper")

func test_dock_level_2_discount_end_to_end() -> void:
	state.data["island"]["plots"]["plot_0"] = {"building": "dock", "level": 2}
	assert_eq(RegionModel.fuel_cost(RegionModel.entry(DataDefs.run, "region_2"), state.data["island"]), 1,
		"spec 4.1: higher Dock levels reduce expedition fuel costs")
