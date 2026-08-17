class_name NotificationScheduler
extends RefCounted
## Seam for the Android notification-scheduler plugin (spec 7.1). This base
## class is the desktop/headless no-op; the plugin-backed implementation is
## vendored at Android-build time and selected at boot, mirroring Ads.service.


func schedule(_id: String, _title: String, _body: String, _fire_at: int) -> void:
	pass


func cancel_all() -> void:
	pass


func request_permission() -> void:
	# Android 13+ POST_NOTIFICATIONS runtime permission (spec 5).
	pass
