extends Control
## The home island (spec 4.1) as a scrollable map (Plan 15): building pads,
## islets and crew live at authored positions from island_layout.json. Dumb
## UI: every rule lives in the models; this screen renders state and routes
## taps to the same handlers the old menu used.
##
## Refresh discipline: RefreshTimer ticks call _refresh_tick, which rebuilds
## the map ONLY when the structural signature changes (a timer starting,
## finishing, or disappearing); otherwise nodes re-render in place so a pad
## is never freed under the player's finger.

var _last_signature := ""
var _modal_plot := ""
var _modal_ids: Array[String] = []
var _modal_index := 0
var _plot_nodes: Dictionary = {}
var _islet_nodes: Dictionary = {}
var _crew_rows: Dictionary = {}
var _letter_islet := ""
var _sheet_plot := ""
var _sheet_islet := ""
var _sheet_button_styles: Dictionary = {}

const BUTTON_ART := "res://game/art/ui/button.png"


func _ready() -> void:
	$BackButton.pressed.connect(_on_back_pressed)
	$RefreshTimer.timeout.connect(_refresh_tick)
	$DailyCrateIcon.pressed.connect(_on_crate_pressed)
	$BonusCrateIcon.pressed.connect(_on_bonus_crate_pressed)
	$BuildModal/VBox/ModalSlotButton.pressed.connect(_on_modal_slot_pressed)
	if ResourceLoader.exists("res://game/art/icons/daily_crate.png"):
		$DailyCrateIcon.texture_normal = load("res://game/art/icons/daily_crate.png")
	if ResourceLoader.exists("res://game/art/icons/bonus_crate.png"):
		$BonusCrateIcon.texture_normal = load("res://game/art/icons/bonus_crate.png")
	if ResourceLoader.exists("res://game/art/icons/ad_badge.png"):
		$BonusCrateIcon/AdBadge.texture = load("res://game/art/icons/ad_badge.png")
	$LetterPanel/VBox/LetterClose.pressed.connect(_on_letter_close_pressed)
	$BuildModal/VBox/NavRow/PrevButton.pressed.connect(_on_modal_prev_pressed)
	$BuildModal/VBox/NavRow/NextButton.pressed.connect(_on_modal_next_pressed)
	$BuildModal/VBox/ActionRow/ConfirmButton.pressed.connect(_on_modal_confirm_pressed)
	$BuildModal/VBox/ActionRow/CancelButton.pressed.connect(_on_modal_cancel_pressed)
	$PlotSheet/VBox/SheetClose.pressed.connect(_on_sheet_close_pressed)
	$CrewSheet/VBox/CrewClose.pressed.connect(func() -> void: $CrewSheet.visible = false)
	$BuildModal.visibility_changed.connect(_update_modal_block)
	$LetterPanel.visibility_changed.connect(_update_modal_block)
	$PlotSheet.visibility_changed.connect(_update_modal_block)
	$CrewSheet.visibility_changed.connect(_update_modal_block)
	$RewardModal.visibility_changed.connect(_update_modal_block)
	$RewardModal/VBox/RewardClose.pressed.connect(_on_reward_close_pressed)
	_build_sheet_button_styles()
	_style_sheet_button($PlotSheet/VBox/SheetClose)
	_style_sheet_button($LetterPanel/VBox/LetterClose)
	_style_sheet_button($CrewSheet/VBox/CrewClose)
	for path in ["NavRow/PrevButton", "NavRow/NextButton", "ActionRow/ConfirmButton", "ActionRow/CancelButton", "ModalSlotButton"]:
		var modal_button: Button = $BuildModal/VBox.get_node(NodePath(path))
		_style_sheet_button(modal_button, 210.0)
		modal_button.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
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
	for plot in _plot_nodes:
		var node: IslandPlotNode = _plot_nodes[plot]
		if is_instance_valid(node):
			node.render(_plot_state(String(plot), now))
	for islet_id in _islet_nodes:
		var islet_node: IslandIsletNode = _islet_nodes[islet_id]
		if is_instance_valid(islet_node):
			islet_node.render(_islet_visual_state(IsletModel.entry(DataDefs.islets, String(islet_id)), now))
	if $PlotSheet.visible:
		_render_sheet()
	_refresh_static_controls(now)


func _rebuild() -> void:
	for container in [$MapScroll/Map/Plots, $MapScroll/Map/Islets]:
		for child in (container as Control).get_children():
			(container as Control).remove_child(child)
			child.queue_free()
	_plot_nodes.clear()
	_islet_nodes.clear()
	var now := TimeUtil.now()
	_last_signature = _signature(now)
	var layout: Dictionary = DataDefs.island_layout
	var plot_positions: Dictionary = layout.get("plots", {})
	for plot in _plot_ids():
		var node := IslandPlotNode.new(plot)
		node.plot_tapped.connect(_on_plot_tapped)
		node.position = _layout_pos(plot_positions.get(plot)) - node.custom_minimum_size / 2.0
		$MapScroll/Map/Plots.add_child(node)
		node.render(_plot_state(plot, now))
		_plot_nodes[plot] = node
	var islet_layout: Dictionary = layout.get("islets", {})
	for row_v in IsletModel.islets(DataDefs.islets):
		var islet := row_v as Dictionary
		var islet_id := String(islet.get("id", ""))
		var islet_node := IslandIsletNode.new(islet_id)
		islet_node.islet_tapped.connect(_on_islet_tapped)
		var entry: Dictionary = islet_layout.get(islet_id, {})
		islet_node.position = _layout_pos(entry.get("pos")) - islet_node.custom_minimum_size / 2.0
		$MapScroll/Map/Islets.add_child(islet_node)
		islet_node.render(_islet_visual_state(islet, now))
		_islet_nodes[islet_id] = islet_node
	if $PlotSheet.visible:
		_render_sheet()
	if $CrewSheet.visible:
		_render_crew_sheet()
	_refresh_static_controls(now)


func _layout_pos(value: Variant) -> Vector2:
	# A plot id missing from island_layout.json must degrade to a visible
	# misplacement, never a crash; the defs test catches the authoring hole.
	if not (value is Array) or (value as Array).size() < 2:
		return Vector2.ZERO
	var arr := value as Array
	return Vector2(float(arr[0]), float(arr[1]))


func _plot_state(plot: String, now: int) -> Dictionary:
	var island: Dictionary = GameState.data["island"]
	var plots: Dictionary = island.get("plots", {})
	var defs: Dictionary = DataDefs.buildings.get("defs", {})
	var timer_id := "build_" + plot
	if TimerService.active_timers().has(timer_id):
		var payload: Dictionary = (TimerService.active_timers()[timer_id] as Dictionary).get("payload", {})
		var building := String(payload.get("building", ""))
		var state := {
			"kind": "constructing",
			"art": "res://game/art/buildings/%s.png" % building,
			"status": "%ds" % TimerService.remaining(timer_id, now),
			"ready": false,
			"letter": String((defs.get(building, {}) as Dictionary).get("name", building)).left(1),
		}
		if TimerService.is_done(timer_id, now):
			# The starburst badge says it all; words stay off the map.
			state["status"] = ""
			state["ready"] = true
		return state
	if plots.has(plot):
		var entry: Dictionary = plots[plot]
		var building := String(entry.get("building", ""))
		var def: Dictionary = defs.get(building, {})
		var state := {
			"kind": "built",
			"art": "res://game/art/buildings/%s.png" % building,
			"status": "",
			"ready": false,
		}
		var level := int(entry.get("level", 0))
		var rows: Array = def.get("levels", [])
		if level < int(def.get("max_level", 1)) and level < rows.size():
			state["upgrade"] = Economy.can_afford((rows[level] as Dictionary).get("cost", {}))
		var worker := CrewModel.crew_at(GameState.data, building)
		if worker != "":
			state["worker_portrait"] = "res://game/art/crew/%s.png" % worker
		var convert_id := "convert_" + building
		if TimerService.active_timers().has(convert_id):
			if TimerService.is_done(convert_id, now):
				state["ready"] = true
			else:
				state["status"] = "batch %ds" % TimerService.remaining(convert_id, now)
		state["letter"] = String(def.get("name", building)).left(1)
		# Speech bubbles (owner request, 2026-10-17): the gardens advertise
		# their pending trickle, the workshop its craftable count. Zero means
		# no bubble, never a zero.
		if building == "gardens":
			var pending_scrap := TrickleModel.pending(GameState.data, DataDefs.buildings, now, DataDefs.crew)
			if pending_scrap > 0:
				state["bubble"] = "+%d scrap" % pending_scrap
		elif building == "workshop":
			var craftable := CraftModel.craftable_ids(GameState.data, DataDefs.gizmos, Economy).size()
			if craftable > 0:
				state["bubble"] = "%d craftable" % craftable
		return state
	return {"kind": "empty", "status": "", "ready": false}


func _islet_visual_state(islet: Dictionary, now: int) -> Dictionary:
	var islet_id := String(islet.get("id", ""))
	var restored := IsletModel.is_restored(GameState.data, islet_id)
	# Label-free marker (owner request, 2026-10-16): the sheet and letter
	# carry the islet's name, cost and progress.
	return {
		"art": "res://game/art/buildings/islet_%s_%s.png" % [islet_id, "restored" if restored else "ruined"],
		"dim": _islet_state(islet_id, now) == "L",
	}


func _crew_visual_state(member: Dictionary) -> Dictionary:
	var member_id := String(member.get("id", ""))
	var rescued := CrewModel.is_rescued(GameState.data, member_id)
	var line := ""
	if rescued:
		var building := CrewModel.building_of(GameState.data, member_id)
		if building == "":
			var specialty := String(member.get("specialty", ""))
			var spec_def: Dictionary = (DataDefs.buildings.get("defs", {}) as Dictionary).get(specialty, {})
			line = "knows the %s" % String(spec_def.get("name", specialty))
		else:
			line = String(((DataDefs.buildings.get("defs", {}) as Dictionary).get(building, {}) as Dictionary).get("name", building))
	return {
		"portrait": "res://game/art/crew/%s.png" % member_id,
		"name": String(member.get("name", member_id)) if rescued else "???",
		"line": line,
		"rescued": rescued,
	}


func _on_plot_tapped(plot: String) -> void:
	var now := TimeUtil.now()
	var timer_id := "build_" + plot
	if TimerService.active_timers().has(timer_id):
		if TimerService.is_done(timer_id, now):
			_on_collect_pressed(plot)
		else:
			_open_plot_sheet(plot)
		return
	var plots: Dictionary = (GameState.data["island"] as Dictionary).get("plots", {})
	if not plots.has(plot):
		_open_build_modal(plot)
		return
	var building := String((plots[plot] as Dictionary).get("building", ""))
	var convert_id := "convert_" + building
	if TimerService.active_timers().has(convert_id) and TimerService.is_done(convert_id, now):
		_on_batch_collect_pressed(building)
		return
	if building == "gardens" and TrickleModel.pending(GameState.data, DataDefs.buildings, now, DataDefs.crew) > 0:
		# The trickle collects on the tap itself; the vanishing bubble is the
		# receipt, and the next tap opens the sheet as before (owner request,
		# 2026-10-17).
		_collect_trickle()
		return
	if building == "crew_quarters":
		# The Crew button left the HUD; the quarters' sheet IS the crew sheet.
		_open_crew_sheet()
		return
	_open_plot_sheet(plot)


func _on_islet_tapped(islet_id: String) -> void:
	match _islet_state(islet_id, TimeUtil.now()):
		"o":
			_open_islet_sheet(islet_id)
		"d":
			_on_restore_collect_pressed(islet_id)
		"R":
			_on_read_letter_pressed(islet_id)


func _open_plot_sheet(plot: String) -> void:
	_sheet_islet = ""
	_sheet_plot = plot
	_render_sheet()
	if _sheet_plot != "":
		$PlotSheet.visible = true


func _open_islet_sheet(islet_id: String) -> void:
	_sheet_plot = ""
	_sheet_islet = islet_id
	_render_sheet()
	if _sheet_islet != "":
		$PlotSheet.visible = true


func _render_islet_sheet() -> void:
	# Restoration spends real currency, so an offered islet confirms through
	# the sheet instead of spending on the map tap (owner report, 2026-10-15).
	if _islet_state(_sheet_islet, TimeUtil.now()) != "o":
		_close_sheet()
		return
	var islet := IsletModel.entry(DataDefs.islets, _sheet_islet)
	var actions: VBoxContainer = $PlotSheet/VBox/SheetActions
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	var picture: TextureRect = $PlotSheet/VBox/SheetPicture
	var art_path := "res://game/art/buildings/islet_%s_ruined.png" % _sheet_islet
	if ResourceLoader.exists(art_path):
		picture.texture = load(art_path)
	else:
		picture.texture = null
	picture.visible = picture.texture != null
	$PlotSheet/VBox/SheetTitle.text = String(islet.get("name", _sheet_islet))
	_set_sheet_lore("", "")
	var info := "Mend the bridge to open new ground."
	var unlock := IsletModel.unlock_text(DataDefs.buildings, _sheet_islet)
	if unlock != "":
		info += " " + unlock
	$PlotSheet/VBox/SheetInfo.text = info
	$PlotSheet/VBox/SheetInfo.visible = true
	var restore := Button.new()
	restore.text = "Restore (%s)" % _cost_text(islet.get("cost", {}))
	restore.pressed.connect(_on_sheet_restore_pressed)
	_style_sheet_button(restore)
	actions.add_child(restore)
	_fit_sheet()


func _on_sheet_restore_pressed() -> void:
	var reason := IsletModel.restore_rejection(GameState.data, DataDefs.islets, Economy, TimerService, _sheet_islet)
	if reason != "":
		# The refusal lives beside the button that earned it.
		$PlotSheet/VBox/SheetInfo.text = reason
		$PlotSheet/VBox/SheetInfo.visible = true
		return
	var islet_id := _sheet_islet
	_close_sheet()
	_on_restore_pressed(islet_id)


func _render_sheet() -> void:
	if _sheet_islet != "":
		_render_islet_sheet()
		return
	var now := TimeUtil.now()
	var island: Dictionary = GameState.data["island"]
	var plots: Dictionary = island.get("plots", {})
	var timer_id := "build_" + _sheet_plot
	var constructing := TimerService.active_timers().has(timer_id)
	if _sheet_plot == "" or (not plots.has(_sheet_plot) and not constructing):
		_close_sheet()
		return
	var actions: VBoxContainer = $PlotSheet/VBox/SheetActions
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	var building := ""
	var level := 0
	if plots.has(_sheet_plot):
		var entry: Dictionary = plots[_sheet_plot]
		building = String(entry.get("building", ""))
		level = int(entry.get("level", 0))
	if constructing:
		var payload: Dictionary = (TimerService.active_timers()[timer_id] as Dictionary).get("payload", {})
		building = String(payload.get("building", building))
	var def: Dictionary = (DataDefs.buildings.get("defs", {}) as Dictionary).get(building, {})
	var display := String(def.get("name", building))
	var art_path := "res://game/art/buildings/%s.png" % building
	var picture: TextureRect = $PlotSheet/VBox/SheetPicture
	if ResourceLoader.exists(art_path):
		picture.texture = load(art_path)
	else:
		picture.texture = null
	picture.visible = picture.texture != null
	if constructing:
		if TimerService.is_done(timer_id, now):
			$PlotSheet/VBox/SheetTitle.text = "%s: ready!" % display
		else:
			$PlotSheet/VBox/SheetTitle.text = "Building %s (%ds)" % [display, TimerService.remaining(timer_id, now)]
	else:
		$PlotSheet/VBox/SheetTitle.text = "%s Lv %d" % [display, level]
	# The sheet owns the building's lore; the upgrade modal keeps only the
	# numbers (owner request, 2026-10-16).
	_set_sheet_lore(String(def.get("flavor", "")), String(def.get("description", "")))
	var info_lines := PackedStringArray()
	var worker := CrewModel.crew_at(GameState.data, building)
	if worker != "":
		info_lines.append("%s is working here" % String(CrewModel.entry(DataDefs.crew, worker).get("name", worker)))
	if level >= 1 and String(def.get("teaser", "")) != "":
		info_lines.append(String(def.get("teaser", "")))
	$PlotSheet/VBox/SheetInfo.text = "\n".join(info_lines)
	$PlotSheet/VBox/SheetInfo.visible = not info_lines.is_empty()
	if constructing:
		if TimerService.is_done(timer_id, now):
			var complete := Button.new()
			complete.text = "Complete!"
			complete.pressed.connect(_on_sheet_collect_pressed)
			_style_sheet_button(complete)
			actions.add_child(complete)
		elif Ads.service.is_available(AdService.Placement.TIMER_SKIP):
			var skip := Button.new()
			skip.text = "Skip (ad)"
			skip.pressed.connect(_on_skip_pressed.bind(timer_id))
			_style_sheet_button(skip)
			actions.add_child(skip)
		_fit_sheet()
		return
	if building == "workshop":
		# The HUD Workshop button moved into the workshop's own sheet
		# (owner request, 2026-10-17).
		var enter := Button.new()
		enter.text = "Enter the workshop"
		enter.pressed.connect(_on_workshop_pressed)
		_style_sheet_button(enter)
		actions.add_child(enter)
	var upgrade := Button.new()
	var max_level := int(def.get("max_level", 1))
	upgrade.text = "Upgrade..." if level < max_level else "Max level"
	upgrade.disabled = level >= max_level
	upgrade.pressed.connect(_on_sheet_upgrade_pressed)
	_style_sheet_button(upgrade)
	actions.add_child(upgrade)
	var convert_id := "convert_" + building
	if TimerService.active_timers().has(convert_id):
		if TimerService.is_done(convert_id, now):
			var payload: Dictionary = (TimerService.active_timers()[convert_id] as Dictionary).get("payload", {})
			var outputs := ConvertModel.outputs_for(DataDefs.buildings, island, building, String(payload.get("recipe", "")))
			var batch := Button.new()
			batch.text = "Collect (%s)" % _cost_text(outputs) if not outputs.is_empty() else "Collect"
			batch.pressed.connect(_on_sheet_batch_collect_pressed.bind(building))
			_style_sheet_button(batch)
			actions.add_child(batch)
	else:
		for recipe_v in ConvertModel.recipes(DataDefs.buildings, building):
			var recipe_id := String((recipe_v as Dictionary).get("id", ""))
			var start_batch := Button.new()
			start_batch.text = _batch_button_text(building, recipe_id)
			start_batch.disabled = not ConvertModel.can_start(GameState.data, DataDefs.buildings, Economy, TimerService, building, recipe_id)
			start_batch.pressed.connect(_on_sheet_batch_start_pressed.bind(building, recipe_id))
			_style_sheet_button(start_batch)
			actions.add_child(start_batch)
	_fit_sheet()


func _set_sheet_lore(flavor: String, description: String) -> void:
	$PlotSheet/VBox/SheetFlavor.text = flavor
	$PlotSheet/VBox/SheetFlavor.visible = flavor != ""
	$PlotSheet/VBox/SheetDescription.text = description
	$PlotSheet/VBox/SheetDescription.visible = description != ""


func _build_sheet_button_styles() -> void:
	# ui/button.png wired for the sheet's buttons (audit section 7); the
	# full theme pass still owns the rest of the game's chrome.
	if not ResourceLoader.exists(BUTTON_ART):
		return
	var art: Texture2D = load(BUTTON_ART)
	var tints := {
		"normal": Color.WHITE,
		"hover": Color(1.06, 1.06, 1.06),
		"pressed": Color(0.88, 0.88, 0.88),
		"disabled": Color(0.72, 0.72, 0.72, 0.9),
	}
	for state in tints:
		var style := StyleBoxTexture.new()
		style.texture = art
		# button.png is a small rounded square centered on a mostly
		# transparent 384x112 canvas (jig centers its subjects), so the
		# nine-patch must slice the PAINTED region, not the whole canvas,
		# and its margins must stay under half the smallest drawn button.
		style.region_rect = Rect2(136, 2, 112, 108)
		style.texture_margin_left = 34.0
		style.texture_margin_right = 34.0
		style.texture_margin_top = 26.0
		style.texture_margin_bottom = 30.0
		style.set_content_margin_all(10.0)
		style.content_margin_left = 24.0
		style.content_margin_right = 24.0
		style.modulate_color = tints[state]
		_sheet_button_styles[String(state)] = style


func _style_sheet_button(button: Button, min_width := 280.0) -> void:
	if _sheet_button_styles.is_empty():
		return
	for state in _sheet_button_styles:
		button.add_theme_stylebox_override(String(state), _sheet_button_styles[state])
	button.add_theme_color_override("font_color", Color(0.12, 0.16, 0.3))
	button.add_theme_color_override("font_hover_color", Color(0.12, 0.16, 0.3))
	button.add_theme_color_override("font_pressed_color", Color(0.12, 0.16, 0.3))
	button.add_theme_color_override("font_disabled_color", Color(0.12, 0.16, 0.3, 0.5))
	# Pills hold a modest width and center; edge-to-edge buttons crowd the
	# painted frame (owner request, 2026-10-16).
	button.custom_minimum_size = Vector2(min_width, 60)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _fit_modal() -> void:
	# Same contract as _fit_sheet: the card hugs its content, centered,
	# deferred past the container sort pass.
	_fit_modal_now.call_deferred()


func _fit_modal_now() -> void:
	$BuildModal.reset_size()
	$BuildModal.position = Vector2(
		(720.0 - $BuildModal.size.x) / 2.0,
		maxf(80.0, (1280.0 - $BuildModal.size.y) / 2.0 - 80.0))


func _fit_sheet() -> void:
	# The panel hugs its content and docks just above the HUD bar; a fixed
	# rect either clips a busy sheet or leaves a quiet one swimming in frame.
	# Deferred: container minimums settle only after the queued sort pass.
	_fit_sheet_now.call_deferred()


func _fit_sheet_now() -> void:
	$PlotSheet.reset_size()
	$PlotSheet.position = Vector2((720.0 - $PlotSheet.size.x) / 2.0, 1150.0 - $PlotSheet.size.y)


func _open_crew_sheet() -> void:
	_render_crew_sheet()
	$CrewSheet.visible = true
	_fit_crew_sheet()


func _render_crew_sheet() -> void:
	# The crew roster and the assign cycle live here; the map stays scenery
	# (owner request, 2026-10-16). Rows rebuild on every render: eight rows
	# is cheap and the assign button label must track the current cycle stop.
	var rows: VBoxContainer = $CrewSheet/VBox/CrewRows
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	_crew_rows.clear()
	for row_v in CrewModel.members(DataDefs.crew):
		var member := row_v as Dictionary
		var member_id := String(member.get("id", ""))
		var state := _crew_visual_state(member)
		var rescued := bool(state.get("rescued", false))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(56, 56)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var portrait_path := String(state.get("portrait", ""))
		if portrait_path != "" and ResourceLoader.exists(portrait_path):
			portrait.texture = load(portrait_path)
		portrait.modulate.a = 1.0 if rescued else 0.5
		row.add_child(portrait)
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var name_label := Label.new()
		name_label.text = String(state.get("name", ""))
		name_label.add_theme_color_override("font_color", Color(0.13, 0.17, 0.32))
		name_label.add_theme_font_size_override("font_size", 17)
		text_box.add_child(name_label)
		var line_label := Label.new()
		line_label.text = String(state.get("line", ""))
		line_label.add_theme_color_override("font_color", Color(0.13, 0.17, 0.32, 0.75))
		line_label.add_theme_font_size_override("font_size", 13)
		text_box.add_child(line_label)
		row.add_child(text_box)
		var assign := Button.new()
		assign.text = "Assign" if rescued else "Lost at sea"
		assign.disabled = not rescued
		assign.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_style_sheet_button(assign, 180.0)
		assign.pressed.connect(_on_assign_pressed.bind(member_id))
		row.add_child(assign)
		rows.add_child(row)
		_crew_rows[member_id] = assign


func _fit_crew_sheet() -> void:
	# Same contract as _fit_modal: hug the content, centered, after the sort.
	_fit_crew_sheet_now.call_deferred()


func _fit_crew_sheet_now() -> void:
	$CrewSheet.reset_size()
	$CrewSheet.position = Vector2(
		(720.0 - $CrewSheet.size.x) / 2.0,
		maxf(60.0, (1280.0 - $CrewSheet.size.y) / 2.0 - 60.0))


func _close_sheet() -> void:
	_sheet_plot = ""
	_sheet_islet = ""
	$PlotSheet.visible = false


func _on_sheet_close_pressed() -> void:
	_close_sheet()


func _on_sheet_collect_pressed() -> void:
	var plot := _sheet_plot
	_close_sheet()
	_on_collect_pressed(plot)


func _on_sheet_upgrade_pressed() -> void:
	var plot := _sheet_plot
	_close_sheet()
	_open_build_modal(plot)


func _on_sheet_batch_start_pressed(building_id: String, recipe_id: String) -> void:
	_on_batch_start_pressed(building_id, recipe_id)


func _on_sheet_batch_collect_pressed(building_id: String) -> void:
	_on_batch_collect_pressed(building_id)


func _update_modal_block() -> void:
	$ModalBlock.visible = ($BuildModal.visible or $LetterPanel.visible
		or $PlotSheet.visible or $CrewSheet.visible or $RewardModal.visible)


func _show_reward(title: String, payout: Dictionary) -> void:
	# Rewards get a proper card, not a status line (owner request, 2026-10-17).
	$RewardModal/VBox/RewardTitle.text = title
	var lines := PackedStringArray()
	for currency in payout:
		lines.append("+%d %s" % [int(payout[currency]), String(currency)])
	$RewardModal/VBox/RewardBody.text = "\n".join(lines)
	var art_path := "res://game/art/icons/daily_crate_open.png"
	var picture: TextureRect = $RewardModal/VBox/RewardPicture
	picture.texture = load(art_path) if ResourceLoader.exists(art_path) else null
	picture.visible = picture.texture != null
	_style_sheet_button($RewardModal/VBox/RewardClose, 240.0)
	$RewardModal.visible = true
	_fit_reward_modal()


func _on_reward_close_pressed() -> void:
	$RewardModal.visible = false


func _fit_reward_modal() -> void:
	# Same contract as _fit_modal: hug the content, centered, after the sort.
	_fit_reward_modal_now.call_deferred()


func _fit_reward_modal_now() -> void:
	$RewardModal.reset_size()
	$RewardModal.position = Vector2(
		(720.0 - $RewardModal.size.x) / 2.0,
		maxf(80.0, (1280.0 - $RewardModal.size.y) / 2.0 - 80.0))


func _refresh_static_controls(now: int) -> void:
	# The HUD row dissolved into the map (owner request, 2026-10-17): crates
	# float top right only while claimable; the trickle, the 2nd slot, the
	# workshop and the crew live on the pads, in the modal and in the sheets.
	$DailyCrateIcon.visible = DailyCrate.can_claim(GameState.data, now)
	$BonusCrateIcon.visible = Ads.service.is_available(AdService.Placement.BONUS_CRATE) \
		and AdLimits.can_use(GameState.data, "bonus_crate", _bonus_crate_limit(), now)


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
	_refresh_modal_slot_offer()
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
	# An occupied plot already told its story in the plot sheet, so the
	# upgrade modal keeps only the numbers (owner request, 2026-10-16); an
	# empty plot has no sheet before the modal, so the lore stays here.
	var upgrading: bool = (GameState.data["island"].get("plots", {}) as Dictionary).has(_modal_plot)
	$BuildModal/VBox/ModalFlavor.text = String(def.get("flavor", ""))
	$BuildModal/VBox/ModalFlavor.visible = not upgrading and String(def.get("flavor", "")) != ""
	$BuildModal/VBox/ModalDescription.text = String(def.get("description", ""))
	$BuildModal/VBox/ModalDescription.visible = not upgrading and String(def.get("description", "")) != ""
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
		_fit_modal()
		return
	var next_row: Dictionary = level_rows[level]
	$BuildModal/VBox/ModalCost.text = "Cost: %s" % _cost_text(next_row.get("cost", {}))
	$BuildModal/VBox/ActionRow/ConfirmButton.text = ("Upgrade to Lv %d" % (level + 1)) if level > 0 else "Build"
	$BuildModal/VBox/ActionRow/ConfirmButton.disabled = false
	_fit_modal()


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


func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for currency in cost:
		parts.append("%d %s" % [int(cost[currency]), String(currency)])
	return ", ".join(parts)


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
	# Refusals explain themselves in the sheet (SheetInfo); this guard is the
	# last line of defense and refuses quietly.
	if IsletModel.restore_rejection(GameState.data, DataDefs.islets, Economy, TimerService, islet_id) != "":
		return
	if IsletModel.start_restore(GameState.data, DataDefs.islets, Economy, TimerService, islet_id, TimeUtil.now()):
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
	var unlock := IsletModel.unlock_text(DataDefs.buildings, islet_id)
	if unlock != "":
		lines.append(unlock)
	$LetterPanel/VBox/LetterScroll/LetterBody.text = "\n\n".join(lines)
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


func _collect_trickle() -> void:
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
	_show_reward("Daily crate!", payout)


func _refresh_modal_slot_offer() -> void:
	# The 2nd build slot moved from the HUD into the moment it matters: the
	# player is trying to build and every builder is busy (owner request,
	# 2026-10-17).
	var slots_cfg: Dictionary = DataDefs.buildings.get("build_slots", {})
	var slots := int(GameState.data["island"].get("build_slots", 1))
	var offer: Button = $BuildModal/VBox/ModalSlotButton
	offer.visible = slots < int(slots_cfg.get("max", 2)) \
		and IslandModel.active_constructions(TimerService, TimeUtil.now()) >= slots
	if not offer.visible:
		return
	var cost := int(slots_cfg.get("second_slot_crystal_cost", 20))
	offer.text = "Hire a second builder (%d crystals)" % cost
	offer.disabled = not Economy.can_afford({"crystals": cost})


func _on_modal_slot_pressed() -> void:
	if IslandModel.unlock_second_slot(GameState.data["island"], DataDefs.buildings, Economy):
		GameState.save_game()
	$BuildModal/VBox/ModalStatus.text = ""
	_render_modal()


func _on_skip_pressed(timer_id: String) -> void:
	if not Ads.service.is_available(AdService.Placement.TIMER_SKIP):
		return
	Ads.service.request_reward(AdService.Placement.TIMER_SKIP, _grant_skip.bind(timer_id))


func _grant_skip(timer_id: String) -> void:
	# skip() emits no signal; the rebuild surfaces the ready state and the
	# player collects with a tap on the pad.
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
	_show_reward("Bonus crate!", payout)


func _bonus_crate_limit() -> int:
	return int((DataDefs.retention.get("ads", {}) as Dictionary).get("bonus_crates_per_day", 1))
