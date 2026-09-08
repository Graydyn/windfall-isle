class_name ConvertModel
## Timed conversion batches (chains spec section 6): a built building with a
## recipe pays the inputs up front, runs a TimerService timer of kind
## "convert" (id convert_<building>), and credits the outputs at collect,
## scaled by the building's level at collect time. One batch per building.
## Crew speed divides the duration through CrewModel.multiplier_for.


static func recipe(building_defs: Dictionary, building_id: String) -> Dictionary:
	var def: Dictionary = (building_defs.get("defs", {}) as Dictionary).get(building_id, {})
	var raw: Variant = def.get("recipe", {})
	return raw if raw is Dictionary else {}


static func outputs_for(building_defs: Dictionary, island: Dictionary, building_id: String) -> Dictionary:
	var level := IslandModel.building_level(island, building_id)
	var base: Dictionary = recipe(building_defs, building_id).get("outputs", {})
	if level <= 0 or base.is_empty():
		return {}
	var out := {}
	for currency in base:
		out[currency] = int(base[currency]) * level
	return out


static func can_start(data: Dictionary, building_defs: Dictionary, economy: Node, timers: Node, building_id: String) -> bool:
	var conversion := recipe(building_defs, building_id)
	if conversion.is_empty():
		return false
	if IslandModel.building_level(data.get("island", {}), building_id) <= 0:
		return false
	if timers.active_timers().has("convert_" + building_id):
		return false
	return economy.can_afford(conversion.get("inputs", {}))


static func start_batch(data: Dictionary, building_defs: Dictionary, economy: Node, timers: Node, building_id: String, now: int, crew_defs: Dictionary = {}) -> bool:
	if not can_start(data, building_defs, economy, timers, building_id):
		return false
	var conversion := recipe(building_defs, building_id)
	if not economy.pay(conversion.get("inputs", {})):
		return false
	# The worker's speed is priced into the duration at START and locked in
	# ends_at, same rule as crafts (crew spec section 5).
	var duration := maxi(1, ceili(float(conversion.get("seconds", 600)) / CrewModel.multiplier_for(data, crew_defs, building_id)))
	return timers.start("convert_" + building_id, "convert", duration, now, {"building": building_id})


static func complete_batch(data: Dictionary, building_defs: Dictionary, economy: Node, payload: Dictionary) -> void:
	var building_id := String(payload.get("building", ""))
	if building_id == "":
		return
	var outputs := outputs_for(building_defs, data.get("island", {}), building_id)
	for currency in outputs:
		economy.add(String(currency), int(outputs[currency]))
