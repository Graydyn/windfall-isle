class_name NotificationPlanner
## Pure computation of the local notifications to schedule at background time
## (spec 5): construction complete, craft complete, conversion batch complete,
## restoration complete, fuel full, daily crate ready. Reads the persisted timers
## dict READ-ONLY; nothing here mutates state, which is what makes the plan
## testable and idempotent.


static func plan(data: Dictionary, building_defs: Dictionary, gizmo_defs: Dictionary, now: int, islet_defs: Dictionary = {}) -> Array:
	var out: Array = []
	var timers: Dictionary = data.get("timers", {})
	for id in timers:
		var timer: Dictionary = timers[id]
		var fire_at := int(timer.get("ends_at", 0))
		if fire_at <= now:
			continue
		var kind := String(timer.get("kind", ""))
		var payload: Dictionary = timer.get("payload", {})
		if kind == "construction":
			var def: Dictionary = (building_defs.get("defs", {}) as Dictionary).get(String(payload.get("building", "")), {})
			out.append({
				"id": String(id),
				"title": "Construction complete",
				"body": "%s is ready." % String(def.get("name", payload.get("building", "A building"))),
				"fire_at": fire_at,
			})
		elif kind == "craft":
			var def: Dictionary = (gizmo_defs.get("defs", {}) as Dictionary).get(String(payload.get("gizmo", "")), {})
			out.append({
				"id": String(id),
				"title": "Craft complete",
				"body": "%s is ready to collect." % String(def.get("name", payload.get("gizmo", "A gizmo"))),
				"fire_at": fire_at,
			})
		elif kind == "restoration":
			var islet: Dictionary = IsletModel.entry(islet_defs, String(payload.get("islet", "")))
			out.append({
				"id": String(id),
				"title": "Bridge restored",
				"body": "The way to %s is open." % String(islet.get("name", payload.get("islet", "an islet"))),
				"fire_at": fire_at,
			})
		elif kind == "convert":
			var recipe_def: Dictionary = (building_defs.get("defs", {}) as Dictionary).get(String(payload.get("building", "")), {})
			out.append({
				"id": String(id),
				"title": "Batch complete",
				"body": "The %s's batch is ready." % String(recipe_def.get("name", payload.get("building", "a building"))),
				"fire_at": fire_at,
			})
	var fuel: Dictionary = data.get("fuel", {})
	if not fuel.is_empty():
		var until_full := FuelModel.seconds_until_full(fuel, now)
		if until_full > 0:
			out.append({
				"id": "fuel_full",
				"title": "Fuel tank full",
				"body": "Your airship is fueled for new expeditions.",
				"fire_at": now + until_full,
			})
	if not DailyCrate.can_claim(data, now):
		out.append({
			"id": "daily_crate",
			"title": "Daily crate ready",
			"body": "A fresh salvage crate is waiting on the island.",
			"fire_at": (DailyCrate.day_of(now) + 1) * DailyCrate.SECONDS_PER_DAY,
		})
	return out
