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
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		# A truncated tmp file (full disk, dying battery) must never be
		# renamed over the good save.
		return write_error
	var dir := DirAccess.open(save_path.get_base_dir())
	if dir == null:
		return DirAccess.get_open_error()
	if FileAccess.file_exists(save_path):
		var copy_error := dir.copy(save_path, backup_path)
		if copy_error != OK:
			return copy_error
	return dir.rename(tmp_path, save_path)


func read() -> Dictionary:
	for path in [save_path, backup_path]:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			return parsed
	return {}


func preserve_incompatible() -> Error:
	# A save written by a NEWER app version (sideload downgrade, rollback)
	# must never be overwritten with defaults; park a copy beside the save so
	# a later app upgrade can recover it (spec 7.3).
	if not FileAccess.file_exists(save_path):
		return OK
	var dir := DirAccess.open(save_path.get_base_dir())
	if dir == null:
		return DirAccess.get_open_error()
	return dir.copy(save_path, save_path + ".incompatible")
