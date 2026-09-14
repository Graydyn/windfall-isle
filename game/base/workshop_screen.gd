extends Control
## Workshop crafting (spec 4.1): craft duplicates of owned gizmos; a finished
## craft merges into a level (spec 3.3). Dumb UI over CraftModel.
##
## Refresh discipline mirrors island_screen: ticks rebuild only on structural
## change; countdown labels update in place.

var _last_signature := ""
var _gizmo_labels: Dictionary = {}

@onready var rows: VBoxContainer = $Rows
@onready var slots_label: Label = $SlotsLabel


func _ready() -> void:
	$BackButton.pressed.connect(_on_back_pressed)
	$RefreshTimer.timeout.connect(_refresh_tick)
	_rebuild()


func _signature(now: int) -> String:
	var parts := PackedStringArray()
	for gizmo_id in DataDefs.gizmos["defs"]:
		var timer_id := "craft_" + String(gizmo_id)
		if TimerService.active_timers().has(timer_id):
			parts.append("d" if TimerService.is_done(timer_id, now) else "r")
		elif CraftModel.rarity_unlocked(GameState.data["island"], DataDefs.gizmos, String(gizmo_id)):
			parts.append("i")
		else:
			parts.append("l")
	return ",".join(parts)


func _refresh_tick() -> void:
	var now := TimeUtil.now()
	if _signature(now) != _last_signature:
		_rebuild()
		return
	_refresh_labels(now)


func _refresh_labels(now: int) -> void:
	slots_label.text = _slots_text()
	for gizmo_id in _gizmo_labels:
		var label: Label = _gizmo_labels[gizmo_id]
		if is_instance_valid(label):
			label.text = _gizmo_label_text(String(gizmo_id), now)


func _slots_text() -> String:
	var slots := CraftModel.craft_slots(GameState.data["island"])
	return "Workshop Lv %d: crafting %d/%d" % [slots, CraftModel.active_crafts(TimerService), maxi(slots, 0)] \
		if slots > 0 else "Build a Workshop on the island to craft"


func _gizmo_label_text(gizmo_id: String, now: int) -> String:
	var owned: Dictionary = GameState.data["gizmos"]["owned"]
	var def: Dictionary = (DataDefs.gizmos["defs"] as Dictionary).get(gizmo_id, {})
	var timer_id := "craft_" + gizmo_id
	var rarity := String(def.get("rarity", ""))
	# A locked idle row shows only the unlock requirement; an in-flight craft
	# on a locked gizmo is grandfathered and renders like any other timer.
	if not TimerService.active_timers().has(timer_id) \
			and not CraftModel.rarity_unlocked(GameState.data["island"], DataDefs.gizmos, gizmo_id):
		var unlock_level := int((DataDefs.gizmos.get("rarity_unlocks", {}) as Dictionary).get(rarity, 0))
		return "%s  Requires Workshop Lv %d" % [String(def.get("name", gizmo_id)), unlock_level]
	var text: String
	if owned.has(gizmo_id):
		text = "%s Lv %d" % [String(def.get("name", gizmo_id)), int(owned[gizmo_id])]
	else:
		text = "%s (not owned)" % String(def.get("name", gizmo_id))
	if TimerService.active_timers().has(timer_id) and not TimerService.is_done(timer_id, now):
		text += "  (%ds)" % TimerService.remaining(timer_id, now)
	elif not TimerService.active_timers().has(timer_id):
		text += "  cost: %s [%s]" % [_cost_text(def.get("craft_cost", {})), rarity.capitalize()]
	return text


func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for currency in cost:
		parts.append("%d %s" % [int(cost[currency]), String(currency)])
	return ", ".join(parts)


func _rebuild() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	_gizmo_labels.clear()
	var now := TimeUtil.now()
	_last_signature = _signature(now)
	slots_label.text = _slots_text()
	for gizmo_id in DataDefs.gizmos["defs"]:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 56)
		var label := Label.new()
		label.custom_minimum_size = Vector2(360, 0)
		label.text = _gizmo_label_text(String(gizmo_id), now)
		row.add_child(label)
		_gizmo_labels[String(gizmo_id)] = label
		var timer_id := "craft_" + String(gizmo_id)
		if TimerService.active_timers().has(timer_id):
			if TimerService.is_done(timer_id, now):
				var collect := Button.new()
				collect.text = "Collect!"
				collect.pressed.connect(_on_collect_pressed.bind(String(gizmo_id)))
				row.add_child(collect)
			elif Ads.service.is_available(AdService.Placement.TIMER_SKIP):
				var skip := Button.new()
				skip.text = "Skip (ad)"
				skip.pressed.connect(_on_skip_pressed.bind(timer_id))
				row.add_child(skip)
		elif CraftModel.rarity_unlocked(GameState.data["island"], DataDefs.gizmos, String(gizmo_id)):
			var craft := Button.new()
			craft.text = "Craft"
			craft.pressed.connect(_on_craft_pressed.bind(String(gizmo_id)))
			row.add_child(craft)
		else:
			label.modulate.a = 0.5
		rows.add_child(row)


func _on_craft_pressed(gizmo_id: String) -> void:
	if CraftModel.start_craft(GameState.data, DataDefs.gizmos, Economy, TimerService, gizmo_id, TimeUtil.now(), DataDefs.crew):
		GameState.save_game()
	_rebuild()


func _on_collect_pressed(gizmo_id: String) -> void:
	var payload := TimerService.collect("craft_" + gizmo_id, TimeUtil.now())
	if payload.is_empty():
		return
	CraftModel.complete_craft(GameState.data, payload)
	GameState.save_game()
	_rebuild()


func _on_back_pressed() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/base/island_screen.tscn")


func _on_skip_pressed(timer_id: String) -> void:
	if not Ads.service.is_available(AdService.Placement.TIMER_SKIP):
		return
	Ads.service.request_reward(AdService.Placement.TIMER_SKIP, _grant_skip.bind(timer_id))


func _grant_skip(timer_id: String) -> void:
	TimerService.skip(timer_id)
	GameState.save_game()
	_rebuild()
