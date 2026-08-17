extends GutTest

const NOW := 1_800_000_000


class RecordingScheduler:
	extends NotificationScheduler
	var scheduled: Array = []
	var cancel_calls := 0
	var permission_calls := 0

	func schedule(id: String, title: String, body: String, fire_at: int) -> void:
		scheduled.append({"id": id, "title": title, "body": body, "fire_at": fire_at})

	func cancel_all() -> void:
		cancel_calls += 1

	func request_permission() -> void:
		permission_calls += 1


func make_data() -> Dictionary:
	var data := SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	data["created_at"] = NOW
	data["fuel"]["updated_at"] = NOW
	return data


func after_all() -> void:
	NotificationSvc.scheduler = NotificationScheduler.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings)


func test_planner_covers_all_four_return_hooks() -> void:
	var data := make_data()
	data["timers"]["build_plot_0"] = {"kind": "construction", "ends_at": NOW + 600, "payload": {"plot": "plot_0", "building": "wind_still", "to_level": 1}}
	data["timers"]["craft_wind_fan"] = {"kind": "craft", "ends_at": NOW + 120, "payload": {"gizmo": "wind_fan"}}
	data["fuel"]["amount"] = 0
	data["daily_crate"]["last_claim_day"] = DailyCrate.day_of(NOW)
	var plan := NotificationPlanner.plan(data, DataDefs.buildings, DataDefs.gizmos, NOW)
	var ids := []
	for entry in plan:
		ids.append(String(entry["id"]))
	ids.sort()
	assert_eq(ids, ["build_plot_0", "craft_wind_fan", "daily_crate", "fuel_full"],
		"spec 5: construction, craft, fuel full, daily crate")

func test_construction_entry_names_the_building_and_fires_at_ends_at() -> void:
	var data := make_data()
	data["timers"]["build_plot_0"] = {"kind": "construction", "ends_at": NOW + 600, "payload": {"plot": "plot_0", "building": "wind_still", "to_level": 1}}
	var plan := NotificationPlanner.plan(data, DataDefs.buildings, DataDefs.gizmos, NOW)
	assert_eq(plan.size(), 1, "full tank and claimable crate add nothing")
	assert_string_contains(String(plan[0]["body"]), "Wind Still")
	assert_eq(int(plan[0]["fire_at"]), NOW + 600)

func test_fuel_entry_fire_time_matches_the_model() -> void:
	var data := make_data()
	data["fuel"]["amount"] = 3
	var plan := NotificationPlanner.plan(data, DataDefs.buildings, DataDefs.gizmos, NOW)
	assert_eq(plan.size(), 1)
	assert_eq(String(plan[0]["id"]), "fuel_full")
	assert_eq(int(plan[0]["fire_at"]), NOW + FuelModel.seconds_until_full(data["fuel"], NOW))

func test_crate_entry_fires_at_next_day_boundary() -> void:
	var data := make_data()
	data["daily_crate"]["last_claim_day"] = DailyCrate.day_of(NOW)
	var plan := NotificationPlanner.plan(data, DataDefs.buildings, DataDefs.gizmos, NOW)
	assert_eq(plan.size(), 1)
	assert_eq(String(plan[0]["id"]), "daily_crate")
	assert_eq(int(plan[0]["fire_at"]), (DailyCrate.day_of(NOW) + 1) * DailyCrate.SECONDS_PER_DAY)

func test_fresh_state_plans_nothing() -> void:
	var plan := NotificationPlanner.plan(make_data(), DataDefs.buildings, DataDefs.gizmos, NOW)
	assert_eq(plan, [], "full tank, claimable crate, no timers: nothing to say")

func test_already_elapsed_timers_are_skipped() -> void:
	var data := make_data()
	data["timers"]["build_plot_0"] = {"kind": "construction", "ends_at": NOW - 5, "payload": {"plot": "plot_0", "building": "dock", "to_level": 1}}
	var plan := NotificationPlanner.plan(data, DataDefs.buildings, DataDefs.gizmos, NOW)
	assert_eq(plan, [], "a done timer is collected in-app, never notified")

func test_svc_reschedules_from_scratch_and_cancels_on_resume() -> void:
	var rec := RecordingScheduler.new()
	NotificationSvc.scheduler = rec
	var data := make_data()
	data["timers"]["build_plot_0"] = {"kind": "construction", "ends_at": NOW + 600, "payload": {"plot": "plot_0", "building": "dock", "to_level": 1}}
	data["fuel"]["amount"] = 0
	GameState.data = data
	NotificationSvc.schedule_all(NOW)
	assert_eq(rec.cancel_calls, 1, "always cancel before scheduling")
	assert_eq(rec.scheduled.size(), 2)
	NotificationSvc.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert_eq(rec.cancel_calls, 2, "resume clears pending notifications (spec 5)")

func test_svc_schedules_on_application_pause() -> void:
	var rec := RecordingScheduler.new()
	NotificationSvc.scheduler = rec
	var data := make_data()
	data["fuel"]["amount"] = 0
	GameState.data = data
	NotificationSvc.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(rec.scheduled.size(), 1, "fuel-full is the only pending hook")

func test_permission_requested_only_once() -> void:
	var rec := RecordingScheduler.new()
	NotificationSvc.scheduler = rec
	GameState.data = make_data()
	NotificationSvc.request_permission_once()
	NotificationSvc.request_permission_once()
	assert_eq(rec.permission_calls, 1)
	assert_true(bool(GameState.data["notifications"]["permission_requested"]))
