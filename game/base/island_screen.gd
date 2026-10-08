extends Control
## The home island (spec 4.1): plots, timed construction, upgrades, and the
## retention controls (trickle, crates, build slot, rewarded-ad accelerators).
## Dumb UI: every rule lives in IslandModel; this screen renders state and
## forwards taps.
##
## Refresh discipline: RefreshTimer ticks call _refresh_tick, which rebuilds
## the row tree ONLY when the structural signature changes (a timer starting,
## finishing, or disappearing); otherwise labels update in place so a button
## mid-tap is never freed under the player's finger.

var _last_signature := ""
var _modal_plot := ""
var _modal_ids: Array[String] = []
var _modal_index := 0
var _plot_labels: Dictionary = {}
var _islet_labels: Dictionary = {}
var _letter_islet := ""

@onready var rows: VBoxContainer = $Rows


func _ready() -> void:
	$WorkshopButton.pressed.connect(_on_workshop_pressed)
	$BackButton.pressed.connect(_on_back_pressed)
	$RefreshTimer.timeout.connect(_refresh_tick)
	$GardensButton.pressed.connect(_on_gardens_pressed)
	$CrateButton.pressed.connect(_on_crate_pressed)
	$SlotButton.pressed.connect(_on_slot_pressed)
	$BonusCrateButton.pressed.connect(_on_bonus_crate_pressed)
	$LetterPanel/VBox/LetterClose.pressed.connect(_on_letter_close_pressed)
	$BuildModal/VBox/NavRow/PrevButton.pressed.connect(_on_modal_prev_pressed)
	$BuildModal/VBox/NavRow/NextButton.pressed.connect(_on_modal_next_pressed)
	$BuildModal/VBox/ActionRow/ConfirmButton.pressed.connect(_on_modal_confirm_pressed)
	$BuildModal/VBox/ActionRow/CancelButton.pressed.connect(_on_modal_cancel_pressed)
	_rebuild()


func _plot_ids() -> Array[String]:
	var ids: Array[String] = []
	for i in int(DataDefs.buildings.get("plot_count", 6)):
		ids.append("plot_%d" % i)
	ids.append_array(IsletModel.open_plots(GameState.data, DataDefs.islets))
	return ids


func _unbuilt_ids(plot: String) -> Array[String]:
	# A home plot offers home buildings; an islet plot offers exactly its
	# islet's buildings (spec 4.4).
	var plot_islet := IsletModel.islet_of_plot(DataDefs.islets, plot)
	var ids: Array[String] = []
	for id in DataDefs.buildings.get("defs", {}):
		var def: Dictionary = (DataDefs.buildings["defs"] as Dictionary)[id]
		if String(def.get("islet", "")) != plot_islet:
			continue
		if IslandModel.building_level(GameState.data["island"], String(id)) == 0 \
				and IslandModel.plot_of(GameState.data["island"], String(id)) == "":
			ids.append(String(id))
	return ids


func _signature(now: int) -> String:
	var parts := PackedStringArray()
	for plot in _plot_ids():
		var timer_id := "build_" + plot
		if TimerService.active_timers().has(timer_id):
			parts.append("d" if TimerService.is_done(timer_id, now) else "r")
		else:
			parts.append("i")
	for row_v in IsletModel.islets(DataDefs.islets):
		parts.append(_islet_state(String((row_v as Dictionary).get("id", "")), now))
	for row_v in CrewModel.members(DataDefs.crew):
		var crew_id := String((row_v as Dictionary).get("id", ""))
		if not CrewModel.is_rescued(GameState.data, crew_id):
			parts.append("u")
		else:
			parts.append("@" + CrewModel.building_of(GameState.data, crew_id))
	for id in DataDefs.buildings.get("defs", {}):
		if not ((DataDefs.buildings["defs"] as Dictionary)[id] as Dictionary).has("recipes"):
			continue
		var convert_id := "convert_" + String(id)
		if TimerService.active_timers().has(convert_id):
			parts.append("cd" if TimerService.is_done(convert_id, now) else "cr")
		else:
			parts.append("ci")
	return ",".join(parts)


func _islet_state(islet_id: String, now: int) -> String:
	# One char per islet: R restored, r restoring, d done-uncollected,
	# o offered, L locked behind an earlier islet. All five are structural.
	if IsletModel.is_restored(GameState.data, islet_id):
		return "R"
	var timer_id := "restore_" + islet_id
	if TimerService.active_timers().has(timer_id):
		return "d" if TimerService.is_done(timer_id, now) else "r"
	return "o" if IsletModel.next_offered(GameState.data, DataDefs.islets) == islet_id else "L"


func _refresh_tick() -> void:
	var now := TimeUtil.now()
	if _signature(now) != _last_signature:
		_rebuild()
		return
	_refresh_labels(now)


func _refresh_labels(now: int) -> void:
	var island: Dictionary = GameState.data["island"]
	for plot in _plot_labels:
		var label: Label = _plot_labels[plot]
		if is_instance_valid(label):
			label.text = _row_text(String(plot), island, now)
	for islet_id in _islet_labels:
		var islet_label: Label = _islet_labels[islet_id]
		if is_instance_valid(islet_label):
			islet_label.text = _islet_row_text(IsletModel.entry(DataDefs.islets, String(islet_id)), now)
	_refresh_static_controls(now)


func _rebuild() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	_plot_labels.clear()
	_islet_labels.clear()
	var now := TimeUtil.now()
	_last_signature = _signature(now)
	var island: Dictionary = GameState.data["island"]
	for plot in _plot_ids():
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 64)
		var label := Label.new()
		label.custom_minimum_size = Vector2(320, 0)
		label.text = _row_text(plot, island, now)
		row.add_child(label)
		_plot_labels[plot] = label
		var timer_id := "build_" + plot
		if TimerService.active_timers().has(timer_id):
			if TimerService.is_done(timer_id, now):
				var collect := Button.new()
				collect.text = "Complete!"
				collect.pressed.connect(_on_collect_pressed.bind(plot))
				row.add_child(collect)
			elif Ads.service.is_available(AdService.Placement.TIMER_SKIP):
				var skip := Button.new()
				skip.text = "Skip (ad)"
				skip.pressed.connect(_on_skip_pressed.bind(timer_id))
				row.add_child(skip)
		else:
			var choose := Button.new()
			choose.text = "Upgrade" if island.get("plots", {}).has(plot) else "Choose..."
			choose.pressed.connect(_open_build_modal.bind(plot))
			row.add_child(choose)
		var occupant := ""
		if island.get("plots", {}).has(plot):
			occupant = String((island["plots"][plot] as Dictionary).get("building", ""))
		if occupant != "" and not ConvertModel.recipes(DataDefs.buildings, occupant).is_empty():
			var convert_id := "convert_" + occupant
			if TimerService.active_timers().has(convert_id):
				if TimerService.is_done(convert_id, now):
					var done_payload: Dictionary = (TimerService.active_timers()[convert_id] as Dictionary).get("payload", {})
					var done_outputs := ConvertModel.outputs_for(DataDefs.buildings, island, occupant, String(done_payload.get("recipe", "")))
					var batch := Button.new()
					batch.text = "Collect (%s)" % _cost_text(done_outputs) if not done_outputs.is_empty() else "Collect"
					batch.pressed.connect(_on_batch_collect_pressed.bind(occupant))
					row.add_child(batch)
			else:
				for recipe_v in ConvertModel.recipes(DataDefs.buildings, occupant):
					var recipe_id := String((recipe_v as Dictionary).get("id", ""))
					var start_batch := Button.new()
					start_batch.text = _batch_button_text(occupant, recipe_id)
					start_batch.disabled = not ConvertModel.can_start(GameState.data, DataDefs.buildings, Economy, TimerService, occupant, recipe_id)
					start_batch.pressed.connect(_on_batch_start_pressed.bind(occupant, recipe_id))
					row.add_child(start_batch)
		rows.add_child(row)
	for row_v in IsletModel.islets(DataDefs.islets):
		var islet := row_v as Dictionary
		var islet_id := String(islet.get("id", ""))
		var islet_row := HBoxContainer.new()
		islet_row.custom_minimum_size = Vector2(0, 64)
		var islet_art := "res://game/art/buildings/islet_%s_%s.png" % [
			islet_id, "restored" if IsletModel.is_restored(GameState.data, islet_id) else "ruined"]
		if ResourceLoader.exists(islet_art):
			var thumb := TextureRect.new()
			thumb.texture = load(islet_art)
			thumb.custom_minimum_size = Vector2(56, 56)
			thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			islet_row.add_child(thumb)
		var islet_label := Label.new()
		islet_label.custom_minimum_size = Vector2(320, 0)
		islet_label.text = _islet_row_text(islet, now)
		islet_row.add_child(islet_label)
		_islet_labels[islet_id] = islet_label
		match _islet_state(islet_id, now):
			"o":
				var restore := Button.new()
				restore.text = "Restore"
				restore.pressed.connect(_on_restore_pressed.bind(islet_id))
				islet_row.add_child(restore)
			"d":
				var cross := Button.new()
				cross.text = "Cross over!"
				cross.pressed.connect(_on_restore_collect_pressed.bind(islet_id))
				islet_row.add_child(cross)
			"R":
				var read := Button.new()
				read.text = "Read letter"
				read.pressed.connect(_on_read_letter_pressed.bind(islet_id))
				islet_row.add_child(read)
		rows.add_child(islet_row)
	for row_v in CrewModel.members(DataDefs.crew):
		var member := row_v as Dictionary
		var member_id := String(member.get("id", ""))
		var crew_row := HBoxContainer.new()
		crew_row.custom_minimum_size = Vector2(0, 56)
		var portrait_path := "res://game/art/crew/%s.png" % member_id
		var portrait: TextureRect = null
		if ResourceLoader.exists(portrait_path):
			portrait = TextureRect.new()
			portrait.texture = load(portrait_path)
			portrait.custom_minimum_size = Vector2(48, 48)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			crew_row.add_child(portrait)
		var crew_label := Label.new()
		crew_label.custom_minimum_size = Vector2(320, 0)
		crew_label.text = _crew_row_text(member)
		crew_row.add_child(crew_label)
		if CrewModel.is_rescued(GameState.data, member_id):
			var assign_button := Button.new()
			assign_button.text = _assign_text(member_id)
			assign_button.pressed.connect(_on_assign_pressed.bind(member_id))
			crew_row.add_child(assign_button)
		else:
			crew_label.modulate.a = 0.5
			if portrait != null:
				portrait.modulate.a = 0.5
		rows.add_child(crew_row)
	_refresh_static_controls(now)


func _refresh_static_controls(now: int) -> void:
	var pending := TrickleModel.pending(GameState.data, DataDefs.buildings, now, DataDefs.crew)
	$GardensButton.text = "Collect trickle (%d scrap)" % pending
	$GardensButton.disabled = pending <= 0
	$CrateButton.disabled = not DailyCrate.can_claim(GameState.data, now)
	$CrateButton.text = "Open daily crate" if not $CrateButton.disabled else "Crate opened today"
	var slots_cfg: Dictionary = DataDefs.buildings.get("build_slots", {})
	var slot_cost := int(slots_cfg.get("second_slot_crystal_cost", 20))
	$SlotButton.visible = int(GameState.data["island"].get("build_slots", 1)) < int(slots_cfg.get("max", 2))
	$SlotButton.text = "Unlock 2nd build slot (%d crystals)" % slot_cost
	$SlotButton.disabled = not Economy.can_afford({"crystals": slot_cost})
	$BonusCrateButton.visible = Ads.service.is_available(AdService.Placement.BONUS_CRATE)
	$BonusCrateButton.disabled = not AdLimits.can_use(GameState.data, "bonus_crate", _bonus_crate_limit(), now)


func _row_text(plot: String, island: Dictionary, now: int) -> String:
	var timer_id := "build_" + plot
	var plots: Dictionary = island.get("plots", {})
	if TimerService.active_timers().has(timer_id):
		var payload: Dictionary = TimerService.active_timers()[timer_id].get("payload", {})
		var remaining := TimerService.remaining(timer_id, now)
		return "%s: building %s (%ds)" % [plot, String(payload.get("building", "?")), remaining]
	if plots.has(plot):
		var entry: Dictionary = plots[plot]
		var def: Dictionary = (DataDefs.buildings["defs"] as Dictionary).get(String(entry["building"]), {})
		var text := "%s: %s Lv %d" % [plot, String(def.get("name", entry["building"])), int(entry["level"])]
		var worker := CrewModel.crew_at(GameState.data, String(entry["building"]))
		if worker != "":
			text += ", %s working" % String(CrewModel.entry(DataDefs.crew, worker).get("name", worker))
		var convert_id := "convert_" + String(entry["building"])
		if TimerService.active_timers().has(convert_id) and not TimerService.is_done(convert_id, now):
			text += "  (batch %ds)" % TimerService.remaining(convert_id, now)
		if String(entry["building"]) == "observatory" and int(entry["level"]) >= 1:
			text += "\n    %s" % String(def.get("teaser", ""))
		return text
	return "%s: (empty)" % plot


func _open_build_modal(plot: String) -> void:
	# The build browser (owner request, 2026-09-09): an empty plot browses its
	# candidates; an occupied plot opens locked on its own building for the
	# upgrade. Confirm routes through IslandModel like the old Build button.
	var plots: Dictionary = GameState.data["island"].get("plots", {})
	_modal_plot = plot
	if plots.has(plot):
		var held: Array[String] = [String((plots[plot] as Dictionary).get("building", ""))]
		_modal_ids = held
	else:
		_modal_ids = _unbuilt_ids(plot)
	if _modal_ids.is_empty():
		return
	_modal_index = 0
	$BuildModal/VBox/ModalStatus.text = ""
	_render_modal()
	$BuildModal.visible = true


func _modal_building() -> String:
	if _modal_ids.is_empty():
		return ""
	return String(_modal_ids[_modal_index])


func _render_modal() -> void:
	var building_id := _modal_building()
	var def: Dictionary = (DataDefs.buildings.get("defs", {}) as Dictionary).get(building_id, {})
	var display := String(def.get("name", building_id))
	$BuildModal/VBox/ModalTitle.text = display
	# Building illustration (audit 4.2); the lettered placeholder only remains
	# as the fallback for a building without delivered art.
	var art_path := "res://game/art/buildings/%s.png" % building_id
	if ResourceLoader.exists(art_path):
		$BuildModal/VBox/ModalPicture.texture = load(art_path)
		$BuildModal/VBox/ModalPicture/PictureLetter.text = ""
	else:
		$BuildModal/VBox/ModalPicture.texture = null
		$BuildModal/VBox/ModalPicture/PictureLetter.text = display.left(1)
	$BuildModal/VBox/ModalFlavor.text = String(def.get("flavor", ""))
	$BuildModal/VBox/ModalDescription.text = String(def.get("description", ""))
	var stats := _stats_text(building_id, def)
	$BuildModal/VBox/ModalStats.text = stats
	$BuildModal/VBox/ModalStats.visible = stats != ""
	$BuildModal/VBox/NavRow.visible = _modal_ids.size() > 1
	var level := IslandModel.building_level(GameState.data["island"], building_id)
	var level_rows: Array = def.get("levels", [])
	if level >= int(def.get("max_level", 1)) or level >= level_rows.size():
		$BuildModal/VBox/ModalCost.text = "Max level reached"
		$BuildModal/VBox/ActionRow/ConfirmButton.text = "Max level"
		$BuildModal/VBox/ActionRow/ConfirmButton.disabled = true
		return
	var next_row: Dictionary = level_rows[level]
	$BuildModal/VBox/ModalCost.text = "Cost: %s" % _cost_text(next_row.get("cost", {}))
	$BuildModal/VBox/ActionRow/ConfirmButton.text = ("Upgrade to Lv %d" % (level + 1)) if level > 0 else "Build"
	$BuildModal/VBox/ActionRow/ConfirmButton.disabled = false


func _stats_text(building_id: String, def: Dictionary) -> String:
	# Concrete numbers straight from the def (owner request, 2026-09-11): the
	# line can never drift from the data because it IS the data. Buildings
	# whose whole effect is narrative (observatory, dock) return "".
	var lines := PackedStringArray()
	if building_id == "workshop":
		lines.append("• 1 craft slot per level")
	if def.has("fuel_cap_bonus_per_level"):
		lines.append("• +%d fuel cap per level" % int(def["fuel_cap_bonus_per_level"]))
	if def.has("regen_delta_per_level"):
		lines.append("• %ds faster fuel regen per level" % absi(int(def["regen_delta_per_level"])))
	if def.has("drops_bonus_per_level"):
		lines.append("• +%d pod drop per run per level" % int(def["drops_bonus_per_level"]))
	if def.has("scrap_per_hour_per_level"):
		lines.append("• %d scrap per hour per level, banks up to %dh" % [
			int(def["scrap_per_hour_per_level"]), int(def.get("cap_hours", 8.0))])
	if def.has("payout_bonus_per_level"):
		lines.append("• +%d%% expedition payout per level" % roundi(float(def["payout_bonus_per_level"]) * 100.0))
	var recipe_rows: Array = def.get("recipes", [])
	for row_v in recipe_rows:
		var conversion := row_v as Dictionary
		var inputs: Dictionary = conversion.get("inputs", {})
		var input_text := _cost_text(inputs) if not inputs.is_empty() else "free"
		lines.append("• Makes: %s (%s -> %s, %dm)" % [
			String(conversion.get("name", conversion.get("id", ""))),
			input_text,
			_cost_text(conversion.get("outputs", {})),
			int(float(conversion.get("seconds", 600)) / 60.0),
		])
	if not recipe_rows.is_empty():
		lines.append("• Batch outputs scale with building level")
	return "\n".join(lines)


func _on_modal_prev_pressed() -> void:
	if _modal_ids.size() <= 1:
		return
	_modal_index = (_modal_index - 1 + _modal_ids.size()) % _modal_ids.size()
	$BuildModal/VBox/ModalStatus.text = ""
	_render_modal()


func _on_modal_next_pressed() -> void:
	if _modal_ids.size() <= 1:
		return
	_modal_index = (_modal_index + 1) % _modal_ids.size()
	$BuildModal/VBox/ModalStatus.text = ""
	_render_modal()


func _on_modal_confirm_pressed() -> void:
	var building_id := _modal_building()
	if building_id == "" or not $BuildModal.visible:
		return
	var island: Dictionary = GameState.data["island"]
	var now := TimeUtil.now()
	var reason := IslandModel.build_rejection(island, DataDefs.buildings, Economy, TimerService, _modal_plot, building_id, now, DataDefs.islets, GameState.data.get("islets", {}))
	if reason != "":
		# Rejections live in the modal so the player sees them beside the card.
		$BuildModal/VBox/ModalStatus.text = reason
		return
	if IslandModel.start_build(island, DataDefs.buildings, Economy, TimerService, _modal_plot, building_id, now, DataDefs.islets, GameState.data.get("islets", {})):
		GameState.save_game()
	$BuildModal.visible = false
	_rebuild()


func _on_modal_cancel_pressed() -> void:
	$BuildModal.visible = false


func _islet_row_text(islet: Dictionary, now: int) -> String:
	var islet_id := String(islet.get("id", ""))
	var islet_name := String(islet.get("name", islet_id))
	match _islet_state(islet_id, now):
		"R":
			return "%s: restored" % islet_name
		"r":
			return "%s: restoring (%ds)" % [islet_name, TimerService.remaining("restore_" + islet_id, now)]
		"d":
			return "%s: the bridge is ready" % islet_name
		"o":
			return "%s: %s" % [islet_name, _cost_text(islet.get("cost", {}))]
	return "%s: beyond a broken bridge" % islet_name


func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for currency in cost:
		parts.append("%d %s" % [int(cost[currency]), String(currency)])
	return ", ".join(parts)


func _crew_row_text(member: Dictionary) -> String:
	var member_id := String(member.get("id", ""))
	if not CrewModel.is_rescued(GameState.data, member_id):
		return "Someone is still out there..."
	var specialty := String(member.get("specialty", ""))
	var def: Dictionary = (DataDefs.buildings.get("defs", {}) as Dictionary).get(specialty, {})
	return "%s (knows the %s)" % [String(member.get("name", member_id)), String(def.get("name", specialty))]


func _assign_text(crew_id: String) -> String:
	var building := CrewModel.building_of(GameState.data, crew_id)
	if building == "":
		return "Assign: (idle)"
	var def: Dictionary = (DataDefs.buildings.get("defs", {}) as Dictionary).get(building, {})
	return "Assign: %s" % String(def.get("name", building))


func _batch_button_text(building_id: String, recipe_id: String) -> String:
	var conversion := ConvertModel.recipe_by_id(DataDefs.buildings, building_id, recipe_id)
	var inputs: Dictionary = conversion.get("inputs", {})
	var display := String(conversion.get("name", recipe_id))
	if inputs.is_empty():
		return display
	return "%s (%s)" % [display, _cost_text(inputs)]


func _on_batch_start_pressed(building_id: String, recipe_id: String) -> void:
	if ConvertModel.start_batch(GameState.data, DataDefs.buildings, Economy, TimerService, building_id, recipe_id, TimeUtil.now(), DataDefs.crew):
		GameState.save_game()
	_rebuild()


func _on_batch_collect_pressed(building_id: String) -> void:
	var payload := TimerService.collect("convert_" + building_id, TimeUtil.now())
	if payload.is_empty():
		return
	ConvertModel.complete_batch(GameState.data, DataDefs.buildings, Economy, payload)
	GameState.save_game()
	_rebuild()


func _on_assign_pressed(crew_id: String) -> void:
	var options: Array = CrewModel.workable(DataDefs.crew)
	var now := TimeUtil.now()
	var current := CrewModel.building_of(GameState.data, crew_id)
	var next_index := options.find(current) + 1
	# Bank fuel accrued at the old regen rate before the rate can change.
	FuelModel.materialize(GameState.data["fuel"], now)
	if next_index >= options.size():
		if current != "":
			CrewModel.unassign(GameState.data, DataDefs.crew, current, DataDefs.buildings, now)
	else:
		CrewModel.assign(GameState.data, DataDefs.crew, String(options[next_index]), crew_id, DataDefs.buildings, now)
	IslandEffects.apply_fuel(GameState.data, DataDefs.economy, DataDefs.buildings, DataDefs.crew)
	GameState.save_game()
	_rebuild()


func _on_collect_pressed(plot: String) -> void:
	var now := TimeUtil.now()
	var payload := TimerService.collect("build_" + plot, now)
	if payload.is_empty():
		return
	IslandModel.complete_build(GameState.data["island"], payload, GameState.data, now, DataDefs.buildings, DataDefs.crew)
	NotificationSvc.request_permission_once()
	# Idempotent re-application self-heals fuel cap/regen after ANY completion,
	# not just the Wind Still: a mangled save heals at the next collect too.
	IslandEffects.apply_fuel(GameState.data, DataDefs.economy, DataDefs.buildings, DataDefs.crew)
	GameState.save_game()
	_rebuild()


func _on_restore_pressed(islet_id: String) -> void:
	var reason := IsletModel.restore_rejection(GameState.data, DataDefs.islets, Economy, TimerService, islet_id)
	if reason != "":
		$StatusLabel.text = reason
		return
	if IsletModel.start_restore(GameState.data, DataDefs.islets, Economy, TimerService, islet_id, TimeUtil.now()):
		$StatusLabel.text = ""
		GameState.save_game()
	_rebuild()


func _on_restore_collect_pressed(islet_id: String) -> void:
	var payload := TimerService.collect("restore_" + islet_id, TimeUtil.now())
	if payload.is_empty():
		return
	IsletModel.complete_restore(GameState.data, payload)
	GameState.save_game()
	_open_letter(islet_id)
	_rebuild()


func _on_read_letter_pressed(islet_id: String) -> void:
	_open_letter(islet_id)


func _open_letter(islet_id: String) -> void:
	var islet := IsletModel.entry(DataDefs.islets, islet_id)
	var vignette: Dictionary = islet.get("vignette", {})
	_letter_islet = islet_id
	$LetterPanel/VBox/LetterTitle.text = String(vignette.get("title", String(islet.get("name", islet_id))))
	var lines := PackedStringArray()
	for line in vignette.get("lines", []):
		lines.append(String(line))
	$LetterPanel/VBox/LetterBody.text = "\n\n".join(lines)
	# Each letter carries its own ornament: a wax seal for the shoal's letter,
	# a brass clasp for the foundry log (audit 4.3).
	var seal_path := String({
		"lantern_shoal": "res://game/art/ui/seal_lantern.png",
		"foundry_rock": "res://game/art/ui/clasp_foundry.png",
	}.get(islet_id, ""))
	var seal: TextureRect = $LetterPanel/VBox/LetterSeal
	seal.texture = load(seal_path) if seal_path != "" and ResourceLoader.exists(seal_path) else null
	seal.visible = seal.texture != null
	$LetterPanel.visible = true


func _on_letter_close_pressed() -> void:
	if _letter_islet != "":
		# Write-back discipline: heal a mangled section before flagging.
		if not GameState.data.has("islets") or not (GameState.data["islets"] is Dictionary):
			GameState.data["islets"] = {"restored": {}, "letters_seen": {}}
		var section: Dictionary = GameState.data["islets"]
		if not section.has("letters_seen") or not (section["letters_seen"] is Dictionary):
			section["letters_seen"] = {}
		(section["letters_seen"] as Dictionary)[_letter_islet] = true
		GameState.save_game()
	_letter_islet = ""
	$LetterPanel.visible = false


func _on_workshop_pressed() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/base/workshop_screen.tscn")


func _on_back_pressed() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/main.tscn")


func _on_gardens_pressed() -> void:
	var amount := TrickleModel.collect(GameState.data, DataDefs.buildings, TimeUtil.now(), DataDefs.crew)
	if amount > 0:
		Economy.add("scrap", amount)
		GameState.save_game()
	_rebuild()


func _on_crate_pressed() -> void:
	var payout := DailyCrate.claim(GameState.data, DataDefs.retention, TimeUtil.now())
	if payout.is_empty():
		return
	for currency in payout:
		Economy.add(currency, int(payout[currency]))
	GameState.save_game()
	_rebuild()


func _on_slot_pressed() -> void:
	if IslandModel.unlock_second_slot(GameState.data["island"], DataDefs.buildings, Economy):
		GameState.save_game()
	_rebuild()


func _on_skip_pressed(timer_id: String) -> void:
	if not Ads.service.is_available(AdService.Placement.TIMER_SKIP):
		return
	Ads.service.request_reward(AdService.Placement.TIMER_SKIP, _grant_skip.bind(timer_id))


func _grant_skip(timer_id: String) -> void:
	# skip() emits no signal; the rebuild surfaces Complete! and the player
	# collects through the normal button.
	TimerService.skip(timer_id)
	GameState.save_game()
	_rebuild()


func _on_bonus_crate_pressed() -> void:
	var now := TimeUtil.now()
	if not Ads.service.is_available(AdService.Placement.BONUS_CRATE):
		return
	if not AdLimits.can_use(GameState.data, "bonus_crate", _bonus_crate_limit(), now):
		return
	Ads.service.request_reward(AdService.Placement.BONUS_CRATE, _grant_bonus_crate)


func _grant_bonus_crate() -> void:
	var now := TimeUtil.now()
	if not AdLimits.use(GameState.data, "bonus_crate", _bonus_crate_limit(), now):
		return
	var payout: Dictionary = DataDefs.retention.get("daily_crate", {})
	for currency in payout:
		Economy.add(currency, int(payout[currency]))
	GameState.save_game()
	_rebuild()


func _bonus_crate_limit() -> int:
	return int((DataDefs.retention.get("ads", {}) as Dictionary).get("bonus_crates_per_day", 1))
