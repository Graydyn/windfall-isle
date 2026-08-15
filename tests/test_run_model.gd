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
