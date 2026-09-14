extends GutTest

const POOL := ["barge_bounty", "rich_seas", "spare_pods", "heavy_loot", "featherfall", "second_wind"]


func seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_offer_draws_three_distinct_pool_members() -> void:
	var offer := BoonModel.offer(POOL, [], seeded(42))
	assert_eq(offer.size(), 3)
	for id in offer:
		assert_has(POOL, id)
	assert_ne(offer[0], offer[1])
	assert_ne(offer[1], offer[2])
	assert_ne(offer[0], offer[2])

func test_offer_is_deterministic_for_a_fixed_seed() -> void:
	assert_eq(BoonModel.offer(POOL, [], seeded(42)), BoonModel.offer(POOL, [], seeded(42)),
		"same seed, same draw: the no-wall-clock discipline applied to randomness")

func test_offer_excludes_taken_boons() -> void:
	var taken := ["barge_bounty", "rich_seas", "spare_pods"]
	for seed_value in [1, 2, 3, 4, 5]:
		var offer := BoonModel.offer(POOL, taken, seeded(seed_value))
		for id in taken:
			assert_false(offer.has(id), "taken boons never reappear")

func test_short_pool_returns_the_remainder() -> void:
	var offer := BoonModel.offer(POOL, ["barge_bounty", "rich_seas", "spare_pods", "heavy_loot"], seeded(7))
	offer.sort()
	assert_eq(offer, ["featherfall", "second_wind"])

func test_exhausted_pool_returns_empty() -> void:
	assert_eq(BoonModel.offer(POOL, POOL, seeded(7)), [])

func test_boon_defs_load_with_names_and_descriptions() -> void:
	var defs: Dictionary = DataDefs.boons.get("defs", {})
	assert_eq(defs.size(), 6)
	for id in POOL:
		assert_has(defs, id)
		assert_true(String((defs[id] as Dictionary).get("name", "")) != "")
		assert_true(String((defs[id] as Dictionary).get("description", "")) != "")

func test_boon_magnitudes_are_data() -> void:
	var defs: Dictionary = DataDefs.boons.get("defs", {})
	assert_almost_eq(float((defs["barge_bounty"] as Dictionary)["barge_multiplier"]), 1.5, 0.001)
	assert_almost_eq(float((defs["rich_seas"] as Dictionary)["sea_multiplier"]), 3.0, 0.001)
	assert_eq(int((defs["spare_pods"] as Dictionary)["extra_drops"]), 2)
	assert_eq(int((defs["heavy_loot"] as Dictionary)["bonus_scrap_per_catch"]), 2)
	assert_almost_eq(float((defs["featherfall"] as Dictionary)["bounce_bonus"]), 0.2, 0.001)

func test_reroll_candidates_excludes_taken_and_current() -> void:
	var pool := ["a", "b", "c", "d", "e", "f"]
	assert_eq(BoonModel.reroll_candidates(pool, ["a", "b"], ["c", "d", "e"]), ["f"])


func test_reroll_candidates_empty_when_pool_covered() -> void:
	var pool := ["a", "b", "c", "d"]
	assert_eq(BoonModel.reroll_candidates(pool, ["a"], ["b", "c", "d"]), [],
		"taken plus the current trio cover the pool: nothing to redraw")
