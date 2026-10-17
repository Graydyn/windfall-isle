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


static func rarity_unlocked(island: Dictionary, gizmo_defs: Dictionary, gizmo_id: String) -> bool:
	# Rarity is an acquisition gate keyed to Workshop level (Plan 13, spec
	# 3.3). Fail-closed authoring guard: a def whose rarity is missing or
	# absent from rarity_unlocks cannot be crafted.
	var def: Dictionary = (gizmo_defs.get("defs", {}) as Dictionary).get(gizmo_id, {})
	var rarity := String(def.get("rarity", ""))
	var unlocks: Dictionary = gizmo_defs.get("rarity_unlocks", {})
	if not unlocks.has(rarity):
		push_warning("Gizmo '%s' has missing or unknown rarity '%s'; crafting locked" % [gizmo_id, rarity])
		return false
	return IslandModel.building_level(island, "workshop") >= int(unlocks[rarity])


static func can_craft(data: Dictionary, gizmo_defs: Dictionary, economy: Node, timers: Node, gizmo_id: String) -> bool:
	if craft_slots(data.get("island", {})) <= 0:
		return false
	if active_crafts(timers) >= craft_slots(data.get("island", {})):
		return false
	if timers.active_timers().has("craft_" + gizmo_id):
		return false
	var def: Dictionary = (gizmo_defs.get("defs", {}) as Dictionary).get(gizmo_id, {})
	if def.is_empty():
		return false
	if not rarity_unlocked(data.get("island", {}), gizmo_defs, gizmo_id):
		return false
	# Craft-to-acquire (spec 3.3): unowned recipes craft at level 0 -> 1;
	# resources (worked parts and regional materials) are the gate, not
	# ownership. Prices are raw craft_cost: the Annex discount died with the
	# parts repricing (chains spec section 3 amendment).
	var owned: Dictionary = (data.get("gizmos", {}) as Dictionary).get("owned", {})
	if int(owned.get(gizmo_id, 0)) >= int(gizmo_defs.get("craft_max_level", 5)):
		return false
	return economy.can_afford(def.get("craft_cost", {}))


static func start_craft(data: Dictionary, gizmo_defs: Dictionary, economy: Node, timers: Node, gizmo_id: String, now: int, crew_defs: Dictionary = {}) -> bool:
	if not can_craft(data, gizmo_defs, economy, timers, gizmo_id):
		return false
	var def: Dictionary = (gizmo_defs.get("defs", {}) as Dictionary).get(gizmo_id, {})
	if not economy.pay(def.get("craft_cost", {})):
		return false
	# The worker's speed is priced into the duration at START and locked in
	# the timer's ends_at; reassignment never retimes a running craft
	# (crew spec section 5).
	var duration := maxi(1, ceili(float(def.get("craft_seconds", 120)) / CrewModel.multiplier_for(data, crew_defs, "workshop")))
	return timers.start("craft_" + gizmo_id, "craft", duration, now, {"gizmo": gizmo_id})


static func complete_craft(data: Dictionary, payload: Dictionary) -> void:
	if payload.is_empty():
		return
	var gizmo_id := String(payload.get("gizmo", ""))
	if gizmo_id == "":
		return
	var owned: Dictionary = (data.get("gizmos", {}) as Dictionary).get("owned", {})
	owned[gizmo_id] = int(owned.get(gizmo_id, 0)) + 1


static func craftable_ids(data: Dictionary, gizmo_defs: Dictionary, economy: Node) -> Array[String]:
	# Distinct gizmos the player could craft on resources alone (the workshop
	# speech bubble, owner request 2026-10-17). Slot occupancy is deliberately
	# ignored: the bubble advertises what the resources allow, not what the
	# queue allows this minute.
	var out: Array[String] = []
	var owned: Dictionary = (data.get("gizmos", {}) as Dictionary).get("owned", {})
	for gizmo_id in gizmo_defs.get("defs", {}):
		var def: Dictionary = (gizmo_defs["defs"] as Dictionary)[gizmo_id]
		if not rarity_unlocked(data.get("island", {}), gizmo_defs, String(gizmo_id)):
			continue
		if int(owned.get(String(gizmo_id), 0)) >= int(gizmo_defs.get("craft_max_level", 5)):
			continue
		if not economy.can_afford(def.get("craft_cost", {})):
			continue
		out.append(String(gizmo_id))
	return out
