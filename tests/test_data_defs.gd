extends GutTest

const DataDefsScript := preload("res://game/autoload/data_defs.gd")


func test_economy_defs_load_with_required_keys() -> void:
	var defs := DataDefsScript.load_json("res://game/data/economy.json")
	assert_has(defs, "starting_balances")
	assert_has(defs, "fuel")
	assert_true(int(defs["fuel"]["cap"]) > 0, "fuel cap must be positive")
	assert_true(int(defs["fuel"]["regen_seconds"]) > 0, "regen_seconds must be positive")

func test_missing_file_returns_empty_dict() -> void:
	assert_eq(DataDefsScript.load_json("res://game/data/does_not_exist.json"), {})
	assert_push_error_count(1)

func test_malformed_json_returns_empty_dict() -> void:
	assert_eq(DataDefsScript.load_json("res://tests/fixtures/bad_data.json"), {})
	assert_engine_error_count(1)
	assert_push_error_count(1)
