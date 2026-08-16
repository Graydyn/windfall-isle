class_name GizmoLoadout
## Pure helpers over GameState.data["gizmos"] (schema v2): who owns what and
## which gizmo sits in which skyfield slot (spec 3.3: owned permanently,
## slotted by the player). All functions mutate/read the passed dict in place;
## persistence stays GameState's job.


static func owned(gizmos_state: Dictionary) -> Dictionary:
	return gizmos_state.get("owned", {})


static func loadout_for(gizmos_state: Dictionary, region_id: String) -> Dictionary:
	return (gizmos_state.get("loadout", {}) as Dictionary).get(region_id, {})


static func set_slot(gizmos_state: Dictionary, region_id: String, slot: String, gizmo_id: String) -> bool:
	if gizmo_id != "" and not owned(gizmos_state).has(gizmo_id):
		return false
	if not gizmos_state.has("loadout"):
		gizmos_state["loadout"] = {}
	var all_regions: Dictionary = gizmos_state["loadout"]
	if not all_regions.has(region_id):
		all_regions[region_id] = {}
	var region: Dictionary = all_regions[region_id]
	if gizmo_id == "":
		region.erase(slot)
		return true
	for other_slot in region:
		if other_slot != slot and region[other_slot] == gizmo_id:
			return false
	region[slot] = gizmo_id
	return true


static func next_choice(current: String, owned_ids: Array, used_elsewhere: Array) -> String:
	var options: Array = [""]
	for id in owned_ids:
		if id == current or not used_elsewhere.has(id):
			options.append(id)
	var index := options.find(current)
	return options[(index + 1) % options.size()]
