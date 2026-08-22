class_name IsletModel
## Pure restoration rules over save.islets (spec 4.4): islets restore in
## islets.json array order, one restoration at a time, riding TimerService
## kind "restoration" with id "restore_<islet_id>" so a bridge repair never
## consumes a build slot. Vignette text stays in the defs; the save stores
## only flags.


static func islets(defs: Dictionary) -> Array:
	return defs.get("islets", [])


static func entry(defs: Dictionary, islet_id: String) -> Dictionary:
	for row_v in islets(defs):
		var row := row_v as Dictionary
		if String(row.get("id", "")) == islet_id:
			return row
	return {}


static func is_restored(data: Dictionary, islet_id: String) -> bool:
	var section: Dictionary = data.get("islets", {}) if data.get("islets", {}) is Dictionary else {}
	return bool((section.get("restored", {}) as Dictionary).get(islet_id, false))


static func open_plots(data: Dictionary, defs: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for row_v in islets(defs):
		var row := row_v as Dictionary
		if is_restored(data, String(row.get("id", ""))):
			for plot in row.get("plots", []):
				out.append(String(plot))
	return out


static func islet_of_plot(defs: Dictionary, plot: String) -> String:
	for row_v in islets(defs):
		var row := row_v as Dictionary
		for candidate in row.get("plots", []):
			if String(candidate) == plot:
				return String(row.get("id", ""))
	return ""


static func active_restoration(timers: Node) -> String:
	for id in timers.active_timers():
		if String((timers.active_timers()[id] as Dictionary).get("kind", "")) == "restoration":
			return String(id)
	return ""


static func next_offered(data: Dictionary, defs: Dictionary) -> String:
	for row_v in islets(defs):
		var row := row_v as Dictionary
		var id := String(row.get("id", ""))
		if not is_restored(data, id):
			return id
	return ""


static func restore_rejection(data: Dictionary, defs: Dictionary, economy: Node, timers: Node, islet_id: String) -> String:
	# "" means startable; anything else is a short player-facing reason.
	var def := entry(defs, islet_id)
	if def.is_empty():
		return "There is no such islet."
	if is_restored(data, islet_id):
		return "%s is already restored." % String(def.get("name", islet_id))
	if islet_id != next_offered(data, defs):
		return "Another islet must be restored first."
	if active_restoration(timers) != "":
		return "A restoration is already underway."
	if not economy.can_afford(def.get("cost", {})):
		return "Not enough resources."
	return ""


static func start_restore(data: Dictionary, defs: Dictionary, economy: Node, timers: Node, islet_id: String, now: int) -> bool:
	if restore_rejection(data, defs, economy, timers, islet_id) != "":
		return false
	var def := entry(defs, islet_id)
	if not economy.pay(def.get("cost", {})):
		return false
	return timers.start("restore_" + islet_id, "restoration", int(def.get("restore_seconds", 3600)), now,
		{"islet": islet_id})


static func complete_restore(data: Dictionary, payload: Dictionary) -> void:
	var islet_id := String(payload.get("islet", ""))
	if islet_id == "":
		return
	# Write-back discipline: heal a missing or wrong-typed section in place so
	# the flag can never land in a detached dict.
	if not data.has("islets") or not (data["islets"] is Dictionary):
		data["islets"] = {"restored": {}, "letters_seen": {}}
	var section: Dictionary = data["islets"]
	if not section.has("restored") or not (section["restored"] is Dictionary):
		section["restored"] = {}
	(section["restored"] as Dictionary)[islet_id] = true


static func duplicate_plot_ids(defs: Dictionary) -> Array:
	# Authoring guard for islet 3+ (mirrors Skyfield.duplicate_barge_ids).
	var seen := {}
	var dupes := {}
	for row_v in islets(defs):
		var row := row_v as Dictionary
		for plot in row.get("plots", []):
			if seen.has(String(plot)):
				dupes[String(plot)] = true
			seen[String(plot)] = true
	return dupes.keys()
