extends GutTest

const IslandScene := preload("res://game/base/island_screen.tscn")
const TEST_SAVE := "user://test_island_screen.json"

var screen


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	GameState.data["currencies"]["scrap"] = 2000
	GameState.data["created_at"] = 1000
	GameState.data["fuel"]["updated_at"] = 1000
	screen = add_child_autofree(IslandScene.instantiate())
	await wait_physics_frames(1)

func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_island_screen.json", "test_island_screen.json.tmp", "test_island_screen.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings)


func test_builds_one_row_per_plot() -> void:
	assert_eq(screen.get_node("Rows").get_child_count(), int(DataDefs.buildings["plot_count"]))

func test_select_cycles_unbuilt_buildings() -> void:
	screen._on_select_pressed("plot_0")
	assert_eq(String(screen._selection["plot_0"]), "workshop", "first def id")
	screen._on_select_pressed("plot_0")
	assert_eq(String(screen._selection["plot_0"]), "wind_still")

func test_build_starts_construction_through_model() -> void:
	screen._on_select_pressed("plot_0")
	screen._on_build_pressed("plot_0")
	assert_true(TimerService.active_timers().has("build_plot_0"))
	assert_eq(Economy.balance("scrap"), 2000 - 60)

func test_collect_applies_completion_and_reapplies_fuel_effects() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "wind_still", "level": 0}
	TimerService.start("build_plot_0", "construction", 10, 1000, {"plot": "plot_0", "building": "wind_still", "to_level": 1})
	TimerService._state.data["timers"]["build_plot_0"]["ends_at"] = 0
	screen._on_collect_pressed("plot_0")
	assert_eq(IslandModel.building_level(GameState.data["island"], "wind_still"), 1)
	assert_eq(int(GameState.data["fuel"]["cap"]), 6, "wind still completion re-applies fuel effects")

func test_built_building_no_longer_offered_for_empty_plots() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	screen._rebuild()
	screen._on_select_pressed("plot_1")
	assert_ne(String(screen._selection["plot_1"]), "workshop")

func test_built_observatory_shows_its_teaser() -> void:
	GameState.data["island"]["plots"]["plot_3"] = {"building": "observatory", "level": 1}
	var text: String = screen._row_text("plot_3", GameState.data["island"], TimeUtil.now())
	assert_string_contains(text, "Brasswork Reach",
		"spec 4.1: the Observatory reveals upcoming regions")

func test_gardens_collect_credits_scrap() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	GameState.data["trickle"]["last_collect"] = TimeUtil.now() - 3600
	var scrap_before := Economy.balance("scrap")
	screen._on_gardens_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 20)
	assert_eq(TrickleModel.pending(GameState.data, DataDefs.buildings, TimeUtil.now()), 0)

func test_crate_claims_once() -> void:
	GameState.data["daily_crate"]["last_claim_day"] = 0
	var scrap_before := Economy.balance("scrap")
	var crystals_before := Economy.balance("crystals")
	screen._on_crate_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 40)
	assert_eq(Economy.balance("crystals"), crystals_before + 1)
	screen._on_crate_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 40, "second claim same day is a no-op")

func test_slot_button_unlocks_second_slot() -> void:
	GameState.data["currencies"]["crystals"] = 30
	screen._on_slot_pressed()
	assert_eq(int(GameState.data["island"]["build_slots"]), 2)
	assert_eq(Economy.balance("crystals"), 10)
