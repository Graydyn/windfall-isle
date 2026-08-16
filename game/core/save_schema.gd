class_name SaveSchema
## Versioned save schema (spec 7.3). One dict is the whole save.
## "island" and "gizmos" are reserved for the base-builder and gizmo plans.

const CURRENT_VERSION := 2


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
		"island": {},
		"gizmos": _fresh_gizmos(gizmo_defs),
	}


static func migrate(data: Dictionary, gizmo_defs: Dictionary = {}) -> Dictionary:
	var version := int(data.get("version", 0))
	if version <= 0 or version > CURRENT_VERSION:
		return {}
	if version == 1:
		data = _migrate_1_to_2(data, gizmo_defs)
	return data


static func _migrate_1_to_2(data: Dictionary, gizmo_defs: Dictionary) -> Dictionary:
	# v1 shipped "gizmos" as a reserved empty dict; v2 gives it structure and
	# grants the starting inventory so pre-gizmo saves get the same starters
	# a fresh save does.
	data["gizmos"] = _fresh_gizmos(gizmo_defs)
	data["version"] = 2
	return data


static func _fresh_gizmos(gizmo_defs: Dictionary) -> Dictionary:
	return {
		"owned": (gizmo_defs.get("starting_inventory", {}) as Dictionary).duplicate(),
		"loadout": {},
	}
