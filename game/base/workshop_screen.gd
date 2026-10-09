extends Control
## Workshop crafting (spec 4.1): craft duplicates of owned gizmos; a finished
## craft merges into a level (spec 3.3). Dumb UI over CraftModel.
##
## Layout (owner request, 2026-10-08): a grid of gizmo tiles, each opening a
## craft modal (picture, description, cost, state-driven action button) that
## mirrors island_screen's build browser.
##
## Refresh discipline mirrors island_screen: ticks rebuild only on structural
## change; countdown labels and the open modal update in place.

var _last_signature := ""
var _tiles: Dictionary = {}
var _tile_labels: Dictionary = {}
var _modal_gizmo := ""

@onready var tiles: GridContainer = $Tiles
@onready var slots_label: Label = $SlotsLabel


func _ready() -> void:
	$BackButton.pressed.connect(_on_back_pressed)
	$RefreshTimer.timeout.connect(_refresh_tick)
	$CraftModal/VBox/ActionRow/ActionButton.pressed.connect(_on_modal_action_pressed)
	$CraftModal/VBox/ActionRow/CloseButton.pressed.connect(_on_modal_close_pressed)
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
		if $CraftModal.visible:
			_render_modal()
		return
	_refresh_labels(now)
	if $CraftModal.visible:
		_render_modal()


func _refresh_labels(now: int) -> void:
	slots_label.text = _slots_text()
	for gizmo_id in _tile_labels:
		var label: Label = _tile_labels[gizmo_id]
		if is_instance_valid(label):
			label.text = _tile_state_text(String(gizmo_id), now)


func _slots_text() -> String:
	var slots := CraftModel.craft_slots(GameState.data["island"])
	return "Workshop Lv %d: crafting %d/%d" % [slots, CraftModel.active_crafts(TimerService), maxi(slots, 0)] \
		if slots > 0 else "Build a Workshop on the island to craft"


func _is_locked(gizmo_id: String) -> bool:
	# An in-flight craft on a locked gizmo is grandfathered (the player already
	# paid): its tile stays tappable so the finished craft can be collected.
	return not TimerService.active_timers().has("craft_" + gizmo_id) \
		and not CraftModel.rarity_unlocked(GameState.data["island"], DataDefs.gizmos, gizmo_id)


func _tile_state_text(gizmo_id: String, now: int) -> String:
	var owned: Dictionary = GameState.data["gizmos"]["owned"]
	var def: Dictionary = (DataDefs.gizmos["defs"] as Dictionary).get(gizmo_id, {})
	var timer_id := "craft_" + gizmo_id
	if _is_locked(gizmo_id):
		var rarity := String(def.get("rarity", ""))
		var unlock_level := int((DataDefs.gizmos.get("rarity_unlocks", {}) as Dictionary).get(rarity, 0))
		return "Requires Workshop Lv %d" % unlock_level
	var text := ("Lv %d" % int(owned[gizmo_id])) if owned.has(gizmo_id) else "(not owned)"
	if TimerService.active_timers().has(timer_id):
		if TimerService.is_done(timer_id, now):
			text += "  Ready!"
		else:
			text += "  (%ds)" % TimerService.remaining(timer_id, now)
	return text


func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for currency in cost:
		parts.append("%d %s" % [int(cost[currency]), String(currency)])
	return ", ".join(parts)


func _rebuild() -> void:
	for child in tiles.get_children():
		tiles.remove_child(child)
		child.queue_free()
	_tiles.clear()
	_tile_labels.clear()
	var now := TimeUtil.now()
	_last_signature = _signature(now)
	slots_label.text = _slots_text()
	for gizmo_id in DataDefs.gizmos["defs"]:
		tiles.add_child(_make_tile(String(gizmo_id), now))


func _make_tile(gizmo_id: String, now: int) -> Button:
	var def: Dictionary = (DataDefs.gizmos["defs"] as Dictionary).get(gizmo_id, {})
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(216, 150)
	tile.pressed.connect(_on_tile_pressed.bind(gizmo_id))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var art := TextureRect.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.custom_minimum_size = Vector2(64, 64)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var art_path := "res://game/art/gizmos/%s.png" % gizmo_id
	if ResourceLoader.exists(art_path):
		art.texture = load(art_path)
	box.add_child(art)
	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text = String(def.get("name", gizmo_id))
	box.add_child(name_label)
	var state_label := Label.new()
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.text = _tile_state_text(gizmo_id, now)
	box.add_child(state_label)
	tile.add_child(box)
	if _is_locked(gizmo_id):
		tile.disabled = true
		tile.modulate.a = 0.5
	_tiles[gizmo_id] = tile
	_tile_labels[gizmo_id] = state_label
	return tile


func _on_tile_pressed(gizmo_id: String) -> void:
	if _is_locked(gizmo_id):
		return
	_modal_gizmo = gizmo_id
	$CraftModal/VBox/ModalStatus.text = ""
	_render_modal()
	$CraftModal.visible = true


func _render_modal() -> void:
	var gizmo_id := _modal_gizmo
	if gizmo_id == "":
		return
	var def: Dictionary = (DataDefs.gizmos["defs"] as Dictionary).get(gizmo_id, {})
	var owned: Dictionary = GameState.data["gizmos"]["owned"]
	var display := String(def.get("name", gizmo_id))
	var title := "%s [%s]" % [display, String(def.get("rarity", "")).capitalize()]
	title += ("  Lv %d" % int(owned[gizmo_id])) if owned.has(gizmo_id) else "  (not owned)"
	$CraftModal/VBox/ModalTitle.text = title
	var art_path := "res://game/art/gizmos/%s.png" % gizmo_id
	if ResourceLoader.exists(art_path):
		$CraftModal/VBox/ModalPicture.texture = load(art_path)
		$CraftModal/VBox/ModalPicture/PictureLetter.text = ""
	else:
		$CraftModal/VBox/ModalPicture.texture = null
		$CraftModal/VBox/ModalPicture/PictureLetter.text = display.left(1)
	$CraftModal/VBox/ModalDescription.text = String(def.get("description", ""))
	var action: Button = $CraftModal/VBox/ActionRow/ActionButton
	var timer_id := "craft_" + gizmo_id
	var now := TimeUtil.now()
	if TimerService.active_timers().has(timer_id):
		if TimerService.is_done(timer_id, now):
			$CraftModal/VBox/ModalCost.text = "Ready!"
			action.text = "Collect!"
			action.disabled = false
		else:
			$CraftModal/VBox/ModalCost.text = "Crafting... %ds" % TimerService.remaining(timer_id, now)
			action.text = "Skip (ad)"
			action.disabled = not Ads.service.is_available(AdService.Placement.TIMER_SKIP)
	elif int(owned.get(gizmo_id, 0)) >= int(DataDefs.gizmos.get("craft_max_level", 5)):
		$CraftModal/VBox/ModalCost.text = "Max level reached"
		action.text = "Craft"
		action.disabled = true
	else:
		$CraftModal/VBox/ModalCost.text = "Cost: %s" % _cost_text(def.get("craft_cost", {}))
		action.text = "Craft"
		action.disabled = false


func _on_modal_action_pressed() -> void:
	var gizmo_id := _modal_gizmo
	if gizmo_id == "" or not $CraftModal.visible:
		return
	var timer_id := "craft_" + gizmo_id
	if TimerService.active_timers().has(timer_id):
		if TimerService.is_done(timer_id, TimeUtil.now()):
			_collect(gizmo_id)
		else:
			_skip(timer_id)
	else:
		_craft(gizmo_id)
	_render_modal()


func _on_modal_close_pressed() -> void:
	$CraftModal.visible = false
	_modal_gizmo = ""


func _craft(gizmo_id: String) -> void:
	if CraftModel.start_craft(GameState.data, DataDefs.gizmos, Economy, TimerService, gizmo_id, TimeUtil.now(), DataDefs.crew):
		GameState.save_game()
	else:
		$CraftModal/VBox/ModalStatus.text = _craft_refusal_reason(gizmo_id)
	_rebuild()


func _craft_refusal_reason(gizmo_id: String) -> String:
	var island: Dictionary = GameState.data["island"]
	var def: Dictionary = (DataDefs.gizmos["defs"] as Dictionary).get(gizmo_id, {})
	if CraftModel.craft_slots(island) <= 0:
		return "Build a Workshop on the island to craft"
	if CraftModel.active_crafts(TimerService) >= CraftModel.craft_slots(island):
		return "All craft slots are busy"
	if not CraftModel.rarity_unlocked(island, DataDefs.gizmos, gizmo_id):
		return "Workshop level too low"
	if not Economy.can_afford(def.get("craft_cost", {})):
		return "Not enough resources"
	return "Cannot craft right now"


func _collect(gizmo_id: String) -> void:
	var payload := TimerService.collect("craft_" + gizmo_id, TimeUtil.now())
	if payload.is_empty():
		return
	CraftModel.complete_craft(GameState.data, payload)
	GameState.save_game()
	_rebuild()


func _on_back_pressed() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/base/island_screen.tscn")


func _skip(timer_id: String) -> void:
	if not Ads.service.is_available(AdService.Placement.TIMER_SKIP):
		return
	Ads.service.request_reward(AdService.Placement.TIMER_SKIP, _grant_skip.bind(timer_id))


func _grant_skip(timer_id: String) -> void:
	TimerService.skip(timer_id)
	GameState.save_game()
	_rebuild()
