extends Node
## Construction/craft timers (spec 5, 7.1): Unix timestamps persisted in the
## save, elapsed time computed on resume. No Godot Timer nodes, no background
## execution assumed. Callers pass `now` explicitly.

signal timer_started(id: String)
signal timer_collected(id: String, payload: Dictionary)

var _state: Node


func setup(state: Node) -> void:
	_state = state


func _ready() -> void:
	if _state == null:
		setup(GameState)


func _timers() -> Dictionary:
	return _state.data["timers"]


func start(id: String, kind: String, duration_sec: int, now: int, payload: Dictionary = {}) -> bool:
	if _timers().has(id):
		return false
	_timers()[id] = {"kind": kind, "ends_at": now + duration_sec, "payload": payload}
	timer_started.emit(id)
	return true


func remaining(id: String, now: int) -> int:
	if not _timers().has(id):
		return 0
	return maxi(0, int(_timers()[id]["ends_at"]) - now)


func is_done(id: String, now: int) -> bool:
	return _timers().has(id) and now >= int(_timers()[id]["ends_at"])


func collect(id: String, now: int) -> Dictionary:
	if not is_done(id, now):
		return {}
	var payload: Dictionary = _timers()[id].get("payload", {})
	_timers().erase(id)
	timer_collected.emit(id, payload)
	return payload


func skip(id: String) -> void:
	# Accelerator hook for rewarded ads / crystal timer skips (spec 6).
	if _timers().has(id):
		_timers()[id]["ends_at"] = 0


func active_timers() -> Dictionary:
	return _timers()
