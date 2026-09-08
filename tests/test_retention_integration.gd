extends GutTest
## End-to-end retention glue on a fake clock (spec 5, 6, 3.2): build, ad-skip,
## craft, notification planning at background time, daily ad limits rolling
## over midnight, quota tiers lifting payouts, and a future-version save
## surviving the downgrade roundtrip.

const TimerServiceScript := preload("res://game/autoload/timer_service.gd")
const EconomyScript := preload("res://game/autoload/economy.gd")
const GameStateScript := preload("res://game/autoload/game_state.gd")
const TEST_PATH := "user://test_retention.json"
const DAY := 86400
const T0 := 20834 * DAY + 3600  # 01:00 on a clean day boundary, far future

var state: Node
var econ: Node
var timers: Node


func before_each() -> void:
	_delete_test_files()
	state = autofree(GameStateScript.new())
	state._io = SaveIO.new(TEST_PATH)
	state.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	state.data["created_at"] = T0
	state.data["fuel"]["updated_at"] = T0
	state.data["currencies"]["scrap"] = 5000
	state.data["currencies"]["parts"] = 10
	econ = autofree(EconomyScript.new())
	econ.setup(state)
	timers = autofree(TimerServiceScript.new())
	timers.setup(state)

func after_all() -> void:
	_delete_test_files()

func _delete_test_files() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_retention.json", "test_retention.json.tmp", "test_retention.json.bak", "test_retention.json.incompatible"]:
		if dir.file_exists(f):
			dir.remove(f)


func test_build_skip_craft_and_notification_flywheel() -> void:
	# Build the Workshop, ad-skip the construction, collect.
	assert_true(IslandModel.start_build(state.data["island"], DataDefs.buildings, econ, timers, "plot_0", "workshop", T0))
	Ads.service.request_reward(AdService.Placement.TIMER_SKIP, func() -> void: timers.skip("build_plot_0"))
	assert_true(timers.is_done("build_plot_0", T0 + 1))
	IslandModel.complete_build(state.data["island"], timers.collect("build_plot_0", T0 + 1), state.data, T0 + 1, DataDefs.buildings)
	assert_eq(IslandModel.building_level(state.data["island"], "workshop"), 1)
	# Start a craft, drain the tank, claim the crate, then background the app:
	# the plan must cover craft, fuel, and crate.
	assert_true(CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan", T0 + 2))
	state.data["fuel"]["amount"] = 0
	state.data["fuel"]["updated_at"] = T0 + 2
	state.data["daily_crate"]["last_claim_day"] = DailyCrate.day_of(T0)
	var plan := NotificationPlanner.plan(state.data, DataDefs.buildings, DataDefs.gizmos, T0 + 2)
	var ids := []
	for entry in plan:
		ids.append(String(entry["id"]))
	ids.sort()
	assert_eq(ids, ["craft_wind_fan", "daily_crate", "fuel_full"])
	# Ad-skip the craft and merge the level.
	Ads.service.request_reward(AdService.Placement.TIMER_SKIP, func() -> void: timers.skip("craft_wind_fan"))
	CraftModel.complete_craft(state.data, timers.collect("craft_wind_fan", T0 + 3))
	assert_eq(int(state.data["gizmos"]["owned"]["wind_fan"]), 2)
	# The save roundtrips through v5 untouched.
	assert_eq(state.save_game(), OK)
	var reloaded := SaveIO.new(TEST_PATH).read()
	assert_eq(int(reloaded["version"]), SaveSchema.CURRENT_VERSION)
	assert_eq(int(reloaded["gizmos"]["owned"]["wind_fan"]), 2)

func test_ad_daily_limits_roll_over_at_midnight() -> void:
	var limit := int((DataDefs.retention["ads"] as Dictionary)["fuel_refills_per_day"])
	for i in limit:
		assert_true(AdLimits.use(state.data, "fuel_refill", limit, T0 + i))
	assert_false(AdLimits.can_use(state.data, "fuel_refill", limit, T0 + 100))
	assert_true(AdLimits.can_use(state.data, "fuel_refill", limit, T0 + DAY),
		"the next calendar day resets the counter")

func test_quota_tier_lifts_payouts_mid_run() -> void:
	var model := RunModel.new({
		"drops_per_run": 3, "max_active_pods": 4,
		"quota_tiers": [{"scrap_quota": 12, "payout_multiplier": 2.0}],
	})
	watch_signals(model)
	model.begin_drop()
	model.resolve_pod({"scrap": 12})
	assert_signal_emitted_with_parameters(model, "tier_reached", [1])
	assert_eq(model.payout_multiplier(), 2.0, "later catches pay double")

func test_future_save_survives_the_downgrade_roundtrip() -> void:
	var io := SaveIO.new(TEST_PATH)
	io.write({"version": SaveSchema.CURRENT_VERSION + 1, "precious": true})
	state.load_game(DataDefs.economy, T0, DataDefs.gizmos, DataDefs.buildings)
	assert_eq(int(state.data["version"]), SaveSchema.CURRENT_VERSION, "playable defaults")
	var parked: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH + ".incompatible"))
	assert_true(bool((parked as Dictionary)["precious"]),
		"the newer save is parked, not destroyed (spec 7.3)")
