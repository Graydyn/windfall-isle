class_name RegionModel
## Pure region rules (spec 3.4, 4.1): unlock by Dock level, per-region fuel
## cost with the Dock's level-2 discount, and the persisted-selection
## fallback. FuelModel pattern: defs in, values out, no nodes, no clock.

const FALLBACK_ID := "region_1"


static func unlocked(region_entry: Dictionary, island: Dictionary) -> bool:
	return IslandModel.building_level(island, "dock") >= int(region_entry.get("min_dock_level", 0))


static func fuel_cost(region_entry: Dictionary, island: Dictionary) -> int:
	var cost := int(region_entry.get("fuel_cost", 1))
	if region_entry.has("reduced_fuel_cost") and region_entry.has("reduced_at_dock_level") \
			and IslandModel.building_level(island, "dock") >= int(region_entry["reduced_at_dock_level"]):
		cost = int(region_entry["reduced_fuel_cost"])
	return cost


static func unlocked_entries(run_defs: Dictionary, island: Dictionary) -> Array:
	var out: Array = []
	for region_entry in _entries(run_defs):
		if unlocked(region_entry, island):
			out.append(region_entry)
	return out


static func entry(run_defs: Dictionary, region_id: String) -> Dictionary:
	for candidate in _entries(run_defs):
		if String((candidate as Dictionary).get("id", "")) == region_id:
			return candidate
	return {}


static func selected_id(data: Dictionary, run_defs: Dictionary, island: Dictionary) -> String:
	# A persisted id that is unknown (defs changed) or no longer unlocked
	# (hand-edited save) falls back silently; nothing rewrites the save.
	var wanted := String((data.get("expedition", {}) as Dictionary).get("region", FALLBACK_ID))
	var region_entry := entry(run_defs, wanted)
	if not region_entry.is_empty() and unlocked(region_entry, island):
		return wanted
	return FALLBACK_ID


static func _entries(run_defs: Dictionary) -> Array:
	var entries: Variant = run_defs.get("regions", [])
	if entries is Array and not (entries as Array).is_empty():
		return entries
	# Defensive: a defs file without regions still yields a playable region 1.
	return [{"id": FALLBACK_ID, "name": "Home Skies", "fuel_cost": int(run_defs.get("fuel_cost", 1)), "min_dock_level": 0}]
