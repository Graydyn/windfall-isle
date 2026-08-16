class_name CraftModel
## Workshop crafting (spec 4.1, 3.3): timed crafts of gizmo duplicates that
## merge into levels. Craft slots equal the Workshop's level.


static func craft_slots(island: Dictionary) -> int:
	return IslandModel.building_level(island, "workshop")


static func active_crafts(timers: Node) -> int:
	var count := 0
	for id in timers.active_timers():
		if String((timers.active_timers()[id] as Dictionary).get("kind", "")) == "craft":
			count += 1
	return count


static func can_craft(data: Dictionary, gizmo_defs: Dictionary, economy: Node, timers: Node, gizmo_id: String) -> bool:
	if craft_slots(data.get("island", {})) <= 0:
		return false
	if active_crafts(timers) >= craft_slots(data.get("island", {})):
		return false
	if timers.active_timers().has("craft_" + gizmo_id):
		return false
	var owned: Dictionary = (data.get("gizmos", {}) as Dictionary).get("owned", {})
	if not owned.has(gizmo_id):
		return false
	if int(owned[gizmo_id]) >= int(gizmo_defs.get("craft_max_level", 5)):
		return false
	var def: Dictionary = (gizmo_defs.get("defs", {}) as Dictionary).get(gizmo_id, {})
	return economy.can_afford(def.get("craft_cost", {}))


static func start_craft(data: Dictionary, gizmo_defs: Dictionary, economy: Node, timers: Node, gizmo_id: String, now: int) -> bool:
	if not can_craft(data, gizmo_defs, economy, timers, gizmo_id):
		return false
	var def: Dictionary = (gizmo_defs.get("defs", {}) as Dictionary).get(gizmo_id, {})
	if not economy.pay(def.get("craft_cost", {})):
		return false
	return timers.start("craft_" + gizmo_id, "craft", int(def.get("craft_seconds", 120)), now, {"gizmo": gizmo_id})


static func complete_craft(data: Dictionary, payload: Dictionary) -> void:
	if payload.is_empty():
		return
	var gizmo_id := String(payload.get("gizmo", ""))
	var owned: Dictionary = (data.get("gizmos", {}) as Dictionary).get("owned", {})
	if owned.has(gizmo_id):
		owned[gizmo_id] = int(owned[gizmo_id]) + 1
