extends Control
## Pre-run gizmo slotting (spec 3.3): one row per skyfield slot; tapping a
## row cycles through the owned gizmos not already used in another slot.
## Placement is the player's skill expression, so this screen stays dumb:
## all rules live in GizmoLoadout.

var region_id := "region_1"

var _slots: Array = []

@onready var rows: VBoxContainer = $Rows


func _ready() -> void:
	var region: Dictionary = DataDefs.skyfield(region_id)
	_slots = []
	for i in (region.get("gizmo_slots", []) as Array).size():
		_slots.append("slot_%d" % i)
	$BackButton.pressed.connect(_on_back_pressed)
	_rebuild()


func _rebuild() -> void:
	for child in rows.get_children():
		child.queue_free()
	var loadout := GizmoLoadout.loadout_for(GameState.data["gizmos"], region_id)
	for slot in _slots:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 72)
		button.text = _row_text(slot, String(loadout.get(slot, "")))
		button.pressed.connect(_on_slot_pressed.bind(slot))
		rows.add_child(button)


func _row_text(slot: String, gizmo_id: String) -> String:
	if gizmo_id == "":
		return "%s: (empty)" % slot
	var def: Dictionary = (DataDefs.gizmos.get("defs", {}) as Dictionary).get(gizmo_id, {})
	var level := int(GizmoLoadout.owned(GameState.data["gizmos"]).get(gizmo_id, 1))
	return "%s: %s (Lv %d)" % [slot, String(def.get("name", gizmo_id)), level]


func _on_slot_pressed(slot: String) -> void:
	var gizmos_state: Dictionary = GameState.data["gizmos"]
	var loadout := GizmoLoadout.loadout_for(gizmos_state, region_id)
	var used: Array = []
	for other_slot in loadout:
		if other_slot != slot:
			used.append(loadout[other_slot])
	var next := GizmoLoadout.next_choice(String(loadout.get(slot, "")), GizmoLoadout.owned(gizmos_state).keys(), used)
	GizmoLoadout.set_slot(gizmos_state, region_id, slot, next)
	_rebuild()


func _on_back_pressed() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/main.tscn")
