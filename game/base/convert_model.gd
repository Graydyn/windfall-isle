class_name ConvertModel
## Timed conversion batches (chains spec section 6; recipe addressing per the
## run-kit spec section 3): a built building carries recipes; a batch pays one
## recipe's inputs up front, runs a TimerService timer of kind "convert"
## (id convert_<building>, ONE batch per building regardless of recipe), and
## credits that recipe's outputs at collect, scaled by the building's level at
## collect time. Crew speed divides the duration through CrewModel.


static func recipes(building_defs: Dictionary, building_id: String) -> Array:
	var def: Dictionary = (building_defs.get("defs", {}) as Dictionary).get(building_id, {})
	var raw: Variant = def.get("recipes", [])
	return raw if raw is Array else []


static func recipe_by_id(building_defs: Dictionary, building_id: String, recipe_id: String) -> Dictionary:
	for row_v in recipes(building_defs, building_id):
		var row := row_v as Dictionary
		if String(row.get("id", "")) == recipe_id:
			return row
	return {}


static func outputs_for(building_defs: Dictionary, island: Dictionary, building_id: String, recipe_id: String) -> Dictionary:
	var level := IslandModel.building_level(island, building_id)
	var base: Dictionary = recipe_by_id(building_defs, building_id, recipe_id).get("outputs", {})
	if level <= 0 or base.is_empty():
		return {}
	var out := {}
	for currency in base:
		out[currency] = int(base[currency]) * level
	return out


static func can_start(data: Dictionary, building_defs: Dictionary, economy: Node, timers: Node, building_id: String, recipe_id: String) -> bool:
	var conversion := recipe_by_id(building_defs, building_id, recipe_id)
	if conversion.is_empty():
		return false
	if IslandModel.building_level(data.get("island", {}), building_id) <= 0:
		return false
	if timers.active_timers().has("convert_" + building_id):
		return false
	return economy.can_afford(conversion.get("inputs", {}))


static func start_batch(data: Dictionary, building_defs: Dictionary, economy: Node, timers: Node, building_id: String, recipe_id: String, now: int, crew_defs: Dictionary = {}) -> bool:
	if not can_start(data, building_defs, economy, timers, building_id, recipe_id):
		return false
	var conversion := recipe_by_id(building_defs, building_id, recipe_id)
	if not economy.pay(conversion.get("inputs", {})):
		return false
	# The worker's speed is priced into the duration at START and locked in
	# ends_at, same rule as crafts (crew spec section 5).
	var duration := maxi(1, ceili(float(conversion.get("seconds", 600)) / CrewModel.multiplier_for(data, crew_defs, building_id)))
	return timers.start("convert_" + building_id, "convert", duration, now, {"building": building_id, "recipe": recipe_id})


static func complete_batch(data: Dictionary, building_defs: Dictionary, economy: Node, payload: Dictionary) -> void:
	var building_id := String(payload.get("building", ""))
	if building_id == "":
		return
	var recipe_id := String(payload.get("recipe", ""))
	if recipe_id == "":
		# Legacy fallback: a Plan 11 save's in-flight batch has no recipe in
		# its payload; a single-recipe building is unambiguous, so credit it.
		# On a multi-recipe building a recipe-less payload stays a no-op.
		var rows := recipes(building_defs, building_id)
		if rows.size() == 1:
			recipe_id = String((rows[0] as Dictionary).get("id", ""))
	if recipe_id == "":
		return
	var outputs := outputs_for(building_defs, data.get("island", {}), building_id, recipe_id)
	for currency in outputs:
		economy.add(String(currency), int(outputs[currency]))
