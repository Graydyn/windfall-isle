extends GutTest


func make_fuel(amount: int, cap := 5, regen := 1200, updated_at := 1000) -> Dictionary:
	return {"amount": amount, "cap": cap, "regen_seconds": regen, "updated_at": updated_at}


func test_full_tank_stays_full() -> void:
	var fuel := make_fuel(5)
	assert_eq(FuelModel.current(fuel, 1000 + 999999), 5)

func test_regenerates_one_unit_per_interval() -> void:
	var fuel := make_fuel(2)
	assert_eq(FuelModel.current(fuel, 1000 + 1200), 3)
	assert_eq(FuelModel.current(fuel, 1000 + 2399), 3)
	assert_eq(FuelModel.current(fuel, 1000 + 2400), 4)

func test_regen_never_exceeds_cap() -> void:
	var fuel := make_fuel(2)
	assert_eq(FuelModel.current(fuel, 1000 + 1200 * 50), 5)

func test_materialize_preserves_partial_progress() -> void:
	var fuel := make_fuel(2)
	FuelModel.materialize(fuel, 1000 + 1800)  # 1.5 regen intervals elapsed
	assert_eq(int(fuel["amount"]), 3)
	# updated_at advances by whole intervals only, keeping the 600s remainder
	assert_eq(int(fuel["updated_at"]), 1000 + 1200)

func test_spend_success_and_failure() -> void:
	var fuel := make_fuel(2)
	assert_true(FuelModel.spend(fuel, 2, 1000))
	assert_eq(int(fuel["amount"]), 0)
	assert_false(FuelModel.spend(fuel, 1, 1000))

func test_spend_from_full_restarts_regen_clock() -> void:
	var fuel := make_fuel(5, 5, 1200, 1000)
	FuelModel.spend(fuel, 1, 50000)
	# Time spent sitting at cap must not bank regen; the clock restarts at spend time
	assert_eq(FuelModel.current(fuel, 50000 + 1199), 4)
	assert_eq(FuelModel.current(fuel, 50000 + 1200), 5)

func test_current_does_not_mutate_input() -> void:
	var fuel := make_fuel(2)
	FuelModel.current(fuel, 1000 + 2400)
	assert_eq(int(fuel["amount"]), 2)
	assert_eq(int(fuel["updated_at"]), 1000)

func test_seconds_until_full() -> void:
	var fuel := make_fuel(3)
	assert_eq(FuelModel.seconds_until_full(fuel, 1000), 2400)
	assert_eq(FuelModel.seconds_until_full(fuel, 1600), 1800)
	var full := make_fuel(5)
	assert_eq(FuelModel.seconds_until_full(full, 1000), 0)
