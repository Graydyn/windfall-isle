class_name RunModel
extends RefCounted
## Pure state machine for one salvage expedition (spec 3.2). No nodes, no
## physics, no clock: the scene layer feeds it begin_drop/resolve_pod events.
## The player always keeps everything collected; abandon never forfeits loot.

signal loot_changed(loot: Dictionary)
signal run_over
signal tier_reached(tier: int)

var drops_total: int
var drops_used := 0
var pods_in_flight := 0
var max_active_pods: int
var loot: Dictionary = {}
var abandoned := false

var tiers: Array = []
var tier := 0

var _over_emitted := false


func _init(config: Dictionary) -> void:
	drops_total = int(config.get("drops_per_run", 8))
	max_active_pods = int(config.get("max_active_pods", 4))
	tiers = _valid_tiers(config.get("quota_tiers", []))


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
	_check_tier()
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
	_check_tier()
	loot_changed.emit(loot)


func add_split_pod() -> bool:
	# Splitter Vane: one more pod in flight without consuming a drop.
	if abandoned or pods_in_flight <= 0 or pods_in_flight >= max_active_pods:
		return false
	pods_in_flight += 1
	return true


func payout_multiplier() -> float:
	# The multiplier of the highest tier reached; the base tier is 1.0.
	if tier <= 0:
		return 1.0
	return float((tiers[tier - 1] as Dictionary).get("payout_multiplier", 1.0))


func _check_tier() -> void:
	# Quota tiers (spec 3.2): the quota is measured in scrap collected this
	# run. One rich catch may cross several tiers; each lift is announced.
	while tier < tiers.size() and int(loot.get("scrap", 0)) >= int((tiers[tier] as Dictionary).get("scrap_quota", 0)):
		tier += 1
		tier_reached.emit(tier)


static func _valid_tiers(rows: Variant) -> Array:
	# Region-authoring validation (Plan 5 final-review carry-forward): a row
	# missing scrap_quota would lift the tier at 0 scrap on the first catch.
	var out: Array = []
	if not (rows is Array):
		return out
	for row in rows:
		if row is Dictionary and int((row as Dictionary).get("scrap_quota", 0)) > 0 \
				and (row as Dictionary).has("payout_multiplier"):
			out.append(row)
		else:
			push_warning("Ignoring malformed quota tier row: %s" % [row])
	return out
