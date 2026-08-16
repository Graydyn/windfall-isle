extends Control
## Workshop crafting (spec 4.1): craft duplicates of owned gizmos; a finished
## craft merges into a level (spec 3.3). Dumb UI over CraftModel.

@onready var rows: VBoxContainer = $Rows
@onready var slots_label: Label = $SlotsLabel


func _ready() -> void:
	$BackButton.pressed.connect(_on_back_pressed)
	$RefreshTimer.timeout.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	for child in rows.get_children():
		child.queue_free()
	var now := TimeUtil.now()
	var slots := CraftModel.craft_slots(GameState.data["island"])
	slots_label.text = "Workshop Lv %d: crafting %d/%d" % [slots, CraftModel.active_crafts(TimerService), maxi(slots, 0)] \
		if slots > 0 else "Build a Workshop on the island to craft"
	var owned: Dictionary = GameState.data["gizmos"]["owned"]
	for gizmo_id in owned:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 56)
		var def: Dictionary = (DataDefs.gizmos["defs"] as Dictionary).get(String(gizmo_id), {})
		var label := Label.new()
		label.custom_minimum_size = Vector2(360, 0)
		label.text = "%s Lv %d" % [String(def.get("name", gizmo_id)), int(owned[gizmo_id])]
		row.add_child(label)
		var timer_id := "craft_" + String(gizmo_id)
		if TimerService.active_timers().has(timer_id):
			if TimerService.is_done(timer_id, now):
				var collect := Button.new()
				collect.text = "Collect!"
				collect.pressed.connect(_on_collect_pressed.bind(String(gizmo_id)))
				row.add_child(collect)
			else:
				label.text += "  (%ds)" % TimerService.remaining(timer_id, now)
		else:
			var craft := Button.new()
			craft.text = "Craft"
			craft.pressed.connect(_on_craft_pressed.bind(String(gizmo_id)))
			row.add_child(craft)
		rows.add_child(row)


func _on_craft_pressed(gizmo_id: String) -> void:
	if CraftModel.start_craft(GameState.data, DataDefs.gizmos, Economy, TimerService, gizmo_id, TimeUtil.now()):
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
