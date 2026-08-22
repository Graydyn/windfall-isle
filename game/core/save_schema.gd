class_name SaveSchema
## Versioned save schema (spec 7.3). One dict is the whole save.
## "island" and "gizmos" are reserved for the base-builder and gizmo plans.

const CURRENT_VERSION := 7


static func default_data(defs: Dictionary, gizmo_defs: Dictionary = {}) -> Dictionary:
	var balances: Dictionary = defs.get("starting_balances", {})
	var fuel_defs: Dictionary = defs.get("fuel", {})
	return {
		"version": CURRENT_VERSION,
		"created_at": 0,  # caller stamps with TimeUtil.now()
		"currencies": balances.duplicate(),
		"fuel": {
			"amount": int(fuel_defs.get("starting", 0)),
			"cap": int(fuel_defs.get("cap", 5)),
			"regen_seconds": int(fuel_defs.get("regen_seconds", 1200)),
			"updated_at": 0,  # caller stamps with TimeUtil.now()
		},
		"timers": {},
		"island": _fresh_island(),
		"trickle": {"last_collect": 0},
		"daily_crate": {"last_claim_day": 0},
		"gizmos": _fresh_gizmos(gizmo_defs),
		"ads": _fresh_ads(),
		"notifications": _fresh_notifications(),
		"expedition": _fresh_expedition(),
		"islets": _fresh_islets(),
	}


static func migrate(data: Dictionary, gizmo_defs: Dictionary = {}) -> Dictionary:
	var version := int(data.get("version", 0))
	if version <= 0 or version > CURRENT_VERSION:
		return {}
	if version == 1:
		data = _migrate_1_to_2(data, gizmo_defs)
	if int(data["version"]) == 2:
		data = _migrate_2_to_3(data, gizmo_defs)
	if int(data["version"]) == 3:
		data = _migrate_3_to_4(data)
	if int(data["version"]) == 4:
		data = _migrate_4_to_5(data)
	if int(data["version"]) == 5:
		data = _migrate_5_to_6(data)
	if int(data["version"]) == 6:
		data = _migrate_6_to_7(data)
	_backfill_missing_keys(data, gizmo_defs)
	return data


static func is_future_version(data: Dictionary) -> bool:
	return int(data.get("version", 0)) > CURRENT_VERSION


static func _migrate_1_to_2(data: Dictionary, gizmo_defs: Dictionary) -> Dictionary:
	if (gizmo_defs.get("starting_inventory", {}) as Dictionary).is_empty():
		push_warning("Migrating v1 save with no gizmo defs; starting grant will be empty until a later merge-grant hop")
	# v1 shipped "gizmos" as a reserved empty dict; v2 gives it structure and
	# grants the starting inventory so pre-gizmo saves get the same starters
	# a fresh save does.
	data["gizmos"] = _fresh_gizmos(gizmo_defs)
	data["version"] = 2
	return data


static func _migrate_2_to_3(data: Dictionary, gizmo_defs: Dictionary) -> Dictionary:
	# New gizmos joined the starting inventory; merge-grant the missing ones
	# without touching levels the player already upgraded or their loadout.
	if not data.has("gizmos") or not (data["gizmos"] is Dictionary):
		data["gizmos"] = _fresh_gizmos(gizmo_defs)
	var gizmos: Dictionary = data["gizmos"]
	if not gizmos.has("owned"):
		gizmos["owned"] = {}
	if not gizmos.has("loadout"):
		gizmos["loadout"] = {}
	var owned: Dictionary = gizmos["owned"]
	var starters: Dictionary = gizmo_defs.get("starting_inventory", {})
	for id in starters:
		if not owned.has(id):
			owned[id] = int(starters[id])
	data["version"] = 3
	return data


static func _fresh_gizmos(gizmo_defs: Dictionary) -> Dictionary:
	return {
		"owned": (gizmo_defs.get("starting_inventory", {}) as Dictionary).duplicate(),
		"loadout": {},
	}


static func _fresh_island() -> Dictionary:
	return {"plots": {}, "build_slots": 1}


static func _migrate_3_to_4(data: Dictionary) -> Dictionary:
	# Loop 1 arrives: plots/build slots, idle trickle clock, daily crate day.
	data["island"] = _fresh_island()
	data["trickle"] = {"last_collect": 0}
	data["daily_crate"] = {"last_claim_day": 0}
	data["version"] = 4
	return data


static func _migrate_4_to_5(data: Dictionary) -> Dictionary:
	# Retention/Android glue: rewarded-ad daily counters and the
	# notification-permission flag.
	data["ads"] = _fresh_ads()
	data["notifications"] = _fresh_notifications()
	data["version"] = 5
	return data


static func _fresh_ads() -> Dictionary:
	return {"day": 0, "counts": {}}


static func _fresh_notifications() -> Dictionary:
	return {"permission_requested": false}


static func _migrate_5_to_6(data: Dictionary) -> Dictionary:
	# Region 2 arrives: the launcher persists which skyfield is selected.
	data["expedition"] = _fresh_expedition()
	data["version"] = 6
	return data


static func _fresh_expedition() -> Dictionary:
	return {"region": "region_1"}


static func _migrate_6_to_7(data: Dictionary) -> Dictionary:
	# Island expansion arrives: restored islets and read letters (spec 4.4).
	data["islets"] = _fresh_islets()
	data["version"] = 7
	return data


static func _fresh_islets() -> Dictionary:
	return {"restored": {}, "letters_seen": {}}


static func _backfill_missing_keys(data: Dictionary, gizmo_defs: Dictionary) -> void:
	# A structurally damaged save of the current version (hand-edited, partial
	# write survived by the backup) heals to neutral defaults instead of
	# crashing consumers; healthy saves are untouched because every key exists.
	var defaults := default_data({}, gizmo_defs)
	for key in defaults:
		if not data.has(key):
			data[key] = defaults[key]
