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
