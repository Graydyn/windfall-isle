class_name RunModel
extends RefCounted
## Pure state machine for one salvage expedition (spec 3.2). No nodes, no
## physics, no clock: the scene layer feeds it begin_drop/resolve_pod events.
## The player always keeps everything collected; abandon never forfeits loot.

signal loot_changed(loot: Dictionary)
signal run_over

var drops_total: int
var drops_used := 0
var pods_in_flight := 0
var max_active_pods: int
var loot: Dictionary = {}
var abandoned := false

var _over_emitted := false


func _init(config: Dictionary) -> void:
	drops_total = int(config.get("drops_per_run", 8))
	max_active_pods = int(config.get("max_active_pods", 4))


func drops_remaining() -> int:
	return drops_total - drops_used


func can_drop() -> bool:
	return not abandoned and drops_remaining() > 0 and pods_in_flight < max_active_pods


func begin_drop() -> bool:
	if not can_drop():
		return false
	drops_used += 1
	pods_in_flight += 1
	return true


func resolve_pod(payout: Dictionary) -> void:
	pods_in_flight = maxi(0, pods_in_flight - 1)
	for currency in payout:
		loot[currency] = int(loot.get(currency, 0)) + int(payout[currency])
	loot_changed.emit(loot)
	_check_over()


func abandon() -> void:
	abandoned = true
	_check_over()


func is_over() -> bool:
	return abandoned or (drops_remaining() <= 0 and pods_in_flight == 0)


func _check_over() -> void:
	if is_over() and not _over_emitted:
		_over_emitted = true
		run_over.emit()


func add_bonus_loot(payout: Dictionary) -> void:
	# Gizmo bonuses (Lightning Jar): loot without pod bookkeeping.
	for currency in payout:
		loot[currency] = int(loot.get(currency, 0)) + int(payout[currency])
	loot_changed.emit(loot)


func add_split_pod() -> bool:
	# Splitter Vane: one more pod in flight without consuming a drop.
	if abandoned or pods_in_flight <= 0 or pods_in_flight >= max_active_pods:
		return false
	pods_in_flight += 1
	return true
