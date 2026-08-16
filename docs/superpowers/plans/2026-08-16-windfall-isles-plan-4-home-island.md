# Windfall Isles Plan 4: Home Island Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Loop 1: six data-driven buildings on plots with real-time construction, the Workshop as the gizmo upgrade faucet (timed crafts merging duplicates into levels), Wind Still and Balloonworks effects feeding runs, the Gardens idle trickle, the daily crate, and the crystal-unlocked second build slot.

**Architecture:** All island state lives in save schema v4 (`island`, `trickle`, `daily_crate` sections) and is manipulated only through pure model classes (`IslandModel`, `IslandEffects`, `TrickleModel`, `DailyCrate`, `CraftModel`) that take explicit `now: int` and defs dicts, following the FuelModel pattern. Construction and crafts ride the existing `TimerService` (kinds `"construction"` and `"craft"`); building effects are re-applied idempotently at load so saves self-heal. UI screens stay dumb: every rule lives in a model.

**Tech Stack:** Godot 4.6.3 GDScript, GUT 9.6.1 headless, JSON data files.

**Spec:** [docs/design/2026-08-15-windfall-isles-design.md](../design/2026-08-15-windfall-isles-design.md) sections 4.1 (buildings), 4.2 (sinks), 4.3 (Wind Still scaling), 5 (return hooks: construction/craft timers, idle trickle, daily crate), 8 (MVP cut line). Plans 1-3b are merged on main.

**MVP scoping rulings (recorded here, argued from spec 8):** The Dock and Observatory are buildable with their strategic payloads deferred: the Dock's region unlocks and fuel-cost reduction act on content that is post-MVP (regions 2+) and on a fuel cost already at the floor of 1; the Observatory shows its data-driven region teaser, with quests/goals deferred to Plan 5 alongside the crystal-faucet work. Balloonworks grants +1 drop per level (the pod weight/bounce profile is a Plan 5 tuning pass). All 8 gizmos remain starters (Plan 3b); the Workshop's crafting purpose is merging crafted duplicates into LEVELS (spec 3.3), gated by craft slots equal to Workshop level.

## Global Constraints

- Engine: Godot 4.6.x pinned; `$GODOT` = `/Applications/Godot-4.6.app/Contents/MacOS/Godot` (4.6.3). Never plain `godot` or `/Applications/Godot.app` (4.7).
- GDScript only; tabs. Every tunable in `game/data/*.json` (spec 7.2). Timers are Unix timestamps persisted in the save, elapsed computed on resume (spec 7.1); logic takes `now: int`, only boundaries call `TimeUtil.now()`.
- Save schema versioned (spec 7.3); this plan bumps to v4. Real v3 saves must gain the island structures losslessly; v1/v2 saves hop the whole chain.
- Crystal sinks are accelerators or breadth, never exclusive progression (spec 4.2): the second build slot costs crystals; everything else is scrap/materials/time.
- Canonical test command (must exit 0): `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- Binding repo lessons (Plans 1-3b): `.gd.uid` sidecars committed, verified via `git status --porcelain` after `--import`; error-count assertions AFTER the trigger; `int()`/`float()` wrap all JSON reads; int-cast scalar assertions against JSON-sourced dicts; scene-owned child Timer + `weakref()` (never SceneTreeTimer with raw objects); `await wait_physics_frames(2)` before velocity asserts; `assert_signal_emitted_with_parameters` takes no message arg; explicit types where `:=` inference hits untyped chains; no cumulative suite totals; physics-world-mutating handlers need one real-contact integration proof (not applicable here: this plan adds no physics mutators); `add_child.call_deferred` inside physics-flush paths.
- UI tests never press buttons that change scenes; state assertions via direct handler calls; GameState._io swap + after_all restore pattern (three-arg load_game with DataDefs.gizmos).
- Commit after every task, conventional-commit messages.

## Interfaces consumed from Plans 1-3b (merged on main, exact)

- `TimerService` autoload: `start(id, kind, duration_sec, now, payload={}) -> bool`, `remaining(id, now) -> int`, `is_done(id, now) -> bool`, `collect(id, now) -> Dictionary` ({} if not done), `skip(id)`, `active_timers() -> Dictionary`, signals `timer_started(id)`, `timer_collected(id, payload)`.
- `Economy` autoload: `balance`, `add`, `spend`, `can_afford(cost)`, `pay(cost) -> bool` (all-or-nothing), `balance_changed`.
- `GameState`: `data`, `save_game()`, `load_game(defs, now, gizmo_defs = {})` (this plan appends an optional `building_defs = {}`), `_io` injectable.
- `SaveSchema`: `CURRENT_VERSION == 3`, `default_data(defs, gizmo_defs={})`, `migrate(data, gizmo_defs={})`, `_migrate_1_to_2`, `_migrate_2_to_3`, `_fresh_gizmos`.
- `FuelModel` (fuel dict keys amount/cap/regen_seconds/updated_at); `TimeUtil.now()`; `DataDefs` (economy/run/gizmos + `load_json`); `GizmoLoadout.owned`.
- `salvage_run.gd`: `_ready` builds `RunModel.new(run_defs)`; `main.gd`: launch flow, GizmosButton pattern; `game/data/gizmos.json` defs (this plan adds `craft_cost`/`craft_seconds` per def and a top-level `craft_max_level`).
- Lightning Jar internals for the T1 carry-forwards: `game/run/gizmos/lightning_jar.gd` `_on_body_entered` (zap loop, `_charges`, `zapped == 0` early return), `tests/test_lightning_jar.gd` fixtures (`make_peg`, `context_stub`).

## File Structure

```
game/core/save_schema.gd            # T1 modify (self-heal write-back), T2 modify (v4)
game/run/gizmos/lightning_jar.gd    # T1 modify (nearest-first zap)
tests/test_lightning_jar.gd         # T1 append 2
game/data/buildings.json            # T2 building defs + slots + plot count
game/data/retention.json            # T2 daily crate payout
game/data/gizmos.json               # T2 modify (craft costs/times + craft_max_level)
game/autoload/data_defs.gd          # T2 modify (buildings, retention)
game/autoload/game_state.gd         # T4 modify (building_defs param + effects apply)
tests/test_save_schema.gd           # T2 modify/append
game/base/island_model.gd           # T3 pure construction/plots/slots model
tests/test_island_model.gd          # T3
game/base/island_effects.gd         # T4 pure effect application
game/run/salvage_run.gd             # T4 modify (drops bonus)
tests/test_island_effects.gd        # T4
tests/test_salvage_run.gd           # T4 append 1
game/base/trickle_model.gd          # T5
game/base/daily_crate.gd            # T5
tests/test_trickle_model.gd         # T5
tests/test_daily_crate.gd           # T5
game/base/craft_model.gd            # T6
tests/test_craft_model.gd           # T6
game/base/island_screen.gd/.tscn    # T7 plots UI, T9 modify (retention controls)
game/main.gd + main.tscn            # T7 modify (Island button)
tests/test_island_screen.gd         # T7, T9 append
tests/test_main_boot.gd             # T7 append 1
game/base/workshop_screen.gd/.tscn  # T8 craft UI
tests/test_workshop_screen.gd       # T8
tests/test_island_integration.gd    # T10 fake-clock end-to-end
```

---

### Task 1: Plan 3b carry-forwards (jar tuning + migration self-heal)

**Files:**
- Modify: `game/run/gizmos/lightning_jar.gd`
- Modify: `game/core/save_schema.gd` (`_migrate_2_to_3`)
- Test: `tests/test_lightning_jar.gd` (append 2)

**Interfaces:**
- Consumes: existing jar and migration code.
- Produces: nearest-first zap ordering; the previously untested `zapped == 0` no-charge path covered; `_migrate_2_to_3` writes its structure back so a malformed v2 save self-heals.

- [ ] **Step 1: Append the failing tests**

Append to `tests/test_lightning_jar.gd`:

```gdscript
func test_zap_prefers_nearest_pegs() -> void:
	make_peg(Vector2(360, 380))
	make_peg(Vector2(360, 460))
	make_peg(Vector2(360, 520))
	make_peg(Vector2(460, 500))
	jar._on_body_entered(make_pod())
	await wait_physics_frames(1)
	var survivors: Array = get_tree().get_nodes_in_group("pegs")
	assert_eq(survivors.size(), 1)
	assert_eq((survivors[0] as Node2D).position, Vector2(360, 380),
		"the farthest in-range peg survives when the cap bites")

func test_out_of_range_contact_consumes_no_charge() -> void:
	make_peg(Vector2(360, 900))
	jar._on_body_entered(make_pod())
	jar._on_body_entered(make_pod())
	jar._on_body_entered(make_pod())
	assert_eq(context_stub.bonuses.size(), 0, "no pegs in range, no bonus ever")
	make_peg(Vector2(360, 480))
	jar._on_body_entered(make_pod())
	assert_eq(context_stub.bonuses.size(), 1,
		"charges were never consumed by the empty zaps")
```

(Distance check for the nearest test: jar at (360, 500); distances are 120, 40, 20, 100; cap 3 zaps the three nearest, so only (360, 380) survives. If the existing fixture's jar position differs, keep the brief's before_each as-is; it already places the jar at (360, 500).)

- [ ] **Step 2: Run tests to verify they fail**

```bash
$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: the nearest-first test FAILS under tree-order zapping (the survivor is order-dependent, not distance-dependent); the no-charge test passes already (guard exists) or fails only if the guard regressed; run and record.

- [ ] **Step 3: Implement**

In `game/run/gizmos/lightning_jar.gd`, replace the zap loop inside `_on_body_entered` with:

```gdscript
	var candidates: Array = []
	for peg in get_tree().get_nodes_in_group("pegs"):
		if peg.global_position.distance_to(global_position) <= _zap_radius:
			candidates.append(peg)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))
	var zapped := 0
	for peg in candidates:
		if zapped >= _pegs_zapped:
			break
		peg.queue_free()
		peg.remove_from_group("pegs")
		zapped += 1
```

In `game/core/save_schema.gd`, inside `_migrate_2_to_3`, replace the `owned` acquisition with a self-healing write-back:

```gdscript
	if not data.has("gizmos") or not (data["gizmos"] is Dictionary):
		data["gizmos"] = _fresh_gizmos(gizmo_defs)
	var gizmos: Dictionary = data["gizmos"]
	if not gizmos.has("owned"):
		gizmos["owned"] = {}
	if not gizmos.has("loadout"):
		gizmos["loadout"] = {}
	var owned: Dictionary = gizmos["owned"]
```

(The rest of the function, the merge-grant loop and version stamp, stays unchanged.)

- [ ] **Step 4: Run tests to verify they pass**

Same command. Expected: PASS, 2 new tests green, full suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/run/gizmos/lightning_jar.gd game/core/save_schema.gd tests/test_lightning_jar.gd
git commit -m "fix: zap nearest pegs first and self-heal malformed saves in the v3 hop"
```

---

### Task 2: Schema v4 and the island data files

**Files:**
- Create: `game/data/buildings.json`, `game/data/retention.json`
- Modify: `game/data/gizmos.json`, `game/autoload/data_defs.gd`, `game/core/save_schema.gd`
- Test: `tests/test_save_schema.gd` (append 3), new `tests/test_building_defs.gd`

**Interfaces:**
- Consumes: v3 schema.
- Produces:
  - `DataDefs.buildings` (keys `build_slots{free,max,second_slot_crystal_cost}`, `plot_count`, `defs{six buildings}` where each def has `name`, `max_level`, `levels` array of `{cost, build_seconds}`, plus per-building effect keys listed below) and `DataDefs.retention` (`daily_crate` payout dict).
  - `gizmos.json` gains top-level `"craft_max_level": 5` and per-def `"craft_cost"` + `"craft_seconds"` (T6 consumes).
  - `SaveSchema.CURRENT_VERSION == 4`; `_migrate_3_to_4(data)` adds `"island": {"plots": {}, "build_slots": 1}`, `"trickle": {"last_collect": 0}`, `"daily_crate": {"last_claim_day": 0}`; `default_data` emits the same fresh shapes; `migrate` chains v1 through v4.
  - Building effect keys: `wind_still.fuel_cap_bonus_per_level` (1) and `wind_still.regen_delta_per_level` (-120.0); `balloonworks.drops_bonus_per_level` (1); `gardens.scrap_per_hour_per_level` (20) and `gardens.cap_hours` (8.0); `workshop` craft slots equal its level; `observatory.teaser` string; `dock` has levels only (effects deferred per the scoping ruling).

- [ ] **Step 1: Write the data files**

`game/data/buildings.json`:

```json
{
	"build_slots": {"free": 1, "max": 2, "second_slot_crystal_cost": 20},
	"plot_count": 6,
	"defs": {
		"workshop": {
			"name": "Workshop",
			"max_level": 3,
			"levels": [
				{"cost": {"scrap": 60}, "build_seconds": 60},
				{"cost": {"scrap": 240, "cloudsilk": 2}, "build_seconds": 900},
				{"cost": {"scrap": 800, "cloudsilk": 6}, "build_seconds": 3600}
			]
		},
		"wind_still": {
			"name": "Wind Still",
			"max_level": 3,
			"fuel_cap_bonus_per_level": 1,
			"regen_delta_per_level": -120.0,
			"levels": [
				{"cost": {"scrap": 80}, "build_seconds": 120},
				{"cost": {"scrap": 320, "cloudsilk": 3}, "build_seconds": 1200},
				{"cost": {"scrap": 1000, "cloudsilk": 8}, "build_seconds": 4800}
			]
		},
		"dock": {
			"name": "Dock",
			"max_level": 2,
			"levels": [
				{"cost": {"scrap": 120}, "build_seconds": 180},
				{"cost": {"scrap": 500, "cloudsilk": 4}, "build_seconds": 1800}
			]
		},
		"balloonworks": {
			"name": "Balloonworks",
			"max_level": 3,
			"drops_bonus_per_level": 1,
			"levels": [
				{"cost": {"scrap": 100}, "build_seconds": 150},
				{"cost": {"scrap": 400, "cloudsilk": 3}, "build_seconds": 1500},
				{"cost": {"scrap": 1200, "cloudsilk": 10}, "build_seconds": 5400}
			]
		},
		"observatory": {
			"name": "Observatory",
			"max_level": 1,
			"teaser": "Charted winds hint at the Brasswork Reach beyond the eastern clouds.",
			"levels": [
				{"cost": {"scrap": 150, "crystals": 2}, "build_seconds": 300}
			]
		},
		"gardens": {
			"name": "Gardens & Cisterns",
			"max_level": 3,
			"scrap_per_hour_per_level": 20,
			"cap_hours": 8.0,
			"levels": [
				{"cost": {"scrap": 90}, "build_seconds": 120},
				{"cost": {"scrap": 360, "cloudsilk": 2}, "build_seconds": 1200},
				{"cost": {"scrap": 1100, "cloudsilk": 7}, "build_seconds": 4200}
			]
		}
	}
}
```

`game/data/retention.json`:

```json
{
	"daily_crate": {
		"scrap": 40,
		"crystals": 1
	}
}
```

In `game/data/gizmos.json`: add a top-level key (after `starting_inventory`):

```json
	"craft_max_level": 5,
```

and add to EVERY entry in `defs` two keys (values below per gizmo):

```json
			"craft_cost": {"scrap": 80},
			"craft_seconds": 120
```

with these per-gizmo values: wind_fan `{"scrap": 80}` / 120; balloon_cluster `{"scrap": 90}` / 150; crystal_prism `{"scrap": 150, "cloudsilk": 1}` / 300; lightning_jar `{"scrap": 140, "cloudsilk": 1}` / 240; chime_bell `{"scrap": 120}` / 200; magnet_buoy `{"scrap": 110}` / 180; cargo_net `{"scrap": 100}` / 160; splitter_vane `{"scrap": 160, "cloudsilk": 2}` / 360.

- [ ] **Step 2: Write the failing tests**

`tests/test_building_defs.gd`:

```gdscript
extends GutTest


func test_buildings_load_with_six_defs() -> void:
	assert_eq((DataDefs.buildings["defs"] as Dictionary).size(), 6, "spec 4.1 lists six buildings")
	for id in ["workshop", "wind_still", "dock", "balloonworks", "observatory", "gardens"]:
		assert_has(DataDefs.buildings["defs"], id)
	for id in DataDefs.buildings["defs"]:
		var def: Dictionary = DataDefs.buildings["defs"][id]
		assert_eq((def["levels"] as Array).size(), int(def["max_level"]),
			"every level needs a cost/time row: %s" % id)

func test_slots_and_retention() -> void:
	assert_eq(int(DataDefs.buildings["build_slots"]["free"]), 1, "spec 4.1: one free build slot")
	assert_true(int(DataDefs.buildings["build_slots"]["second_slot_crystal_cost"]) > 0)
	assert_true(int(DataDefs.retention["daily_crate"]["scrap"]) > 0)

func test_every_gizmo_has_craft_tuning() -> void:
	assert_eq(int(DataDefs.gizmos["craft_max_level"]), 5)
	for id in DataDefs.gizmos["defs"]:
		var def: Dictionary = DataDefs.gizmos["defs"][id]
		assert_true((def["craft_cost"] as Dictionary).size() > 0, "craft_cost missing: %s" % id)
		assert_true(int(def["craft_seconds"]) > 0, "craft_seconds missing: %s" % id)
```

Append to `tests/test_save_schema.gd`:

```gdscript
func test_default_data_has_v4_island_shape() -> void:
	var data := SaveSchema.default_data(DEFS)
	assert_eq(int(data["version"]), 4)
	assert_eq(data["island"], {"plots": {}, "build_slots": 1})
	assert_eq(data["trickle"], {"last_collect": 0})
	assert_eq(data["daily_crate"], {"last_claim_day": 0})

func test_migrate_v3_to_v4_adds_island_losslessly() -> void:
	var v3 := SaveSchema.default_data(DEFS, GIZMO_DEFS)
	v3["version"] = 3
	v3.erase("island")
	v3["currencies"]["scrap"] = 555
	var migrated := SaveSchema.migrate(v3, GIZMO_DEFS)
	assert_eq(int(migrated["version"]), 4)
	assert_eq(migrated["island"], {"plots": {}, "build_slots": 1})
	assert_eq(int(migrated["currencies"]["scrap"]), 555)

func test_migrate_v1_hops_all_the_way_to_v4() -> void:
	var v1 := SaveSchema.default_data(DEFS)
	v1["version"] = 1
	v1["gizmos"] = {}
	var migrated := SaveSchema.migrate(v1, GIZMO_DEFS)
	assert_eq(int(migrated["version"]), 4)
	assert_has(migrated, "island")
	assert_has(migrated, "daily_crate")
```

Also UPDATE the two version-literal assertions from Plan 3b: in `test_migrate_v2_merge_grants_new_starters_preserving_levels` and `test_migrate_v1_hops_to_current_with_grant` the `SaveSchema.CURRENT_VERSION` comparisons already track the constant and stay valid; in `test_current_version_is_three_and_defaults_grant_eight`, rename to `test_current_version_is_four_and_defaults_grant_eight` and change the first assertion to `assert_eq(SaveSchema.CURRENT_VERSION, 4)`.

- [ ] **Step 3: Run tests to verify they fail**

Expected: FAIL (no buildings/retention loaders, CURRENT_VERSION is 3, island stays `{}`).

- [ ] **Step 4: Implement**

`game/autoload/data_defs.gd`: add paths and vars, extend `_ready`:

```gdscript
const BUILDINGS_PATH := "res://game/data/buildings.json"
const RETENTION_PATH := "res://game/data/retention.json"
```

```gdscript
var buildings: Dictionary = {}
var retention: Dictionary = {}
```

```gdscript
	buildings = load_json(BUILDINGS_PATH)
	retention = load_json(RETENTION_PATH)
```

`game/core/save_schema.gd`: set `const CURRENT_VERSION := 4`; in `default_data`, replace the reserved `"island": {}` with:

```gdscript
		"island": _fresh_island(),
		"trickle": {"last_collect": 0},
		"daily_crate": {"last_claim_day": 0},
```

(keep `"timers": {}` and `"gizmos"` as they are); add:

```gdscript
static func _fresh_island() -> Dictionary:
	return {"plots": {}, "build_slots": 1}


static func _migrate_3_to_4(data: Dictionary) -> Dictionary:
	# Loop 1 arrives: plots/build slots, idle trickle clock, daily crate day.
	data["island"] = _fresh_island()
	data["trickle"] = {"last_collect": 0}
	data["daily_crate"] = {"last_claim_day": 0}
	data["version"] = 4
	return data
```

and extend `migrate`'s hop chain after the v2 hop:

```gdscript
	if int(data["version"]) == 3:
		data = _migrate_3_to_4(data)
```

- [ ] **Step 5: Run tests to verify they pass**

Expected: PASS, full suite exit 0 (the updated Plan 3b test names included).

- [ ] **Step 6: Commit**

```bash
git add game/data/buildings.json game/data/retention.json game/data/gizmos.json game/autoload/data_defs.gd game/core/save_schema.gd tests/test_building_defs.gd tests/test_save_schema.gd
git commit -m "feat: add building and retention data with save schema v4"
```

---

### Task 3: IslandModel (construction over TimerService)

**Files:**
- Create: `game/base/island_model.gd`
- Test: `tests/test_island_model.gd`

**Interfaces:**
- Consumes: v4 island shape (T2), buildings defs shape (T2), `TimerService` and `Economy` autoload duck-types (tests inject fresh instances, the established pattern).
- Produces: `class_name IslandModel` statics (T7/T10 consume):
  - `static func building_level(island: Dictionary, building_id: String) -> int` (0 = not built)
  - `static func plot_of(island: Dictionary, building_id: String) -> String` ("" if none)
  - `static func active_constructions(timers: Node, now: int) -> int` (counts kind "construction" among `timers.active_timers()`)
  - `static func can_start_build(island, defs, economy: Node, timers: Node, plot: String, building_id: String, now: int) -> bool` (plot empty or holds this building below max; building not on another plot; a level row exists; affordable; construction slots free; no timer already on this plot)
  - `static func start_build(island, defs, economy, timers, plot, building_id, now) -> bool` (pays, writes `plots[plot] = {"building": id, "level": current}` if absent, starts timer id `"build_" + plot` kind "construction" payload `{"plot", "building", "to_level"}`)
  - `static func complete_build(island, payload: Dictionary, data: Dictionary, now: int) -> void` (applies the level; when gardens reach level 1, stamps `data["trickle"]["last_collect"] = now`)
  - `static func unlock_second_slot(island, defs, economy) -> bool` (crystal sink, caps at `build_slots.max`)

- [ ] **Step 1: Write the failing tests**

`tests/test_island_model.gd`:

```gdscript
extends GutTest

const TimerServiceScript := preload("res://game/autoload/timer_service.gd")
const EconomyScript := preload("res://game/autoload/economy.gd")
const GameStateScript := preload("res://game/autoload/game_state.gd")

var state
var econ
var timers
var island: Dictionary
var defs: Dictionary


func before_each() -> void:
	defs = DataDefs.buildings
	state = autofree(GameStateScript.new())
	state.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	state.data["currencies"]["scrap"] = 2000
	state.data["currencies"]["cloudsilk"] = 20
	state.data["currencies"]["crystals"] = 30
	island = state.data["island"]
	econ = autofree(EconomyScript.new())
	econ.setup(state)
	timers = autofree(TimerServiceScript.new())
	timers.setup(state)


func test_fresh_island_has_no_buildings() -> void:
	assert_eq(IslandModel.building_level(island, "workshop"), 0)
	assert_eq(IslandModel.plot_of(island, "workshop"), "")

func test_start_build_pays_and_starts_timer() -> void:
	assert_true(IslandModel.start_build(island, defs, econ, timers, "plot_0", "workshop", 1000))
	assert_eq(econ.balance("scrap"), 2000 - 60)
	assert_eq(timers.remaining("build_plot_0", 1000), 60)
	assert_eq(IslandModel.building_level(island, "workshop"), 0, "not leveled until collected")

func test_complete_build_applies_level() -> void:
	IslandModel.start_build(island, defs, econ, timers, "plot_0", "workshop", 1000)
	var payload := timers.collect("build_plot_0", 1061)
	IslandModel.complete_build(island, payload, state.data, 1061)
	assert_eq(IslandModel.building_level(island, "workshop"), 1)
	assert_eq(IslandModel.plot_of(island, "workshop"), "plot_0")

func test_one_construction_slot_by_default() -> void:
	IslandModel.start_build(island, defs, econ, timers, "plot_0", "workshop", 1000)
	assert_false(IslandModel.can_start_build(island, defs, econ, timers, "plot_1", "gardens", 1000),
		"spec 4.1: one free build slot")

func test_unlock_second_slot_costs_crystals_and_allows_parallel() -> void:
	assert_true(IslandModel.unlock_second_slot(island, defs, econ))
	assert_eq(econ.balance("crystals"), 30 - 20)
	assert_eq(int(island["build_slots"]), 2)
	assert_false(IslandModel.unlock_second_slot(island, defs, econ), "capped at max")
	IslandModel.start_build(island, defs, econ, timers, "plot_0", "workshop", 1000)
	assert_true(IslandModel.can_start_build(island, defs, econ, timers, "plot_1", "gardens", 1000))

func test_same_building_cannot_occupy_two_plots() -> void:
	IslandModel.start_build(island, defs, econ, timers, "plot_0", "workshop", 1000)
	IslandModel.complete_build(island, timers.collect("build_plot_0", 1100), state.data, 1100)
	assert_false(IslandModel.can_start_build(island, defs, econ, timers, "plot_1", "workshop", 1100))

func test_upgrade_uses_next_level_row_and_respects_max() -> void:
	IslandModel.start_build(island, defs, econ, timers, "plot_0", "dock", 1000)
	IslandModel.complete_build(island, timers.collect("build_plot_0", 1200), state.data, 1200)
	var scrap_before: int = econ.balance("scrap")
	assert_true(IslandModel.start_build(island, defs, econ, timers, "plot_0", "dock", 1200))
	assert_eq(econ.balance("scrap"), scrap_before - 500, "level 2 cost row")
	IslandModel.complete_build(island, timers.collect("build_plot_0", 3200), state.data, 3200)
	assert_eq(IslandModel.building_level(island, "dock"), 2)
	assert_false(IslandModel.can_start_build(island, defs, econ, timers, "plot_0", "dock", 3200),
		"dock max_level is 2")

func test_gardens_completion_stamps_trickle_clock() -> void:
	IslandModel.start_build(island, defs, econ, timers, "plot_2", "gardens", 5000)
	IslandModel.complete_build(island, timers.collect("build_plot_2", 5200), state.data, 5200)
	assert_eq(int(state.data["trickle"]["last_collect"]), 5200,
		"the trickle counts from the moment gardens first exist")

func test_insufficient_funds_rejected() -> void:
	state.data["currencies"]["scrap"] = 10
	assert_false(IslandModel.start_build(island, defs, econ, timers, "plot_0", "workshop", 1000))
	assert_eq(timers.active_timers().size(), 0)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL with parse errors on `IslandModel`.

- [ ] **Step 3: Implement**

`game/base/island_model.gd`:

```gdscript
class_name IslandModel
## Pure construction rules over save.island (spec 4.1): plots hold buildings,
## build SLOTS cap concurrent constructions (one free, second via crystals),
## costs and durations come from buildings.json level rows. Timers ride
## TimerService kind "construction" with id "build_<plot>".


static func building_level(island: Dictionary, building_id: String) -> int:
	for plot in island.get("plots", {}):
		var entry: Dictionary = island["plots"][plot]
		if String(entry.get("building", "")) == building_id:
			return int(entry.get("level", 0))
	return 0


static func plot_of(island: Dictionary, building_id: String) -> String:
	for plot in island.get("plots", {}):
		if String((island["plots"][plot] as Dictionary).get("building", "")) == building_id:
			return String(plot)
	return ""


static func active_constructions(timers: Node, _now: int) -> int:
	var count := 0
	for id in timers.active_timers():
		if String((timers.active_timers()[id] as Dictionary).get("kind", "")) == "construction":
			count += 1
	return count


static func _next_level_row(defs: Dictionary, island: Dictionary, plot: String, building_id: String) -> Dictionary:
	var def: Dictionary = (defs.get("defs", {}) as Dictionary).get(building_id, {})
	if def.is_empty():
		return {}
	var plots: Dictionary = island.get("plots", {})
	var current := 0
	if plots.has(plot):
		var entry: Dictionary = plots[plot]
		if String(entry.get("building", "")) != building_id:
			return {}
		current = int(entry.get("level", 0))
	elif plot_of(island, building_id) != "":
		return {}
	if current >= int(def.get("max_level", 1)):
		return {}
	var rows: Array = def.get("levels", [])
	if current >= rows.size():
		return {}
	return rows[current]


static func can_start_build(island: Dictionary, defs: Dictionary, economy: Node, timers: Node, plot: String, building_id: String, now: int) -> bool:
	if timers.active_timers().has("build_" + plot):
		return false
	if active_constructions(timers, now) >= int(island.get("build_slots", 1)):
		return false
	var row := _next_level_row(defs, island, plot, building_id)
	if row.is_empty():
		return false
	return economy.can_afford(row.get("cost", {}))


static func start_build(island: Dictionary, defs: Dictionary, economy: Node, timers: Node, plot: String, building_id: String, now: int) -> bool:
	if not can_start_build(island, defs, economy, timers, plot, building_id, now):
		return false
	var row := _next_level_row(defs, island, plot, building_id)
	if not economy.pay(row.get("cost", {})):
		return false
	var plots: Dictionary = island.get("plots", {})
	if not plots.has(plot):
		plots[plot] = {"building": building_id, "level": 0}
	var to_level := int((plots[plot] as Dictionary).get("level", 0)) + 1
	return timers.start("build_" + plot, "construction", int(row.get("build_seconds", 60)), now,
		{"plot": plot, "building": building_id, "to_level": to_level})


static func complete_build(island: Dictionary, payload: Dictionary, data: Dictionary, now: int) -> void:
	if payload.is_empty():
		return
	var plot := String(payload.get("plot", ""))
	var building_id := String(payload.get("building", ""))
	var plots: Dictionary = island.get("plots", {})
	if not plots.has(plot):
		return
	plots[plot]["level"] = int(payload.get("to_level", 1))
	if building_id == "gardens" and int(plots[plot]["level"]) == 1:
		(data.get("trickle", {}) as Dictionary)["last_collect"] = now


static func unlock_second_slot(island: Dictionary, defs: Dictionary, economy: Node) -> bool:
	var slots_cfg: Dictionary = defs.get("build_slots", {})
	if int(island.get("build_slots", 1)) >= int(slots_cfg.get("max", 2)):
		return false
	if not economy.pay({"crystals": int(slots_cfg.get("second_slot_crystal_cost", 20))}):
		return false
	island["build_slots"] = int(island.get("build_slots", 1)) + 1
	return true
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, 9 new tests green, full suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/base/island_model.gd tests/test_island_model.gd
git commit -m "feat: add IslandModel with slot-capped timed construction"
```

---

### Task 4: IslandEffects and run wiring

**Files:**
- Create: `game/base/island_effects.gd`
- Modify: `game/autoload/game_state.gd` (optional `building_defs` param, effects applied post-load)
- Modify: `game/run/salvage_run.gd` (drops bonus)
- Test: `tests/test_island_effects.gd`, `tests/test_salvage_run.gd` (append 1)

**Interfaces:**
- Consumes: `building_level` (T3), effect keys (T2), fuel dict, run defs.
- Produces:
  - `class_name IslandEffects` statics: `apply_fuel(data: Dictionary, economy_defs: Dictionary, building_defs: Dictionary) -> void` (idempotent: cap = base cap + wind_still level bonus; regen = max(300, base regen + level * delta); amount clamped to cap) and `drops_per_run(run_defs: Dictionary, island: Dictionary, building_defs: Dictionary) -> int` (base + balloonworks level * bonus).
  - `GameState.load_game(defs, now, gizmo_defs = {}, building_defs = {})` calls `IslandEffects.apply_fuel(data, defs, building_defs)` after data is set (before `loaded.emit()`); `_ready` passes `DataDefs.buildings`. Effects also re-apply whenever a wind_still construction completes (T7 wires the UI call; T10 proves it).
  - `salvage_run._ready` builds the run config with the bonus: `run_defs` duplicated, `drops_per_run` overridden via `IslandEffects.drops_per_run`.

- [ ] **Step 1: Write the failing tests**

`tests/test_island_effects.gd`:

```gdscript
extends GutTest

const ECON_DEFS := {
	"starting_balances": {"scrap": 100, "cloudsilk": 0, "crystals": 10},
	"fuel": {"starting": 5, "cap": 5, "regen_seconds": 1200},
}


func data_with_wind_still(level: int) -> Dictionary:
	var data := SaveSchema.default_data(ECON_DEFS)
	if level > 0:
		data["island"]["plots"]["plot_0"] = {"building": "wind_still", "level": level}
	return data


func test_apply_fuel_without_wind_still_keeps_base() -> void:
	var data := data_with_wind_still(0)
	IslandEffects.apply_fuel(data, ECON_DEFS, DataDefs.buildings)
	assert_eq(int(data["fuel"]["cap"]), 5)
	assert_eq(int(data["fuel"]["regen_seconds"]), 1200)

func test_apply_fuel_scales_with_wind_still_level() -> void:
	var data := data_with_wind_still(2)
	IslandEffects.apply_fuel(data, ECON_DEFS, DataDefs.buildings)
	assert_eq(int(data["fuel"]["cap"]), 7, "base 5 + 2 levels x 1")
	assert_eq(int(data["fuel"]["regen_seconds"]), 960, "base 1200 + 2 x -120")

func test_apply_fuel_is_idempotent_and_clamps() -> void:
	var data := data_with_wind_still(1)
	data["fuel"]["amount"] = 99
	IslandEffects.apply_fuel(data, ECON_DEFS, DataDefs.buildings)
	IslandEffects.apply_fuel(data, ECON_DEFS, DataDefs.buildings)
	assert_eq(int(data["fuel"]["cap"]), 6, "applying twice must not stack")
	assert_eq(int(data["fuel"]["amount"]), 6, "amount clamps to the new cap")

func test_drops_per_run_scales_with_balloonworks() -> void:
	var island := {"plots": {"plot_1": {"building": "balloonworks", "level": 2}}, "build_slots": 1}
	assert_eq(IslandEffects.drops_per_run({"drops_per_run": 8}, island, DataDefs.buildings), 10)
	assert_eq(IslandEffects.drops_per_run({"drops_per_run": 8}, {"plots": {}, "build_slots": 1}, DataDefs.buildings), 8)
```

Append to `tests/test_salvage_run.gd`:

```gdscript
func test_run_drops_include_balloonworks_bonus() -> void:
	GameState.data["island"]["plots"]["plot_1"] = {"building": "balloonworks", "level": 1}
	var second = add_child_autofree(RunScene.instantiate())
	assert_eq(second.model.drops_remaining(), int(DataDefs.run["drops_per_run"]) + 1)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL (`IslandEffects` does not exist; the run test sees base drops).

- [ ] **Step 3: Implement**

`game/base/island_effects.gd`:

```gdscript
class_name IslandEffects
## Idempotent application of building effects (spec 4.1, 4.3). Effects are
## always recomputed from base defs plus levels, never incremented, so
## re-applying at every load self-heals the save.

const MIN_REGEN_SECONDS := 300


static func apply_fuel(data: Dictionary, economy_defs: Dictionary, building_defs: Dictionary) -> void:
	var base: Dictionary = economy_defs.get("fuel", {})
	var def: Dictionary = (building_defs.get("defs", {}) as Dictionary).get("wind_still", {})
	var level := IslandModel.building_level(data.get("island", {}), "wind_still")
	var fuel: Dictionary = data.get("fuel", {})
	fuel["cap"] = int(base.get("cap", 5)) + level * int(def.get("fuel_cap_bonus_per_level", 1))
	fuel["regen_seconds"] = maxi(MIN_REGEN_SECONDS,
		int(base.get("regen_seconds", 1200)) + level * int(def.get("regen_delta_per_level", -120.0)))
	fuel["amount"] = mini(int(fuel.get("amount", 0)), int(fuel["cap"]))


static func drops_per_run(run_defs: Dictionary, island: Dictionary, building_defs: Dictionary) -> int:
	var def: Dictionary = (building_defs.get("defs", {}) as Dictionary).get("balloonworks", {})
	var level := IslandModel.building_level(island, "balloonworks")
	return int(run_defs.get("drops_per_run", 8)) + level * int(def.get("drops_bonus_per_level", 1))
```

`game/autoload/game_state.gd`: change the signature and `_ready`:

```gdscript
func _ready() -> void:
	load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings)


func load_game(defs: Dictionary, now: int, gizmo_defs: Dictionary = {}, building_defs: Dictionary = {}) -> void:
```

and insert before `loaded.emit()`:

```gdscript
	if not building_defs.is_empty():
		IslandEffects.apply_fuel(data, defs, building_defs)
```

`game/run/salvage_run.gd`: in `_ready`, replace `model = RunModel.new(run_defs)` with:

```gdscript
	var run_config: Dictionary = run_defs.duplicate()
	run_config["drops_per_run"] = IslandEffects.drops_per_run(run_defs, GameState.data["island"], DataDefs.buildings)
	model = RunModel.new(run_config)
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, 5 new tests green, full suite exit 0. (Existing tests pass GameState fresh v4 data via `before_each`, so `data["island"]` exists; existing 2/3-arg `load_game` calls keep working through the new optional parameter.)

- [ ] **Step 5: Commit**

```bash
git add game/base/island_effects.gd game/autoload/game_state.gd game/run/salvage_run.gd tests/test_island_effects.gd tests/test_salvage_run.gd
git commit -m "feat: apply wind still and balloonworks effects idempotently"
```

---

### Task 5: TrickleModel and DailyCrate

**Files:**
- Create: `game/base/trickle_model.gd`, `game/base/daily_crate.gd`
- Test: `tests/test_trickle_model.gd`, `tests/test_daily_crate.gd`

**Interfaces:**
- Consumes: v4 `trickle`/`daily_crate` shapes (T2), gardens effect keys (T2), `building_level` (T3).
- Produces (T9/T10 consume):
  - `class_name TrickleModel`: `static func pending(data: Dictionary, building_defs: Dictionary, now: int) -> int` (gardens level * scrap_per_hour, elapsed hours capped at cap_hours, floor int; 0 when gardens unbuilt) and `static func collect(data: Dictionary, building_defs: Dictionary, now: int) -> int` (returns the pending amount, stamps `last_collect = now`; caller credits Economy).
  - `class_name DailyCrate`: `static func day_of(now: int) -> int` (`now / 86400` UTC days), `static func can_claim(data: Dictionary, now: int) -> bool`, `static func claim(data: Dictionary, retention_defs: Dictionary, now: int) -> Dictionary` (payout dict or `{}` when already claimed today; stamps `last_claim_day`). Spec 5: calendar-day based, no punishing streaks.

- [ ] **Step 1: Write the failing tests**

`tests/test_trickle_model.gd`:

```gdscript
extends GutTest


func make_data(gardens_level: int, last_collect: int) -> Dictionary:
	var data := SaveSchema.default_data(DataDefs.economy)
	if gardens_level > 0:
		data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": gardens_level}
	data["trickle"]["last_collect"] = last_collect
	return data


func test_no_gardens_no_trickle() -> void:
	var data := make_data(0, 0)
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, 999999), 0)

func test_pending_accrues_per_hour_and_caps() -> void:
	var data := make_data(1, 10000)
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, 10000 + 3600), 20, "20/hour at level 1")
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, 10000 + 1800), 10, "half an hour")
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, 10000 + 3600 * 50), 160,
		"capped at 8 hours worth (spec 5: capped, must collect)")

func test_level_scales_rate() -> void:
	var data := make_data(3, 10000)
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, 10000 + 3600), 60)

func test_collect_returns_and_restamps() -> void:
	var data := make_data(1, 10000)
	assert_eq(TrickleModel.collect(data, DataDefs.buildings, 10000 + 3600), 20)
	assert_eq(int(data["trickle"]["last_collect"]), 10000 + 3600)
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, 10000 + 3600), 0)
```

`tests/test_daily_crate.gd`:

```gdscript
extends GutTest


func test_day_of() -> void:
	assert_eq(DailyCrate.day_of(0), 0)
	assert_eq(DailyCrate.day_of(86399), 0)
	assert_eq(DailyCrate.day_of(86400), 1)

func test_claim_once_per_calendar_day() -> void:
	var data := SaveSchema.default_data(DataDefs.economy)
	var now := 86400 * 100 + 500
	assert_true(DailyCrate.can_claim(data, now))
	var payout := DailyCrate.claim(data, DataDefs.retention, now)
	assert_eq(int(payout["scrap"]), 40)
	assert_eq(int(payout["crystals"]), 1)
	assert_false(DailyCrate.can_claim(data, now + 100))
	assert_eq(DailyCrate.claim(data, DataDefs.retention, now + 100), {})
	assert_true(DailyCrate.can_claim(data, now + 86400), "next calendar day, no streak punishment")
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL with parse errors on both classes.

- [ ] **Step 3: Implement**

`game/base/trickle_model.gd`:

```gdscript
class_name TrickleModel
## Gardens & Cisterns idle faucet (spec 4.1, 5): scrap trickles while away,
## capped, must be collected. Lazy math over trickle.last_collect, same
## pattern as FuelModel.


static func pending(data: Dictionary, building_defs: Dictionary, now: int) -> int:
	var level := IslandModel.building_level(data.get("island", {}), "gardens")
	if level <= 0:
		return 0
	var def: Dictionary = (building_defs.get("defs", {}) as Dictionary).get("gardens", {})
	var rate := level * int(def.get("scrap_per_hour_per_level", 20))
	var elapsed_hours := maxf(0.0, float(now - int((data.get("trickle", {}) as Dictionary).get("last_collect", 0))) / 3600.0)
	var capped_hours: float = minf(elapsed_hours, float(def.get("cap_hours", 8.0)))
	return int(floor(capped_hours * float(rate)))


static func collect(data: Dictionary, building_defs: Dictionary, now: int) -> int:
	var amount := pending(data, building_defs, now)
	(data.get("trickle", {}) as Dictionary)["last_collect"] = now
	return amount
```

`game/base/daily_crate.gd`:

```gdscript
class_name DailyCrate
## Daily salvage crate (spec 5): calendar-day based, no punishing streaks.

const SECONDS_PER_DAY := 86400


static func day_of(now: int) -> int:
	@warning_ignore("integer_division")
	return now / SECONDS_PER_DAY


static func can_claim(data: Dictionary, now: int) -> bool:
	return day_of(now) > int((data.get("daily_crate", {}) as Dictionary).get("last_claim_day", 0))


static func claim(data: Dictionary, retention_defs: Dictionary, now: int) -> Dictionary:
	if not can_claim(data, now):
		return {}
	(data.get("daily_crate", {}) as Dictionary)["last_claim_day"] = day_of(now)
	return (retention_defs.get("daily_crate", {}) as Dictionary).duplicate()
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, 7 new tests green, full suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/base/trickle_model.gd game/base/daily_crate.gd tests/test_trickle_model.gd tests/test_daily_crate.gd
git commit -m "feat: add gardens trickle and daily crate lazy-clock models"
```

---

### Task 6: CraftModel (Workshop upgrades gizmos)

**Files:**
- Create: `game/base/craft_model.gd`
- Test: `tests/test_craft_model.gd`

**Interfaces:**
- Consumes: gizmo craft tuning (T2), `building_level` (T3), TimerService/Economy duck-types, `data["gizmos"]["owned"]`.
- Produces (T8/T10 consume): `class_name CraftModel` statics:
  - `static func craft_slots(island: Dictionary) -> int` (== workshop level)
  - `static func active_crafts(timers: Node) -> int` (kind "craft" count)
  - `static func can_craft(data: Dictionary, gizmo_defs: Dictionary, economy: Node, timers: Node, gizmo_id: String) -> bool` (workshop built; slots free; gizmo owned; below `craft_max_level`; no craft of this gizmo already running; affordable)
  - `static func start_craft(data, gizmo_defs, economy, timers, gizmo_id, now) -> bool` (pays `craft_cost`, timer id `"craft_" + gizmo_id` kind "craft" payload `{"gizmo": id}`)
  - `static func complete_craft(data: Dictionary, payload: Dictionary) -> void` (merges the crafted duplicate: `owned[id] += 1`, spec 3.3)

- [ ] **Step 1: Write the failing tests**

`tests/test_craft_model.gd`:

```gdscript
extends GutTest

const TimerServiceScript := preload("res://game/autoload/timer_service.gd")
const EconomyScript := preload("res://game/autoload/economy.gd")
const GameStateScript := preload("res://game/autoload/game_state.gd")

var state
var econ
var timers


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	state.data["currencies"]["scrap"] = 5000
	state.data["currencies"]["cloudsilk"] = 50
	state.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	econ = autofree(EconomyScript.new())
	econ.setup(state)
	timers = autofree(TimerServiceScript.new())
	timers.setup(state)


func test_no_workshop_no_crafting() -> void:
	state.data["island"]["plots"].clear()
	assert_false(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan"))

func test_start_craft_pays_and_starts_timer() -> void:
	assert_true(CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan", 1000))
	assert_eq(econ.balance("scrap"), 5000 - 80)
	assert_eq(timers.remaining("craft_wind_fan", 1000), 120)

func test_complete_craft_merges_into_level() -> void:
	CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan", 1000)
	CraftModel.complete_craft(state.data, timers.collect("craft_wind_fan", 1200))
	assert_eq(int(state.data["gizmos"]["owned"]["wind_fan"]), 2,
		"crafted duplicates merge into upgrades (spec 3.3)")

func test_slots_equal_workshop_level() -> void:
	assert_eq(CraftModel.craft_slots(state.data["island"]), 1)
	CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan", 1000)
	assert_false(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "chime_bell"),
		"level 1 workshop crafts one at a time")
	state.data["island"]["plots"]["plot_0"]["level"] = 2
	assert_true(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "chime_bell"))

func test_craft_max_level_respected() -> void:
	state.data["gizmos"]["owned"]["wind_fan"] = 5
	assert_false(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan"))

func test_unowned_gizmo_cannot_be_crafted() -> void:
	state.data["gizmos"]["owned"].erase("wind_fan")
	assert_false(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan"))
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL with parse errors on `CraftModel`.

- [ ] **Step 3: Implement**

`game/base/craft_model.gd`:

```gdscript
class_name CraftModel
## Workshop crafting (spec 4.1, 3.3): timed crafts of gizmo duplicates that
## merge into levels. Craft slots equal the Workshop's level.


static func craft_slots(island: Dictionary) -> int:
	return IslandModel.building_level(island, "workshop")


static func active_crafts(timers: Node) -> int:
	var count := 0
	for id in timers.active_timers():
		if String((timers.active_timers()[id] as Dictionary).get("kind", "")) == "craft":
			count += 1
	return count


static func can_craft(data: Dictionary, gizmo_defs: Dictionary, economy: Node, timers: Node, gizmo_id: String) -> bool:
	if craft_slots(data.get("island", {})) <= 0:
		return false
	if active_crafts(timers) >= craft_slots(data.get("island", {})):
		return false
	if timers.active_timers().has("craft_" + gizmo_id):
		return false
	var owned: Dictionary = (data.get("gizmos", {}) as Dictionary).get("owned", {})
	if not owned.has(gizmo_id):
		return false
	if int(owned[gizmo_id]) >= int(gizmo_defs.get("craft_max_level", 5)):
		return false
	var def: Dictionary = (gizmo_defs.get("defs", {}) as Dictionary).get(gizmo_id, {})
	return economy.can_afford(def.get("craft_cost", {}))


static func start_craft(data: Dictionary, gizmo_defs: Dictionary, economy: Node, timers: Node, gizmo_id: String, now: int) -> bool:
	if not can_craft(data, gizmo_defs, economy, timers, gizmo_id):
		return false
	var def: Dictionary = (gizmo_defs.get("defs", {}) as Dictionary).get(gizmo_id, {})
	if not economy.pay(def.get("craft_cost", {})):
		return false
	return timers.start("craft_" + gizmo_id, "craft", int(def.get("craft_seconds", 120)), now, {"gizmo": gizmo_id})


static func complete_craft(data: Dictionary, payload: Dictionary) -> void:
	if payload.is_empty():
		return
	var gizmo_id := String(payload.get("gizmo", ""))
	var owned: Dictionary = (data.get("gizmos", {}) as Dictionary).get("owned", {})
	if owned.has(gizmo_id):
		owned[gizmo_id] = int(owned[gizmo_id]) + 1
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, 6 new tests green, full suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/base/craft_model.gd tests/test_craft_model.gd
git commit -m "feat: add CraftModel merging timed gizmo duplicates into levels"
```

---

### Task 7: Island screen (plots and construction)

**Files:**
- Create: `game/base/island_screen.gd`, `game/base/island_screen.tscn`
- Modify: `game/main.gd`, `game/main.tscn` (IslandButton)
- Test: `tests/test_island_screen.gd`, `tests/test_main_boot.gd` (append 1)

**Interfaces:**
- Consumes: `IslandModel` (T3), `IslandEffects.apply_fuel` (T4), `DataDefs.buildings`, `TimerService`/`Economy`/`GameState` autoloads.
- Produces: `res://game/base/island_screen.tscn`: one row per plot (`plot_0` .. `plot_<count-1>`). Row behavior, all rules in the model: empty plot shows a selection button cycling through unbuilt buildings (`_on_select_pressed(plot)`) and a build button (`_on_build_pressed(plot)`, label carries the cost); a constructing plot shows remaining seconds and a Collect button when done (`_on_collect_pressed(plot)`, which routes the payload through `IslandModel.complete_build`, re-applies `IslandEffects.apply_fuel` when the building is wind_still, and saves); a built plot shows level and the upgrade path through the same select/build handlers. Back returns to main and saves. T9 extends this screen with retention controls; the selection state var `_selection: Dictionary` (plot -> building_id) and `_rebuild()` are the extension points.

- [ ] **Step 1: Write the failing tests**

`tests/test_island_screen.gd`:

```gdscript
extends GutTest

const IslandScene := preload("res://game/base/island_screen.tscn")
const TEST_SAVE := "user://test_island_screen.json"

var screen


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	GameState.data["currencies"]["scrap"] = 2000
	GameState.data["created_at"] = 1000
	GameState.data["fuel"]["updated_at"] = 1000
	screen = add_child_autofree(IslandScene.instantiate())
	await wait_physics_frames(1)

func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_island_screen.json", "test_island_screen.json.tmp", "test_island_screen.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings)


func test_builds_one_row_per_plot() -> void:
	assert_eq(screen.get_node("Rows").get_child_count(), int(DataDefs.buildings["plot_count"]))

func test_select_cycles_unbuilt_buildings() -> void:
	screen._on_select_pressed("plot_0")
	assert_eq(String(screen._selection["plot_0"]), "workshop", "first def id")
	screen._on_select_pressed("plot_0")
	assert_eq(String(screen._selection["plot_0"]), "wind_still")

func test_build_starts_construction_through_model() -> void:
	screen._on_select_pressed("plot_0")
	screen._on_build_pressed("plot_0")
	assert_true(TimerService.active_timers().has("build_plot_0"))
	assert_eq(Economy.balance("scrap"), 2000 - 60)

func test_collect_applies_completion_and_reapplies_fuel_effects() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "wind_still", "level": 0}
	TimerService.start("build_plot_0", "construction", 10, 1000, {"plot": "plot_0", "building": "wind_still", "to_level": 1})
	TimerService._state.data["timers"]["build_plot_0"]["ends_at"] = 0
	screen._on_collect_pressed("plot_0")
	assert_eq(IslandModel.building_level(GameState.data["island"], "wind_still"), 1)
	assert_eq(int(GameState.data["fuel"]["cap"]), 6, "wind still completion re-applies fuel effects")

func test_built_building_no_longer_offered_for_empty_plots() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	screen._rebuild()
	screen._on_select_pressed("plot_1")
	assert_ne(String(screen._selection["plot_1"]), "workshop")

func test_built_observatory_shows_its_teaser() -> void:
	GameState.data["island"]["plots"]["plot_3"] = {"building": "observatory", "level": 1}
	var text: String = screen._row_text("plot_3", GameState.data["island"], TimeUtil.now())
	assert_string_contains(text, "Brasswork Reach",
		"spec 4.1: the Observatory reveals upcoming regions")
```

Append to `tests/test_main_boot.gd`:

```gdscript
func test_island_button_exists() -> void:
	assert_not_null(main.get_node_or_null("IslandButton"))
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL (island scene and IslandButton do not exist).

- [ ] **Step 3: Implement**

`game/base/island_screen.gd`:

```gdscript
extends Control
## The home island (spec 4.1): plots, timed construction, upgrades. Dumb UI:
## every rule lives in IslandModel; this screen renders state and forwards
## taps. T9 adds the retention controls (gardens trickle, daily crate,
## second build slot) to this same screen.

var _selection: Dictionary = {}

@onready var rows: VBoxContainer = $Rows


func _ready() -> void:
	$BackButton.pressed.connect(_on_back_pressed)
	$RefreshTimer.timeout.connect(_rebuild)
	_rebuild()


func _plot_ids() -> Array:
	var ids: Array = []
	for i in int(DataDefs.buildings.get("plot_count", 6)):
		ids.append("plot_%d" % i)
	return ids


func _unbuilt_ids() -> Array:
	var ids: Array = []
	for id in DataDefs.buildings.get("defs", {}):
		if IslandModel.building_level(GameState.data["island"], String(id)) == 0 \
				and IslandModel.plot_of(GameState.data["island"], String(id)) == "":
			ids.append(String(id))
	return ids


func _rebuild() -> void:
	for child in rows.get_children():
		child.queue_free()
	var now := TimeUtil.now()
	var island: Dictionary = GameState.data["island"]
	for plot in _plot_ids():
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 64)
		var label := Label.new()
		label.custom_minimum_size = Vector2(320, 0)
		label.text = _row_text(plot, island, now)
		row.add_child(label)
		var timer_id := "build_" + plot
		if TimerService.active_timers().has(timer_id):
			if TimerService.is_done(timer_id, now):
				var collect := Button.new()
				collect.text = "Complete!"
				collect.pressed.connect(_on_collect_pressed.bind(plot))
				row.add_child(collect)
		else:
			var select := Button.new()
			select.text = _selection_text(plot, island)
			select.pressed.connect(_on_select_pressed.bind(plot))
			row.add_child(select)
			var build := Button.new()
			build.text = "Build"
			build.pressed.connect(_on_build_pressed.bind(plot))
			row.add_child(build)
		rows.add_child(row)


func _row_text(plot: String, island: Dictionary, now: int) -> String:
	var timer_id := "build_" + plot
	var plots: Dictionary = island.get("plots", {})
	if TimerService.active_timers().has(timer_id):
		var payload: Dictionary = TimerService.active_timers()[timer_id].get("payload", {})
		var remaining := TimerService.remaining(timer_id, now)
		return "%s: building %s (%ds)" % [plot, String(payload.get("building", "?")), remaining]
	if plots.has(plot):
		var entry: Dictionary = plots[plot]
		var def: Dictionary = (DataDefs.buildings["defs"] as Dictionary).get(String(entry["building"]), {})
		var text := "%s: %s Lv %d" % [plot, String(def.get("name", entry["building"])), int(entry["level"])]
		if String(entry["building"]) == "observatory" and int(entry["level"]) >= 1:
			text += "\n    %s" % String(def.get("teaser", ""))
		return text
	return "%s: (empty)" % plot


func _selection_text(plot: String, island: Dictionary) -> String:
	var plots: Dictionary = island.get("plots", {})
	if plots.has(plot):
		return "Upgrade"
	var chosen := String(_selection.get(plot, ""))
	return chosen if chosen != "" else "Choose..."


func _on_select_pressed(plot: String) -> void:
	var plots: Dictionary = GameState.data["island"]["plots"]
	if plots.has(plot):
		return
	var options := _unbuilt_ids()
	if options.is_empty():
		return
	var current := String(_selection.get(plot, ""))
	var index := options.find(current)
	_selection[plot] = options[(index + 1) % options.size()]
	_rebuild()


func _on_build_pressed(plot: String) -> void:
	var island: Dictionary = GameState.data["island"]
	var building_id: String
	if island["plots"].has(plot):
		building_id = String(island["plots"][plot]["building"])
	else:
		building_id = String(_selection.get(plot, ""))
	if building_id == "":
		return
	if IslandModel.start_build(island, DataDefs.buildings, Economy, TimerService, plot, building_id, TimeUtil.now()):
		GameState.save_game()
	_rebuild()


func _on_collect_pressed(plot: String) -> void:
	var now := TimeUtil.now()
	var payload := TimerService.collect("build_" + plot, now)
	if payload.is_empty():
		return
	IslandModel.complete_build(GameState.data["island"], payload, GameState.data, now)
	if String(payload.get("building", "")) == "wind_still":
		IslandEffects.apply_fuel(GameState.data, DataDefs.economy, DataDefs.buildings)
	GameState.save_game()
	_rebuild()


func _on_back_pressed() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/main.tscn")
```

`game/base/island_screen.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://game/base/island_screen.gd" id="1_is"]

[node name="IslandScreen" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_is")

[node name="Title" type="Label" parent="."]
offset_left = 24.0
offset_top = 24.0
offset_right = 500.0
offset_bottom = 64.0
text = "Home Island"

[node name="Rows" type="VBoxContainer" parent="."]
offset_left = 20.0
offset_top = 90.0
offset_right = 700.0
offset_bottom = 760.0

[node name="RefreshTimer" type="Timer" parent="."]
wait_time = 1.0
autostart = true

[node name="BackButton" type="Button" parent="."]
offset_left = 160.0
offset_top = 1080.0
offset_right = 560.0
offset_bottom = 1160.0
text = "Back"
```

`game/main.gd`: in `_ready`, add `$IslandButton.pressed.connect(_on_island_pressed)` and at the bottom:

```gdscript
func _on_island_pressed() -> void:
	get_tree().change_scene_to_file("res://game/base/island_screen.tscn")
```

`game/main.tscn`: add before GizmosButton:

```
[node name="IslandButton" type="Button" parent="."]
offset_left = 160.0
offset_top = 890.0
offset_right = 560.0
offset_bottom = 960.0
text = "Island"
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, 7 new tests green (6 island + 1 main boot), full suite exit 0. (The collect test manipulates the timer's `ends_at` directly through the injected state, the established pattern for fake clocks on autoloads.)

- [ ] **Step 5: Commit**

```bash
git add game/base/island_screen.gd game/base/island_screen.tscn game/main.gd game/main.tscn tests/test_island_screen.gd tests/test_main_boot.gd
git commit -m "feat: add island screen with plot construction and upgrades"
```

---

### Task 8: Workshop screen (crafting)

**Files:**
- Create: `game/base/workshop_screen.gd`, `game/base/workshop_screen.tscn`
- Modify: `game/base/island_screen.gd`, `game/base/island_screen.tscn` (WorkshopButton)
- Test: `tests/test_workshop_screen.gd`

**Interfaces:**
- Consumes: `CraftModel` (T6), `DataDefs.gizmos`, autoloads.
- Produces: `res://game/base/workshop_screen.tscn`: one row per owned gizmo showing level and a Craft button (`_on_craft_pressed(gizmo_id)`: starts the craft through the model and saves); running crafts show remaining seconds and a Collect button when done (`_on_collect_pressed(gizmo_id)`: routes through `CraftModel.complete_craft`, saves); a slots label ("Crafting 1/2"). Back returns to the island screen. The island screen gains a WorkshopButton (`_on_workshop_pressed` -> scene change), visible always (the screen itself explains when no workshop exists).

- [ ] **Step 1: Write the failing tests**

`tests/test_workshop_screen.gd`:

```gdscript
extends GutTest

const WorkshopScene := preload("res://game/base/workshop_screen.tscn")
const TEST_SAVE := "user://test_workshop_screen.json"

var screen


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	GameState.data["currencies"]["scrap"] = 5000
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	screen = add_child_autofree(WorkshopScene.instantiate())
	await wait_physics_frames(1)

func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_workshop_screen.json", "test_workshop_screen.json.tmp", "test_workshop_screen.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings)


func test_one_row_per_owned_gizmo() -> void:
	assert_eq(screen.get_node("Rows").get_child_count(), 8, "all eight starters owned")

func test_craft_starts_through_model() -> void:
	screen._on_craft_pressed("wind_fan")
	assert_true(TimerService.active_timers().has("craft_wind_fan"))
	assert_eq(Economy.balance("scrap"), 5000 - 80)

func test_collect_merges_level() -> void:
	screen._on_craft_pressed("wind_fan")
	TimerService._state.data["timers"]["craft_wind_fan"]["ends_at"] = 0
	screen._on_collect_pressed("wind_fan")
	assert_eq(int(GameState.data["gizmos"]["owned"]["wind_fan"]), 2)

func test_no_workshop_blocks_crafting() -> void:
	GameState.data["island"]["plots"].clear()
	screen._on_craft_pressed("wind_fan")
	assert_false(TimerService.active_timers().has("craft_wind_fan"))
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL (workshop scene does not exist).

- [ ] **Step 3: Implement**

`game/base/workshop_screen.gd`:

```gdscript
extends Control
## Workshop crafting (spec 4.1): craft duplicates of owned gizmos; a finished
## craft merges into a level (spec 3.3). Dumb UI over CraftModel.

@onready var rows: VBoxContainer = $Rows
@onready var slots_label: Label = $SlotsLabel


func _ready() -> void:
	$BackButton.pressed.connect(_on_back_pressed)
	$RefreshTimer.timeout.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	for child in rows.get_children():
		child.queue_free()
	var now := TimeUtil.now()
	var slots := CraftModel.craft_slots(GameState.data["island"])
	slots_label.text = "Workshop Lv %d: crafting %d/%d" % [slots, CraftModel.active_crafts(TimerService), maxi(slots, 0)] \
		if slots > 0 else "Build a Workshop on the island to craft"
	var owned: Dictionary = GameState.data["gizmos"]["owned"]
	for gizmo_id in owned:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 56)
		var def: Dictionary = (DataDefs.gizmos["defs"] as Dictionary).get(String(gizmo_id), {})
		var label := Label.new()
		label.custom_minimum_size = Vector2(360, 0)
		label.text = "%s Lv %d" % [String(def.get("name", gizmo_id)), int(owned[gizmo_id])]
		row.add_child(label)
		var timer_id := "craft_" + String(gizmo_id)
		if TimerService.active_timers().has(timer_id):
			if TimerService.is_done(timer_id, now):
				var collect := Button.new()
				collect.text = "Collect!"
				collect.pressed.connect(_on_collect_pressed.bind(String(gizmo_id)))
				row.add_child(collect)
			else:
				label.text += "  (%ds)" % TimerService.remaining(timer_id, now)
		else:
			var craft := Button.new()
			craft.text = "Craft"
			craft.pressed.connect(_on_craft_pressed.bind(String(gizmo_id)))
			row.add_child(craft)
		rows.add_child(row)


func _on_craft_pressed(gizmo_id: String) -> void:
	if CraftModel.start_craft(GameState.data, DataDefs.gizmos, Economy, TimerService, gizmo_id, TimeUtil.now()):
		GameState.save_game()
	_rebuild()


func _on_collect_pressed(gizmo_id: String) -> void:
	var payload := TimerService.collect("craft_" + gizmo_id, TimeUtil.now())
	if payload.is_empty():
		return
	CraftModel.complete_craft(GameState.data, payload)
	GameState.save_game()
	_rebuild()


func _on_back_pressed() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/base/island_screen.tscn")
```

`game/base/workshop_screen.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://game/base/workshop_screen.gd" id="1_ws"]

[node name="WorkshopScreen" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_ws")

[node name="SlotsLabel" type="Label" parent="."]
offset_left = 24.0
offset_top = 24.0
offset_right = 660.0
offset_bottom = 64.0
text = "Workshop"

[node name="Rows" type="VBoxContainer" parent="."]
offset_left = 20.0
offset_top = 90.0
offset_right = 700.0
offset_bottom = 900.0

[node name="RefreshTimer" type="Timer" parent="."]
wait_time = 1.0
autostart = true

[node name="BackButton" type="Button" parent="."]
offset_left = 160.0
offset_top = 1080.0
offset_right = 560.0
offset_bottom = 1160.0
text = "Back to Island"
```

`game/base/island_screen.gd`: in `_ready`, add `$WorkshopButton.pressed.connect(_on_workshop_pressed)` and:

```gdscript
func _on_workshop_pressed() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/base/workshop_screen.tscn")
```

`game/base/island_screen.tscn`: add before BackButton:

```
[node name="WorkshopButton" type="Button" parent="."]
offset_left = 160.0
offset_top = 990.0
offset_right = 560.0
offset_bottom = 1060.0
text = "Workshop"
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, 4 new tests green, full suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/base/workshop_screen.gd game/base/workshop_screen.tscn game/base/island_screen.gd game/base/island_screen.tscn tests/test_workshop_screen.gd
git commit -m "feat: add workshop screen crafting gizmo levels"
```

---

### Task 9: Retention controls on the island screen

**Files:**
- Modify: `game/base/island_screen.gd`, `game/base/island_screen.tscn`
- Test: `tests/test_island_screen.gd` (append 3)

**Interfaces:**
- Consumes: `TrickleModel`, `DailyCrate` (T5), `IslandModel.unlock_second_slot` (T3), `DataDefs.retention`.
- Produces: three controls on the island screen: `GardensButton` (`_on_gardens_pressed`: collects pending trickle into Economy scrap, saves; label shows pending), `CrateButton` (`_on_crate_pressed`: claims the daily crate into Economy, saves; disabled when claimed), `SlotButton` (`_on_slot_pressed`: crystal unlock through the model, saves; hidden at max). All three refresh in `_rebuild`.

- [ ] **Step 1: Append the failing tests**

Append to `tests/test_island_screen.gd`:

```gdscript
func test_gardens_collect_credits_scrap() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	GameState.data["trickle"]["last_collect"] = TimeUtil.now() - 3600
	var scrap_before := Economy.balance("scrap")
	screen._on_gardens_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 20)
	assert_eq(TrickleModel.pending(GameState.data, DataDefs.buildings, TimeUtil.now()), 0)

func test_crate_claims_once() -> void:
	GameState.data["daily_crate"]["last_claim_day"] = 0
	var scrap_before := Economy.balance("scrap")
	var crystals_before := Economy.balance("crystals")
	screen._on_crate_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 40)
	assert_eq(Economy.balance("crystals"), crystals_before + 1)
	screen._on_crate_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 40, "second claim same day is a no-op")

func test_slot_button_unlocks_second_slot() -> void:
	GameState.data["currencies"]["crystals"] = 30
	screen._on_slot_pressed()
	assert_eq(int(GameState.data["island"]["build_slots"]), 2)
	assert_eq(Economy.balance("crystals"), 10)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL (handlers do not exist).

- [ ] **Step 3: Implement**

`game/base/island_screen.gd`: in `_ready`, add:

```gdscript
	$GardensButton.pressed.connect(_on_gardens_pressed)
	$CrateButton.pressed.connect(_on_crate_pressed)
	$SlotButton.pressed.connect(_on_slot_pressed)
```

Append to `_rebuild` (at the end):

```gdscript
	var pending := TrickleModel.pending(GameState.data, DataDefs.buildings, now)
	$GardensButton.text = "Collect trickle (%d scrap)" % pending
	$GardensButton.disabled = pending <= 0
	$CrateButton.disabled = not DailyCrate.can_claim(GameState.data, now)
	$CrateButton.text = "Open daily crate" if not $CrateButton.disabled else "Crate opened today"
	var slots_cfg: Dictionary = DataDefs.buildings.get("build_slots", {})
	$SlotButton.visible = int(GameState.data["island"].get("build_slots", 1)) < int(slots_cfg.get("max", 2))
	$SlotButton.text = "Unlock 2nd build slot (%d crystals)" % int(slots_cfg.get("second_slot_crystal_cost", 20))
```

Append the handlers:

```gdscript
func _on_gardens_pressed() -> void:
	var amount := TrickleModel.collect(GameState.data, DataDefs.buildings, TimeUtil.now())
	if amount > 0:
		Economy.add("scrap", amount)
		GameState.save_game()
	_rebuild()


func _on_crate_pressed() -> void:
	var payout := DailyCrate.claim(GameState.data, DataDefs.retention, TimeUtil.now())
	if payout.is_empty():
		return
	for currency in payout:
		Economy.add(currency, int(payout[currency]))
	GameState.save_game()
	_rebuild()


func _on_slot_pressed() -> void:
	if IslandModel.unlock_second_slot(GameState.data["island"], DataDefs.buildings, Economy):
		GameState.save_game()
	_rebuild()
```

`game/base/island_screen.tscn`: add before WorkshopButton:

```
[node name="GardensButton" type="Button" parent="."]
offset_left = 20.0
offset_top = 780.0
offset_right = 350.0
offset_bottom = 840.0
text = "Collect trickle"

[node name="CrateButton" type="Button" parent="."]
offset_left = 370.0
offset_top = 780.0
offset_right = 700.0
offset_bottom = 840.0
text = "Open daily crate"

[node name="SlotButton" type="Button" parent="."]
offset_left = 20.0
offset_top = 860.0
offset_right = 700.0
offset_bottom = 920.0
text = "Unlock 2nd build slot"
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, 3 new tests green, full suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/base/island_screen.gd game/base/island_screen.tscn tests/test_island_screen.gd
git commit -m "feat: add trickle collection, daily crate, and second-slot unlock"
```

---

### Task 10: Fake-clock end-to-end integration

No production code: the whole Loop 1 flywheel proven with fake clocks, no real waiting.

**Files:**
- Test: `tests/test_island_integration.gd`

**Interfaces:**
- Consumes: everything above.
- Produces: recorded evidence of the spec 5 flywheel: build, wait (faked), collect, craft, upgrade, effects feeding runs.

- [ ] **Step 1: Write the tests**

`tests/test_island_integration.gd`:

```gdscript
extends GutTest

const TimerServiceScript := preload("res://game/autoload/timer_service.gd")
const EconomyScript := preload("res://game/autoload/economy.gd")
const GameStateScript := preload("res://game/autoload/game_state.gd")

var state
var econ
var timers


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	state.data["currencies"]["scrap"] = 5000
	state.data["currencies"]["cloudsilk"] = 50
	state.data["currencies"]["crystals"] = 40
	econ = autofree(EconomyScript.new())
	econ.setup(state)
	timers = autofree(TimerServiceScript.new())
	timers.setup(state)


func test_flywheel_build_craft_upgrade_with_fake_clock() -> void:
	var island: Dictionary = state.data["island"]
	var t := 1000
	assert_true(IslandModel.start_build(island, DataDefs.buildings, econ, timers, "plot_0", "workshop", t))
	t += 61
	IslandModel.complete_build(island, timers.collect("build_plot_0", t), state.data, t)
	assert_eq(IslandModel.building_level(island, "workshop"), 1)
	assert_true(CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "splitter_vane", t))
	t += 361
	CraftModel.complete_craft(state.data, timers.collect("craft_splitter_vane", t))
	assert_eq(int(state.data["gizmos"]["owned"]["splitter_vane"]), 2,
		"the flywheel: runs feed the base, the base upgrades the board (spec 5)")

func test_wind_still_completion_raises_effective_fuel() -> void:
	var island: Dictionary = state.data["island"]
	var t := 1000
	IslandModel.start_build(island, DataDefs.buildings, econ, timers, "plot_0", "wind_still", t)
	t += 121
	IslandModel.complete_build(island, timers.collect("build_plot_0", t), state.data, t)
	IslandEffects.apply_fuel(state.data, DataDefs.economy, DataDefs.buildings)
	assert_eq(int(state.data["fuel"]["cap"]), 6)
	assert_eq(int(state.data["fuel"]["regen_seconds"]), 1080)

func test_offline_return_pays_trickle_and_crate_and_regen() -> void:
	var island: Dictionary = state.data["island"]
	var t := 86400 * 50
	IslandModel.start_build(island, DataDefs.buildings, econ, timers, "plot_2", "gardens", t)
	IslandModel.complete_build(island, timers.collect("build_plot_2", t + 121), state.data, t + 121)
	var away_until := t + 121 + 3600 * 10
	assert_eq(TrickleModel.pending(state.data, DataDefs.buildings, away_until), 160,
		"10h away, capped at 8h x 20")
	assert_true(DailyCrate.can_claim(state.data, away_until))
	state.data["fuel"]["amount"] = 0
	state.data["fuel"]["updated_at"] = t
	assert_eq(FuelModel.current(state.data["fuel"], away_until), 5,
		"fuel refilled while away (spec 5 return hooks)")

func test_second_slot_enables_parallel_construction() -> void:
	var island: Dictionary = state.data["island"]
	assert_true(IslandModel.unlock_second_slot(island, DataDefs.buildings, econ))
	assert_true(IslandModel.start_build(island, DataDefs.buildings, econ, timers, "plot_0", "workshop", 1000))
	assert_true(IslandModel.start_build(island, DataDefs.buildings, econ, timers, "plot_1", "gardens", 1000))
	assert_eq(IslandModel.active_constructions(timers, 1000), 2)
```

- [ ] **Step 2: Run and record**

```bash
$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: PASS, 4 new tests green (all fake-clock, sub-second wall time), full suite exit 0.

- [ ] **Step 3: Manual smoke check (skip in a non-interactive environment; note the skip)**

```bash
$GODOT
```

Expected: Island button on main; build a Workshop on a plot (scrap drops, 60s countdown ticks); Complete! applies Lv 1; Workshop screen crafts a duplicate that merges into Lv 2; Wind Still raises fuel to 6/6 on the main readout; Gardens accrue collectable scrap; the daily crate opens once; the crystal unlock allows two simultaneous constructions.

- [ ] **Step 4: Commit**

```bash
git add tests/test_island_integration.gd
git commit -m "test: prove the loop 1 flywheel end to end with fake clocks"
```
