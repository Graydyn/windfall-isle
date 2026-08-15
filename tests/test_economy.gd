extends GutTest

const EconomyScript := preload("res://game/autoload/economy.gd")
const GameStateScript := preload("res://game/autoload/game_state.gd")
const DEFS := {
	"starting_balances": {"scrap": 100, "cloudsilk": 0, "crystals": 10},
	"fuel": {"starting": 5, "cap": 5, "regen_seconds": 1200},
}

var econ
var state


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.data = SaveSchema.default_data(DEFS)
	econ = autofree(EconomyScript.new())
	econ.setup(state)


func test_starting_balances() -> void:
	assert_eq(econ.balance("scrap"), 100)
	assert_eq(econ.balance("crystals"), 10)
	assert_eq(econ.balance("unknown_currency"), 0)

func test_add_increases_balance_and_emits() -> void:
	watch_signals(econ)
	econ.add("scrap", 10)
	assert_eq(econ.balance("scrap"), 110)
	assert_signal_emitted_with_parameters(econ, "balance_changed", ["scrap", 110])

func test_spend_success() -> void:
	assert_true(econ.spend("scrap", 40))
	assert_eq(econ.balance("scrap"), 60)

func test_spend_insufficient_funds_fails_without_change() -> void:
	assert_false(econ.spend("scrap", 101))
	assert_eq(econ.balance("scrap"), 100)

func test_can_afford_multi_currency() -> void:
	assert_true(econ.can_afford({"scrap": 100, "crystals": 10}))
	assert_false(econ.can_afford({"scrap": 100, "crystals": 11}))

func test_pay_is_all_or_nothing() -> void:
	assert_false(econ.pay({"scrap": 50, "crystals": 11}))
	assert_eq(econ.balance("scrap"), 100, "failed pay must not partially charge")
	assert_true(econ.pay({"scrap": 50, "crystals": 5}))
	assert_eq(econ.balance("scrap"), 50)
	assert_eq(econ.balance("crystals"), 5)

func test_mutations_land_in_state_dict() -> void:
	econ.add("scrap", 1)
	assert_eq(int(state.data["currencies"]["scrap"]), 101,
		"Economy must mutate GameState.data so saves capture it")
