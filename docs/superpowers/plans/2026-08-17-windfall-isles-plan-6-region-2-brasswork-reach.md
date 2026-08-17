# Windfall Isles Plan 6: Region 2 Brasswork Reach Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the second skyfield: the Dock unlocks Brasswork Reach (drift-current hazard, brasswork material, 8 gizmo slots), two brasswork-crafted gizmos arrive via a craft-to-acquire Workshop, region selection is persisted in save schema v6, and the Plan 5 backlog fixes land.

**Architecture:** Regions become data: a `regions` array in run.json read by a new pure `RegionModel` (FuelModel pattern: defs in, values out, no clock, no nodes). Drift currents are board-owned Area2D wind columns (`DriftZone`) built from region JSON, the hostile twin of the Wind Fan; the Gyro Damper nulls them via a one-directional group check (zones ask, dampers exist). The Workshop becomes the first non-starter gizmo faucet: `CraftModel` drops its owned-only gate and grants level 1 on a first craft. Save schema v6 adds the persisted region selection with the established migration + backfill pattern.

**Tech Stack:** Godot 4.6.3 GDScript, GUT 9.6.1 headless, JSON data files.

**Spec:** [docs/superpowers/specs/2026-08-17-region-2-brasswork-reach-design.md](../specs/2026-08-17-region-2-brasswork-reach-design.md) (approved; its parent docs/design/2026-08-15-windfall-isles-design.md binds where it is silent). Plans 1-5 are merged on main (284 tests green at 0f652aa, plus the spec commit).

## Global Constraints

- Engine: Godot 4.6.x pinned; `$GODOT` = `/Applications/Godot-4.6.app/Contents/MacOS/Godot` (4.6.3). Never plain `godot` or `/Applications/Godot.app` (4.7).
- GDScript only; tabs. Every tunable in `game/data/*.json`. Logic takes `now: int`; only boundaries call `TimeUtil.now()`. No em dashes in any file.
- Save schema versioned; this plan bumps to v6 (`"expedition": {"region": "region_1"}`). v5 saves gain it losslessly; v1 chain-hops to 6; `_backfill_missing_keys` picks it up once `default_data` carries it.
- Unknown or locked persisted region ids fall back to `region_1` at the point of use; nothing crashes, nothing rewrites the save eagerly.
- Forces on pods are mass-respecting (`apply_central_force`/`apply_central_impulse`), never direct velocity writes (standing exception: relaunching a FROZEN body from a timer context).
- Contact gizmos early-return on `body.has_meta("caught")`. Impulse-in-`body_entered` is safe (Balloon Cluster precedent); anything that ADDS nodes during a physics flush uses `add_child.call_deferred`.
- Any gizmo/hazard handler that affects the physics world needs one integration proof driven by REAL contact, never only direct handler calls. `await wait_physics_frames(2)` (or `wait_seconds`) before velocity asserts.
- Canonical test command (must exit 0): `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- Binding repo lessons (Plans 1-5): `.gd.uid` sidecars committed for EVERY new script including tests, verified via `git status --porcelain` after `--import`; error-count assertions AFTER the trigger; `int()`/`float()` wrap all JSON reads; int-cast scalar assertions against JSON-sourced dicts; no cumulative suite totals (per-task new-test lists only); GUT auto-fails on pushed ERRORS not warnings; UI tests never press buttons that change scenes; GameState `_io` swap + `after_all` restore with four-arg `load_game`; scene-owned child Timer + `weakref()`; `assert_signal_emitted_with_parameters` takes no message arg; explicit types where `:=` inference hits untyped chains.
- One pre-existing GUT warning (`tests/fixtures/test_gizmo.gd` not extending GutTest) is known and benign; new warnings are findings.
- The sandbox rejects compound bash commands; run commands one at a time.
- Commit after every task, conventional-commit messages.

## Interfaces consumed from Plans 1-5 (merged, exact)

- `IslandModel.building_level(island: Dictionary, building_id: String) -> int`; `IslandModel.start_build(island, defs, economy, timers, plot, building_id, now) -> bool`; `IslandModel.complete_build(island, payload, data, now, building_defs = {})`.
- `SaveSchema`: `CURRENT_VERSION == 5`, `default_data(defs, gizmo_defs = {})`, `migrate(data, gizmo_defs = {})`, `_migrate_4_to_5`, `_fresh_ads()`, `_fresh_notifications()`, `_backfill_missing_keys(data, gizmo_defs)`.
- `Skyfield`: `build(region_defs, run_defs)` calling `_build_walls(board)`, `_build_pegs`, `_build_barges` (warns via `duplicate_barge_ids(barges) -> Array`), `_build_sea(board)`, `_build_slots`; `install_gizmos(loadout, gizmo_defs, owned, context)`; scene children `Walls/Pegs/Barges/GizmoSlots/Gizmos`; signal `pod_caught(pod, payout, source)`; `sea_payout: Dictionary`.
- `GizmoBase`: `setup(gizmo_defs, gizmo_level, run_context)` calls `_configure()`; `scaled(base) -> float` is `base * (1.0 + 0.25 * (level - 1))`; gizmo scenes are `Node2D` + optional `Zone` Area2D with `Shape` + `Visual` Polygon2D.
- `WindFan._physics_process` pattern: `for body in zone.get_overlapping_bodies(): if body is RigidBody2D: body.apply_central_force(_force_vector)`.
- `CraftModel`: `craft_slots(island)`, `active_crafts(timers)`, `can_craft(data, gizmo_defs, economy, timers, gizmo_id)`, `start_craft(... , now)`, `complete_craft(data, payload)`; craft timers id `"craft_<gizmo_id>"` kind `"craft"` payload `{"gizmo"}`.
- `GizmoLoadout.loadout_for(gizmos_state, region_id) -> Dictionary`, `owned(gizmos_state) -> Dictionary`, `set_slot(gizmos_state, region_id, slot, gizmo_id)`, `next_choice(current, owned_ids, used) -> String`.
- `RunModel`: `_init(config)` reads `drops_per_run`/`max_active_pods`/`quota_tiers`; `tiers: Array`, `tier: int`, `payout_multiplier() -> float`, `resolve_pod`, `add_bonus_loot`, signal `tier_reached(tier)`.
- `FuelModel.current/spend(fuel, ..., now)`; `Economy.balance/add/can_afford/pay`; `TimeUtil.now()`; `DailyCrate.day_of(now)`; `AdLimits.used/can_use/use`; `NotificationSvc.scheduler: NotificationScheduler`, `request_permission_once()`.
- `DataDefs.run/economy/gizmos/buildings/retention`, `DataDefs.skyfield(region_id)`, `DataDefs.load_json(path)`.
- `main.gd`: `_refresh()` (debug label + RefillButton state + launch disabled), `_on_launch_pressed()` (spends fuel, changes scene), `_refill_limit()`.
- `loadout_screen.gd`: `region_id` member (currently `"region_1"`), `_slots: Array`, `_rebuild()`, `_row_text(slot, gizmo_id)`, `_on_slot_pressed(slot)` (saves per tap).
- `workshop_screen.gd`: `_signature(now)`, `_refresh_tick()`, `_refresh_labels(now)`, `_slots_text()`, `_gizmo_label_text(gizmo_id, now)`, `_rebuild()`, `_gizmo_labels: Dictionary`, `_last_signature`, `_on_craft_pressed/_on_collect_pressed/_on_skip_pressed/_grant_skip`.
- `island_screen.gd`: `_on_select_pressed(plot)` (cycles `_selection`, calls `_rebuild()`), `StatusLabel` node, `_on_bonus_crate_pressed()`.
- `NotificationSvc.request_permission_once` current body reads `GameState.data.get("notifications", {})` (the detached-dict weakness this plan fixes).

## File Structure

```
game/run/run_model.gd                     # T1 modify (tier row validation)
game/autoload/notification_svc.gd         # T1 modify (write-back)
game/base/island_screen.gd                # T1 modify (StatusLabel clear)
tests/test_run_model.gd                   # T1 append
tests/test_notifications.gd               # T1 append
tests/test_island_screen.gd               # T1 append + bonus-crate test edit
tests/test_main_boot.gd                   # T1 edit (flake shrink), T8 append
game/core/region_model.gd                 # T2 pure region rules
game/data/run.json                        # T2 modify (regions array)
tests/test_region_model.gd                # T2
game/core/save_schema.gd                  # T3 modify (v6)
tests/test_save_schema.gd                 # T3 edits + append
game/run/drift_zone.gd                    # T4 hazard node
game/run/skyfield.gd + skyfield.tscn      # T4 modify (drift zones, sea override)
tests/test_drift_zone.gd                  # T4
game/data/skyfields/region_2.json         # T5
game/data/economy.json                    # T5 modify (brasswork)
tests/test_region_2_defs.gd               # T5
game/run/gizmos/gyro_damper.gd/.tscn      # T6
game/run/gizmos/piston_kicker.gd/.tscn    # T6
game/data/gizmos.json                     # T6 modify (two defs)
tests/test_gyro_damper.gd                 # T6
tests/test_piston_kicker.gd               # T6
game/base/craft_model.gd                  # T7 modify (craft-to-acquire)
game/base/workshop_screen.gd              # T7 modify (defs iteration)
tests/test_craft_model.gd                 # T7 edit + append
tests/test_workshop_screen.gd             # T7 edit + append
game/main.gd + game/main.tscn             # T8 modify (region cycler, brasswork line)
game/run/salvage_run.gd                   # T8 modify (selected region)
tests/test_salvage_run.gd                 # T8 append
game/ui/loadout_screen.gd/.tscn           # T9 modify (region cycler)
tests/test_loadout_screen.gd              # T9 append
tests/test_region_2_integration.gd        # T10 fake-clock e2e
```

---

### Task 1: Plan 5 backlog fixes

**Files:**
- Modify: `game/run/run_model.gd`, `game/autoload/notification_svc.gd`, `game/base/island_screen.gd`
- Test: `tests/test_run_model.gd` (append), `tests/test_notifications.gd` (append), `tests/test_island_screen.gd` (append + 1 edit), `tests/test_main_boot.gd` (1 edit)

**Interfaces:**
- Consumes: `RunModel._init` tiers assignment, `NotificationSvc.request_permission_once`, `island_screen._on_select_pressed`, the two wall-clock ad-limit tests.
- Produces: `RunModel` static `_valid_tiers(rows: Variant) -> Array` (only Dictionary rows with `int(scrap_quota) > 0` and a `payout_multiplier` key survive; each dropped row push_warnings once); `request_permission_once` writes the notifications section back before mutating; `_on_select_pressed` clears StatusLabel; the daily-limit tests stamp `data["ads"]` and press once (flake window shrinks to milliseconds, accepted residual).

- [ ] **Step 1: Append the failing tests**

Append to `tests/test_run_model.gd`:

```gdscript
func test_malformed_tier_rows_are_dropped_with_a_warning() -> void:
	var model := RunModel.new({
		"drops_per_run": 3, "max_active_pods": 4,
		"quota_tiers": [
			{"payout_multiplier": 9.0},
			{"scrap_quota": 0, "payout_multiplier": 9.0},
			{"scrap_quota": 10, "payout_multiplier": 1.5},
			"junk",
		],
	})
	assert_push_warning_count(3, "one warning per dropped row")
	assert_eq(model.tiers.size(), 1, "only the well-formed row survives")
	model.begin_drop()
	model.resolve_pod({"scrap": 5})
	assert_eq(model.tier, 0, "a zero-quota row must never lift at 0 scrap")
	model.begin_drop()
	model.resolve_pod({"scrap": 5})
	assert_eq(model.tier, 1)
	assert_eq(model.payout_multiplier(), 1.5)
```

(If GUT 9.6.1 rejects `assert_push_warning_count` as unknown, use `assert_eq(model.tiers.size(), 1)` alone and delete the warning-count line; the warning itself is cosmetic. Check `addons/gut/` for the assert before deciding; GUT 9.6 provides `assert_push_error_count` and `assert_engine_error_count`, and the warning variant may not exist.)

Append to `tests/test_notifications.gd`:

```gdscript
func test_permission_once_heals_a_missing_notifications_section() -> void:
	var rec := RecordingScheduler.new()
	NotificationSvc.scheduler = rec
	var data := make_data()
	data.erase("notifications")
	GameState.data = data
	NotificationSvc.request_permission_once()
	assert_true(GameState.data.has("notifications"), "the section is written back, not lost in a detached dict")
	assert_true(bool(GameState.data["notifications"]["permission_requested"]))
	assert_eq(rec.permission_calls, 1)
```

Append to `tests/test_island_screen.gd`:

```gdscript
func test_selection_change_clears_stale_status() -> void:
	screen.get_node("StatusLabel").text = "Not enough resources."
	screen._on_select_pressed("plot_0")
	assert_eq(screen.get_node("StatusLabel").text, "", "a stale rejection must not outlive the selection it judged")
```

- [ ] **Step 2: Make the two flake-window edits**

In `tests/test_main_boot.gd`, replace the whole `test_refill_stops_at_the_daily_limit` function with:

```gdscript
func test_refill_stops_at_the_daily_limit() -> void:
	var limit := int((DataDefs.retention["ads"] as Dictionary)["fuel_refills_per_day"])
	GameState.data["ads"] = {"day": DailyCrate.day_of(TimeUtil.now()), "counts": {"fuel_refill": limit}}
	GameState.data["fuel"]["amount"] = 0
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	main._on_refill_pressed()
	assert_eq(FuelModel.current(GameState.data["fuel"], TimeUtil.now()), 0,
		"spec 6: fuel refills are limited per day")
```

In `tests/test_island_screen.gd`, replace the whole `test_bonus_crate_pays_and_respects_the_daily_limit` function with:

```gdscript
func test_bonus_crate_pays_and_respects_the_daily_limit() -> void:
	var scrap_before := Economy.balance("scrap")
	screen._on_bonus_crate_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 40)
	GameState.data["ads"]["day"] = DailyCrate.day_of(TimeUtil.now())
	screen._on_bonus_crate_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 40, "bonus crate is once per day")
```

- [ ] **Step 3: Run tests to verify the new ones fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL. The malformed-tier test lifts at 0 scrap (tier becomes 2, tiers.size() is 4); the notifications test loses the flag in a detached dict (`has("notifications")` false); the StatusLabel test sees stale text. The two edited tests still pass (behavior unchanged, structure only).

- [ ] **Step 4: Implement**

In `game/run/run_model.gd`, change the `_init` tiers line from `tiers = config.get("quota_tiers", [])` to `tiers = _valid_tiers(config.get("quota_tiers", []))` and add at the end of the file:

```gdscript
static func _valid_tiers(rows: Variant) -> Array:
	# Region-authoring validation (Plan 5 final-review carry-forward): a row
	# missing scrap_quota would lift the tier at 0 scrap on the first catch.
	var out: Array = []
	if not (rows is Array):
		return out
	for row in rows:
		if row is Dictionary and int((row as Dictionary).get("scrap_quota", 0)) > 0 \
				and (row as Dictionary).has("payout_multiplier"):
			out.append(row)
		else:
			push_warning("Ignoring malformed quota tier row: %s" % [row])
	return out
```

In `game/autoload/notification_svc.gd`, replace `request_permission_once` with:

```gdscript
func request_permission_once() -> void:
	# Spec 5: ask at the first construction completion, not at first launch.
	# Write the section back first so a damaged save cannot swallow the flag
	# in a detached dict (same discipline as AdLimits._ads).
	if not GameState.data.has("notifications"):
		GameState.data["notifications"] = {"permission_requested": false}
	var flags: Dictionary = GameState.data["notifications"]
	if bool(flags.get("permission_requested", false)):
		return
	flags["permission_requested"] = true
	scheduler.request_permission()
```

In `game/base/island_screen.gd`, in `_on_select_pressed`, add `$StatusLabel.text = ""` immediately before the final `_rebuild()` line.

- [ ] **Step 5: Run tests to verify they pass**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0.

- [ ] **Step 6: Commit**

```bash
git add game/run/run_model.gd game/autoload/notification_svc.gd game/base/island_screen.gd tests/test_run_model.gd tests/test_notifications.gd tests/test_island_screen.gd tests/test_main_boot.gd
git commit -m "fix: plan 5 backlog: tier validation, notification write-back, status clear, flake shrink"
```

---

### Task 2: RegionModel and regions data

**Files:**
- Create: `game/core/region_model.gd`
- Modify: `game/data/run.json`
- Test: `tests/test_region_model.gd` (new)

**Interfaces:**
- Consumes: `IslandModel.building_level`.
- Produces (consumed by T8/T9/T10): `RegionModel.FALLBACK_ID == "region_1"`; `unlocked(region_entry: Dictionary, island: Dictionary) -> bool`; `fuel_cost(region_entry: Dictionary, island: Dictionary) -> int`; `unlocked_entries(run_defs: Dictionary, island: Dictionary) -> Array` (declared order); `entry(run_defs: Dictionary, region_id: String) -> Dictionary` ({} when unknown); `selected_id(data: Dictionary, run_defs: Dictionary, island: Dictionary) -> String` (persisted choice, falling back to region_1 when unknown or locked). run.json gains the `regions` array.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_region_model.gd`:

```gdscript
extends GutTest

const RUN_DEFS := {
	"fuel_cost": 1,
	"regions": [
		{"id": "region_1", "name": "Home Skies", "fuel_cost": 1, "min_dock_level": 0},
		{"id": "region_2", "name": "Brasswork Reach", "fuel_cost": 2, "min_dock_level": 1,
			"reduced_fuel_cost": 1, "reduced_at_dock_level": 2},
	],
}


func island_with_dock(level: int) -> Dictionary:
	if level <= 0:
		return {"plots": {}, "build_slots": 1}
	return {"plots": {"plot_0": {"building": "dock", "level": level}}, "build_slots": 1}


func test_region_1_is_always_unlocked_at_one_fuel() -> void:
	var entry: Dictionary = RUN_DEFS["regions"][0]
	assert_true(RegionModel.unlocked(entry, island_with_dock(0)))
	assert_eq(RegionModel.fuel_cost(entry, island_with_dock(0)), 1)
	assert_eq(RegionModel.fuel_cost(entry, island_with_dock(2)), 1, "no discount keys, no change")

func test_region_2_needs_the_dock() -> void:
	var entry: Dictionary = RUN_DEFS["regions"][1]
	assert_false(RegionModel.unlocked(entry, island_with_dock(0)))
	assert_true(RegionModel.unlocked(entry, island_with_dock(1)),
		"spec 4.1: the Dock unlocks new skyfield regions")

func test_dock_level_2_reduces_region_2_fuel_cost() -> void:
	var entry: Dictionary = RUN_DEFS["regions"][1]
	assert_eq(RegionModel.fuel_cost(entry, island_with_dock(1)), 2)
	assert_eq(RegionModel.fuel_cost(entry, island_with_dock(2)), 1,
		"spec 4.1: higher Dock levels reduce expedition fuel costs")

func test_unlocked_entries_keep_declared_order() -> void:
	var locked := RegionModel.unlocked_entries(RUN_DEFS, island_with_dock(0))
	assert_eq(locked.size(), 1)
	assert_eq(String((locked[0] as Dictionary)["id"]), "region_1")
	var open := RegionModel.unlocked_entries(RUN_DEFS, island_with_dock(1))
	assert_eq(open.size(), 2)
	assert_eq(String((open[1] as Dictionary)["id"]), "region_2")

func test_entry_lookup_and_unknown_id() -> void:
	assert_eq(String(RegionModel.entry(RUN_DEFS, "region_2").get("name", "")), "Brasswork Reach")
	assert_eq(RegionModel.entry(RUN_DEFS, "region_9"), {})

func test_missing_regions_key_yields_an_implicit_region_1() -> void:
	var entries := RegionModel.unlocked_entries({"fuel_cost": 3}, island_with_dock(0))
	assert_eq(entries.size(), 1)
	assert_eq(String((entries[0] as Dictionary)["id"]), "region_1")
	assert_eq(RegionModel.fuel_cost(entries[0], island_with_dock(0)), 3,
		"the implicit entry carries the flat run fuel_cost")

func test_selected_id_reads_the_save_and_falls_back() -> void:
	var data := {"expedition": {"region": "region_2"}}
	assert_eq(RegionModel.selected_id(data, RUN_DEFS, island_with_dock(1)), "region_2")
	assert_eq(RegionModel.selected_id(data, RUN_DEFS, island_with_dock(0)), "region_1",
		"a locked selection falls back, never crashes")
	assert_eq(RegionModel.selected_id({"expedition": {"region": "region_9"}}, RUN_DEFS, island_with_dock(2)), "region_1")
	assert_eq(RegionModel.selected_id({}, RUN_DEFS, island_with_dock(2)), "region_1",
		"a missing expedition section falls back")

func test_shipped_run_defs_carry_both_regions() -> void:
	var regions: Array = DataDefs.run.get("regions", [])
	assert_eq(regions.size(), 2)
	assert_eq(String((regions[0] as Dictionary)["id"]), "region_1")
	assert_eq(String((regions[1] as Dictionary)["id"]), "region_2")
	assert_eq(int((regions[1] as Dictionary)["fuel_cost"]), 2)
	assert_eq(int((regions[1] as Dictionary)["min_dock_level"]), 1)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: `RegionModel` unknown; the shipped-defs test finds no `regions` key.

- [ ] **Step 3: Implement**

In `game/data/run.json`, add after the `"fuel_cost": 1,` line:

```json
	"regions": [
		{"id": "region_1", "name": "Home Skies", "fuel_cost": 1, "min_dock_level": 0},
		{"id": "region_2", "name": "Brasswork Reach", "fuel_cost": 2, "min_dock_level": 1,
			"reduced_fuel_cost": 1, "reduced_at_dock_level": 2}
	],
```

Create `game/core/region_model.gd`:

```gdscript
class_name RegionModel
## Pure region rules (spec 3.4, 4.1): unlock by Dock level, per-region fuel
## cost with the Dock's level-2 discount, and the persisted-selection
## fallback. FuelModel pattern: defs in, values out, no nodes, no clock.

const FALLBACK_ID := "region_1"


static func unlocked(region_entry: Dictionary, island: Dictionary) -> bool:
	return IslandModel.building_level(island, "dock") >= int(region_entry.get("min_dock_level", 0))


static func fuel_cost(region_entry: Dictionary, island: Dictionary) -> int:
	var cost := int(region_entry.get("fuel_cost", 1))
	if region_entry.has("reduced_fuel_cost") and region_entry.has("reduced_at_dock_level") \
			and IslandModel.building_level(island, "dock") >= int(region_entry["reduced_at_dock_level"]):
		cost = int(region_entry["reduced_fuel_cost"])
	return cost


static func unlocked_entries(run_defs: Dictionary, island: Dictionary) -> Array:
	var out: Array = []
	for region_entry in _entries(run_defs):
		if unlocked(region_entry, island):
			out.append(region_entry)
	return out


static func entry(run_defs: Dictionary, region_id: String) -> Dictionary:
	for candidate in _entries(run_defs):
		if String((candidate as Dictionary).get("id", "")) == region_id:
			return candidate
	return {}


static func selected_id(data: Dictionary, run_defs: Dictionary, island: Dictionary) -> String:
	# A persisted id that is unknown (defs changed) or no longer unlocked
	# (hand-edited save) falls back silently; nothing rewrites the save.
	var wanted := String((data.get("expedition", {}) as Dictionary).get("region", FALLBACK_ID))
	var region_entry := entry(run_defs, wanted)
	if not region_entry.is_empty() and unlocked(region_entry, island):
		return wanted
	return FALLBACK_ID


static func _entries(run_defs: Dictionary) -> Array:
	var entries: Variant = run_defs.get("regions", [])
	if entries is Array and not (entries as Array).is_empty():
		return entries
	# Defensive: a defs file without regions still yields a playable region 1.
	return [{"id": FALLBACK_ID, "name": "Home Skies", "fuel_cost": int(run_defs.get("fuel_cost", 1)), "min_dock_level": 0}]
```

- [ ] **Step 4: Import, verify sidecars, run tests**

Run: `$GODOT --headless --import`
Run: `git status --porcelain` and confirm `game/core/region_model.gd.uid` and `tests/test_region_model.gd.uid` appear; both go in the commit.
Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0 (the existing `test_run_defs_load_with_required_keys` is region-1-scoped and unaffected).

- [ ] **Step 5: Commit**

```bash
git add game/core/region_model.gd game/core/region_model.gd.uid game/data/run.json tests/test_region_model.gd tests/test_region_model.gd.uid
git commit -m "feat: region model with dock unlocks and fuel discounts"
```

---

### Task 3: Save schema v6: the expedition section

**Files:**
- Modify: `game/core/save_schema.gd`
- Test: `tests/test_save_schema.gd` (edits + append)

**Interfaces:**
- Consumes: `SaveSchema` v5 internals.
- Produces: `CURRENT_VERSION == 6`; `default_data` carries `"expedition": {"region": "region_1"}` via `_fresh_expedition()`; `_migrate_5_to_6(data)`; backfill covers the new key. T8/T9 read and write `data["expedition"]["region"]`.

- [ ] **Step 1: Update version pins and append schema tests**

In `tests/test_save_schema.gd`, make these edits:

1. Replace `test_current_version_is_five_and_defaults_grant_eight` wholesale with:

```gdscript
func test_current_version_is_six_and_defaults_grant_eight() -> void:
	assert_eq(SaveSchema.CURRENT_VERSION, 6)
	var data := SaveSchema.default_data(DEFS, DataDefs.gizmos)
	assert_eq((data["gizmos"]["owned"] as Dictionary).size(), 8,
		"the brass gizmos are craft-to-acquire, never starters")
```

2. In `test_migrate_v3_to_v4_adds_island_losslessly`, change `assert_eq(int(migrated["version"]), 5)` to `assert_eq(int(migrated["version"]), 6)`.
3. In `test_migrate_v1_hops_all_the_way_to_v4`, change `assert_eq(int(migrated["version"]), 5)` to `assert_eq(int(migrated["version"]), 6)`.
4. In `test_migrate_4_to_5_adds_ads_and_notifications_losslessly`, change `assert_eq(int(out["version"]), 5)` to `assert_eq(int(out["version"]), SaveSchema.CURRENT_VERSION)`.
5. In `test_backfill_heals_missing_keys_on_current_version`, change the damaged dict's version from `5` to `6` and add `"expedition"` to the key list, so the loop line reads:

```gdscript
	for key in ["fuel", "timers", "island", "trickle", "daily_crate", "gizmos", "ads", "notifications", "expedition"]:
```

Then append:

```gdscript
func test_migrate_5_to_6_adds_expedition_losslessly() -> void:
	var v5 := SaveSchema.default_data(DEFS, GIZMO_DEFS)
	v5["version"] = 5
	v5.erase("expedition")
	v5["currencies"]["scrap"] = 777
	var out := SaveSchema.migrate(v5, GIZMO_DEFS)
	assert_eq(int(out["version"]), 6)
	assert_eq(out["expedition"], {"region": "region_1"})
	assert_eq(int(out["currencies"]["scrap"]), 777, "balances untouched")

func test_default_data_has_expedition_section() -> void:
	assert_eq(SaveSchema.default_data(DEFS)["expedition"], {"region": "region_1"})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: `CURRENT_VERSION` is 5, no `expedition` key anywhere, `_migrate_5_to_6` missing.

- [ ] **Step 3: Implement**

In `game/core/save_schema.gd`:

1. Change `const CURRENT_VERSION := 5` to `const CURRENT_VERSION := 6`.
2. In `default_data`, add after the `"notifications": _fresh_notifications(),` line:

```gdscript
		"expedition": _fresh_expedition(),
```

3. In `migrate`, add after the `if int(data["version"]) == 4:` block:

```gdscript
	if int(data["version"]) == 5:
		data = _migrate_5_to_6(data)
```

4. Add at the end of the file:

```gdscript
static func _migrate_5_to_6(data: Dictionary) -> Dictionary:
	# Region 2 arrives: the launcher persists which skyfield is selected.
	data["expedition"] = _fresh_expedition()
	data["version"] = 6
	return data


static func _fresh_expedition() -> Dictionary:
	return {"region": "region_1"}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0 (`test_migrate_current_version_is_noop` keeps passing: default_data now carries `expedition`, so backfill adds nothing).

- [ ] **Step 5: Commit**

```bash
git add game/core/save_schema.gd tests/test_save_schema.gd
git commit -m "feat: save schema v6 persists the selected expedition region"
```

---

### Task 4: Drift zones and the per-region sea payout

**Files:**
- Create: `game/run/drift_zone.gd`
- Modify: `game/run/skyfield.gd`, `game/run/skyfield.tscn`
- Test: `tests/test_drift_zone.gd` (new)

**Interfaces:**
- Consumes: `Skyfield.build`, the WindFan force pattern.
- Produces: `DriftZone` (extends Area2D, group `"drift_zones"`): `setup(zone_defs: Dictionary)` reading `x/y/half_width/half_height/force/direction`, `force_vector: Vector2`, pushes overlapping RigidBody2D pods horizontally every physics frame UNLESS the pod is inside a `"gyro_dampers"`-group node's `field_radius` (T6 provides the damper; with the group empty the check is a no-op). `Skyfield._build_drift_zones(zones: Array)` populating a new `DriftZones` scene child; `Skyfield.build` prefers a region-level `sea_payout` over the run-level default. Region JSON keys consumed: `drift_zones`, `sea_payout` (both optional; region 1 has neither: zero behavior change).

- [ ] **Step 1: Write the failing tests**

Create `tests/test_drift_zone.gd`:

```gdscript
extends GutTest

const SkyfieldScene := preload("res://game/run/skyfield.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var run_defs := {"sea_payout": {"scrap": 1}, "pod": {"radius": 12.0, "bounce": 0.55, "friction": 0.2}}

const DRIFT_REGION := {
	"name": "Drift Test",
	"board": {"left": 20, "right": 700, "top": 140, "bottom": 1020},
	"pegs": [], "gizmo_slots": [], "barges": [],
	"drift_zones": [
		{"x": 360, "y": 400, "half_width": 300, "half_height": 200, "force": 220.0, "direction": 1.0},
	],
}


func build_board(region: Dictionary) -> Skyfield:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	board.build(region, run_defs)
	return board


func test_build_creates_drift_zone_nodes_from_data() -> void:
	var board := build_board(DRIFT_REGION)
	assert_eq(board.get_node("DriftZones").get_child_count(), 1)
	var zone: DriftZone = board.get_node("DriftZones").get_child(0)
	assert_eq(zone.position, Vector2(360, 400))
	assert_almost_eq(zone.force_vector.x, 220.0, 0.001)
	assert_true(zone.is_in_group("drift_zones"))

func test_region_without_drift_zones_builds_none() -> void:
	var board := build_board(DataDefs.skyfield("region_1"))
	assert_eq(board.get_node("DriftZones").get_child_count(), 0, "region 1 is calm skies")

func test_pod_falling_through_a_zone_is_pushed_sideways() -> void:
	var board := build_board(DRIFT_REGION)
	var pod: Pod = PodScene.instantiate()
	pod.position = Vector2(360, 250)
	pod.setup(run_defs["pod"])
	board.add_child(pod)
	autofree(pod)
	await wait_seconds(0.5)
	assert_true(pod.linear_velocity.x > 30.0,
		"spec 3.4: the drift current pushes the pod in its direction")

func test_region_sea_payout_overrides_the_run_default() -> void:
	var region := DRIFT_REGION.duplicate(true)
	region["sea_payout"] = {"scrap": 2}
	var board := build_board(region)
	assert_eq(board.sea_payout, {"scrap": 2})

func test_run_sea_payout_still_applies_without_an_override() -> void:
	var board := build_board(DRIFT_REGION)
	assert_eq(board.sea_payout, {"scrap": 1})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: `DriftZone` unknown, no `DriftZones` node in skyfield.tscn.

- [ ] **Step 3: Implement**

Create `game/run/drift_zone.gd`:

```gdscript
class_name DriftZone
extends Area2D
## One drift current (spec 3.4 hazard; region JSON "drift_zones"): a hostile
## wind column pushing pods sideways every physics frame, the board-owned
## twin of the Wind Fan. A board feature, not a gizmo: no level, no defs
## lookup, no context. Gyro Dampers (group "gyro_dampers") null the push for
## any pod inside their field; the zone asks, the damper just exists.

var force_vector := Vector2.ZERO


func setup(zone_defs: Dictionary) -> void:
	position = Vector2(float(zone_defs.get("x", 0)), float(zone_defs.get("y", 0)))
	force_vector = Vector2(float(zone_defs.get("force", 220.0)) * float(zone_defs.get("direction", 1.0)), 0.0)
	var half := Vector2(float(zone_defs.get("half_width", 100)), float(zone_defs.get("half_height", 60)))
	var shape := RectangleShape2D.new()
	shape.size = half * 2.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	visual.color = Color(0.8, 0.7, 0.5, 0.22)
	add_child(visual)
	add_to_group("drift_zones")


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is RigidBody2D and not _damped(body):
			body.apply_central_force(force_vector)


func _damped(body: Node2D) -> bool:
	for damper in get_tree().get_nodes_in_group("gyro_dampers"):
		if body.global_position.distance_to((damper as Node2D).global_position) <= float(damper.field_radius):
			return true
	return false
```

In `game/run/skyfield.tscn`, add after the `Gizmos` node block:

```
[node name="DriftZones" type="Node2D" parent="."]
```

In `game/run/skyfield.gd`:

1. Replace the first line of `build` (`sea_payout = ...`) with:

```gdscript
	sea_payout = (region_defs.get("sea_payout", run_defs.get("sea_payout", {"scrap": 1})) as Dictionary).duplicate()
```

2. In `build`, add after the `_build_slots(...)` line:

```gdscript
	_build_drift_zones(region_defs.get("drift_zones", []))
```

3. Add after `_build_slots`:

```gdscript
func _build_drift_zones(zones: Array) -> void:
	for zone_defs in zones:
		var zone := DriftZone.new()
		zone.setup(zone_defs as Dictionary)
		$DriftZones.add_child(zone)
```

- [ ] **Step 4: Import, verify sidecars, run tests**

Run: `$GODOT --headless --import`
Run: `git status --porcelain` and confirm `game/run/drift_zone.gd.uid` and `tests/test_drift_zone.gd.uid` appear; both go in the commit.
Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0 (existing skyfield tests unaffected: region 1 carries neither new key).

- [ ] **Step 5: Commit**

```bash
git add game/run/drift_zone.gd game/run/drift_zone.gd.uid game/run/skyfield.gd game/run/skyfield.tscn tests/test_drift_zone.gd tests/test_drift_zone.gd.uid
git commit -m "feat: drift-current hazard zones and per-region sea payouts"
```

---

### Task 5: Region 2 board data and the brasswork currency

**Files:**
- Create: `game/data/skyfields/region_2.json`
- Modify: `game/data/economy.json`
- Test: `tests/test_region_2_defs.gd` (new)

**Interfaces:**
- Consumes: `Skyfield.build` + `duplicate_barge_ids`, `DataDefs.skyfield`, T4's drift zones.
- Produces: the shipped Brasswork Reach board (39 pegs including two 8-peg gear rings, 8 slots, 5 barges dropping brasswork on the outer ones, 2 opposing drift zones, quota tiers 35/80, sea payout 2 scrap); `starting_balances` gains `"brasswork": 0`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_region_2_defs.gd`:

```gdscript
extends GutTest

const SkyfieldScene := preload("res://game/run/skyfield.tscn")

var run_defs := {"sea_payout": {"scrap": 1}, "pod": {"radius": 12.0, "bounce": 0.55, "friction": 0.2}}


func test_region_2_parses_with_required_keys() -> void:
	var region := DataDefs.skyfield("region_2")
	assert_eq(String(region.get("name", "")), "Brasswork Reach")
	assert_has(region, "board")
	assert_eq((region.get("gizmo_slots", []) as Array).size(), 8, "spec: 8 slots, up from 6")
	assert_eq((region.get("barges", []) as Array).size(), 5)
	assert_eq((region.get("drift_zones", []) as Array).size(), 2)
	assert_eq(region.get("sea_payout", {}), {"scrap": 2})

func test_region_2_barge_ids_are_unique() -> void:
	var region := DataDefs.skyfield("region_2")
	assert_eq(Skyfield.duplicate_barge_ids(region.get("barges", [])), [])

func test_region_2_quota_tiers_are_well_formed() -> void:
	var region := DataDefs.skyfield("region_2")
	var tiers: Array = region.get("quota_tiers", [])
	assert_eq(tiers.size(), 2)
	for tier in tiers:
		assert_true(int((tier as Dictionary).get("scrap_quota", 0)) > 0)
		assert_true(float((tier as Dictionary).get("payout_multiplier", 0.0)) > 1.0)

func test_region_2_drops_brasswork_on_outer_barges() -> void:
	var region := DataDefs.skyfield("region_2")
	var brasswork_total := 0
	for barge in region.get("barges", []):
		brasswork_total += int(((barge as Dictionary).get("payout", {}) as Dictionary).get("brasswork", 0))
	assert_true(brasswork_total >= 3, "spec 3.4: the region drops its distinctive material")

func test_region_2_board_builds() -> void:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	board.build(DataDefs.skyfield("region_2"), run_defs)
	assert_eq(board.get_node("Pegs").get_child_count(), 39)
	assert_eq(board.get_node("GizmoSlots").get_child_count(), 8)
	assert_eq(board.get_node("DriftZones").get_child_count(), 2)
	assert_eq(board.sea_payout, {"scrap": 2})
	var zones := board.get_node("DriftZones")
	assert_true((zones.get_child(0) as DriftZone).force_vector.x > 0.0, "upper zone pushes right")
	assert_true((zones.get_child(1) as DriftZone).force_vector.x < 0.0, "lower zone pushes left")

func test_starting_balances_carry_brasswork() -> void:
	assert_eq(int((DataDefs.economy["starting_balances"] as Dictionary).get("brasswork", -1)), 0)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: region_2.json missing (DataDefs push_error "Missing data file" makes those tests fail loudly), brasswork absent.

- [ ] **Step 3: Implement**

Create `game/data/skyfields/region_2.json`:

```json
{
	"name": "Brasswork Reach",
	"board": {"left": 20, "right": 700, "top": 140, "bottom": 1020},
	"quota_tiers": [
		{"scrap_quota": 35, "payout_multiplier": 1.25},
		{"scrap_quota": 80, "payout_multiplier": 1.6}
	],
	"sea_payout": {"scrap": 2},
	"pegs": [
		{"x": 100, "y": 260, "r": 14}, {"x": 230, "y": 260, "r": 14}, {"x": 360, "y": 260, "r": 14}, {"x": 490, "y": 260, "r": 14}, {"x": 620, "y": 260, "r": 14},
		{"x": 165, "y": 360, "r": 14}, {"x": 295, "y": 360, "r": 14}, {"x": 425, "y": 360, "r": 14}, {"x": 555, "y": 360, "r": 14},
		{"x": 302, "y": 500, "r": 14}, {"x": 281, "y": 551, "r": 14}, {"x": 230, "y": 572, "r": 14}, {"x": 179, "y": 551, "r": 14}, {"x": 158, "y": 500, "r": 14}, {"x": 179, "y": 449, "r": 14}, {"x": 230, "y": 428, "r": 14}, {"x": 281, "y": 449, "r": 14},
		{"x": 425, "y": 500, "r": 14}, {"x": 555, "y": 500, "r": 14},
		{"x": 562, "y": 700, "r": 14}, {"x": 541, "y": 751, "r": 14}, {"x": 490, "y": 772, "r": 14}, {"x": 439, "y": 751, "r": 14}, {"x": 418, "y": 700, "r": 14}, {"x": 439, "y": 649, "r": 14}, {"x": 490, "y": 628, "r": 14}, {"x": 541, "y": 649, "r": 14},
		{"x": 100, "y": 700, "r": 14}, {"x": 230, "y": 700, "r": 14}, {"x": 330, "y": 700, "r": 14},
		{"x": 100, "y": 850, "r": 14}, {"x": 230, "y": 850, "r": 14}, {"x": 360, "y": 850, "r": 14}, {"x": 490, "y": 850, "r": 14}, {"x": 620, "y": 850, "r": 14},
		{"x": 165, "y": 940, "r": 14}, {"x": 295, "y": 940, "r": 14}, {"x": 425, "y": 940, "r": 14}, {"x": 555, "y": 940, "r": 14}
	],
	"gizmo_slots": [
		{"x": 165, "y": 320}, {"x": 555, "y": 320},
		{"x": 100, "y": 560}, {"x": 620, "y": 560},
		{"x": 360, "y": 640}, {"x": 360, "y": 760},
		{"x": 100, "y": 900}, {"x": 620, "y": 900}
	],
	"drift_zones": [
		{"x": 360, "y": 400, "half_width": 220, "half_height": 80, "force": 220.0, "direction": 1.0},
		{"x": 360, "y": 800, "half_width": 220, "half_height": 80, "force": 220.0, "direction": -1.0}
	],
	"barges": [
		{"id": "far_left", "x": 90, "y": 1060, "half_width": 50, "half_height": 25, "payout": {"scrap": 14}},
		{"id": "left", "x": 225, "y": 1060, "half_width": 50, "half_height": 25, "payout": {"scrap": 6}},
		{"id": "center", "x": 360, "y": 1060, "half_width": 50, "half_height": 25, "payout": {"scrap": 3}},
		{"id": "right", "x": 495, "y": 1060, "half_width": 50, "half_height": 25, "payout": {"scrap": 6, "brasswork": 1}},
		{"id": "far_right", "x": 630, "y": 1060, "half_width": 50, "half_height": 25, "payout": {"scrap": 10, "brasswork": 2}}
	]
}
```

(Peg count is 39: two 5-peg rows, two 4-peg rows, two 8-peg gear rings, one 2-peg pair beside ring 1, one 3-peg row beside ring 2. The spec's "~36" is approximate by design.)

In `game/data/economy.json`, add `"brasswork": 0,` to `starting_balances` after the `"cloudsilk": 0,` line.

- [ ] **Step 4: Run tests to verify they pass**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0. (Import step + sidecar check for `tests/test_region_2_defs.gd.uid`: run `$GODOT --headless --import` then `git status --porcelain`.)

- [ ] **Step 5: Commit**

```bash
git add game/data/skyfields/region_2.json game/data/economy.json tests/test_region_2_defs.gd tests/test_region_2_defs.gd.uid
git commit -m "feat: brasswork reach board data and brasswork currency"
```

---

### Task 6: The brass gizmos: Gyro Damper and Piston Kicker

**Files:**
- Create: `game/run/gizmos/gyro_damper.gd`, `game/run/gizmos/gyro_damper.tscn`, `game/run/gizmos/piston_kicker.gd`, `game/run/gizmos/piston_kicker.tscn`
- Modify: `game/data/gizmos.json` (two defs; starting_inventory untouched)
- Test: `tests/test_gyro_damper.gd`, `tests/test_piston_kicker.gd` (new)

**Interfaces:**
- Consumes: `GizmoBase.setup/_configure/scaled`, T4's `DriftZone` (`setup`, `_damped` group check).
- Produces: `GyroDamper` (group `"gyro_dampers"`, `field_radius: float`, def key `field_radius` 140, craft `{"scrap": 200, "brasswork": 2}` / 420 s); `PistonKicker` (contact impulse, def keys `force` 520 / `direction` 1.0 / `radius` 24, once per pod via `"piston_kicked"` meta, craft `{"scrap": 180, "brasswork": 1}` / 300 s). Neither joins `starting_inventory` (owned stays 8 by default; T7 makes them craftable).

- [ ] **Step 1: Write the failing tests**

Create `tests/test_gyro_damper.gd`:

```gdscript
extends GutTest

const DamperScene := preload("res://game/run/gizmos/gyro_damper.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var damper_defs: Dictionary


func before_each() -> void:
	damper_defs = (DataDefs.gizmos["defs"]["gyro_damper"] as Dictionary).duplicate()


func test_configure_registers_group_and_radius() -> void:
	var damper: GyroDamper = add_child_autofree(DamperScene.instantiate())
	damper.setup(damper_defs, 1, self)
	assert_true(damper.is_in_group("gyro_dampers"))
	assert_almost_eq(damper.field_radius, 140.0, 0.001)

func test_level_scales_the_field() -> void:
	var damper: GyroDamper = add_child_autofree(DamperScene.instantiate())
	damper.setup(damper_defs, 3, self)
	assert_almost_eq(damper.field_radius, 140.0 * 1.5, 0.001)

func test_damper_nulls_the_drift_push() -> void:
	var zone := DriftZone.new()
	zone.setup({"x": 360, "y": 400, "half_width": 300, "half_height": 200, "force": 220.0, "direction": 1.0})
	add_child_autofree(zone)
	var damper: GyroDamper = add_child_autofree(DamperScene.instantiate())
	damper.position = Vector2(360, 400)
	damper.setup(damper_defs, 1, self)
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	pod.position = Vector2(360, 300)
	pod.setup({"radius": 12.0, "bounce": 0.55, "friction": 0.2})
	await wait_seconds(0.4)
	assert_true(absf(pod.linear_velocity.x) < 5.0,
		"inside the damper field the drift current cannot push the pod")

func test_craft_recipe_costs_brasswork() -> void:
	assert_eq(int((damper_defs["craft_cost"] as Dictionary)["brasswork"]), 2,
		"spec 3.4: new recipes are gated on the regional material")
```

Create `tests/test_piston_kicker.gd`:

```gdscript
extends GutTest

const KickerScene := preload("res://game/run/gizmos/piston_kicker.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var kicker_defs: Dictionary
var kicker: PistonKicker


func before_each() -> void:
	kicker_defs = (DataDefs.gizmos["defs"]["piston_kicker"] as Dictionary).duplicate()
	kicker = add_child_autofree(KickerScene.instantiate())
	kicker.position = Vector2(360, 500)
	kicker.setup(kicker_defs, 1, self)


func make_pod() -> RigidBody2D:
	var pod := RigidBody2D.new()
	add_child_autofree(pod)
	return pod


func test_configure_builds_zone_and_impulse() -> void:
	assert_almost_eq((kicker.get_node("Zone/Shape").shape as CircleShape2D).radius, 24.0, 0.001)
	assert_almost_eq(kicker._impulse_vector.x, 520.0, 0.001)

func test_level_scales_the_kick() -> void:
	var strong: PistonKicker = add_child_autofree(KickerScene.instantiate())
	strong.setup(kicker_defs, 3, self)
	assert_almost_eq(strong._impulse_vector.x, 520.0 * 1.5, 0.001)

func test_kicks_each_pod_exactly_once() -> void:
	var pod := make_pod()
	kicker._on_body_entered(pod)
	kicker._on_body_entered(pod)
	await wait_physics_frames(2)
	assert_almost_eq(pod.linear_velocity.x, 520.0, 60.0,
		"the second contact must not stack a second impulse")
	assert_true(pod.has_meta("piston_kicked"))

func test_caught_pods_are_ignored() -> void:
	var pod := make_pod()
	pod.set_meta("caught", true)
	kicker._on_body_entered(pod)
	await wait_physics_frames(2)
	assert_almost_eq(pod.linear_velocity.x, 0.0, 5.0)

func test_falling_pod_is_kicked_on_real_contact() -> void:
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	pod.position = Vector2(360, 420)
	pod.setup({"radius": 12.0, "bounce": 0.55, "friction": 0.2})
	await wait_seconds(0.6)
	assert_true(pod.linear_velocity.x > 200.0,
		"real contact with the piston fires the pod sideways")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: both scene preloads error (missing files), `gyro_damper`/`piston_kicker` defs absent.

- [ ] **Step 3: Implement**

Create `game/run/gizmos/gyro_damper.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://game/run/gizmos/gyro_damper.gd" id="1_gd"]

[node name="GyroDamper" type="Node2D"]
script = ExtResource("1_gd")

[node name="Visual" type="Polygon2D" parent="."]
```

Create `game/run/gizmos/gyro_damper.gd`:

```gdscript
class_name GyroDamper
extends GizmoBase
## Gyro Damper (region 2 counterplay, spec 3.4): a passive stabilizing field
## in which drift currents cannot push pods. Drift zones do the checking
## (they ask the "gyro_dampers" group); the damper just exists and exposes
## field_radius. No Zone Area2D: it never reacts to contact itself.

var field_radius := 140.0


func _configure() -> void:
	field_radius = scaled(float(defs.get("field_radius", 140.0)))
	add_to_group("gyro_dampers")
	var visual: Polygon2D = $Visual
	visual.polygon = Geometry.circle_points(20.0, 8)
	visual.color = Color(0.85, 0.7, 0.35)
	var field := Polygon2D.new()
	field.polygon = Geometry.circle_points(field_radius, 24)
	field.color = Color(0.85, 0.7, 0.35, 0.12)
	add_child(field)
```

Create `game/run/gizmos/piston_kicker.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://game/run/gizmos/piston_kicker.gd" id="1_pk"]

[node name="PistonKicker" type="Node2D"]
script = ExtResource("1_pk")

[node name="Zone" type="Area2D" parent="."]

[node name="Shape" type="CollisionShape2D" parent="Zone"]

[node name="Visual" type="Polygon2D" parent="."]
```

Create `game/run/gizmos/piston_kicker.gd`:

```gdscript
class_name PistonKicker
extends GizmoBase
## Piston Kicker (region 2 offense): fires the pod sideways with a sharp
## impulse on contact, once per pod per drop ("piston_kicked" meta; split
## clones carry no meta, so each clone earns its own kick). Impulse inside
## body_entered is safe per the Balloon Cluster precedent.

var _impulse_vector := Vector2.ZERO

@onready var zone: Area2D = $Zone


func _configure() -> void:
	var force := scaled(float(defs.get("force", 520.0)))
	_impulse_vector = Vector2(force * float(defs.get("direction", 1.0)), 0.0)
	var circle := CircleShape2D.new()
	circle.radius = float(defs.get("radius", 24.0))
	$Zone/Shape.shape = circle
	var visual: Polygon2D = $Visual
	visual.polygon = PackedVector2Array([
		Vector2(-24, -10), Vector2(10, -10), Vector2(24, 0), Vector2(10, 10), Vector2(-24, 10),
	])
	visual.color = Color(0.8, 0.55, 0.3)
	zone.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not (body is RigidBody2D) or body.has_meta("caught") or body.has_meta("piston_kicked"):
		return
	body.set_meta("piston_kicked", true)
	body.apply_central_impulse(_impulse_vector)
```

In `game/data/gizmos.json`, add to the `defs` dict after the `splitter_vane` entry (comma discipline: add a comma to splitter_vane's closing brace):

```json
		"gyro_damper": {
			"name": "Gyro Damper",
			"scene": "res://game/run/gizmos/gyro_damper.tscn",
			"field_radius": 140.0,
			"craft_cost": {"scrap": 200, "brasswork": 2},
			"craft_seconds": 420
		},
		"piston_kicker": {
			"name": "Piston Kicker",
			"scene": "res://game/run/gizmos/piston_kicker.tscn",
			"force": 520.0,
			"direction": 1.0,
			"radius": 24.0,
			"craft_cost": {"scrap": 180, "brasswork": 1},
			"craft_seconds": 300
		}
```

`starting_inventory` is NOT touched: both gizmos are craft-to-acquire.

- [ ] **Step 4: Import, verify sidecars, run tests**

Run: `$GODOT --headless --import`
Run: `git status --porcelain` and confirm four new `.gd.uid` sidecars (two sources, two tests); all go in the commit.
Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0. The workshop screen still iterates `owned` at this point, so its 8-row test is unaffected until T7; the schema starters test pins `owned` size 8, also unaffected.

- [ ] **Step 5: Commit**

```bash
git add game/run/gizmos/gyro_damper.gd game/run/gizmos/gyro_damper.gd.uid game/run/gizmos/gyro_damper.tscn game/run/gizmos/piston_kicker.gd game/run/gizmos/piston_kicker.gd.uid game/run/gizmos/piston_kicker.tscn game/data/gizmos.json tests/test_gyro_damper.gd tests/test_gyro_damper.gd.uid tests/test_piston_kicker.gd tests/test_piston_kicker.gd.uid
git commit -m "feat: gyro damper and piston kicker brass gizmos"
```

---

### Task 7: Craft-to-acquire: CraftModel and the Workshop screen

**Files:**
- Modify: `game/base/craft_model.gd`, `game/base/workshop_screen.gd`
- Test: `tests/test_craft_model.gd` (1 replacement + append), `tests/test_workshop_screen.gd` (1 edit + append)

**Interfaces:**
- Consumes: T6's defs, current `CraftModel`, current workshop `_signature/_rebuild/_gizmo_label_text`.
- Produces: `can_craft` allows any gizmo in `defs` (unknown ids rejected; unowned treated as level 0 for the max-level check); `complete_craft` grants `owned[id] = 1` when unowned, merges `+1` otherwise; the workshop screen iterates `DataDefs.gizmos["defs"]` (stable JSON order) with unowned rows labeled `"<name> (not owned)"`. The Workshop is now the first non-starter gizmo faucet.

- [ ] **Step 1: Replace the stale test and append the failing tests**

In `tests/test_craft_model.gd`, replace the whole `test_unowned_gizmo_cannot_be_crafted` function (its behavior is inverted by this task) with:

```gdscript
func test_unowned_gizmo_craft_grants_level_one() -> void:
	state.data["gizmos"]["owned"].erase("wind_fan")
	assert_true(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan"),
		"recipes are craft-to-acquire; resources are the gate (spec 3.3)")
	CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan", 1000)
	CraftModel.complete_craft(state.data, timers.collect("craft_wind_fan", 1200))
	assert_eq(int(state.data["gizmos"]["owned"]["wind_fan"]), 1)

func test_unknown_gizmo_id_cannot_be_crafted() -> void:
	assert_false(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "no_such_gizmo"))

func test_brasswork_gates_the_brass_recipes() -> void:
	assert_false(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "gyro_damper"),
		"5000 scrap but zero brasswork: locked")
	state.data["currencies"]["brasswork"] = 2
	assert_true(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "gyro_damper"))
```

In `tests/test_workshop_screen.gd`, replace the whole `test_one_row_per_owned_gizmo` function with:

```gdscript
func test_one_row_per_recipe() -> void:
	assert_eq(screen.get_node("Rows").get_child_count(), (DataDefs.gizmos["defs"] as Dictionary).size(),
		"every recipe shows, owned or not (craft-to-acquire)")
```

Then append to `tests/test_workshop_screen.gd`:

```gdscript
func test_unowned_recipe_row_is_labeled_and_craftable() -> void:
	GameState.data["currencies"]["brasswork"] = 2
	screen._rebuild()
	assert_string_contains(screen._gizmo_label_text("gyro_damper", TimeUtil.now()), "(not owned)")
	screen._on_craft_pressed("gyro_damper")
	assert_true(TimerService.active_timers().has("craft_gyro_damper"))
	TimerService._state.data["timers"]["craft_gyro_damper"]["ends_at"] = 0
	screen._on_collect_pressed("gyro_damper")
	assert_eq(int(GameState.data["gizmos"]["owned"]["gyro_damper"]), 1,
		"first craft grants ownership at level 1")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: `can_craft` still requires ownership; the workshop shows 8 rows, not 10.

- [ ] **Step 3: Implement**

In `game/base/craft_model.gd`, replace `can_craft` and `complete_craft` with:

```gdscript
static func can_craft(data: Dictionary, gizmo_defs: Dictionary, economy: Node, timers: Node, gizmo_id: String) -> bool:
	if craft_slots(data.get("island", {})) <= 0:
		return false
	if active_crafts(timers) >= craft_slots(data.get("island", {})):
		return false
	if timers.active_timers().has("craft_" + gizmo_id):
		return false
	var def: Dictionary = (gizmo_defs.get("defs", {}) as Dictionary).get(gizmo_id, {})
	if def.is_empty():
		return false
	# Craft-to-acquire (spec 3.3): unowned recipes craft at level 0 -> 1;
	# resources (regional materials) are the gate, not ownership.
	var owned: Dictionary = (data.get("gizmos", {}) as Dictionary).get("owned", {})
	if int(owned.get(gizmo_id, 0)) >= int(gizmo_defs.get("craft_max_level", 5)):
		return false
	return economy.can_afford(def.get("craft_cost", {}))


static func complete_craft(data: Dictionary, payload: Dictionary) -> void:
	if payload.is_empty():
		return
	var gizmo_id := String(payload.get("gizmo", ""))
	if gizmo_id == "":
		return
	var owned: Dictionary = (data.get("gizmos", {}) as Dictionary).get("owned", {})
	owned[gizmo_id] = int(owned.get(gizmo_id, 0)) + 1
```

In `game/base/workshop_screen.gd`:

1. In `_signature`, change the loop line `for gizmo_id in GameState.data["gizmos"]["owned"]:` to `for gizmo_id in DataDefs.gizmos["defs"]:`.
2. In `_rebuild`, delete the line `var owned: Dictionary = GameState.data["gizmos"]["owned"]` and change its loop line `for gizmo_id in owned:` to `for gizmo_id in DataDefs.gizmos["defs"]:`.
3. Replace `_gizmo_label_text` with:

```gdscript
func _gizmo_label_text(gizmo_id: String, now: int) -> String:
	var owned: Dictionary = GameState.data["gizmos"]["owned"]
	var def: Dictionary = (DataDefs.gizmos["defs"] as Dictionary).get(gizmo_id, {})
	var text: String
	if owned.has(gizmo_id):
		text = "%s Lv %d" % [String(def.get("name", gizmo_id)), int(owned[gizmo_id])]
	else:
		text = "%s (not owned)" % String(def.get("name", gizmo_id))
	var timer_id := "craft_" + gizmo_id
	if TimerService.active_timers().has(timer_id) and not TimerService.is_done(timer_id, now):
		text += "  (%ds)" % TimerService.remaining(timer_id, now)
	return text
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0. Existing craft/collect/skip workshop tests keep passing: owned gizmos behave exactly as before.

- [ ] **Step 5: Commit**

```bash
git add game/base/craft_model.gd game/base/workshop_screen.gd tests/test_craft_model.gd tests/test_workshop_screen.gd
git commit -m "feat: craft-to-acquire recipes make the workshop the gizmo faucet"
```

---

### Task 8: Region selection: main screen and the run scene

**Files:**
- Modify: `game/main.gd`, `game/main.tscn`, `game/run/salvage_run.gd`
- Test: `tests/test_main_boot.gd` (append), `tests/test_salvage_run.gd` (append)

**Interfaces:**
- Consumes: `RegionModel` (T2), schema v6 `expedition` (T3), region_2 data (T5).
- Produces: `main.gd` gains `_selected_region() -> String`, `_on_region_pressed()`, a `RegionButton` node showing `"Region: <name> (<cost> fuel)"`; launch disable and spend use `RegionModel.fuel_cost`; the debug label gains the Brasswork line; `salvage_run._ready` builds the selected region and passes its id to the loadout. T9 reuses the cycle pattern.

- [ ] **Step 1: Append the failing tests**

Append to `tests/test_main_boot.gd`:

```gdscript
func test_region_button_shows_the_home_region() -> void:
	main._refresh()
	assert_string_contains(main.get_node("RegionButton").text, "Home Skies")
	assert_string_contains(main.get_node("RegionButton").text, "(1 fuel)")

func test_cycling_without_a_dock_stays_home() -> void:
	main._on_region_pressed()
	assert_eq(String(GameState.data["expedition"]["region"]), "region_1",
		"region 2 is locked until the Dock exists (spec 4.1)")

func test_cycling_with_a_dock_selects_brasswork_reach_and_persists() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "dock", "level": 1}
	main._on_region_pressed()
	assert_eq(String(GameState.data["expedition"]["region"]), "region_2")
	assert_string_contains(main.get_node("RegionButton").text, "Brasswork Reach")
	assert_string_contains(main.get_node("RegionButton").text, "(2 fuel)")
	var saved := SaveIO.new(TEST_SAVE).read()
	assert_eq(String((saved["expedition"] as Dictionary)["region"]), "region_2",
		"the selection survives an OS kill")

func test_dock_level_2_shows_the_discount() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "dock", "level": 2}
	GameState.data["expedition"]["region"] = "region_2"
	main._refresh()
	assert_string_contains(main.get_node("RegionButton").text, "(1 fuel)")

func test_launch_disabled_when_fuel_below_region_cost() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "dock", "level": 1}
	GameState.data["expedition"]["region"] = "region_2"
	GameState.data["fuel"]["amount"] = 1
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	main._refresh()
	assert_true(main.get_node("LaunchButton").disabled, "region 2 costs 2 fuel")

func test_debug_label_shows_brasswork() -> void:
	assert_string_contains(main.get_node("DebugLabel").text, "Brasswork: ")
```

Append to `tests/test_salvage_run.gd`:

```gdscript
func test_scene_builds_the_selected_region() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "dock", "level": 1}
	GameState.data["expedition"]["region"] = "region_2"
	var second = add_child_autofree(RunScene.instantiate())
	await wait_physics_frames(1)
	assert_eq(second.get_node("Skyfield/DriftZones").get_child_count(), 2)
	assert_eq(int((second.model.tiers[0] as Dictionary)["scrap_quota"]), 35,
		"the run model carries region 2's quota tiers")

func test_locked_selection_falls_back_to_region_1() -> void:
	GameState.data["expedition"]["region"] = "region_2"
	var second = add_child_autofree(RunScene.instantiate())
	await wait_physics_frames(1)
	assert_eq(second.get_node("Skyfield/DriftZones").get_child_count(), 0,
		"no Dock, no Brasswork Reach; the scene falls back, never crashes")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: no `RegionButton` node, `_on_region_pressed` undefined, salvage_run hardcodes region_1 (the fallback test passes trivially; the selected-region test fails).

- [ ] **Step 3: Implement the scene node**

In `game/main.tscn`, add after the `GizmosButton` node block (before `RefillButton`):

```
[node name="RegionButton" type="Button" parent="."]
offset_left = 160.0
offset_top = 720.0
offset_right = 560.0
offset_bottom = 780.0
text = "Region"
```

- [ ] **Step 4: Implement the handlers**

In `game/main.gd`:

1. In `_ready`, add after the `$RefillButton` connect line: `$RegionButton.pressed.connect(_on_region_pressed)`.
2. In `_refresh`, replace the `debug_label.text` assignment with:

```gdscript
	debug_label.text = "Scrap: %d\nCloudsilk: %d\nBrasswork: %d\nCrystals: %d\nFuel: %d/%d" % [
		Economy.balance("scrap"),
		Economy.balance("cloudsilk"),
		Economy.balance("brasswork"),
		Economy.balance("crystals"),
		FuelModel.current(fuel, now),
		int(fuel["cap"]),
	]
```

3. In `_refresh`, replace the `launch_button.disabled` line with:

```gdscript
	var region_entry := RegionModel.entry(DataDefs.run, _selected_region())
	var cost := RegionModel.fuel_cost(region_entry, GameState.data["island"])
	$RegionButton.text = "Region: %s (%d fuel)" % [String(region_entry.get("name", "?")), cost]
	launch_button.disabled = FuelModel.current(fuel, now) < cost
```

4. Replace `_on_launch_pressed` with:

```gdscript
func _on_launch_pressed() -> void:
	var region_entry := RegionModel.entry(DataDefs.run, _selected_region())
	var cost := RegionModel.fuel_cost(region_entry, GameState.data["island"])
	if not FuelModel.spend(GameState.data["fuel"], cost, TimeUtil.now()):
		_refresh()
		return
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/run/salvage_run.tscn")
```

5. Add at the end of the file:

```gdscript
func _selected_region() -> String:
	return RegionModel.selected_id(GameState.data, DataDefs.run, GameState.data["island"])


func _on_region_pressed() -> void:
	var entries := RegionModel.unlocked_entries(DataDefs.run, GameState.data["island"])
	if entries.size() <= 1:
		return
	var current := _selected_region()
	var index := 0
	for i in entries.size():
		if String((entries[i] as Dictionary).get("id", "")) == current:
			index = i
			break
	if not GameState.data.has("expedition"):
		GameState.data["expedition"] = {"region": RegionModel.FALLBACK_ID}
	(GameState.data["expedition"] as Dictionary)["region"] = \
		String((entries[(index + 1) % entries.size()] as Dictionary).get("id", RegionModel.FALLBACK_ID))
	GameState.save_game()
	_refresh()
```

In `game/run/salvage_run.gd`, in `_ready`, replace the two region-1 hardcodes:

1. Replace `var region: Dictionary = DataDefs.skyfield("region_1")` with:

```gdscript
	var region_id := RegionModel.selected_id(GameState.data, run_defs, GameState.data["island"])
	var region: Dictionary = DataDefs.skyfield(region_id)
```

2. In the `board.install_gizmos(` call, replace `GizmoLoadout.loadout_for(gizmos_state, "region_1"),` with `GizmoLoadout.loadout_for(gizmos_state, region_id),`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0. Existing main-boot and salvage-run tests keep passing: with a fresh save the selection is region_1 at cost 1, identical behavior.

- [ ] **Step 6: Commit**

```bash
git add game/main.gd game/main.tscn game/run/salvage_run.gd tests/test_main_boot.gd tests/test_salvage_run.gd
git commit -m "feat: region selection on the launcher and region-aware run scene"
```

---

### Task 9: Loadout screen region cycler

**Files:**
- Modify: `game/ui/loadout_screen.gd`, `game/ui/loadout_screen.tscn`
- Test: `tests/test_loadout_screen.gd` (append)

**Interfaces:**
- Consumes: `RegionModel` (T2), schema v6 (T3), region_2 slots (T5), main's cycle pattern (T8).
- Produces: the loadout screen edits whichever region is selected, cycles unlocked regions via a `RegionButton`, and persists the selection per tap.

- [ ] **Step 1: Append the failing tests**

Append to `tests/test_loadout_screen.gd`:

```gdscript
func test_region_cycle_without_a_dock_is_a_no_op() -> void:
	screen._on_region_pressed()
	assert_eq(screen.region_id, "region_1")
	assert_eq(screen.get_node("Rows").get_child_count(), 6)

func test_region_cycle_with_a_dock_edits_brasswork_reach() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "dock", "level": 1}
	screen._on_region_pressed()
	assert_eq(screen.region_id, "region_2")
	assert_eq(screen.get_node("Rows").get_child_count(), 8, "region 2 has 8 slots")
	assert_string_contains(screen.get_node("RegionButton").text, "Brasswork Reach")
	var saved := SaveIO.new(TEST_SAVE).read()
	assert_eq(String((saved["expedition"] as Dictionary)["region"]), "region_2")

func test_slot_edits_land_in_the_cycled_region() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "dock", "level": 1}
	screen._on_region_pressed()
	screen._on_slot_pressed("slot_7")
	var loadout := GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_2")
	assert_true(loadout.has("slot_7"), "the edit belongs to region 2, not region 1")
	assert_eq(GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1"), {})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: no `RegionButton` node, `_on_region_pressed` undefined.

- [ ] **Step 3: Implement**

In `game/ui/loadout_screen.tscn`, add after the `Rows` node block (before `BackButton`):

```
[node name="RegionButton" type="Button" parent="."]
offset_left = 160.0
offset_top = 1000.0
offset_right = 560.0
offset_bottom = 1060.0
text = "Region"
```

In `game/ui/loadout_screen.gd`, replace `_ready` with, and add `_load_region`/`_on_region_pressed`:

```gdscript
func _ready() -> void:
	region_id = RegionModel.selected_id(GameState.data, DataDefs.run, GameState.data["island"])
	$BackButton.pressed.connect(_on_back_pressed)
	$RegionButton.pressed.connect(_on_region_pressed)
	_load_region()


func _load_region() -> void:
	var region: Dictionary = DataDefs.skyfield(region_id)
	_slots = []
	for i in (region.get("gizmo_slots", []) as Array).size():
		_slots.append("slot_%d" % i)
	$RegionButton.text = "Region: %s" % String(RegionModel.entry(DataDefs.run, region_id).get("name", region_id))
	_rebuild()


func _on_region_pressed() -> void:
	var entries := RegionModel.unlocked_entries(DataDefs.run, GameState.data["island"])
	if entries.size() <= 1:
		return
	var index := 0
	for i in entries.size():
		if String((entries[i] as Dictionary).get("id", "")) == region_id:
			index = i
			break
	region_id = String((entries[(index + 1) % entries.size()] as Dictionary).get("id", RegionModel.FALLBACK_ID))
	if not GameState.data.has("expedition"):
		GameState.data["expedition"] = {"region": RegionModel.FALLBACK_ID}
	(GameState.data["expedition"] as Dictionary)["region"] = region_id
	GameState.save_game()
	_load_region()
```

(The `region_id` member and everything else in the file stay as they are; `_ready`'s old slot-derivation body moved into `_load_region`.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0. Existing loadout tests keep passing: fresh saves select region_1 with 6 slots.

- [ ] **Step 5: Commit**

```bash
git add game/ui/loadout_screen.gd game/ui/loadout_screen.tscn tests/test_loadout_screen.gd
git commit -m "feat: loadout screen edits the selected region's gizmo slots"
```

---

### Task 10: Region 2 end-to-end integration proof

**Files:**
- Test: `tests/test_region_2_integration.gd` (new)

**Interfaces:**
- Consumes: everything this plan produced, driven together on a fake clock through the pure models.

This is an integration-proof task: RED is not required (standing ruling for fake-clock e2e tasks). Write the test, make it pass; a failing assertion is a real integration bug to investigate, never a test to weaken.

- [ ] **Step 1: Write the integration test**

Create `tests/test_region_2_integration.gd`:

```gdscript
extends GutTest
## End-to-end region 2 flywheel on a fake clock: build the Dock, unlock and
## select Brasswork Reach, bank brasswork through the run model, craft the
## Gyro Damper with it, slot it in region 2's loadout, and roundtrip the v6
## save. Spec: 2026-08-17-region-2-brasswork-reach-design.md sections 2-7.

const TimerServiceScript := preload("res://game/autoload/timer_service.gd")
const EconomyScript := preload("res://game/autoload/economy.gd")
const GameStateScript := preload("res://game/autoload/game_state.gd")
const TEST_PATH := "user://test_region_2.json"
const T0 := 1_900_000_000

var state: Node
var econ: Node
var timers: Node


func before_each() -> void:
	_delete_test_files()
	state = autofree(GameStateScript.new())
	state._io = SaveIO.new(TEST_PATH)
	state.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	state.data["created_at"] = T0
	state.data["fuel"]["updated_at"] = T0
	state.data["currencies"]["scrap"] = 5000
	econ = autofree(EconomyScript.new())
	econ.setup(state)
	timers = autofree(TimerServiceScript.new())
	timers.setup(state)

func after_all() -> void:
	_delete_test_files()

func _delete_test_files() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_region_2.json", "test_region_2.json.tmp", "test_region_2.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)


func test_dock_unlock_to_brass_craft_flywheel() -> void:
	# Locked at first: the selection falls back home.
	assert_eq(RegionModel.selected_id(state.data, DataDefs.run, state.data["island"]), "region_1")
	# Build the Dock (120 scrap, 180 s) and collect it.
	assert_true(IslandModel.start_build(state.data["island"], DataDefs.buildings, econ, timers, "plot_0", "dock", T0))
	IslandModel.complete_build(state.data["island"], timers.collect("build_plot_0", T0 + 181), state.data, T0 + 181, DataDefs.buildings)
	var region_2 := RegionModel.entry(DataDefs.run, "region_2")
	assert_true(RegionModel.unlocked(region_2, state.data["island"]))
	assert_eq(RegionModel.fuel_cost(region_2, state.data["island"]), 2)
	# Select it and spend a region-2 expedition's fuel.
	(state.data["expedition"] as Dictionary)["region"] = "region_2"
	assert_eq(RegionModel.selected_id(state.data, DataDefs.run, state.data["island"]), "region_2")
	assert_true(FuelModel.spend(state.data["fuel"], 2, T0 + 200))
	# A scripted run on region 2's tiers banks scrap and brasswork.
	var region_defs := DataDefs.skyfield("region_2")
	var model := RunModel.new({"drops_per_run": 8, "max_active_pods": 4, "quota_tiers": region_defs.get("quota_tiers", [])})
	model.begin_drop()
	model.resolve_pod({"scrap": 35, "brasswork": 2})
	assert_eq(model.tier, 1, "region 2's first quota lifts at 35 scrap")
	econ.add("scrap", 35)
	econ.add("brasswork", 2)
	# Build the Workshop, then craft the Gyro Damper with the brasswork.
	assert_true(IslandModel.start_build(state.data["island"], DataDefs.buildings, econ, timers, "plot_1", "workshop", T0 + 300))
	IslandModel.complete_build(state.data["island"], timers.collect("build_plot_1", T0 + 361), state.data, T0 + 361, DataDefs.buildings)
	assert_true(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "gyro_damper"))
	assert_true(CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "gyro_damper", T0 + 400))
	assert_eq(econ.balance("brasswork"), 0, "the recipe consumed the regional material")
	CraftModel.complete_craft(state.data, timers.collect("craft_gyro_damper", T0 + 400 + 421))
	assert_eq(int(state.data["gizmos"]["owned"]["gyro_damper"]), 1, "first craft grants ownership")
	# Slot it on Brasswork Reach and roundtrip the save.
	GizmoLoadout.set_slot(state.data["gizmos"], "region_2", "slot_4", "gyro_damper")
	assert_eq(state.save_game(), OK)
	var reloaded := SaveIO.new(TEST_PATH).read()
	assert_eq(int(reloaded["version"]), SaveSchema.CURRENT_VERSION)
	assert_eq(String((reloaded["expedition"] as Dictionary)["region"]), "region_2")
	assert_eq(String(((reloaded["gizmos"]["loadout"] as Dictionary)["region_2"] as Dictionary)["slot_4"]), "gyro_damper")

func test_dock_level_2_discount_end_to_end() -> void:
	state.data["island"]["plots"]["plot_0"] = {"building": "dock", "level": 2}
	assert_eq(RegionModel.fuel_cost(RegionModel.entry(DataDefs.run, "region_2"), state.data["island"]), 1,
		"spec 4.1: higher Dock levels reduce expedition fuel costs")
```

- [ ] **Step 2: Run the suite**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0. Any failure is an integration bug: debug it, never weaken the test.

- [ ] **Step 3: Import, verify sidecar, commit**

Run: `$GODOT --headless --import` then `git status --porcelain` (stage `tests/test_region_2_integration.gd.uid`).

```bash
git add tests/test_region_2_integration.gd tests/test_region_2_integration.gd.uid
git commit -m "test: prove the region 2 unlock-to-craft flywheel end to end"
```

---

## Post-plan checklist (for the executing session, not a task)

- Final whole-branch review runs the canonical suite once as the gate.
- Windowed smoke steps are waived in this non-interactive environment (headless substitutes), noted in the report.
- Collect every ledger "Ruling:" line for the finishing menu.
- Deliberate deferrals after this plan: boons + boon-reroll placement (Plan 7), AdMob and its two parked async items, island expansion/story, gizmo rarities, sound, art pass (docs/art/placeholder-graphics-audit.md gains region-2 and brass-gizmo entries only when the art pass happens), regions 3+ (now a JSON file plus at most a new hazard).
