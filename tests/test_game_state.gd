extends GutTest

const GameStateScript := preload("res://game/autoload/game_state.gd")
const TEST_PATH := "user://test_gamestate.json"
const DEFS := {
	"starting_balances": {"scrap": 100, "cloudsilk": 0, "crystals": 10},
	"fuel": {"starting": 5, "cap": 5, "regen_seconds": 1200},
}

var gs


func before_each() -> void:
	_delete_test_files()
	gs = autofree(GameStateScript.new())
	gs._io = SaveIO.new(TEST_PATH)

func after_all() -> void:
	_delete_test_files()

func _delete_test_files() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_gamestate.json", "test_gamestate.json.tmp", "test_gamestate.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)


func test_time_util_returns_plausible_unix_seconds() -> void:
	assert_true(TimeUtil.now() > 1_700_000_000)

func test_fresh_load_creates_stamped_defaults() -> void:
	gs.load_game(DEFS, 5000)
	assert_eq(int(gs.data["version"]), SaveSchema.CURRENT_VERSION)
	assert_eq(int(gs.data["created_at"]), 5000)
	assert_eq(int(gs.data["fuel"]["updated_at"]), 5000)
	assert_eq(int(gs.data["currencies"]["scrap"]), 100)

func test_save_load_roundtrip() -> void:
	gs.load_game(DEFS, 5000)
	gs.data["currencies"]["scrap"] = 123
	assert_eq(gs.save_game(), OK)
	var gs2 = autofree(GameStateScript.new())
	gs2._io = SaveIO.new(TEST_PATH)
	gs2.load_game(DEFS, 6000)
	assert_eq(int(gs2.data["currencies"]["scrap"]), 123)
	assert_eq(int(gs2.data["created_at"]), 5000, "existing save must not be re-stamped")

func test_unmigratable_save_falls_back_to_defaults() -> void:
	var io := SaveIO.new(TEST_PATH)
	io.write({"version": 99, "currencies": {"scrap": 1}})
	gs.load_game(DEFS, 7000)
	assert_eq(int(gs.data["version"]), SaveSchema.CURRENT_VERSION)
	assert_eq(int(gs.data["currencies"]["scrap"]), 100)

func test_loaded_signal_emitted() -> void:
	watch_signals(gs)
	gs.load_game(DEFS, 5000)
	assert_signal_emitted(gs, "loaded")

func test_saves_on_application_pause() -> void:
	gs.load_game(DEFS, 5000)
	gs.data["currencies"]["scrap"] = 777
	gs.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var raw := SaveIO.new(TEST_PATH).read()
	assert_eq(int(raw["currencies"]["scrap"]), 777)
