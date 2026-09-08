# Production Chains: Design Spec (Island Rework, Plan 11 of 3)

**Date:** 2026-09-08
**Status:** Approved scope, pre-plan
**Parent decision:** docs/superpowers/specs/2026-09-07-crew-system-design.md section 0 (the island rework arc); docs/ROADMAP.md Phase A
**Baseline:** main at b162876, 480/480 GUT tests green, save schema v8

## 1. Summary

The island learns to make things. Two new currencies (worked **parts** and **provisions**) enter the economy; buildings gain timed batch **conversion recipes** (Smeltery and Foundry Annex smelt scrap into parts, the Gardens put up provisions); and every gizmo craft is repriced from raw scrap to parts, making the chain the spine of gizmo progression. Crew speed conversions through the existing `CrewModel.multiplier_for` seam with zero new wiring, which is what Plan 10 built that seam for.

Owner decisions locked during brainstorming:

1. **Rebase clamp ruling (carried from Plan 10):** keep the clamp. Pending trickle value never exceeds what the current rate could accrue inside the cap window; a downward reassignment may clamp excess pending. This plan adds the pinning test.
2. **Chain shape:** a new home **Smeltery** building converts scrap to parts from the early game, and ALL gizmo crafts reprice to parts (raw scrap no longer crafts anything).
3. **Plot math:** `plot_count` rises to 7 so all seven home buildings fit; no demolish mechanic, no softlock.
4. **Conversion mechanics:** timed batch jobs. Inputs paid up front, a TimerService timer of new kind `"convert"` runs, outputs collected at the end; crew divide the duration.
5. **Unbuilt-building multiplier (carried question):** kept as-is. Recipes are gated on the building being built, which closes the oddity for conversions; the one residual case (a crew assigned to an unbuilt Wind Still still speeding base regen) stays: it is simple, tested, and the worker is a real opportunity cost elsewhere.

Out of scope: Balloonworks consumable recipes, spending consumables or provisions at the run setup phase, provisioning bonuses (all Plan 12); recipe queues or parallel batches per building; storage caps for the new currencies; demolish.

## 2. Currencies

`parts` and `provisions` are ordinary currencies in the save's `currencies` dict, handled by the existing generic Economy (arbitrary currency dicts in `add`/`pay`/`can_afford`/`balance`). `economy.json` `starting_balances` gains `"parts": 0, "provisions": 0`. No schema bump: old saves lack the keys, `Economy.balance` returns 0 for missing keys, and the first `add` creates them. The plan verifies both behaviors with tests rather than assuming them.

Provisions are earned but inert in this plan (Plan 12's expedition provisioning consumes them); they are visible so the stock is already building when Plan 12 lands.

## 3. Recipes (buildings.json)

A building def may carry a single `recipe` dict: `{"id", "inputs" (currency dict, may be empty), "outputs" (currency dict), "seconds"}`. **Outputs scale with building level** (level N credits N times the outputs); inputs and duration do not scale. One batch per building at a time.

- **Smeltery** (new home building def):

```json
"smeltery": {
	"name": "Smeltery",
	"max_level": 3,
	"levels": [
		{"cost": {"scrap": 120}, "build_seconds": 180},
		{"cost": {"scrap": 480, "cloudsilk": 3}, "build_seconds": 1800},
		{"cost": {"scrap": 1400, "cloudsilk": 9}, "build_seconds": 5400}
	],
	"recipe": {"id": "smelt", "inputs": {"scrap": 40}, "outputs": {"parts": 1}, "seconds": 600}
}
```

- **Foundry Annex** keeps its craft discount and gains the efficient late-game recipe:

```json
	"recipe": {"id": "brass_smelt", "inputs": {"scrap": 30, "brasswork": 1}, "outputs": {"parts": 2}, "seconds": 600}
```

- **Gardens** gain a zero-input recipe (starting it costs nothing but the timer):

```json
	"recipe": {"id": "put_up_provisions", "inputs": {}, "outputs": {"provisions": 2}, "seconds": 3600}
```

`plot_count` becomes 7. `buildings.json`'s def count rises to 9 (seven home + two islet); the def-count guard test updates accordingly.

## 4. Gizmo repricing

Every `craft_cost` in gizmos.json converts at roughly 40 scrap per part; cloudsilk and brasswork components survive unchanged:

| Gizmo | Old cost | New cost |
|---|---|---|
| wind_fan | 80 scrap | 2 parts |
| balloon_cluster | 90 scrap | 2 parts |
| cargo_net | 100 scrap | 2 parts |
| magnet_buoy | 110 scrap | 3 parts |
| chime_bell | 120 scrap | 3 parts |
| lightning_jar | 140 scrap + 1 cloudsilk | 3 parts + 1 cloudsilk |
| crystal_prism | 150 scrap + 1 cloudsilk | 3 parts + 1 cloudsilk |
| splitter_vane | 160 scrap + 2 cloudsilk | 4 parts + 2 cloudsilk |
| piston_kicker | 180 scrap + 1 brasswork | 4 parts + 1 brasswork |
| gyro_damper | 200 scrap + 2 brasswork | 5 parts + 2 brasswork |

The Foundry Annex discount continues to apply through `CraftModel.effective_cost` to the new costs (ceil, floor 1, unchanged). Progression note: all eight starter gizmos are owned at level 1, so a fresh save is never blocked from playing; crafting (upgrades and the two brass recipes) now requires standing up the Smeltery first, which is the chain working as intended. Existing saves need no migration: costs live in defs.

## 5. Crew

`smeltery` joins crew.json's `workable` list, and the cast gets a smelting specialist: **Reya's specialty moves from `balloonworks` to `smeltery`** (her line already reads foundry-adjacent grit; Petch keeps the Balloonworks, which stays assignable ahead of Plan 12). No other crew changes. The crew-defs guard tests keep passing because `workable` entries must be real building defs, which `smeltery` now is.

## 6. ConvertModel (new, pure)

`game/base/convert_model.gd`, `class_name ConvertModel`, all-static, mirroring CraftModel's shape. Timer ids `convert_<building_id>`, kind `"convert"`, payload `{"building": building_id}`.

- `recipe(building_defs, building_id) -> Dictionary`: the def's recipe, `{}` when absent.
- `outputs_for(building_defs, island, building_id) -> Dictionary`: recipe outputs multiplied by the building's current level (empty when unbuilt or recipe-less).
- `can_start(data, building_defs, economy, timers, building_id) -> bool`: recipe exists, building level >= 1, no `convert_<building>` timer active, inputs affordable.
- `start_batch(data, building_defs, economy, timers, building_id, now, crew_defs = {}) -> bool`: can_start, `economy.pay(inputs)` (an empty inputs dict pays nothing), duration `maxi(1, ceili(seconds / CrewModel.multiplier_for(data, crew_defs, building_id)))`, locked at start like crafts.
- `complete_batch(data, building_defs, economy, payload) -> void`: credits `outputs_for` at collect time (so an upgrade finishing mid-batch pays the new level's outputs; stated behavior), via `economy.add` per currency. Empty/unknown payload is a no-op.

## 7. Rebase helper fold (carried chore)

The duplicated trickle-rebase logic (in `CrewModel._rebase_trickle` and `IslandModel.complete_build`'s gardens branch) folds into one shared pure helper on TrickleModel: `TrickleModel.rebase_preserving(data, building_defs, crew_defs, now, pending_before) -> void` (relocates `last_collect` so `pending_before` is preserved at the current rate; no-op when the rate is 0 or defs are empty). Both call sites delegate to it; behavior is pinned by the existing rebase tests plus the new clamp test.

## 8. Island UI

- Building rows for built, recipe-carrying buildings gain the conversion affordance: idle shows a start button labeled from the recipe ("Smelt (40 scrap)", "Put up provisions"); running shows the countdown appended to the row label (in-place per tick); done shows "Collect (N parts)" / "Collect (N provisions)" from `outputs_for`.
- Convert timers join the island refresh signature with the same absent/running/done chars as build timers, one char per recipe-carrying building def.
- The main screen's balance readout adds Parts and Provisions lines.
- The workshop screen needs no code change: `effective_cost` renders parts prices via the existing cost label.

## 9. Notifications

`NotificationPlanner.plan` gains a `"convert"` branch mirroring crafts: id = timer id, title "Batch complete", body "The %s's batch is ready." with the building name from building defs. `NotificationSvc` already passes building defs; no signature change.

## 10. Testing

Headless GUT, repo conventions.

- **Data guards:** recipe inputs/outputs are dicts of known currencies (known = appears in starting_balances or is a recipe output anywhere), recipe buildings exist, smeltery in `workable`, def-count and plot-count updates pinned, repricing table pinned (each gizmo's exact new cost).
- **ConvertModel:** built-gate, unknown-building no-op, pay-then-timer (including the zero-input Gardens recipe paying nothing), one batch per building, output scaling at levels 1-3, crew-divided duration locked at start, complete_batch credits at collect-time level, idempotent no-op on junk payloads.
- **Clamp pinning test (owner ruling):** a downward gardens rebase clamps pending to the new rate's cap window (240 pending at 30/hour becomes 160 at 20/hour after unassignment with more than the cap window accrued).
- **Rebase fold:** existing rebase tests keep passing through the shared helper; one direct helper test.
- **Repricing:** craft-cost assertions updated to the table; Annex discount over parts costs; check/pay agreement untouched.
- **Economy defaults:** `balance("parts")` is 0 on a pre-parts save dict; first `add` creates the key.
- **Screen tests** via direct handlers: start batch pays and starts, countdown joins the signature, collect credits scaled outputs, zero-input recipe startable at zero scrap.
- **Notifications:** convert entry names the building; past-deadline excluded (inherited).
- **Integration proof (fixed clock, no-strict-RED per standing ruling):** build the Smeltery, assign Reya, smelt a batch at the crew-divided duration, craft a Wind Fan upgrade priced in parts, end to end.

## 11. Risks and interactions

- **Repricing is a hard cutover:** after this plan, scrap crafts nothing. Any test asserting old scrap costs must be updated in the same task as the data change or the suite breaks mid-plan; the plan enumerates them (test_craft_model's 80/72 assertions, workshop label test, region-2/retention integration tests that craft).
- **collect-time output leveling** means upgrading a building mid-batch changes what the batch pays (upward only in practice). Deliberate and stated; the alternative (lock outputs at start) needs payload plumbing for no player-visible benefit.
- **Foundry Annex now has three roles** (craft discount, brass recipe, Halvard's specialty): the recipe and discount are independent code paths; the plan keeps them separate.
- **Reya's specialty change** edits shipped authored data; acceptable pre-release, and no save state references specialties (they live in defs).
- **Convert timers on islet buildings** (Foundry Annex) work unchanged because timers are building-id keyed, not plot-keyed; the signature char covers it like any recipe building.
