extends GutTest


func make_data(gardens_level: int, last_collect: int) -> Dictionary:
	var data := SaveSchema.default_data(DataDefs.economy)
	if gardens_level > 0:
		data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": gardens_level}
	data["trickle"]["last_collect"] = last_collect
	return data


func test_no_gardens_no_trickle() -> void:
	var data := make_data(0, 0)
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, 999999), 0)

func test_pending_accrues_per_hour_and_caps() -> void:
	var data := make_data(1, 10000)
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, 10000 + 3600), 20, "20/hour at level 1")
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, 10000 + 1800), 10, "half an hour")
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, 10000 + 3600 * 50), 160,
		"capped at 8 hours worth (spec 5: capped, must collect)")

func test_level_scales_rate() -> void:
	var data := make_data(3, 10000)
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, 10000 + 3600), 60)

func test_collect_returns_and_restamps() -> void:
	var data := make_data(1, 10000)
	assert_eq(TrickleModel.collect(data, DataDefs.buildings, 10000 + 3600), 20)
	assert_eq(int(data["trickle"]["last_collect"]), 10000 + 3600)
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, 10000 + 3600), 0)

func test_crewed_gardens_trickles_faster() -> void:
	var data := make_data(1, 10000)
	CrewModel.rescue(data, "odo")
	(data["crew"]["assignments"] as Dictionary)["gardens"] = "odo"
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, 10000 + 3600, DataDefs.crew), 30,
		"20/hour x 1.5 specialist")
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, 10000 + 3600), 20,
		"callers without crew defs still get the baseline rate")

func test_upgrade_rebase_respects_the_crew_rate() -> void:
	var data := make_data(1, 10000)
	CrewModel.rescue(data, "odo")
	(data["crew"]["assignments"] as Dictionary)["gardens"] = "odo"
	var now := 10000 + 3600
	var pending_before := TrickleModel.pending(data, DataDefs.buildings, now, DataDefs.crew)
	IslandModel.complete_build(data["island"],
		{"plot": "plot_2", "building": "gardens", "to_level": 2}, data, now, DataDefs.buildings, DataDefs.crew)
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, now, DataDefs.crew), pending_before,
		"the upgrade rebase must price the carried value at the crewed rate")

func test_rebase_preserving_relocates_the_clock() -> void:
	var data := make_data(1, 10000)
	var now := 10000 + 1800
	TrickleModel.rebase_preserving(data, DataDefs.buildings, {}, now, 10)
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, now), 10, "value preserved at the current rate")
	TrickleModel.rebase_preserving(data, {}, {}, now, 999)
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, now), 10, "empty defs is a no-op")
