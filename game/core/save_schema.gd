class_name SaveSchema
## Versioned save schema (spec 7.3). One dict is the whole save.
## "island" and "gizmos" are reserved for the base-builder and gizmo plans.

const CURRENT_VERSION := 3


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
	if int(data["version"]) == 2:
		data = _migrate_2_to_3(data, gizmo_defs)
	return data


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
