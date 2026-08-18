extends GutTest


func make_model(drops := 3, cap := 2) -> RunModel:
	return RunModel.new({"drops_per_run": drops, "max_active_pods": cap})


func test_init_from_config() -> void:
	var model := make_model(8, 4)
	assert_eq(model.drops_remaining(), 8)
	assert_true(model.can_drop())
	assert_false(model.is_over())

func test_begin_drop_consumes_a_drop() -> void:
	var model := make_model()
	assert_true(model.begin_drop())
	assert_eq(model.drops_remaining(), 2)

func test_pod_cap_blocks_drops() -> void:
	var model := make_model(3, 2)
	model.begin_drop()
	model.begin_drop()
	assert_false(model.can_drop(), "2 pods in flight at cap 2")
	assert_false(model.begin_drop())
	model.resolve_pod({"scrap": 1})
	assert_true(model.can_drop(), "capacity freed after resolve")

func test_resolve_accumulates_multi_currency_loot() -> void:
	var model := make_model()
	model.begin_drop()
	model.resolve_pod({"scrap": 7, "cloudsilk": 1})
	model.begin_drop()
	model.resolve_pod({"scrap": 4})
	assert_eq(model.loot, {"scrap": 11, "cloudsilk": 1})

func test_loot_changed_emitted_on_resolve() -> void:
	var model := make_model()
	watch_signals(model)
	model.begin_drop()
	model.resolve_pod({"scrap": 2})
	assert_signal_emitted_with_parameters(model, "loot_changed", [{"scrap": 2}])

func test_run_over_after_last_pod_resolves() -> void:
	var model := make_model(1, 2)
	watch_signals(model)
	model.begin_drop()
	assert_false(model.is_over(), "pod still in flight")
	model.resolve_pod({"scrap": 1})
	assert_true(model.is_over())
	assert_signal_emit_count(model, "run_over", 1)

func test_abandon_ends_run_once_and_keeps_loot() -> void:
	var model := make_model()
	watch_signals(model)
	model.begin_drop()
	model.resolve_pod({"scrap": 5})
	model.abandon()
	model.abandon()
	assert_true(model.is_over())
	assert_signal_emit_count(model, "run_over", 1)
	assert_eq(model.loot, {"scrap": 5}, "abandon never touches collected loot (spec 3.2)")
	assert_false(model.can_drop())

func test_resolve_after_abandon_still_banks_loot() -> void:
	var model := make_model()
	model.begin_drop()
	model.abandon()
	model.resolve_pod({"scrap": 3})
	assert_eq(model.loot, {"scrap": 3}, "a pod already falling at abandon still pays out")

func test_add_bonus_loot_accumulates_without_pod_bookkeeping() -> void:
	var model := make_model()
	watch_signals(model)
	model.begin_drop()
	model.add_bonus_loot({"scrap": 6})
	assert_eq(model.loot, {"scrap": 6})
	assert_eq(model.drops_remaining(), 2, "bonus loot consumes no drops")
	assert_eq(model.pods_in_flight, 1, "bonus loot resolves no pods")
	assert_signal_emitted(model, "loot_changed")

func test_add_split_pod_respects_cap_and_flight() -> void:
	var model := make_model(3, 2)
	assert_false(model.add_split_pod(), "nothing in flight yet")
	model.begin_drop()
	assert_true(model.add_split_pod())
	assert_eq(model.pods_in_flight, 2)
	assert_false(model.add_split_pod(), "at cap 2")

func test_split_pod_extends_run_until_both_resolve() -> void:
	var model := make_model(1, 4)
	model.begin_drop()
	model.add_split_pod()
	model.resolve_pod({"scrap": 1})
	assert_false(model.is_over(), "the split twin is still falling")
	model.resolve_pod({"scrap": 1})
	assert_true(model.is_over())

func make_tiered(drops := 8) -> RunModel:
	return RunModel.new({
		"drops_per_run": drops,
		"max_active_pods": 4,
		"quota_tiers": [
			{"scrap_quota": 10, "payout_multiplier": 1.5},
			{"scrap_quota": 30, "payout_multiplier": 2.0},
		],
	})


func test_tier_starts_at_zero_with_no_multiplier() -> void:
	var model := make_tiered()
	assert_eq(model.tier, 0)
	assert_eq(model.payout_multiplier(), 1.0)

func test_reaching_scrap_quota_lifts_tier() -> void:
	var model := make_tiered()
	watch_signals(model)
	model.begin_drop()
	model.resolve_pod({"scrap": 10})
	assert_eq(model.tier, 1)
	assert_eq(model.payout_multiplier(), 1.5)
	assert_signal_emitted_with_parameters(model, "tier_reached", [1])

func test_one_catch_can_cross_multiple_tiers() -> void:
	var model := make_tiered()
	watch_signals(model)
	model.begin_drop()
	model.resolve_pod({"scrap": 45})
	assert_eq(model.tier, 2)
	assert_eq(model.payout_multiplier(), 2.0)
	assert_signal_emit_count(model, "tier_reached", 2)

func test_bonus_loot_counts_toward_quota() -> void:
	var model := make_tiered()
	model.add_bonus_loot({"scrap": 10})
	assert_eq(model.tier, 1, "Lightning Jar bonuses are salvage too")

func test_non_scrap_loot_ignores_quota() -> void:
	var model := make_tiered()
	model.begin_drop()
	model.resolve_pod({"cloudsilk": 50})
	assert_eq(model.tier, 0, "the quota is measured in scrap (spec 4.2 common currency)")

func test_no_tiers_config_never_lifts() -> void:
	var model := make_model()
	model.begin_drop()
	model.resolve_pod({"scrap": 999})
	assert_eq(model.tier, 0)
	assert_eq(model.payout_multiplier(), 1.0)

func test_malformed_tier_rows_are_dropped_with_a_warning() -> void:
	var model := RunModel.new({
		"drops_per_run": 3, "max_active_pods": 4,
		"quota_tiers": [
			{"payout_multiplier": 9.0},
			{"scrap_quota": 0, "payout_multiplier": 9.0},
			{"scrap_quota": 10, "payout_multiplier": 1.5},
			"junk",
		],
	})
	assert_push_warning_count(3, "one warning per dropped row")
	assert_eq(model.tiers.size(), 1, "only the well-formed row survives")
	model.begin_drop()
	model.resolve_pod({"scrap": 5})
	assert_eq(model.tier, 0, "a zero-quota row must never lift at 0 scrap")
	model.begin_drop()
	model.resolve_pod({"scrap": 5})
	assert_eq(model.tier, 1)
	assert_eq(model.payout_multiplier(), 1.5)

func test_non_ascending_quota_tiers_warn_but_load() -> void:
	var model := RunModel.new({
		"drops_per_run": 3, "max_active_pods": 4,
		"quota_tiers": [
			{"scrap_quota": 80, "payout_multiplier": 2.0},
			{"scrap_quota": 35, "payout_multiplier": 1.5},
		],
	})
	assert_push_warning_count(1, "one warning per out-of-order pair")
	assert_eq(model.tiers.size(), 2, "authoring warning only; rows still load")


const BOON_DEFS := {
	"defs": {
		"barge_bounty": {"name": "Barge Bounty", "barge_multiplier": 1.5},
		"rich_seas": {"name": "Rich Seas", "sea_multiplier": 3.0},
		"spare_pods": {"name": "Spare Pods", "extra_drops": 2},
		"heavy_loot": {"name": "Heavy Loot", "bonus_scrap_per_catch": 2},
		"featherfall": {"name": "Featherfall", "bounce_bonus": 0.2},
		"second_wind": {"name": "Second Wind"},
	},
}


func test_boon_accessors_default_neutral() -> void:
	var model := make_model()
	assert_eq(model.barge_boon_multiplier(), 1.0)
	assert_eq(model.sea_boon_multiplier(), 1.0)
	assert_eq(model.bonus_scrap_per_catch(), 0)
	assert_false(model.has_boon("barge_bounty"))

func test_add_boon_captures_magnitudes() -> void:
	var model := make_model()
	model.add_boon("barge_bounty", BOON_DEFS)
	model.add_boon("rich_seas", BOON_DEFS)
	model.add_boon("heavy_loot", BOON_DEFS)
	assert_true(model.has_boon("barge_bounty"))
	assert_almost_eq(model.barge_boon_multiplier(), 1.5, 0.001)
	assert_almost_eq(model.sea_boon_multiplier(), 3.0, 0.001)
	assert_eq(model.bonus_scrap_per_catch(), 2)
	assert_eq(model.boons, ["barge_bounty", "rich_seas", "heavy_loot"], "pick order preserved")

func test_spare_pods_extends_the_run_immediately() -> void:
	var model := make_model(3)
	model.add_boon("spare_pods", BOON_DEFS)
	assert_eq(model.drops_remaining(), 5)

func test_duplicate_boon_is_a_no_op() -> void:
	var model := make_model()
	model.add_boon("heavy_loot", BOON_DEFS)
	model.add_boon("heavy_loot", BOON_DEFS)
	assert_eq(model.bonus_scrap_per_catch(), 2, "magnitudes never stack")
	assert_eq(model.boons.size(), 1)

func test_add_drops_is_negative_safe() -> void:
	var model := make_model(3)
	model.add_drops(-5)
	assert_eq(model.drops_remaining(), 3)

func test_scene_only_boons_record_without_magnitudes() -> void:
	var model := make_model()
	model.add_boon("featherfall", BOON_DEFS)
	model.add_boon("second_wind", BOON_DEFS)
	assert_true(model.has_boon("featherfall"))
	assert_true(model.has_boon("second_wind"))
	assert_eq(model.barge_boon_multiplier(), 1.0, "no payout magnitudes on scene-side boons")
