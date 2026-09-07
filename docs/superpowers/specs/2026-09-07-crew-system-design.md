# Crew System: Design Spec (Island Rework, Plan 10 of 3)

**Date:** 2026-09-07
**Status:** Approved scope, pre-plan
**Parent decision:** docs/ROADMAP.md Phase A "Island mechanic rework" (owner, 2026-09-07)
**Baseline:** main at d90769b, 438/438 GUT tests green, save schema v7

## 0. The island rework arc

The owner's diagnosis of the current island: no real decisions, too passive, disconnected from runs, no sense of place. The chosen spine combines crew and production chains inside one closed economy loop: every run resource feeds the island, every island output feeds the runs. The rework ships as three plans:

- **Plan 10 (this spec): Crew.** Rescue survivors during runs, assign them to buildings, crew multiply existing production rates. Establishes the per-building rate seam.
- **Plan 11: Production chains.** Intermediate resources (worked parts, provisions), conversion recipes, gizmo crafts repriced to components. Crew multipliers apply to chain throughput through the Plan 10 seam.
- **Plan 12: The run kit.** Chain outputs spendable at the Plan 9 setup phase: one-run consumables and expedition provisioning.

Owner decisions locked during brainstorming: crew gating is soft (uncrewed buildings run at today's rates, crewed runs faster; no onboarding cliff and clean v7 migration); rescues happen as a survivor drifting on the run board, rescued by pod contact; the cast is authored and finite (eight named characters, rescues stop when everyone is home).

## 1. Summary of Plan 10

Salvage runs occasionally spawn a drifting survivor among the pegs; touching them with a pod rescues them on the spot. Rescued crew appear on the island roster and can be assigned to workable buildings, multiplying that building's production rate (Gardens trickle, Workshop craft speed, Wind Still regen; Balloonworks and Foundry Annex assignments are legal now and become productive in Plan 11). Eight authored characters carry the sky-civilization story the islet letters started, two of them continuing those letters directly.

Out of scope for this plan: production chains and new resources (Plan 11), setup-phase consumables and provisioning (Plan 12), crew portraits or art, any spatial island UI, crew appearing in the run setup phase, crew upkeep or happiness simulation.

## 2. Data: crew.json

New file `game/data/crew.json`, loaded by DataDefs as `DataDefs.crew`. Raw JSON numbers follow the repo convention (cast with `int()` / `float()` at use and assert sites).

```json
{
	"generalist_bonus": 1.25,
	"workable": ["gardens", "workshop", "wind_still", "balloonworks", "foundry_annex"],
	"survivor": {
		"chance_per_run": 0.25,
		"spawn_delay_min": 2.0,
		"spawn_delay_max": 8.0,
		"drift_speed": 60.0,
		"drift_y": 480.0,
		"radius": 26.0
	},
	"crew": [
		{"id": "maren", "name": "Maren", "specialty": "workshop", "bonus": 1.5,
			"line": "You found my tools on the shoal? Then let's put them to work."},
		{"id": "halvard", "name": "Halvard", "specialty": "foundry_annex", "bonus": 1.5,
			"line": "Day 417. The coals were banked on purpose. I said someone would come."},
		{"id": "odo", "name": "Odo", "specialty": "gardens", "bonus": 1.5,
			"line": "Soil remembers. So do I."},
		{"id": "brisa", "name": "Brisa", "specialty": "wind_still", "bonus": 1.5,
			"line": "That still of yours whistles flat. I can fix that."},
		{"id": "petch", "name": "Petch", "specialty": "balloonworks", "bonus": 1.5,
			"line": "Silk holds if you tie it like you mean it."},
		{"id": "suno", "name": "Suno", "specialty": "gardens", "bonus": 1.5,
			"line": "Rain is just sky-sea. I speak both."},
		{"id": "immel", "name": "Immel", "specialty": "workshop", "bonus": 1.5,
			"line": "Half these gizmos were mine once, you know. The good halves."},
		{"id": "reya", "name": "Reya", "specialty": "balloonworks", "bonus": 1.5,
			"line": "Ditched at sea twice already. The third time buys the drinks."}
	]
}
```

Story continuity is deliberate: Maren is the lens grinder named in Lantern Shoal's letter, Halvard the foreman whose brass-bound log is found on Foundry Rock. Their lines only land if those islets can be restored, but rescue order is random and independent of islet progress; the lines read fine either way.

Authoring guards: crew ids must be unique; every `specialty` must appear in `workable`; every entry in `workable` must be a real building def id. A data test pins all three.

## 3. Save schema v8

```
"crew": {"rescued": {}, "assignments": {}}
```

`rescued` maps crew id to `true`. `assignments` maps building id to crew id; a crew id appears in at most one assignment (model-enforced, and healed defensively on read). `CURRENT_VERSION` becomes 8, `_migrate_7_to_8` adds the section, `_backfill_missing_keys` heals it. No other sections change.

## 4. CrewModel (new, pure)

`game/base/crew_model.gd`, `class_name CrewModel`, all-static, no autoload/clock/RNG reads.

- `members(defs: Dictionary) -> Array` and `entry(defs: Dictionary, crew_id: String) -> Dictionary`: def accessors.
- `is_rescued(data: Dictionary, crew_id: String) -> bool`; `rescued_ids(data: Dictionary, defs: Dictionary) -> Array[String]` (defs order).
- `unrescued_ids(data: Dictionary, defs: Dictionary) -> Array[String]`: the survivor spawn pool.
- `rescue(data: Dictionary, crew_id: String) -> bool`: sets `rescued[crew_id]`; write-back discipline heals a missing or wrong-typed `crew` section; false for empty id; idempotent.
- `crew_at(data: Dictionary, building_id: String) -> String` and `building_of(data: Dictionary, crew_id: String) -> String`.
- `assign(data: Dictionary, defs: Dictionary, building_id: String, crew_id: String) -> bool`: requires the crew rescued and the building in `workable`; clears the crew's previous assignment (a move) and overwrites the building's previous occupant (they become unassigned). Mirrors `GizmoLoadout.place` semantics.
- `unassign(data: Dictionary, building_id: String) -> void`.
- `multiplier_for(data: Dictionary, defs: Dictionary, building_id: String) -> float`: 1.0 when unmanned, `generalist_bonus` (1.25) when the assigned crew's specialty is elsewhere, the crew's `bonus` (1.5) on a specialty match. This function is the seam Plan 11 reuses for chain throughput.

## 5. Rate wiring

All three wirings recompute from state, never increment, in the existing idempotent style:

- **Gardens trickle:** `TrickleModel` rate becomes `base_rate x multiplier_for(data, crew_defs, "gardens")`. An assignment change mid-accrual must not re-rate scrap already earned: reuse the Plan 4 rebase pattern (recompute `last_collect` so the pending VALUE carries over unchanged at the new rate). Rebase happens inside the assignment mutation path so every caller inherits it.
- **Workshop crafts:** `CraftModel.start_craft` divides `craft_seconds` by `multiplier_for(..., "workshop")` (ceiled to an int, minimum 1 second). The duration locks at timer start: reassigning mid-craft neither shortens nor lengthens a running craft (timers persist plain `ends_at`; this is stated behavior, not a gap).
- **Wind Still regen:** `IslandEffects.apply_fuel` divides the wind-still-adjusted `regen_seconds` by `multiplier_for(..., "wind_still")`, still flooring at `MIN_REGEN_SECONDS`. Idempotent re-application at load and collect self-heals as today. Signature grows optional trailing `crew_defs` with `{}` default so existing callers and tests stay valid until updated.
- **Balloonworks / Foundry Annex:** assignment is legal and persisted; no rate exists yet to multiply (Balloonworks' drops bonus is static, the Annex discount is static). The crew panel labels these "ready for new work"; Plan 11 gives them chains.

## 6. Run-side rescue

- On entering RUNNING (inside the Start flow, never during setup), if `unrescued_ids` is non-empty, roll `chance_per_run` on the scene's existing injected `_rng`. On success, pick one unrescued survivor and a spawn delay in `[spawn_delay_min, spawn_delay_max]` seconds, then start a scene-owned child Timer.
- The survivor is an `Area2D` (`game/run/survivor.gd`, group `"survivors"`, placeholder Polygon2D raft) that drifts horizontally across the board at `drift_y` with `drift_speed`, direction and entry side from the same rng roll. It monitors body contact; any `RigidBody2D` pod touching it triggers the rescue. It frees itself when it exits the far side; run over sweeps it.
- Rescue: `CrewModel.rescue`, immediate `GameState.save_game()` (a rescue must survive an OS kill), a RescueBanner label on the run HUD ("Rescued Maren! \"You found my tools on the shoal? Then let's put them to work.\"") shown for a few seconds via a child Timer, survivor node freed. No drop consumed, no payout pipeline involvement, no interaction with boon offers.
- If the timer fires while the phase is not RUNNING (over/abandoned), it does nothing.

## 7. Island UI

Below the islet rows on the island screen, a **Crew panel**:

- One row per crew def, in defs order. Rescued: name, specialty tag, and an assignment cycle button ("Assign: Gardens" tapping cycles Unassigned then each `workable` building; the model's displacement rules apply; every change saves). Unrescued: a dimmed silhouette row ("Someone is still out there...") so the collection is visible.
- Building rows gain a worker suffix when crewed ("Gardens Lv 2, Odo working").
- The refresh signature extends with the rescued set and the assignments map (both structural); labels update in place otherwise.
- Assignment changes route rejections (unknown building states cannot occur via the cycle UI, so no StatusLabel wiring is needed beyond what the model returns) and always `_rebuild` after a change.

## 8. Testing

Headless GUT, repo conventions (injected clocks and RNG, direct handler calls, int casts at JSON assert sites).

- **Data guards:** crew id uniqueness, specialties within `workable`, workable ids are real building defs.
- **CrewModel:** rescue idempotence and wrong-typed-section healing; assign requires rescued + workable; move clears the old building; overwrite unassigns the displaced crew; multiplier tiers 1.0 / 1.25 / 1.5.
- **Schema:** v8 default shape, 7 to 8 lossless migration, backfill healing, full v1-to-8 chain.
- **Wiring:** trickle at 1.5x with Odo on Gardens including the rebase-on-reassignment proof (pending value unchanged across an assignment flip); craft duration shortened at start and locked mid-craft; regen divided with the MIN floor respected.
- **Run side (fixed seed):** survivor spawns only when the pool is non-empty and only in RUNNING; contact rescues, persists to disk mid-run, and frees the node; run-over sweep; no spawn when the cast is complete.
- **Screen:** silhouette vs rescued rows, cycle assignment through the workable list, worker suffix, signature changes on rescue and reassignment.
- **Integration proof (fixed seed, no-strict-RED per standing ruling):** a run rescues a survivor end to end, assignment to Gardens speeds the trickle measurably against the injected clock.

## 9. Risks and interactions

- **Trickle re-rating** is the sharpest correctness edge (same class as the Plan 4 gardens-upgrade rebase); the rebase lives in the mutation path, and the test proves value preservation.
- **`IslandEffects.apply_fuel` signature growth**: optional trailing param keeps every existing caller compiling; callers that should pass crew defs are enumerated in the plan.
- **Survivor node lifetime** follows the pod-watchdog rules: scene-owned child Timers, no typed freeable binds, `is_instance_valid` guards, group sweep on run over.
- **Two crew share a specialty** (gardens x2, workshop x2, balloonworks x2): deliberate, so a second specialist is available once Plan 11 makes more buildings productive simultaneously; before then the duplicate is a generalist elsewhere, which is a real assignment decision.
- **Migration**: v7 saves gain an empty crew section; behavior with zero rescues is byte-identical to today (multiplier 1.0 everywhere), which is the soft-gating decision doing its job.
