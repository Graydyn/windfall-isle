extends Node
## Schedules local notifications when the app backgrounds and cancels them on
## resume (spec 5). The pending set is recomputed from save state every time,
## never stored, so it can never drift from the truth.

var scheduler: NotificationScheduler = NotificationScheduler.new()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		schedule_all(TimeUtil.now())
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		scheduler.cancel_all()


func schedule_all(now: int) -> void:
	scheduler.cancel_all()
	for entry in NotificationPlanner.plan(GameState.data, DataDefs.buildings, DataDefs.gizmos, now, DataDefs.islets):
		scheduler.schedule(String(entry["id"]), String(entry["title"]), String(entry["body"]), int(entry["fire_at"]))


func request_permission_once() -> void:
	# Spec 5: ask at the first construction completion, not at first launch.
	# Write the section back first so a damaged save cannot swallow the flag
	# in a detached dict (same discipline as AdLimits._ads).
	if not GameState.data.has("notifications"):
		GameState.data["notifications"] = {"permission_requested": false}
	var flags: Dictionary = GameState.data["notifications"]
	if bool(flags.get("permission_requested", false)):
		return
	flags["permission_requested"] = true
	scheduler.request_permission()
