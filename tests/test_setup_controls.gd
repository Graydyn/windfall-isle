extends GutTest


func make_chip(id: String, source_slot: String) -> GizmoChip:
	var chip: GizmoChip = autofree(GizmoChip.new())
	chip.setup(id, "%s display" % id, source_slot)
	return chip


func test_chip_drag_payload_carries_id_and_source() -> void:
	var chip := make_chip("wind_fan", "")
	assert_eq(chip._get_drag_data(Vector2.ZERO), {"gizmo": "wind_fan", "from_slot": ""})
	var token := make_chip("wind_fan", "slot_2")
	assert_eq(token._get_drag_data(Vector2.ZERO), {"gizmo": "wind_fan", "from_slot": "slot_2"})

func test_dimmed_chip_does_not_drag() -> void:
	var chip := make_chip("wind_fan", "")
	chip.set_dimmed(true)
	assert_eq(chip._get_drag_data(Vector2.ZERO), null, "a placed gizmo's tray chip is inert")
	chip.set_dimmed(false)
	assert_eq(chip._get_drag_data(Vector2.ZERO), {"gizmo": "wind_fan", "from_slot": ""})

func test_chip_receives_mouse() -> void:
	var chip := make_chip("wind_fan", "")
	assert_eq(chip.mouse_filter, Control.MOUSE_FILTER_STOP,
		"Labels default to IGNORE; a chip must receive the drag press")

func test_slot_target_accepts_gizmo_payloads_only() -> void:
	var target: SlotTarget = autofree(SlotTarget.new())
	target.setup("slot_0", Callable())
	assert_true(target._can_drop_data(Vector2.ZERO, {"gizmo": "wind_fan", "from_slot": ""}))
	assert_true(target._can_drop_data(Vector2.ZERO, {"gizmo": "wind_fan", "from_slot": "slot_1"}))
	assert_false(target._can_drop_data(Vector2.ZERO, {"gizmo": ""}))
	assert_false(target._can_drop_data(Vector2.ZERO, "wind_fan"))
	assert_false(target._can_drop_data(Vector2.ZERO, 7))

func test_tray_target_accepts_only_placed_gizmos() -> void:
	var tray: SlotTarget = autofree(SlotTarget.new())
	tray.setup("", Callable())
	assert_false(tray._can_drop_data(Vector2.ZERO, {"gizmo": "wind_fan", "from_slot": ""}),
		"dropping a tray chip back onto the tray is a no-op")
	assert_true(tray._can_drop_data(Vector2.ZERO, {"gizmo": "wind_fan", "from_slot": "slot_0"}),
		"a placed gizmo dragged to the tray is a removal")

func test_drop_delegates_payload_and_slot() -> void:
	var seen: Array = []
	var target: SlotTarget = autofree(SlotTarget.new())
	target.setup("slot_3", func(payload: Dictionary, slot: String) -> void: seen.append([payload, slot]))
	target._drop_data(Vector2.ZERO, {"gizmo": "wind_fan", "from_slot": ""})
	assert_eq(seen, [[{"gizmo": "wind_fan", "from_slot": ""}, "slot_3"]])
