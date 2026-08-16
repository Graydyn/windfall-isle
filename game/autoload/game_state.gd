extends Node
## Owns the one save dict. Services (Economy, TimerService) mutate sub-dicts
## of `data` by reference; saving is serializing this dict (spec 7.2, 7.3).

signal loaded

var data: Dictionary = {}
var _io: SaveIO = SaveIO.new()


func _ready() -> void:
	load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings)


func load_game(defs: Dictionary, now: int, gizmo_defs: Dictionary = {}, building_defs: Dictionary = {}) -> void:
	var raw := _io.read()
	var migrated: Dictionary = SaveSchema.migrate(raw, gizmo_defs) if not raw.is_empty() else {}
	if migrated.is_empty():
		migrated = SaveSchema.default_data(defs, gizmo_defs)
		migrated["created_at"] = now
		migrated["fuel"]["updated_at"] = now
	data = migrated
	if not building_defs.is_empty():
		IslandEffects.apply_fuel(data, defs, building_defs)
	loaded.emit()


func save_game() -> Error:
	return _io.write(data)


func _notification(what: int) -> void:
	# Save-anywhere: the OS backgrounding or closing the app never loses state.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
