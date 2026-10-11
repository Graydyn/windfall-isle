extends Node
## Loads and validates the designer-tunable JSON under game/data/.
## All balance numbers live in those files, never in scripts (spec 7.2).

const ECONOMY_PATH := "res://game/data/economy.json"
const RUN_PATH := "res://game/data/run.json"
const GIZMOS_PATH := "res://game/data/gizmos.json"
const BUILDINGS_PATH := "res://game/data/buildings.json"
const RETENTION_PATH := "res://game/data/retention.json"
const BOONS_PATH := "res://game/data/boons.json"
const ISLETS_PATH := "res://game/data/islets.json"
const CREW_PATH := "res://game/data/crew.json"
const ISLAND_LAYOUT_PATH := "res://game/data/island_layout.json"

var economy: Dictionary = {}
var run: Dictionary = {}
var gizmos: Dictionary = {}
var buildings: Dictionary = {}
var retention: Dictionary = {}
var boons: Dictionary = {}
var islets: Dictionary = {}
var crew: Dictionary = {}
var island_layout: Dictionary = {}


func _ready() -> void:
	economy = load_json(ECONOMY_PATH)
	run = load_json(RUN_PATH)
	gizmos = load_json(GIZMOS_PATH)
	buildings = load_json(BUILDINGS_PATH)
	retention = load_json(RETENTION_PATH)
	boons = load_json(BOONS_PATH)
	islets = load_json(ISLETS_PATH)
	crew = load_json(CREW_PATH)
	island_layout = load_json(ISLAND_LAYOUT_PATH)


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
