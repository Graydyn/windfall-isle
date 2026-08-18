class_name BoonModel
## Pure boon-offer draws (spec 3.2 step 4): pick-1-of-3 run-scoped modifiers.
## The RandomNumberGenerator is injected: the scene seeds from the clock at
## its boundary, tests pass fixed seeds. This is the repo's no-wall-clock
## discipline applied to randomness.


static func offer(pool_ids: Array, taken: Array, rng: RandomNumberGenerator) -> Array:
	var candidates: Array = []
	for id in pool_ids:
		if not taken.has(id):
			candidates.append(id)
	var out: Array = []
	while out.size() < 3 and not candidates.is_empty():
		out.append(candidates.pop_at(rng.randi_range(0, candidates.size() - 1)))
	return out
