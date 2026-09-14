# Regions 3 and 4: Design

**Date:** 2026-09-14
**Status:** Approved by owner (brainstorm session 2026-09-14)
**Parent spec:** docs/design/2026-08-15-windfall-isles-design.md sections 3.4 (regions, storm and ice pegs), 4.2 (one regional material per region)
**Roadmap item:** Phase A, "Regions 3+", including the boon-pool tripwire fixes that must land before any region ships 3+ quota tiers.

## 0. Scope and owner decisions

Two new regions ship in one plan (owner's call: both at once). Everything region-shaped is already data-driven; the new code surface is two peg hazards, two gizmos, and the three tripwire fixes. No save schema change (stays v8; new currencies ride the existing key backfill, as parts and provisions did in Plan 11).

Owner decisions recorded from the brainstorm:

1. Ship Regions 3 AND 4 together, one plan.
2. Region 3 is ice-themed with ice pegs; Region 4 is storm-themed with storm pegs.
3. Materials: Region 3 drops **rimeglass**, Region 4 drops **stormglass** (the parent design doc's stormglass lands in the storm region; rimeglass is new).
4. One new rare gizmo per region (two total), craft-to-acquire, each priced in its region's material.
5. Region 3 is the first region with three quota tiers; Region 4 also gets three. The tripwire fixes therefore land before the region data, in the same plan.

## 1. Content grid

| | Region 3 "Rimefall Shallows" | Region 4 "Stormglass Verge" |
|---|---|---|
| Hazard | ice pegs (deaden bounce) | storm pegs (consume pods) |
| Material | rimeglass | stormglass |
| Unlock | Dock Lv3, fuel 3, reduced to 2 at Dock Lv4 | Dock Lv4, fuel 3, no reduction row |
| Quota tiers | 50 / 110 / 180 at x1.3 / x1.6 / x2.0 | 70 / 150 / 250 at x1.3 / x1.7 / x2.2 |
| Gizmo slots | 9 | 10 |
| Pegs | ~45 total, of which ~8 ice | ~48 total, of which ~6 storm |
| Sea payout | {"scrap": 3} | {"scrap": 3} |
| Barges | far_left 20, left 9, center 4, right 9 + 1 rimeglass, far_right 14 + 2 rimeglass | far_left 26, left 12, center 5, right 12 + 1 stormglass, far_right 18 + 2 stormglass |
| Drift zones | none (one hazard identity per region) | none |

Exact peg coordinates are plan-level authoring; the counts, hazard mix, and payouts above are the binding numbers. Terrain intent: Region 3 arranges pegs in loose shelf rows with ice pegs guarding the rich right side; Region 4 uses staggered columns with storm pegs seeded along the high-value drop lanes so routing around them is the region's skill test.

Files: `game/data/skyfields/region_3.json`, `game/data/skyfields/region_4.json`, two new rows in `run.json` `regions` (same shape as region_2's row; region_3 carries `reduced_fuel_cost`/`reduced_at_dock_level`, region_4 does not), and `starting_balances` gains `"rimeglass": 0, "stormglass": 0`.

## 2. Boon tripwire fixes (land before the region data)

All three come from Plan 7's final review; they become reachable the moment a region has 3+ tiers or the pool grows.

1. **Exhausted-pool offer lockout:** `salvage_run._show_next_offer` currently returns early on an empty draw, leaving `controller.enabled` false when a queued tier crossing finds the pool exhausted (taken + skipped coverage). Fix: on an empty draw, close out the offer (no panel) and re-enable the controller unless the run is over, matching the Skip path's cleanup.
2. **Pointless reroll:** the reroll can consume an ad grant (or the wind_charm free reroll) when taken boons + the current trio cover the whole pool, redrawing nothing. Fix: a pure helper on BoonModel, `reroll_candidates(pool_ids: Array, taken: Array, current: Array) -> Array`, returning the disjoint remainder; the BoonOffer panel hides the reroll button when it is empty, and the grant path early-returns (consuming nothing) if it became empty between show and grant.
3. **maxf composition pin:** `RunModel.add_boon`'s `maxf` composition of same-type multipliers is untested. Add unit tests calling `add_boon` twice with synthetic barge and sea magnitudes, pinning that the larger multiplier wins and the composition never multiplies.

## 3. Peg hazards

Peg entries in region JSON gain an optional `"type"` field; absent means a normal peg. `Skyfield._build_pegs` branches on it.

**Ice peg (`"type": "ice"`):** built as the same StaticBody2D as a normal peg, plus a `PhysicsMaterial2D` with `bounce = 0.0` and `absorbent = true` as `physics_material_override`, and an icy visual tint. A pod hitting one loses its restitution on that contact and drops nearly dead, killing the run's rhythm on the rich side of the board. No new script and no per-run state: the hazard is pure physics material.

**Storm peg (`"type": "storm"`):** a new small scene `game/run/storm_peg.gd` (Area2D, like DriftZone) built by the skyfield at the peg's position and radius. On `body_entered` with an uncaught RigidBody2D pod: set the pod's `caught` meta, route the resolution through the board's existing `pod_caught` flow with an EMPTY payout and source `"storm"`, and free the pod (deferred). The drop is spent, nothing is earned, the watchdog and catchers skip the pod via the meta, and `resolve_pod({})` decrements pods in flight. Boon interactions fall out correctly: heavy_loot only pays on non-empty catches, and barge/sea multipliers do not apply to the `"storm"` source. Storm pegs never consume a pod that is already caught, and they have no use limit.

**Authoring guard:** an unknown `"type"` value warns (`push_warning`) and builds a normal peg (fail-open: a typo costs the hazard, not the board).

## 4. Dock levels 3 and 4

`buildings.json` dock: `max_level` 2 -> 4, two new level rows:

- Lv3: cost {"scrap": 2000, "brasswork": 6}, build_seconds 7200
- Lv4: cost {"scrap": 4000, "rimeglass": 6}, build_seconds 14400

Each region funds the next unlock (brasswork from Region 2 opens Region 3; rimeglass from Region 3 opens Region 4). RegionModel already reads `min_dock_level`/`reduced_at_dock_level` generically; no code change to unlocking.

## 5. New gizmos (one rare per region)

Both are rare (Workshop Lv3 to craft, extending the pinned tier table), craft-to-acquire, never starters.

**Sleet Sail** (Region 3, rimeglass): a tall column zone (Area2D, wind-fan-like geometry). Pods inside have `gravity_scale` multiplied by the def's `gravity_factor` 0.5, restored on exit. Slow-drifting pods rack up more peg hits and steerable time. Column WIDTH scales with level via `scaled()`; the gravity factor is level-independent. Defs: `column_width` 80, `column_height` 420, `gravity_factor` 0.5, craft_cost {"parts": 5, "rimeglass": 2}, craft_seconds 480.

**Gale Vent** (Region 4, stormglass): a zone that fires one sharp upward impulse per pod (a re-loft tool for dodging storm pegs). On `body_entered` with an uncaught pod that this vent has not kicked before (per-pod meta keyed by the vent's instance id), `apply_central_impulse(Vector2(0, -scaled(impulse)))`. Impulse scales with level. Defs: `radius` 28, `impulse` 380, craft_cost {"parts": 5, "stormglass": 2}, craft_seconds 480.

Physics rules apply: impulses are mass-respecting; neither gizmo adds physics bodies inside a contact callback; each gets one real-contact integration proof.

## 6. UI and flow

No structural UI work: the region cyclers, salvage_run scene, setup phase, and kit panel are region-agnostic. Ripple items only:

- The kit panel slot-clearance pin test (`test_kit_panel_intersects_no_slot_target_in_any_region`) automatically covers the two new boards; slot layouts must keep the center band x 160-560 / y 830-925 clear.
- Workshop rows for the two new gizmos come free from the defs iteration (rare, so dimmed until Workshop Lv3).
- Main and loadout region cyclers show locked names as they already do for region_2.

## 7. Testing

- **Tripwires:** unit tests for the exhausted-draw re-enable (offer queued, pool covered, controller re-enabled, no panel), `reroll_candidates` truth table, the hidden reroll button, the no-op grant path, and the maxf composition pins.
- **Region defs pins:** for each new region, quota tiers valid and ascending (existing `_valid_tiers` warning stays silent), unique barge ids, slots count 9/10, all peg `type` values in the known set, board geometry keeps the kit band clear (existing pin test extended by data alone), regions rows in run.json pinned (dock levels, fuel costs, reduction row present only on region_3).
- **Hazards:** ice peg unit test (built peg carries the override material with bounce 0 and absorbent) plus a real-contact integration proof (a pod dropped onto an ice peg ends with near-zero rebound velocity); storm peg unit tests (uncaught pod consumed and resolved empty, caught pod ignored) plus a real-contact proof (drop through a storm peg: pods_in_flight returns to 0, no payout credited, no engine errors); unknown-type warning test.
- **RunModel:** empty-payout resolution keeps tier math and drop accounting honest (no tier lift from a consumed pod).
- **Dock/regions:** RegionModel gating truth table for dock levels 0-4 across all four regions; fuel cost and reduction values.
- **Gizmos:** Sleet Sail (gravity_scale halves inside, restores on exit, width scales with level), Gale Vent (one kick per pod per vent, impulse scales with level, caught pods ignored), rarity tier table pin extended to 12 entries, real-contact proof each.
- **Economy:** new currencies present in starting_balances; an old save missing the keys reads them as 0 through Economy.balance and gains them on first add (no schema bump, no migration).

## 8. Out of scope

- Region 5+, new boon pool entries, and the "expedition perks" tree (open question 1 stays open).
- Observatory functionality (region preview) beyond what exists.
- Art for the new regions and gizmos (extends the Phase B art brief).
- Dock Lv5+ or a fuel reduction row for Region 4 (add when a later dock level exists).
- New kit consumables or Balloonworks recipes for the new materials.
