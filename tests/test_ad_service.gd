extends GutTest


func test_base_service_is_never_available() -> void:
	var svc := AdService.new()
	assert_false(svc.is_available(AdService.Placement.FUEL_REFILL))

func test_base_service_never_grants() -> void:
	var svc := AdService.new()
	var granted := [false]
	svc.request_reward(AdService.Placement.FUEL_REFILL, func() -> void: granted[0] = true)
	assert_false(granted[0])

func test_grant_service_is_always_available() -> void:
	var svc := GrantAdService.new()
	assert_true(svc.is_available(AdService.Placement.TIMER_SKIP))

func test_grant_service_grants_immediately() -> void:
	var svc := GrantAdService.new()
	var granted := [false]
	svc.request_reward(AdService.Placement.PAYOUT_DOUBLE, func() -> void: granted[0] = true)
	assert_true(granted[0])

func test_ads_autoload_serves_grant_implementation_in_mvp() -> void:
	assert_true(Ads.service is GrantAdService)
