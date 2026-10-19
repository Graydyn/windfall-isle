class_name RegionModel
## Pure region rules (spec 3.4, 4.1): unlock by Dock level, per-region fuel
## cost with the Observatory's discount, and the persisted-selection
## fallback. FuelModel pattern: defs in, values out, no nodes, no clock.

const FALLBACK_ID := "region_1"


static func unlocked(region_entry: Dictionary, island: Dictionary) -> bool:
	return IslandModel.building_level(island, "dock") >= int(region_entry.get("min_dock_level", 0))


static func fuel_cost(region_entry: Dictionary, island: Dictionary) -> int:
	var cost := int(region_entry.get("fuel_cost", 1))
	if region_entry.has("reduced_fuel_cost") and region_entry.has("reduced_at_observatory_level") \
			and IslandModel.building_level(island, "observatory") >= int(region_entry["reduced_at_observatory_level"]):
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
	# A persisted id that is unknown (defs changed), no longer unlocked
	# (hand-edited save), or held in a wrong-typed section falls back
	# silently; nothing rewrites the save.
	var expedition: Variant = data.get("expedition", {})
	if not (expedition is Dictionary):
		return FALLBACK_ID
	var wanted := String((expedition as Dictionary).get("region", FALLBACK_ID))
	var region_entry := entry(run_defs, wanted)
	if not region_entry.is_empty() and unlocked(region_entry, island):
		return wanted
	return FALLBACK_ID


static func next_region_id(run_defs: Dictionary, island: Dictionary, current_id: String) -> String:
	# Cycle helper shared by the launcher and loadout screens: the next
	# unlocked id in declared order, or current_id when there is no cycle.
	return _cycled_id(run_defs, island, current_id, 1)


static func prev_region_id(run_defs: Dictionary, island: Dictionary, current_id: String) -> String:
	# Mirror of next_region_id for the launcher's left arrow: the previous
	# unlocked id in declared order, wrapping past the front.
	return _cycled_id(run_defs, island, current_id, -1)


static func _cycled_id(run_defs: Dictionary, island: Dictionary, current_id: String, step: int) -> String:
	var entries := unlocked_entries(run_defs, island)
	if entries.size() <= 1:
		return current_id
	var index := 0
	for i in entries.size():
		if String((entries[i] as Dictionary).get("id", "")) == current_id:
			index = i
			break
	return String((entries[posmod(index + step, entries.size())] as Dictionary).get("id", FALLBACK_ID))


static func _entries(run_defs: Dictionary) -> Array:
	var entries: Variant = run_defs.get("regions", [])
	if entries is Array and not (entries as Array).is_empty():
		return entries
	# Defensive: a defs file without regions still yields a playable region 1.
	return [{"id": FALLBACK_ID, "name": "Home Skies", "fuel_cost": int(run_defs.get("fuel_cost", 1)), "min_dock_level": 0}]
