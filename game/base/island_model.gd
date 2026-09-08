class_name IslandModel
## Pure construction rules over save.island (spec 4.1): plots hold buildings,
## build SLOTS cap concurrent constructions (one free, second via crystals),
## costs and durations come from buildings.json level rows. Timers ride
## TimerService kind "construction" with id "build_<plot>".


static func building_level(island: Dictionary, building_id: String) -> int:
	for plot in island.get("plots", {}):
		var entry: Dictionary = island["plots"][plot]
		if String(entry.get("building", "")) == building_id:
			return int(entry.get("level", 0))
	return 0


static func plot_of(island: Dictionary, building_id: String) -> String:
	for plot in island.get("plots", {}):
		if String((island["plots"][plot] as Dictionary).get("building", "")) == building_id:
			return String(plot)
	return ""


static func active_constructions(timers: Node, _now: int) -> int:
	var count := 0
	for id in timers.active_timers():
		if String((timers.active_timers()[id] as Dictionary).get("kind", "")) == "construction":
			count += 1
	return count


static func _next_level_row(defs: Dictionary, island: Dictionary, plot: String, building_id: String) -> Dictionary:
	var def: Dictionary = (defs.get("defs", {}) as Dictionary).get(building_id, {})
	if def.is_empty():
		return {}
	var plots: Dictionary = island.get("plots", {})
	var current := 0
	if plots.has(plot):
		var entry: Dictionary = plots[plot]
		if String(entry.get("building", "")) != building_id:
			return {}
		current = int(entry.get("level", 0))
	elif plot_of(island, building_id) != "":
		return {}
	if current >= int(def.get("max_level", 1)):
		return {}
	var rows: Array = def.get("levels", [])
	if current >= rows.size():
		return {}
	return rows[current]


static func placement_rejection(defs: Dictionary, islet_defs: Dictionary, islets_state: Dictionary, plot: String, building_id: String) -> String:
	# Islet buildings live only on their islet's restored plots; home buildings
	# never leave the home island (spec 4.4). "" means placement is fine.
	var def: Dictionary = (defs.get("defs", {}) as Dictionary).get(building_id, {})
	var home_islet := String(def.get("islet", ""))
	var plot_islet := IsletModel.islet_of_plot(islet_defs, plot)
	if home_islet == "" and plot_islet == "":
		return ""
	if home_islet == "":
		return "This plot awaits its own building."
	if plot_islet != home_islet:
		var islet_name := String(IsletModel.entry(islet_defs, home_islet).get("name", home_islet))
		return "%s belongs on %s." % [String(def.get("name", building_id)), islet_name]
	if not bool((islets_state.get("restored", {}) as Dictionary).get(home_islet, false)):
		return "Restore the bridge first."
	return ""


static func build_rejection(island: Dictionary, defs: Dictionary, economy: Node, timers: Node, plot: String, building_id: String, now: int, islet_defs: Dictionary = {}, islets_state: Dictionary = {}) -> String:
	# "" means buildable; anything else is a short player-facing reason
	# (Plan 5 polish: a rejected Build tap must say why).
	if timers.active_timers().has("build_" + plot):
		return "This plot is already under construction."
	if active_constructions(timers, now) >= int(island.get("build_slots", 1)):
		return "All build slots are busy."
	var placement := placement_rejection(defs, islet_defs, islets_state, plot, building_id)
	if placement != "":
		return placement
	var row := _next_level_row(defs, island, plot, building_id)
	if row.is_empty():
		return "%s cannot be built here." % building_id
	if not economy.can_afford(row.get("cost", {})):
		return "Not enough resources."
	return ""


static func can_start_build(island: Dictionary, defs: Dictionary, economy: Node, timers: Node, plot: String, building_id: String, now: int, islet_defs: Dictionary = {}, islets_state: Dictionary = {}) -> bool:
	return build_rejection(island, defs, economy, timers, plot, building_id, now, islet_defs, islets_state) == ""


static func start_build(island: Dictionary, defs: Dictionary, economy: Node, timers: Node, plot: String, building_id: String, now: int, islet_defs: Dictionary = {}, islets_state: Dictionary = {}) -> bool:
	if not can_start_build(island, defs, economy, timers, plot, building_id, now, islet_defs, islets_state):
		return false
	var row := _next_level_row(defs, island, plot, building_id)
	if not economy.pay(row.get("cost", {})):
		return false
	var plots: Dictionary = island.get("plots", {})
	if not plots.has(plot):
		plots[plot] = {"building": building_id, "level": 0}
	var to_level := int((plots[plot] as Dictionary).get("level", 0)) + 1
	return timers.start("build_" + plot, "construction", int(row.get("build_seconds", 60)), now,
		{"plot": plot, "building": building_id, "to_level": to_level})


static func complete_build(island: Dictionary, payload: Dictionary, data: Dictionary, now: int, building_defs: Dictionary = {}, crew_defs: Dictionary = {}) -> void:
	if payload.is_empty():
		return
	var plot := String(payload.get("plot", ""))
	var building_id := String(payload.get("building", ""))
	var plots: Dictionary = island.get("plots", {})
	if not plots.has(plot):
		return
	if building_id == "gardens":
		var to_level := int(payload.get("to_level", 1))
		if to_level == 1:
			plots[plot]["level"] = to_level
			(data.get("trickle", {}) as Dictionary)["last_collect"] = now
		elif not building_defs.is_empty():
			# Rebase at the new rate so the pending VALUE carries over (spec
			# 4.1 retention finding), priced at the crewed rate when crew defs
			# are provided; the shared helper owns the relocation math.
			var pending_old := TrickleModel.pending(data, building_defs, now, crew_defs)
			plots[plot]["level"] = to_level
			TrickleModel.rebase_preserving(data, building_defs, crew_defs, now, pending_old)
		else:
			plots[plot]["level"] = to_level
	else:
		plots[plot]["level"] = int(payload.get("to_level", 1))


static func unlock_second_slot(island: Dictionary, defs: Dictionary, economy: Node) -> bool:
	var slots_cfg: Dictionary = defs.get("build_slots", {})
	if int(island.get("build_slots", 1)) >= int(slots_cfg.get("max", 2)):
		return false
	if not economy.pay({"crystals": int(slots_cfg.get("second_slot_crystal_cost", 20))}):
		return false
	island["build_slots"] = int(island.get("build_slots", 1)) + 1
	return true
