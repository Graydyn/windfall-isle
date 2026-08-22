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


static func effective_cost(def: Dictionary, island: Dictionary, building_defs: Dictionary) -> Dictionary:
	# Foundry Annex discount (spec 4.4): ceil keeps every price a positive int
	# and the 1 floor keeps crafts from ever becoming free. can_craft and
	# start_craft must BOTH price through here so check and pay agree.
	var annex: Dictionary = (building_defs.get("defs", {}) as Dictionary).get("foundry_annex", {})
	var level := IslandModel.building_level(island, "foundry_annex")
	var discount := float(level) * float(annex.get("craft_discount_per_level", 0.0))
	var base: Dictionary = def.get("craft_cost", {})
	if discount <= 0.0:
		return base.duplicate()
	var out := {}
	for currency in base:
		out[currency] = maxi(1, ceili(float(base[currency]) * (1.0 - discount)))
	return out


static func can_craft(data: Dictionary, gizmo_defs: Dictionary, economy: Node, timers: Node, gizmo_id: String, building_defs: Dictionary = {}) -> bool:
	if craft_slots(data.get("island", {})) <= 0:
		return false
	if active_crafts(timers) >= craft_slots(data.get("island", {})):
		return false
	if timers.active_timers().has("craft_" + gizmo_id):
		return false
	var def: Dictionary = (gizmo_defs.get("defs", {}) as Dictionary).get(gizmo_id, {})
	if def.is_empty():
		return false
	# Craft-to-acquire (spec 3.3): unowned recipes craft at level 0 -> 1;
	# resources (regional materials) are the gate, not ownership.
	var owned: Dictionary = (data.get("gizmos", {}) as Dictionary).get("owned", {})
	if int(owned.get(gizmo_id, 0)) >= int(gizmo_defs.get("craft_max_level", 5)):
		return false
	return economy.can_afford(effective_cost(def, data.get("island", {}), building_defs))


static func start_craft(data: Dictionary, gizmo_defs: Dictionary, economy: Node, timers: Node, gizmo_id: String, now: int, building_defs: Dictionary = {}) -> bool:
	if not can_craft(data, gizmo_defs, economy, timers, gizmo_id, building_defs):
		return false
	var def: Dictionary = (gizmo_defs.get("defs", {}) as Dictionary).get(gizmo_id, {})
	if not economy.pay(effective_cost(def, data.get("island", {}), building_defs)):
		return false
	return timers.start("craft_" + gizmo_id, "craft", int(def.get("craft_seconds", 120)), now, {"gizmo": gizmo_id})


static func complete_craft(data: Dictionary, payload: Dictionary) -> void:
	if payload.is_empty():
		return
	var gizmo_id := String(payload.get("gizmo", ""))
	if gizmo_id == "":
		return
	var owned: Dictionary = (data.get("gizmos", {}) as Dictionary).get("owned", {})
	owned[gizmo_id] = int(owned.get(gizmo_id, 0)) + 1
