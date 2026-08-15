class_name SaveSchema
## Versioned save schema (spec 7.3). One dict is the whole save.
## "island" and "gizmos" are reserved for the base-builder and gizmo plans.

const CURRENT_VERSION := 1


static func default_data(defs: Dictionary) -> Dictionary:
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
		"gizmos": {},
	}


static func migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 0))
	if version <= 0 or version > CURRENT_VERSION:
		return {}
	# When CURRENT_VERSION bumps past 1, add a `while version < CURRENT_VERSION`
	# loop here dispatching to _migrate_N_to_M(data) functions, stamping
	# data["version"] after each hop. v1 has no predecessors to migrate from.
	return data
