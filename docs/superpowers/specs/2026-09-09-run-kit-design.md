# The Run Kit: Design Spec (Island Rework, Plan 12 of 3)

**Date:** 2026-09-09
**Status:** Approved scope, pre-plan
**Parent decision:** docs/superpowers/specs/2026-09-07-crew-system-design.md section 0 (the island rework arc); docs/ROADMAP.md Phase A
**Baseline:** main at cf651f5, 504/504 GUT tests green, save schema v8

## 1. Summary

The arc closes: island output flows back into runs. The Balloonworks crafts three **consumables** (Charged Ballast, Wind Charm, Storm Oil), the Plan 9 setup phase gains a **kit panel** where the player elects consumables and **provisions the run** with the Gardens' stockpile, and everything elected is consumed exactly once when Start succeeds. With this plan, every island resource has a run-facing purpose and every run resource feeds the island: the closed bidirectional economy the owner asked for.

Owner decisions locked during brainstorming:

1. **Three consumables**, all crafted at the Balloonworks, which requires generalizing building recipes from Plan 11's single `recipe` dict to a **`recipes` array**. One batch per building remains the concurrency rule; the player picks which recipe to run.
2. **Provisioning**: spending 3 provisions at setup multiplies every catch payout that run by 1.15, folded in beside the Lens Array multiplier. Numbers tunable.
3. Consumable counts are ordinary currencies (like parts); effect magnitudes live in a `"kit"` block in run.json.
4. Nothing is consumed before Start succeeds: fuel is spent first, then the kit; Back stays free; a failed Start consumes nothing; finished or abandoned runs never refund kit.

Out of scope: consumable stacking (each consumable type electable at most once per run), kit persistence across scene loads, new notification copy, a dedicated kit/inventory screen, more consumable types (the array makes them JSON authoring later), boon-pool growth (the Plan 7 tripwire stands).

## 2. Recipes array (buildings.json)

The building-def key `recipe` (single dict) becomes `recipes` (array of the same dicts: `{"id", "name", "inputs", "outputs", "seconds"}`). Smeltery, Foundry Annex, and Gardens each wrap their existing recipe in a one-element array, values unchanged. The Balloonworks gains three:

```json
	"recipes": [
		{"id": "charged_ballast", "name": "Charged Ballast", "inputs": {"cloudsilk": 1, "parts": 1}, "outputs": {"ballast": 1}, "seconds": 900},
		{"id": "wind_charm", "name": "Wind Charm", "inputs": {"cloudsilk": 2, "parts": 1}, "outputs": {"wind_charm": 1}, "seconds": 1200},
		{"id": "storm_oil", "name": "Storm Oil", "inputs": {"cloudsilk": 1, "parts": 2}, "outputs": {"storm_oil": 1}, "seconds": 900}
	]
```

Outputs still scale with building level at collect time. Recipe ids are globally unique across all buildings (authoring guard). `starting_balances` gains `"ballast": 0, "wind_charm": 0, "storm_oil": 0` so the known-currency guard covers them. No schema bump (currencies stay generic, schema stays v8).

## 3. ConvertModel: recipe addressing

- `recipes(building_defs, building_id) -> Array`: the def's recipes, `[]` when absent. The Plan 11 `recipe(...)` single accessor is removed with its callers (no live external caller keeps the old shape; the plan enumerates every touch).
- `recipe_by_id(building_defs, building_id, recipe_id) -> Dictionary`.
- `outputs_for(building_defs, island, building_id, recipe_id) -> Dictionary` (level-scaled, `{}` when unbuilt/unknown).
- `can_start(data, building_defs, economy, timers, building_id, recipe_id) -> bool`: recipe exists, building built, no `convert_<building>` timer (one batch per building regardless of recipe), inputs affordable.
- `start_batch(..., building_id, recipe_id, now, crew_defs = {})`: pays that recipe's inputs; duration from that recipe's seconds, crew-divided, locked at start; payload `{"building": building_id, "recipe": recipe_id}`.
- `complete_batch(data, building_defs, economy, payload)`: credits the payload recipe's outputs at collect-time level; junk building or recipe ids are no-ops.

Timer ids stay `convert_<building_id>` (no recipe in the id: one batch per building makes it unambiguous; the payload carries the recipe).

## 4. The kit (run.json)

New `"kit"` block:

```json
	"kit": {
		"ballast": {"name": "Charged Ballast", "drops_bonus": 2},
		"wind_charm": {"name": "Wind Charm", "free_rerolls": 1},
		"storm_oil": {"name": "Storm Oil", "bounce_bonus": 0.15},
		"provision": {"name": "Provision run", "cost": 3, "payout_multiplier": 1.15}
	}
```

Kit keys `ballast`/`wind_charm`/`storm_oil` are the consumable currency ids; `provision` spends the `provisions` currency. Each consumable is electable at most once per run.

## 5. Setup-phase kit panel (salvage_run)

New `KitPanel` nodes under `SetupUI`: one toggle chip per consumable ("Charged Ballast x2", disabled at count 0) and a provisioning toggle ("Provision run (3 provisions)", disabled below cost). Elections live in scene state (`_kit_elected: Dictionary`), reset with the scene, refreshed per setup tick (counts and affordability).

On Start, AFTER the fuel spend succeeds and BEFORE gizmos install:

1. Each elected consumable is paid (`Economy.pay({id: 1})`); an election that can no longer be afforded is silently dropped (unreachable through the UI, guarded anyway; the run proceeds).
2. Effects apply through existing seams: ballast `model.add_drops(drops_bonus)` (the Spare Pods seam); storm oil bumps the scene's duplicated `pod_defs` bounce (the Featherfall seam, capped at 1.0); wind charm sets `_free_rerolls` (consumed in the reroll handler BEFORE any ad request, still at most one reroll per offer); provisioning pays `cost` provisions and sets `_provision_mult` to `payout_multiplier`, folded into `_compute_payout`'s product beside `_island_mult`.
3. One save after the kit is paid (the fuel save already happens; a single combined save at the end of the Start flow is fine as long as the debit-before-install ordering holds).

The HUD and results need no changes; kit effects are visible through their consequences (drops count, payouts).

## 6. Island UI

The Balloonworks row (and any multi-recipe building later) shows one start button per recipe when idle, each labeled name + inputs via the existing `_batch_button_text` (which becomes recipe-addressed). Running and done states are unchanged (one countdown, one collect; the collect label names the payload recipe's outputs). The single-recipe buildings look identical to Plan 11.

## 7. Testing

- **Data guards:** recipes arrays well-formed (reusing the Plan 11 guard shapes over arrays), recipe-id global uniqueness, the three consumable currencies known, kit block well-formed (each consumable key is a known currency, provision cost and multiplier positive).
- **ConvertModel:** migrated to recipe addressing; new cases: picking each of the Balloonworks' three recipes, one-batch-per-building across DIFFERENT recipes, junk recipe id no-ops, collect credits the payload recipe (not another).
- **Setup kit (direct handlers):** toggles flip elections and respect counts; Start consumes exactly the elected items once; Start without fuel consumes nothing; Back consumes nothing (no handler call needed, just assert no debit pre-Start); each effect lands (drops +2 via `model.drops_remaining`, bounce bump on `pod_defs` with the 1.0 cap, free reroll consumed before the ad path and still once per offer, 1.15 in `_compute_payout`); elections absent on a fresh scene.
- **Integration proof (fixed clock, no-strict-RED per standing ruling):** craft a Ballast at the Balloonworks, elect Ballast + provisioning at setup, Start; the run has baseline+2 drops and a catch pays 1.15x, end to end.

## 8. Risks and interactions

- **The recipe-to-recipes migration touches every Plan 11 consumer** (ConvertModel, island screen, data guards, notification planner is untouched since it reads building names only); the plan does it as one atomic task with all tests migrated in the same commit, like the Plan 11 cutover.
- **Start-flow ordering grows**: fuel, then kit, then install, then RUNNING. The failed-fuel path must leave elections un-consumed; the test pins it.
- **`_compute_payout` gains a third multiplicand**; the `is_equal_approx(mult, 1.0)` early return keeps every non-kit run byte-identical.
- **Reroll interplay**: the free reroll consumes `_free_rerolls` and skips the ad request but must still respect `_offer_rerolled` (once per offer) and the disjoint-redraw rules; the Plan 7 tripwire about pool exhaustion is unchanged (pool still six).
- **Chips discipline**: kit toggles are plain Buttons (no drag), but they live in SetupUI where the Plan 9 MOUSE_FILTER lesson applies to anything overlapping drop targets; the KitPanel must not overlap SlotTargets.
