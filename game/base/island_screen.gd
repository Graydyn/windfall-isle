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

var _selection: Dictionary = {}
var _last_signature := ""
var _plot_labels: Dictionary = {}

@onready var rows: VBoxContainer = $Rows


func _ready() -> void:
	$WorkshopButton.pressed.connect(_on_workshop_pressed)
	$BackButton.pressed.connect(_on_back_pressed)
	$RefreshTimer.timeout.connect(_refresh_tick)
	$GardensButton.pressed.connect(_on_gardens_pressed)
	$CrateButton.pressed.connect(_on_crate_pressed)
	$SlotButton.pressed.connect(_on_slot_pressed)
	$BonusCrateButton.pressed.connect(_on_bonus_crate_pressed)
	_rebuild()


func _plot_ids() -> Array[String]:
	var ids: Array[String] = []
	for i in int(DataDefs.buildings.get("plot_count", 6)):
		ids.append("plot_%d" % i)
	return ids


func _unbuilt_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in DataDefs.buildings.get("defs", {}):
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
	return ",".join(parts)


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
	_refresh_static_controls(now)


func _rebuild() -> void:
	for child in rows.get_children():
		child.queue_free()
	_plot_labels.clear()
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
			var select := Button.new()
			select.text = _selection_text(plot, island)
			select.pressed.connect(_on_select_pressed.bind(plot))
			row.add_child(select)
			var build := Button.new()
			build.text = "Build"
			build.pressed.connect(_on_build_pressed.bind(plot))
			row.add_child(build)
		rows.add_child(row)
	_refresh_static_controls(now)


func _refresh_static_controls(now: int) -> void:
	var pending := TrickleModel.pending(GameState.data, DataDefs.buildings, now)
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
		if String(entry["building"]) == "observatory" and int(entry["level"]) >= 1:
			text += "\n    %s" % String(def.get("teaser", ""))
		return text
	return "%s: (empty)" % plot


func _selection_text(plot: String, island: Dictionary) -> String:
	var plots: Dictionary = island.get("plots", {})
	if plots.has(plot):
		return "Upgrade"
	var chosen := String(_selection.get(plot, ""))
	return chosen if chosen != "" else "Choose..."


func _on_select_pressed(plot: String) -> void:
	var plots: Dictionary = GameState.data["island"]["plots"]
	if plots.has(plot):
		return
	var options := _unbuilt_ids()
	if options.is_empty():
		return
	var current := String(_selection.get(plot, ""))
	var index := options.find(current)
	_selection[plot] = options[(index + 1) % options.size()]
	$StatusLabel.text = ""
	_rebuild()


func _on_build_pressed(plot: String) -> void:
	var island: Dictionary = GameState.data["island"]
	var building_id: String
	if island["plots"].has(plot):
		building_id = String(island["plots"][plot]["building"])
	else:
		building_id = String(_selection.get(plot, ""))
	if building_id == "":
		$StatusLabel.text = "Pick a building for %s first." % plot
		return
	var now := TimeUtil.now()
	var reason := IslandModel.build_rejection(island, DataDefs.buildings, Economy, TimerService, plot, building_id, now)
	if reason != "":
		$StatusLabel.text = reason
		return
	if IslandModel.start_build(island, DataDefs.buildings, Economy, TimerService, plot, building_id, now):
		$StatusLabel.text = ""
		GameState.save_game()
	_rebuild()


func _on_collect_pressed(plot: String) -> void:
	var now := TimeUtil.now()
	var payload := TimerService.collect("build_" + plot, now)
	if payload.is_empty():
		return
	IslandModel.complete_build(GameState.data["island"], payload, GameState.data, now, DataDefs.buildings)
	NotificationSvc.request_permission_once()
	# Idempotent re-application self-heals fuel cap/regen after ANY completion,
	# not just the Wind Still: a mangled save heals at the next collect too.
	IslandEffects.apply_fuel(GameState.data, DataDefs.economy, DataDefs.buildings)
	GameState.save_game()
	_rebuild()


func _on_workshop_pressed() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/base/workshop_screen.tscn")


func _on_back_pressed() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/main.tscn")


func _on_gardens_pressed() -> void:
	var amount := TrickleModel.collect(GameState.data, DataDefs.buildings, TimeUtil.now())
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
