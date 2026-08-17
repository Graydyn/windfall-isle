# Region 2 "Brasswork Reach" Design (Plan 6)

**Status:** Approved design, pre-plan
**Date:** 2026-08-17
**Parent spec:** docs/design/2026-08-15-windfall-isles-design.md (binding where this document is silent; sections 3.1, 3.4, 4.1, 4.2 govern regions, hazards, the Dock, and materials)
**Scope decisions made with the project owner:** region 2 ships before boons (boons are Plan 7); the hazard is drift currents; brasswork gates two new gizmos. AdMob remains untouched. Island expansion/story, rarities, sound, and the art pass stay out.

---

## 1. Goals

Give the Dock its spec-4.1 payload (region unlocks, fuel-cost reduction), start the Loop 2 content treadmill with a second skyfield that plays differently (drift currents), and give brasswork real sinks (two new craftable gizmos). Fold in the Plan 5 backlog fixes. Everything a designer would tune stays in `game/data/*.json`.

## 2. Regions as data

`game/data/run.json` gains a top-level `regions` array (array, not dict, so ordering is explicit):

```json
"regions": [
	{"id": "region_1", "name": "Home Skies", "fuel_cost": 1, "min_dock_level": 0},
	{"id": "region_2", "name": "Brasswork Reach", "fuel_cost": 2, "min_dock_level": 1,
	 "reduced_fuel_cost": 1, "reduced_at_dock_level": 2}
]
```

A new pure class `game/core/region_model.gd` (`RegionModel`), following the FuelModel pattern (no clock, no nodes, defs passed in):

- `unlocked(region_entry: Dictionary, island: Dictionary) -> bool`: true when `IslandModel.building_level(island, "dock") >= int(region_entry.get("min_dock_level", 0))`.
- `fuel_cost(region_entry: Dictionary, island: Dictionary) -> int`: the entry's `fuel_cost`, replaced by `reduced_fuel_cost` when the Dock level is at or above `reduced_at_dock_level` (both keys optional; absent means no reduction).
- `unlocked_entries(run_defs: Dictionary, island: Dictionary) -> Array`: the `regions` array filtered to unlocked entries, in declared order. Falls back to a single implicit region_1 entry when the `regions` key is absent (defensive only; the shipped JSON always carries it).
- `entry(run_defs: Dictionary, region_id: String) -> Dictionary`: lookup by id, `{}` when unknown.

Region 1 is `min_dock_level: 0`: always unlocked, always 1 fuel. Dock Lv1 unlocks Brasswork Reach at 2 fuel; Dock Lv2 reduces it to 1. This exhausts the Dock's spec payloads.

## 3. Save schema v6: selected region

`SaveSchema.CURRENT_VERSION` becomes 6. The save gains `"expedition": {"region": "region_1"}` (named to avoid colliding with the `DataDefs.run` defs concept). `_migrate_5_to_6` adds the section; the existing `_backfill_missing_keys` picks it up for damaged current-version saves once `default_data` carries it. Migration is lossless for v5 and the v1 chain hops all the way, same test pattern as v5.

If the persisted region id is unknown or no longer unlocked at read time (defs changed, hand-edited save), consumers fall back to `region_1` at the point of use; nothing crashes and nothing rewrites the save eagerly.

## 4. Region selection UI

**Main screen** gains a `RegionButton` above the refill button (same cycler pattern as the island plot selector): its text shows `"Region: <name> (<cost> fuel)"` for the selected region; tapping cycles through `RegionModel.unlocked_entries` and persists `expedition.region` (save on change). The Launch button's disabled state and `_on_launch_pressed`'s spend both use `RegionModel.fuel_cost` for the selected region instead of the flat `run.fuel_cost` (which remains in the JSON as the fallback for the defensive implicit-region path only).

**Loadout screen**: `region_id` stops being a hardcoded `"region_1"` and becomes the persisted selection, with a `RegionButton` cycler at the top that switches which region's slots and loadout are being edited (GizmoLoadout has been keyed by region_id since Plan 3a; only the screen was fixed to region 1). Slots count comes from the region JSON as today. Cycling saves the region selection immediately (same per-tap persistence rule as slot edits).

**salvage_run.gd** reads the selected region id from the save (with the region-1 fallback), loads `DataDefs.skyfield(region_id)`, and passes the id to `GizmoLoadout.loadout_for`. The launcher (main.gd) remains the only fuel spender.

## 5. The Brasswork Reach board

`game/data/skyfields/region_2.json`, same shape as region 1 plus two new optional keys (`drift_zones`, `sea_payout`):

- **Board:** same portrait envelope `{left: 20, right: 700, top: 140, bottom: 1020}`.
- **Pegs:** ~36 pegs; the staggered grid is interrupted by two "gear cluster" rings (8 pegs arranged in a circle around an open hub) that create orbit-and-funnel paths. Pegs are the same node type as region 1; art differentiation is the image agent's job later.
- **Gizmo slots:** 8 (up from 6), ids `slot_0..slot_7` as generated today.
- **Barges (5):** brasswork drops on the outer barges: far_left `{"scrap": 14}`, left `{"scrap": 6}`, center `{"scrap": 3}`, right `{"scrap": 6, "brasswork": 1}`, far_right `{"scrap": 10, "brasswork": 2}`.
- **Quota tiers:** `[{"scrap_quota": 35, "payout_multiplier": 1.25}, {"scrap_quota": 80, "payout_multiplier": 1.6}]`.
- **Sea payout override:** region JSON may carry `"sea_payout"`; `Skyfield.build` prefers it over the run-level default. Region 2 uses `{"scrap": 2}` (richer skies, richer misses).
- **Drift zones (the hazard):** see section 6. Region 2 ships two: an upper zone pushing right and a lower zone pushing left, so a straight drop is impossible but a Wind Fan, Magnet Buoy, or Gyro Damper restores control.

`economy.json` `starting_balances` gains `"brasswork": 0`. Balance displays (main debug label) add the brasswork line.

## 6. Drift currents

Region JSON: `"drift_zones": [{"x": 360, "y": 420, "half_width": 200, "half_height": 90, "force": 220.0, "direction": 1.0}, ...]` (direction -1.0 pushes left). `Skyfield` gains `_build_drift_zones(zones: Array)` called from `build()`, creating one Area2D per zone (group `"drift_zones"`, rectangle collider, position/size from data) under a new `DriftZones` child node in `skyfield.tscn`. Each zone applies `force * direction` horizontally to overlapping RigidBody2D pods every physics frame, mirroring the Wind Fan's column mechanics (same force application pattern; forces are mass-respecting, never direct velocity writes).

**Damper interaction:** before applying force to a pod, a drift zone checks the `"gyro_dampers"` group: if the pod's global position is within any damper's `field_radius`, the push is skipped for that pod that frame. This keeps the interaction one-directional (zones ask, dampers just exist) and testable with real physics contact.

Region 1 has no `drift_zones` key: zero behavior change there. A drift zone is a board feature, not a gizmo: it has no level, no defs lookup, no context.

## 7. The two brass gizmos

Both are defined in `gizmos.json` `defs` but NOT added to `starting_inventory`: they are the game's first craft-to-acquire gizmos. Both extend GizmoBase, live in `game/run/gizmos/`, and follow every established gizmo discipline (self-contained scenes, `scaled()` level growth, `has_meta("caught")` early returns for contact effects, `add_child.call_deferred` if they ever mutate the physics world mid-flush; the Kicker applies impulses only, which is safe in-callback per the Balloon Cluster precedent).

- **Gyro Damper** (`gyro_damper`): passive field, `field_radius` 140 (scaled by level). Registers in group `"gyro_dampers"` and exposes `field_radius`; drift zones do the checking (section 6). Visual: circle polygon placeholder like Magnet Buoy. Craft: `{"scrap": 200, "brasswork": 2}`, 420 s.
- **Piston Kicker** (`piston_kicker`): contact gizmo, zone radius 24. On pod contact (not caught, no `"piston_kicked"` meta), applies a horizontal impulse `force * direction` (force 520 scaled, direction from defs, default 1.0) and sets `"piston_kicked"` so each pod is kicked at most once per drop (split clones inherit no meta, so each clone can be kicked once). Craft: `{"scrap": 180, "brasswork": 1}`, 300 s.

**Workshop acquires-by-craft change:** `CraftModel.can_craft` currently requires `owned.has(gizmo_id)`; it changes to allow any gizmo present in `defs` (owned or not), still respecting slots, per-gizmo active-craft, `craft_max_level`, and affordability (unowned treated as level 0, so max-level check never blocks a first craft). `CraftModel.complete_craft` grants `owned[id] = 1` when unowned, else merges `+1` as today. The workshop screen iterates `defs` (stable order) instead of `owned`, labeling unowned rows `"<name> (not owned)"`; brasswork costs make region 2 the natural gate, no extra recipe-lock mechanism (YAGNI). The Plan 4 memory note about the hardcoded 8-starter test is now live: that test still holds (starting inventory stays 8) but workshop-screen row-count tests change from 8 to the defs count (10).

## 8. Plan 5 backlog fixes (fold into the plan's first task)

1. **Quota-tier row validation:** `RunModel._init` keeps only rows that are Dictionaries with `int(scrap_quota) > 0` and a present `payout_multiplier`; each dropped row gets one `push_warning`. Prevents a malformed region row from lifting the tier at 0 scrap.
2. **Notifications write-back symmetry:** `NotificationSvc.request_permission_once` writes the section back (`if not data.has("notifications"): data["notifications"] = {"permission_requested": false}`) before mutating, matching `AdLimits._ads`.
3. **Stale StatusLabel:** `island_screen._on_select_pressed` clears `$StatusLabel.text` before `_rebuild()`.
4. **UTC-midnight flake shrink:** the two wall-clock ad-limit tests (`test_refill_stops_at_the_daily_limit`, bonus-crate daily-limit test) restructure to stamp `data["ads"]` with today's day and pre-filled counts at test start, then make a single press and assert. The flake window shrinks from a multi-press loop to milliseconds; noted as accepted residual risk.

Explicitly NOT fixed here (parked for the AdMob plan, per project owner): skip-button availability outside the refresh signature; grant callbacks assuming synchronous grants.

## 9. Testing

House pattern throughout (GUT 9.6.1 headless, explicit `now`, int-cast JSON assertions, `.gd.uid` sidecars, error-count assertions after triggers):

- **RegionModel:** pure unit tests: locked/unlocked by dock level, cost reduction at Lv2, ordering, unknown-id fallback.
- **Schema v6:** lossless v5 hop, v1 chain to 6, backfill covers `expedition`.
- **Drift zones:** physics integration proof with real contact: a pod dropped through a right-pushing zone ends measurably right of its drop x (`await wait_physics_frames` discipline); a pod inside a Gyro Damper field does not.
- **Gizmos:** Piston Kicker kicks once per pod (real contact), respects `caught` meta; Gyro Damper registers group/radius and scales with level.
- **CraftModel:** unowned craft grants Lv1; still blocked by slots/affordability; max-level unaffected.
- **Screens:** region cycler cycles only unlocked regions and persists; launch spends region cost; loadout edits region-2 slots; workshop lists unowned rows and crafts them.
- **Region 2 data:** barge-id uniqueness (validator from Plan 5), quota tiers valid, board parses.
- **E2E (fake clock, no-strict-RED per standing ruling):** build Dock, unlock region 2, select it, run a scripted catch dropping brasswork, craft the Gyro Damper with it, slot it in region 2's loadout.

## 10. Out of scope

Boons (Plan 7), AdMob and the two parked async-ad items, island expansion/story vignettes, gizmo rarities, sound, art (docs/art/placeholder-graphics-audit.md gains region-2 entries only when the art pass happens), regions 3+ (but everything here is data-driven so region 3 is a JSON file plus at most a new hazard).
