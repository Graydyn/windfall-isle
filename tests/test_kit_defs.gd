extends GutTest
## Authoring guards for the run kit (run-kit spec section 4).


func kit() -> Dictionary:
	return DataDefs.run.get("kit", {})


func test_kit_block_shape() -> void:
	for kit_id in ["ballast", "wind_charm", "storm_oil", "provision"]:
		assert_has(kit(), kit_id)
		assert_true(String((kit()[kit_id] as Dictionary).get("name", "")) != "", "kit name missing: %s" % kit_id)

func test_consumable_keys_are_known_currencies() -> void:
	var balances: Dictionary = DataDefs.economy.get("starting_balances", {})
	for kit_id in ["ballast", "wind_charm", "storm_oil"]:
		assert_has(balances, kit_id, "kit consumable is not a currency: %s" % kit_id)

func test_kit_magnitudes() -> void:
	assert_eq(int((kit()["ballast"] as Dictionary).get("drops_bonus", 0)), 2)
	assert_eq(int((kit()["wind_charm"] as Dictionary).get("free_rerolls", 0)), 1)
	assert_almost_eq(float((kit()["storm_oil"] as Dictionary).get("bounce_bonus", 0.0)), 0.15, 0.001)
	assert_eq(int((kit()["provision"] as Dictionary).get("cost", 0)), 3)
	assert_almost_eq(float((kit()["provision"] as Dictionary).get("payout_multiplier", 0.0)), 1.15, 0.001)
