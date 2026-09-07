class_name CrewModel
## Pure crew rules over save.crew (crew spec sections 3-5): who is rescued,
## who works where, and the production multiplier a building earns from its
## worker. Buildings run at 1.0 unmanned (the pre-crew baseline), at the
## generalist bonus with any worker, and at the worker's own bonus on a
## specialty match. multiplier_for is the seam Plan 11 chains reuse.


static func members(defs: Dictionary) -> Array:
	return defs.get("crew", [])


static func entry(defs: Dictionary, crew_id: String) -> Dictionary:
	for row_v in members(defs):
		var row := row_v as Dictionary
		if String(row.get("id", "")) == crew_id:
			return row
	return {}


static func workable(defs: Dictionary) -> Array:
	return defs.get("workable", [])


static func _section(data: Dictionary) -> Dictionary:
	# Write-back discipline: heal a missing or wrong-typed crew section in
	# place so no mutation can land in a detached dict.
	if not data.has("crew") or not (data["crew"] is Dictionary):
		data["crew"] = {"rescued": {}, "assignments": {}}
	var section: Dictionary = data["crew"]
	if not section.has("rescued") or not (section["rescued"] is Dictionary):
		section["rescued"] = {}
	if not section.has("assignments") or not (section["assignments"] is Dictionary):
		section["assignments"] = {}
	return section


static func is_rescued(data: Dictionary, crew_id: String) -> bool:
	var raw: Variant = data.get("crew", {})
	var section: Dictionary = raw if raw is Dictionary else {}
	return bool((section.get("rescued", {}) as Dictionary).get(crew_id, false))


static func rescued_ids(data: Dictionary, defs: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for row_v in members(defs):
		var id := String((row_v as Dictionary).get("id", ""))
		if is_rescued(data, id):
			out.append(id)
	return out


static func unrescued_ids(data: Dictionary, defs: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for row_v in members(defs):
		var id := String((row_v as Dictionary).get("id", ""))
		if not is_rescued(data, id):
			out.append(id)
	return out


static func rescue(data: Dictionary, crew_id: String) -> bool:
	if crew_id == "":
		return false
	(_section(data)["rescued"] as Dictionary)[crew_id] = true
	return true


static func crew_at(data: Dictionary, building_id: String) -> String:
	var raw: Variant = data.get("crew", {})
	var section: Dictionary = raw if raw is Dictionary else {}
	return String((section.get("assignments", {}) as Dictionary).get(building_id, ""))


static func building_of(data: Dictionary, crew_id: String) -> String:
	var raw: Variant = data.get("crew", {})
	var section: Dictionary = raw if raw is Dictionary else {}
	var assignments: Dictionary = section.get("assignments", {})
	for building in assignments:
		if String(assignments[building]) == crew_id:
			return String(building)
	return ""


static func assign(data: Dictionary, defs: Dictionary, building_id: String, crew_id: String, building_defs: Dictionary = {}, now: int = 0) -> bool:
	if crew_id == "" or not is_rescued(data, crew_id):
		return false
	if not workable(defs).has(building_id):
		return false
	var pending_before := TrickleModel.pending(data, building_defs, now, defs)
	var mult_before := multiplier_for(data, defs, "gardens")
	var assignments: Dictionary = _section(data)["assignments"]
	var previous := building_of(data, crew_id)
	if previous != "":
		assignments.erase(previous)
	assignments[building_id] = crew_id
	_rebase_trickle(data, defs, building_defs, now, pending_before, mult_before)
	return true


static func unassign(data: Dictionary, defs: Dictionary, building_id: String, building_defs: Dictionary = {}, now: int = 0) -> void:
	var pending_before := TrickleModel.pending(data, building_defs, now, defs)
	var mult_before := multiplier_for(data, defs, "gardens")
	(_section(data)["assignments"] as Dictionary).erase(building_id)
	_rebase_trickle(data, defs, building_defs, now, pending_before, mult_before)


static func multiplier_for(data: Dictionary, defs: Dictionary, building_id: String) -> float:
	if defs.is_empty():
		return 1.0
	var crew_id := crew_at(data, building_id)
	if crew_id == "":
		return 1.0
	var member := entry(defs, crew_id)
	if String(member.get("specialty", "")) == building_id:
		return float(member.get("bonus", 1.5))
	return float(defs.get("generalist_bonus", 1.25))


static func _rebase_trickle(data: Dictionary, defs: Dictionary, building_defs: Dictionary, now: int, pending_before: int, mult_before: float) -> void:
	# An assignment flip must not re-rate scrap already accrued (same rule as
	# the gardens-upgrade rebase in IslandModel.complete_build). Only a real
	# gardens-rate change rebases, so unrelated moves leave the clock alone.
	if building_defs.is_empty():
		return
	if is_equal_approx(multiplier_for(data, defs, "gardens"), mult_before):
		return
	var rate := TrickleModel.rate_per_hour(data, building_defs, defs)
	if rate <= 0.0:
		return
	(data.get("trickle", {}) as Dictionary)["last_collect"] = now - int(float(pending_before) * 3600.0 / rate)
