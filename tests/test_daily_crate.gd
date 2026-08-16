extends GutTest


func test_day_of() -> void:
	assert_eq(DailyCrate.day_of(0), 0)
	assert_eq(DailyCrate.day_of(86399), 0)
	assert_eq(DailyCrate.day_of(86400), 1)

func test_claim_once_per_calendar_day() -> void:
	var data := SaveSchema.default_data(DataDefs.economy)
	var now := 86400 * 100 + 500
	assert_true(DailyCrate.can_claim(data, now))
	var payout := DailyCrate.claim(data, DataDefs.retention, now)
	assert_eq(int(payout["scrap"]), 40)
	assert_eq(int(payout["crystals"]), 1)
	assert_false(DailyCrate.can_claim(data, now + 100))
	assert_eq(DailyCrate.claim(data, DataDefs.retention, now + 100), {})
	assert_true(DailyCrate.can_claim(data, now + 86400), "next calendar day, no streak punishment")
