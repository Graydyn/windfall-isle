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
