# Boons Design (Plan 7)

**Status:** Approved design, pre-plan
**Date:** 2026-08-18
**Parent spec:** docs/design/2026-08-15-windfall-isles-design.md (binding where this document is silent; section 3.2 step 4 defines the boon moment, section 6 placement 5 defines the reroll ad)
**Scope decisions made with the project owner:** the "clean six" boon vocabulary (below) replaces the parent spec's three illustrative examples; the offer is skippable; the reroll ad placement ships through the existing AdService seam with GrantAdService only (AdMob untouched); boon persistence trees (parent spec open question 1) stay out.

---

## 1. Goals

Give quota tiers their payoff: reaching a tier mid-run offers a pick-1-of-3 run-scoped boon (light roguelite spice, parent spec 3.2). Ship the boon-reroll rewarded-ad placement (parent spec 6, placement 5). Fold in the Plan 6 backlog fixes. Boons are strictly run-scoped: nothing persists, no save schema change.

## 2. The boon pool as data

New `game/data/boons.json`, loaded by DataDefs as `boons`:

```json
{
	"defs": {
		"barge_bounty": {"name": "Barge Bounty", "description": "Barge payouts +50% this run.", "barge_multiplier": 1.5},
		"rich_seas": {"name": "Rich Seas", "description": "Cloud-sea payouts tripled this run.", "sea_multiplier": 3.0},
		"spare_pods": {"name": "Spare Pods", "description": "+2 pod drops this run.", "extra_drops": 2},
		"heavy_loot": {"name": "Heavy Loot", "description": "+2 scrap on every catch this run.", "bonus_scrap_per_catch": 2},
		"featherfall": {"name": "Featherfall", "description": "Pods dropped from now on bounce higher.", "bounce_bonus": 0.2},
		"second_wind": {"name": "Second Wind", "description": "Consumable gizmos regain their uses."}
	}
}
```

All magnitudes are designer-tunable data. Descriptions are the player-facing offer text (no text baked into art; labels only).

## 3. BoonModel (pure, seeded)

`game/core/boon_model.gd` (`BoonModel`), FuelModel pattern:

- `offer(pool_ids: Array, taken: Array, rng: RandomNumberGenerator) -> Array`: draws up to 3 distinct ids from `pool_ids` minus `taken`, uniformly without replacement via the injected rng. Fewer than 3 candidates: returns what remains. Zero candidates: returns `[]` (the scene then skips the offer entirely).
- The rng is injected: the scene seeds one from `TimeUtil.now()` at `_ready`; tests pass a fixed-seed rng for determinism (the repo's no-wall-clock discipline, applied to randomness).

Taken-boon state lives on the RunModel (section 4), not in the save.

## 4. RunModel boon state and accessors

`RunModel` gains:

- `boons: Array` (taken boon ids, in pick order) and `add_boon(boon_id: String, boon_defs: Dictionary) -> void`, which records the id and, for `spare_pods`, applies `drops_total += int(extra_drops)` immediately (via a new `add_drops(count: int)` helper).
- Pure accessors the payout path reads, all defaulting to neutral when no boon is taken: `barge_boon_multiplier() -> float` (1.0), `sea_boon_multiplier() -> float` (1.0), `bonus_scrap_per_catch() -> int` (0). Each reads its magnitude from the defs snapshot captured at `add_boon` time (RunModel stores the relevant magnitudes, not the whole defs dict, so it stays node-free and defs-free after the call).
- `has_boon(boon_id: String) -> bool`.

Stacking rule: each boon can be taken at most once per run (the offer already excludes taken ids), so accessors never compose duplicates.

## 5. Offer flow in the run scene

- On `RunModel.tier_reached`, `salvage_run.gd` computes the offer (`BoonModel.offer` over `DataDefs.boons` def keys and `model.boons`). Empty offer: nothing happens. Otherwise drops pause (`controller.enabled = false`) and a `BoonOffer` panel shows (a `PanelContainer` under `UI`, sibling of `Results`, hidden by default): three (or fewer) pick buttons labeled `<name>\n<description>`, a `Skip` button, and a `Reroll (ad)` button.
- **Pick** applies the boon (`model.add_boon`, plus the scene-side effects in section 7), hides the panel, and re-enables drops (unless the run is already over).
- **Skip** hides the panel and re-enables drops; the offer is forfeited (no banking offers).
- If a second tier lands while an offer is up (one rich catch crossing both tiers emits twice), the offers queue: the panel serves them one at a time.
- Run end (`run_over` or abandon) while an offer is up: the panel closes unpicked, results show as normal. No fail state, nothing lost (parent spec pillar).
- Pods already in flight keep falling while the panel is up (physics never pauses; only new drops are gated). Their catches resolve normally, including boon effects already active.

## 6. The reroll ad placement

- `AdService.Placement` gains `BOON_REROLL` (fifth member, appended; existing member order unchanged). GrantAdService remains the only implementation; AdMob stays out per the project owner's standing instruction.
- The Reroll button is visible only when `Ads.service.is_available(BOON_REROLL)` and the offer has not been rerolled yet: **one reroll per offer**, granted at reward time (the request/grant split as in Plan 5). A reroll redraws via `BoonModel.offer` with the current offer's ids ALSO excluded (so the reroll never returns the same trio; exclusions are per-reroll only, not permanent). No daily limit (parent spec 6 sets none for placement 5).

## 7. Effect wiring (all through existing seams)

- **Barge Bounty:** in `_on_pod_caught`, barge-source payouts multiply by `model.barge_boon_multiplier()`, composing with the Chime Bell's one-shot multiplier (bell applies after, on the boosted value, matching its "next barge payout is doubled" wording).
- **Rich Seas:** sea-source payouts (including watchdog timeouts, which resolve as sea) multiply by `model.sea_boon_multiplier()`.
- **Heavy Loot:** after `_compute_payout`, non-empty catches gain `+ bonus_scrap_per_catch()` scrap flat (empty payouts, e.g. zero-value split remnants, stay empty so "nothing salvaged" remains truthful).
- **Spare Pods:** `RunModel.add_drops(2)` at pick time; the HUD's drops-left count reflects it immediately.
- **Featherfall:** the scene keeps a `_pod_defs_current` copy; taking the boon bumps its `bounce` by `bounce_bonus` (clamped to 1.0); pods dropped afterwards use it (pods already falling are unchanged; split clones use the current defs like any new pod).
- **Second Wind:** new virtual `GizmoBase.recharge() -> void` (default no-op). Overrides: Balloon Cluster restores `_hits_left` and its visual alpha and re-enables monitoring; Lightning Jar restores charges and alpha; Chime Bell restores rings and alpha; Cargo Net restores its use and alpha. Taking the boon calls `recharge()` on every child of the board's `Gizmos` node. Multiplier/field gizmos (prism, fan, buoy, vane, damper, kicker) keep the no-op default; the Piston Kicker's once-per-POD meta is a pod property, deliberately not recharged.

Rounding: multiplied payouts use the existing `roundi` + drop-zero-entries path in the shared payout code, identical treatment for every catch source.

## 8. Plan 6 backlog fixes (fold into the plan's first task)

1. `RegionModel.selected_id` gains an `is Dictionary` guard on the expedition section (wrong-typed hand-edited saves fall back to region_1 instead of crashing).
2. The duplicated region-cycle logic in `main.gd` and `loadout_screen.gd` extracts into `RegionModel.next_region_id(run_defs, island, current_id) -> String` (returns the next unlocked id in declared order, or `current_id` unchanged when there is nothing to cycle to); both screens keep their own persistence line.
3. `RunModel._valid_tiers` warns when `scrap_quota` values are not strictly ascending (region 3+ authoring guard); out-of-order rows still load (warning only).

Deliberately not touched (parked for the AdMob plan): skip-button availability outside the refresh signature; grant callbacks assuming synchronous grants (the BoonOffer reroll inherits this known limitation knowingly: with GrantAdService the grant is synchronous and safe).

## 9. Testing

House pattern (GUT 9.6.1 headless, fixed seeds instead of wall-clock randomness, int-cast JSON assertions, `.gd.uid` sidecars):

- **BoonModel:** fixed-seed draws: 3 distinct from 6; excludes taken; short pool returns remainder; empty pool returns []; different seeds can differ (sanity, not distribution testing).
- **RunModel:** add_boon records + accessors return magnitudes; neutral defaults; spare_pods extends drops; add_drops.
- **Scene:** tier_reached shows the offer and disables drops; pick applies and resumes; skip resumes without applying; reroll excludes the current trio and hides after one use; queued second offer; run-over closes the panel. All via direct handler calls (no scene-changing presses).
- **Effects:** barge/sea multipliers through `_on_pod_caught` with sources; heavy loot flat bonus; featherfall changes only subsequent pods' bounce; recharge restores each consumable (unit per gizmo, real-contact where the original behavior tests were real-contact).
- **E2E (fixed seed, no-strict-RED per standing ruling):** scripted run crosses tier 1, offer appears, pick barge_bounty, next barge catch pays 1.5x, cross tier 2, pick spare_pods, drops extended, finish run, loot banked.

## 10. Out of scope

Boon persistence/perk trees (parent spec open question 1), AdMob and async-grant hardening, regions 3+, island expansion/story, rarities, sound, art (the BoonOffer panel uses the placeholder UI style; docs/art/placeholder-graphics-audit.md gains boon-icon entries only at the art pass).
