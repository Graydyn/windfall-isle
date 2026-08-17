extends GutTest

const TEST_PATH := "user://test_save.json"

var io: SaveIO


func before_each() -> void:
	io = SaveIO.new(TEST_PATH)
	_delete_test_files()

func after_all() -> void:
	_delete_test_files()

func _delete_test_files() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_save.json", "test_save.json.tmp", "test_save.json.bak", "test_save.json.incompatible"]:
		if dir.file_exists(f):
			dir.remove(f)


func test_read_with_no_files_returns_empty() -> void:
	assert_eq(io.read(), {})

func test_write_read_roundtrip() -> void:
	assert_eq(io.write({"version": 1, "marker": "A"}), OK)
	assert_eq(io.read()["marker"], "A")

func test_no_tmp_file_left_behind() -> void:
	io.write({"marker": "A"})
	assert_false(FileAccess.file_exists(io.tmp_path))

func test_second_write_creates_backup_of_previous_save() -> void:
	io.write({"marker": "A"})
	io.write({"marker": "B"})
	assert_true(FileAccess.file_exists(io.backup_path))
	assert_eq(io.read()["marker"], "B")

func test_corrupted_save_falls_back_to_backup() -> void:
	io.write({"marker": "A"})
	io.write({"marker": "B"})  # backup now holds A
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("{ corrupted garbage")
	f.close()
	assert_eq(io.read()["marker"], "A")
	assert_engine_error_count(1)

func test_preserve_incompatible_parks_a_copy() -> void:
	io.write({"version": 99, "marker": "future"})
	assert_eq(io.preserve_incompatible(), OK)
	var parked: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH + ".incompatible"))
	assert_eq(String((parked as Dictionary)["marker"]), "future")
	assert_eq(io.read()["marker"], "future", "the original save is untouched")

func test_preserve_incompatible_with_no_save_is_a_quiet_ok() -> void:
	assert_eq(io.preserve_incompatible(), OK)
	assert_false(FileAccess.file_exists(TEST_PATH + ".incompatible"))
