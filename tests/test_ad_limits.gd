extends GutTest

const NOW := 1_800_000_000


func make_data() -> Dictionary:
	return SaveSchema.default_data({}, {})


func test_fresh_data_allows_use_under_limit() -> void:
	assert_true(AdLimits.can_use(make_data(), "fuel_refill", 2, NOW))
	assert_eq(AdLimits.used(make_data(), "fuel_refill", NOW), 0)

func test_use_counts_up_to_the_limit() -> void:
	var data := make_data()
	assert_true(AdLimits.use(data, "fuel_refill", 2, NOW))
	assert_true(AdLimits.use(data, "fuel_refill", 2, NOW))
	assert_false(AdLimits.use(data, "fuel_refill", 2, NOW), "third use is over the cap")
	assert_eq(AdLimits.used(data, "fuel_refill", NOW), 2, "a rejected use never counts")

func test_placements_have_independent_counters() -> void:
	var data := make_data()
	assert_true(AdLimits.use(data, "fuel_refill", 1, NOW))
	assert_true(AdLimits.use(data, "bonus_crate", 1, NOW),
		"the fuel counter does not spend the crate counter")

func test_midnight_rollover_resets_counts() -> void:
	var data := make_data()
	assert_true(AdLimits.use(data, "bonus_crate", 1, NOW))
	assert_false(AdLimits.can_use(data, "bonus_crate", 1, NOW + 100))
	assert_true(AdLimits.can_use(data, "bonus_crate", 1, NOW + DailyCrate.SECONDS_PER_DAY),
		"fresh calendar day, fresh limit")
	assert_eq(AdLimits.used(data, "bonus_crate", NOW + DailyCrate.SECONDS_PER_DAY), 0)

func test_missing_ads_section_self_heals() -> void:
	var data := {"version": 5}
	assert_true(AdLimits.use(data, "fuel_refill", 1, NOW))
	assert_eq(int(((data["ads"] as Dictionary)["counts"] as Dictionary)["fuel_refill"]), 1)

func test_retention_defs_carry_ad_limits() -> void:
	var ads: Dictionary = DataDefs.retention.get("ads", {})
	assert_eq(int(ads.get("fuel_refills_per_day", 0)), 2)
	assert_eq(int(ads.get("bonus_crates_per_day", 0)), 1)
