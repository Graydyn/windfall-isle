extends GutTest


func fresh_data() -> Dictionary:
	var data := SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	data["trickle"]["last_collect"] = 10000
	return data


func rescue_all(data: Dictionary) -> void:
	for row_v in CrewModel.members(DataDefs.crew):
		CrewModel.rescue(data, String((row_v as Dictionary).get("id", "")))


func test_fresh_save_has_nobody() -> void:
	var data := fresh_data()
	assert_eq(CrewModel.rescued_ids(data, DataDefs.crew), [] as Array[String])
	assert_eq((CrewModel.unrescued_ids(data, DataDefs.crew) as Array).size(), 8)

func test_rescue_marks_and_is_idempotent() -> void:
	var data := fresh_data()
	assert_true(CrewModel.rescue(data, "odo"))
	assert_true(CrewModel.rescue(data, "odo"))
	assert_true(CrewModel.is_rescued(data, "odo"))
	assert_false(CrewModel.rescue(data, ""), "empty id is rejected")
	assert_eq((CrewModel.rescued_ids(data, DataDefs.crew) as Array).size(), 1)

func test_rescue_heals_a_wrong_typed_section() -> void:
	var data := fresh_data()
	data["crew"] = 7
	assert_true(CrewModel.rescue(data, "odo"))
	assert_true(CrewModel.is_rescued(data, "odo"),
		"write-back discipline: the mangled section is rebuilt in place")

func test_assign_requires_rescued_and_workable() -> void:
	var data := fresh_data()
	assert_false(CrewModel.assign(data, DataDefs.crew, "gardens", "odo"), "not rescued yet")
	CrewModel.rescue(data, "odo")
	assert_false(CrewModel.assign(data, DataDefs.crew, "observatory", "odo"), "not workable")
	assert_true(CrewModel.assign(data, DataDefs.crew, "gardens", "odo"))
	assert_eq(CrewModel.crew_at(data, "gardens"), "odo")
	assert_eq(CrewModel.building_of(data, "odo"), "gardens")

func test_assign_moves_and_displaces() -> void:
	var data := fresh_data()
	rescue_all(data)
	CrewModel.assign(data, DataDefs.crew, "gardens", "odo")
	assert_true(CrewModel.assign(data, DataDefs.crew, "workshop", "odo"), "a move")
	assert_eq(CrewModel.crew_at(data, "gardens"), "", "the old post empties")
	CrewModel.assign(data, DataDefs.crew, "workshop", "maren")
	assert_eq(CrewModel.crew_at(data, "workshop"), "maren", "the newcomer takes the post")
	assert_eq(CrewModel.building_of(data, "odo"), "", "the displaced crew is idle, not duplicated")

func test_unassign_clears() -> void:
	var data := fresh_data()
	rescue_all(data)
	CrewModel.assign(data, DataDefs.crew, "gardens", "odo")
	CrewModel.unassign(data, DataDefs.crew, "gardens")
	assert_eq(CrewModel.crew_at(data, "gardens"), "")

func test_multiplier_tiers() -> void:
	var data := fresh_data()
	rescue_all(data)
	assert_almost_eq(CrewModel.multiplier_for(data, DataDefs.crew, "gardens"), 1.0, 0.001, "unmanned")
	CrewModel.assign(data, DataDefs.crew, "gardens", "maren")
	assert_almost_eq(CrewModel.multiplier_for(data, DataDefs.crew, "gardens"), 1.25, 0.001,
		"Maren is a workshop specialist, a generalist in the gardens")
	CrewModel.assign(data, DataDefs.crew, "gardens", "odo")
	assert_almost_eq(CrewModel.multiplier_for(data, DataDefs.crew, "gardens"), 1.5, 0.001,
		"Odo is a gardens specialist")

func test_assignment_flip_preserves_pending_trickle_value() -> void:
	var data := fresh_data()
	rescue_all(data)
	var now := 10000 + 3600
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, now, DataDefs.crew), 20, "1h unmanned at Lv1")
	assert_true(CrewModel.assign(data, DataDefs.crew, "gardens", "odo", DataDefs.buildings, now))
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, now, DataDefs.crew), 20,
		"the flip must not re-rate scrap already accrued")
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, now + 3600, DataDefs.crew), 20 + 30,
		"the next hour accrues at the 1.5x specialist rate")

func test_unassign_rebases_too() -> void:
	var data := fresh_data()
	rescue_all(data)
	CrewModel.assign(data, DataDefs.crew, "gardens", "odo", DataDefs.buildings, 10000)
	var now := 10000 + 3600
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, now, DataDefs.crew), 30, "1h at 1.5x")
	CrewModel.unassign(data, DataDefs.crew, "gardens", DataDefs.buildings, now)
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, now, DataDefs.crew), 30,
		"accrued value survives the departure")
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, now + 3600, DataDefs.crew), 30 + 20,
		"the next hour is back to baseline")

func test_non_gardens_assignment_does_not_touch_the_trickle_clock() -> void:
	var data := fresh_data()
	rescue_all(data)
	var stamp := int(data["trickle"]["last_collect"])
	CrewModel.assign(data, DataDefs.crew, "workshop", "maren", DataDefs.buildings, 99999)
	assert_eq(int(data["trickle"]["last_collect"]), stamp,
		"only a gardens-rate change rebases the clock")
