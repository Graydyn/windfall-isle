extends GutTest


func fresh_state() -> Dictionary:
	return {"owned": {"wind_fan": 1, "balloon_cluster": 2}, "loadout": {}}


func test_owned_reads_levels() -> void:
	assert_eq(GizmoLoadout.owned(fresh_state()), {"wind_fan": 1, "balloon_cluster": 2})
	assert_eq(GizmoLoadout.owned({}), {})

func test_set_slot_and_loadout_for() -> void:
	var state := fresh_state()
	assert_true(GizmoLoadout.set_slot(state, "region_1", "slot_0", "wind_fan"))
	assert_eq(GizmoLoadout.loadout_for(state, "region_1"), {"slot_0": "wind_fan"})
	assert_eq(GizmoLoadout.loadout_for(state, "region_2"), {})

func test_set_slot_rejects_unowned() -> void:
	var state := fresh_state()
	assert_false(GizmoLoadout.set_slot(state, "region_1", "slot_0", "chime_bell"))
	assert_eq(GizmoLoadout.loadout_for(state, "region_1"), {})

func test_set_slot_rejects_double_slotting() -> void:
	var state := fresh_state()
	GizmoLoadout.set_slot(state, "region_1", "slot_0", "wind_fan")
	assert_false(GizmoLoadout.set_slot(state, "region_1", "slot_1", "wind_fan"),
		"one owned copy occupies one slot")
	assert_true(GizmoLoadout.set_slot(state, "region_1", "slot_0", "wind_fan"),
		"re-setting the same slot is allowed")

func test_clear_slot() -> void:
	var state := fresh_state()
	GizmoLoadout.set_slot(state, "region_1", "slot_0", "wind_fan")
	assert_true(GizmoLoadout.set_slot(state, "region_1", "slot_0", ""))
	assert_eq(GizmoLoadout.loadout_for(state, "region_1"), {})

func test_next_choice_cycles_and_skips_used() -> void:
	var owned_ids := ["wind_fan", "balloon_cluster", "crystal_prism"]
	assert_eq(GizmoLoadout.next_choice("", owned_ids, []), "wind_fan")
	assert_eq(GizmoLoadout.next_choice("wind_fan", owned_ids, []), "balloon_cluster")
	assert_eq(GizmoLoadout.next_choice("crystal_prism", owned_ids, []), "")
	assert_eq(GizmoLoadout.next_choice("", owned_ids, ["wind_fan"]), "balloon_cluster",
		"ids used in other slots are skipped")
	assert_eq(GizmoLoadout.next_choice("wind_fan", owned_ids, ["balloon_cluster", "crystal_prism"]), "",
		"current id cycles out even when everything else is used")


func test_place_seats_into_an_empty_slot() -> void:
	var state := fresh_state()
	assert_true(GizmoLoadout.place(state, "region_1", "slot_0", "wind_fan"))
	assert_eq(GizmoLoadout.loadout_for(state, "region_1"), {"slot_0": "wind_fan"})

func test_place_moves_between_slots_clearing_the_old_one() -> void:
	var state := fresh_state()
	GizmoLoadout.place(state, "region_1", "slot_0", "wind_fan")
	assert_true(GizmoLoadout.place(state, "region_1", "slot_1", "wind_fan"))
	assert_eq(GizmoLoadout.loadout_for(state, "region_1"), {"slot_1": "wind_fan"},
		"a move never leaves the gizmo doubled")

func test_place_overwrites_an_occupied_slot() -> void:
	var state := fresh_state()
	GizmoLoadout.place(state, "region_1", "slot_0", "wind_fan")
	assert_true(GizmoLoadout.place(state, "region_1", "slot_0", "balloon_cluster"))
	assert_eq(GizmoLoadout.loadout_for(state, "region_1"), {"slot_0": "balloon_cluster"},
		"the displaced gizmo simply stops being slotted")

func test_place_rejects_unowned_and_empty_ids() -> void:
	var state := fresh_state()
	assert_false(GizmoLoadout.place(state, "region_1", "slot_0", "chime_bell"))
	assert_false(GizmoLoadout.place(state, "region_1", "slot_0", ""),
		"removal goes through set_slot, never place")
	assert_eq(GizmoLoadout.loadout_for(state, "region_1"), {})

func test_place_move_and_overwrite_compose() -> void:
	var state := fresh_state()
	GizmoLoadout.place(state, "region_1", "slot_0", "wind_fan")
	GizmoLoadout.place(state, "region_1", "slot_1", "balloon_cluster")
	assert_true(GizmoLoadout.place(state, "region_1", "slot_1", "wind_fan"),
		"dragging wind_fan onto the occupied slot_1 seats it there")
	assert_eq(GizmoLoadout.loadout_for(state, "region_1"), {"slot_1": "wind_fan"},
		"balloon_cluster was un-seated and slot_0 emptied in one drop")
