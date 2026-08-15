extends Node
## Loads and validates the designer-tunable JSON under game/data/.
## All balance numbers live in those files, never in scripts (spec 7.2).

const ECONOMY_PATH := "res://game/data/economy.json"
const RUN_PATH := "res://game/data/run.json"

var economy: Dictionary = {}
var run: Dictionary = {}


func _ready() -> void:
	economy = load_json(ECONOMY_PATH)
	run = load_json(RUN_PATH)


static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing data file: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_error("Malformed JSON in %s" % path)
		return {}
	return parsed


func skyfield(region_id: String) -> Dictionary:
	return load_json("res://game/data/skyfields/%s.json" % region_id)
