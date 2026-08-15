class_name SaveIO
extends RefCounted
## Atomic save IO (spec 7.3): write to temp then rename, keep a rolling backup
## of the previous good save, fall back to the backup on corruption.

var save_path: String
var tmp_path: String
var backup_path: String


func _init(path: String = "user://save.json") -> void:
	save_path = path
	tmp_path = path + ".tmp"
	backup_path = path + ".bak"


func write(data: Dictionary) -> Error:
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var dir := DirAccess.open(save_path.get_base_dir())
	if dir == null:
		return DirAccess.get_open_error()
	if FileAccess.file_exists(save_path):
		dir.copy(save_path, backup_path)
	return dir.rename(tmp_path, save_path)


func read() -> Dictionary:
	for path in [save_path, backup_path]:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			return parsed
	return {}
