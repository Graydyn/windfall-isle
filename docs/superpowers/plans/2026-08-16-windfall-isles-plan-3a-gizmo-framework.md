# Windfall Isles Plan 3a: Gizmo Framework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the gizmo system's foundation: gizmo inventory in the save (with the project's first real schema migration), the common gizmo scene interface, board installation at the slot anchors, the payout-multiplier pipeline, a pre-run loadout screen, and three archetypal gizmos (Wind Fan, Balloon Cluster, Crystal Prism) proving the passive-force, contact, and payout-mutating archetypes.

**Architecture:** Gizmos are self-contained scenes extending `GizmoBase`, configured entirely from `game/data/gizmos.json`, and installed by `Skyfield.install_gizmos` at the `GizmoSlots` markers that Plan 2 shipped. Inventory and per-region loadout live in `GameState.data["gizmos"]` (schema v2, migrated from v1), manipulated only through pure `GizmoLoadout` statics. Pod-carried effects ride pod metadata (`"value_mult"`) and are resolved centrally by `_compute_payout` in the run scene, so Plan 3b's remaining gizmos are additive scenes plus data.

**Tech Stack:** Godot 4.6.3 (GDScript, Area2D contact zones, `apply_central_force`/`apply_central_impulse`), GUT 9.6.1 headless.

**Spec:** [docs/design/2026-08-15-windfall-isles-design.md](../design/2026-08-15-windfall-isles-design.md) sections 3.3 (gizmos), 7.2 (design rules: gizmo behaviors are self-contained scenes implementing a common trigger interface; tunables in data), 7.3 (versioned schema with per-version migrations). Plans 1-2 are merged on main.

**Follow-on:** Plan 3b adds the remaining five gizmos (Lightning Jar, Chime Bell, Magnet Buoy, Cargo Net, Splitter Vane) plus the run-context methods they need (`add_bonus`, `set_next_barge_multiplier`, `request_split`) and `RunModel.add_split_pod`. Plan 4 (home island) makes the Workshop the gizmo faucet; until then a small starting inventory in gizmos.json makes the system playable.

## Global Constraints

- Engine: Godot 4.6.x pinned; `$GODOT` = `/Applications/Godot-4.6.app/Contents/MacOS/Godot` (4.6.3). Never plain `godot` or `/Applications/Godot.app` (4.7).
- GDScript only; tabs for indentation.
- Every tunable number lives in `game/data/*.json`, never in scripts (spec 7.2). Gizmo behaviors are self-contained scenes implementing a common interface so new gizmos are additive (spec 7.2).
- Save schema: versioned with per-version migration functions (spec 7.3). This plan bumps `SaveSchema.CURRENT_VERSION` from 1 to 2 and ships `_migrate_1_to_2`; existing v1 saves (they exist on real devices, including the project owner's) must migrate losslessly.
- Completely offline; portrait 720x1280; native touch only.
- Canonical test command (must exit 0): `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- Repo conventions (learned in Plans 1-2, all binding):
  - Commit auto-generated `.gd.uid` sidecars with their scripts; scenes get none. After any `--import`, run `git status --porcelain` and confirm no untracked `.gd.uid` remains before committing (this has escaped twice).
  - GUT 9.6 fails tests on undeclared pushed errors; error-path tests declare `assert_push_error_count`/`assert_engine_error_count` AFTER the triggering call.
  - JSON numbers decode as float and Dictionary `==` does not coerce; every read out of JSON-sourced dicts is `int(...)`/`float(...)`-wrapped, and tests assert int-cast scalars, never whole dicts, against JSON-sourced data.
  - Never bind a freeable object into a `SceneTreeTimer` callable with a typed parameter (freed instances fail argument marshalling before the handler runs); scene-owned child `Timer` nodes + `weakref()` bindings are the pattern.
  - GUT's strict warnings reject `:=` inference from untyped Array chains (e.g. `filter().size()`); declare explicit types there.
  - Do NOT state cumulative suite totals; each task names its new tests and requires the full suite to exit 0.
- Commit after every task, conventional-commit messages.

## Interfaces consumed from Plans 1-2 (merged on main, exact)

- `DataDefs`: `economy/run: Dictionary`, `skyfield(region_id) -> Dictionary`, `static load_json(path) -> Dictionary`.
- `SaveSchema`: `CURRENT_VERSION`, `default_data(defs) -> Dictionary`, `migrate(data) -> Dictionary` ({} = unmigratable). This plan extends both signatures with an optional trailing `gizmo_defs: Dictionary = {}` parameter (backward compatible).
- `GameState`: `data`, `load_game(defs, now)` (gains optional trailing `gizmo_defs`), `save_game()`, `_io` injectable.
- `Economy.add/balance/balance_changed`; `FuelModel`; `TimeUtil.now()`.
- `Skyfield`: `build(region_defs, run_defs)`, `signal pod_caught(pod, payout)`, `sea_payout`, containers `Walls/Pegs/Barges/GizmoSlots` with `slot_0..slot_5` Marker2D anchors; the `"caught"` pod-meta one-shot convention.
- `RunModel`, `Pod` (group `"pods"`, `setup(pod_defs)`), `DropController` (`enabled`, `drop_requested`, `configure`), `Geometry.circle_points`.
- `salvage_run.gd` methods: `_on_drop_requested(x)`, `_on_pod_caught(pod, payout)`, `_on_pod_timeout(pod_ref: WeakRef, watchdog: Timer)`, `_on_run_over()`, `_start_watchdog(pod)`.
- Test isolation pattern (from tests/test_salvage_run.gd): swap `GameState._io` to a test path and reassign `GameState.data` in `before_each`; restore `_io` and `load_game` from disk in `after_all`.

## File Structure

```
game/run/salvage_run.gd            # T1 modify (sweep hardening), T4 modify (install wiring), T7 modify (_compute_payout)
game/run/drop_controller.gd        # T1 modify (enabled setter resets aim state)
game/data/gizmos.json              # T2 gizmo defs + starting inventory
game/autoload/data_defs.gd         # T2 modify (gizmos loader)
game/core/save_schema.gd           # T2 modify (v2 + _migrate_1_to_2)
game/autoload/game_state.gd        # T2 modify (optional gizmo_defs pass-through)
game/run/gizmo_loadout.gd          # T3 pure inventory/loadout statics
game/run/gizmos/gizmo_base.gd      # T4 common gizmo interface
game/run/skyfield.gd + .tscn       # T4 modify (Gizmos container + install_gizmos)
game/run/gizmos/wind_fan.gd/.tscn  # T5 passive-force archetype
game/run/gizmos/balloon_cluster.gd/.tscn  # T6 contact archetype
game/run/gizmos/crystal_prism.gd/.tscn    # T7 payout archetype (+ pipeline)
game/ui/loadout_screen.gd/.tscn    # T8 pre-run slotting UI
game/main.gd + main.tscn           # T8 modify (Gizmos button)
tests/fixtures/test_gizmo.gd/.tscn # T4 framework test double
tests/fixtures/test_region_slot.json  # T9 single-slot physics fixture
tests/test_salvage_run.gd          # T1 modify, T4 modify, T7 modify
tests/test_drop_controller.gd      # T1 modify
tests/test_save_schema.gd          # T2 modify
tests/test_gizmo_loadout.gd        # T3
tests/test_skyfield.gd             # T4 modify (install tests)
tests/test_wind_fan.gd             # T5
tests/test_balloon_cluster.gd      # T6
tests/test_crystal_prism.gd        # T7
tests/test_loadout_screen.gd       # T8
tests/test_main_boot.gd            # T8 modify
tests/test_gizmo_integration.gd    # T9
```

---

### Task 1: Plan 2 carry-forward hardening

Two items the Plan 2 final review queued as "first changes of Plan 3".

**Files:**
- Modify: `game/run/salvage_run.gd` (`_on_run_over`)
- Modify: `game/run/drop_controller.gd` (`enabled` becomes a property with a setter)
- Test: `tests/test_salvage_run.gd` (append 1), `tests/test_drop_controller.gd` (append 1)

**Interfaces:**
- Consumes: existing behavior of both files.
- Produces: pods swept at run end carry the `"caught"` meta (closes the same-frame watchdog/abandon race and the late-catch stale-summary window); `DropController.enabled = false` resets `_aiming`/`_touch_index` so re-enabling never resurrects stale aim state. External signatures unchanged.

- [ ] **Step 1: Append the failing tests**

Append to `tests/test_salvage_run.gd`:

```gdscript
func test_run_over_marks_swept_pods_caught() -> void:
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_abandon_pressed()
	assert_true(pod.has_meta("caught"),
		"swept pods must be marked so no catcher or watchdog can resolve them later")
```

Append to `tests/test_drop_controller.gd`:

```gdscript
func test_disabling_resets_aim_state() -> void:
	watch_signals(controller)
	controller._unhandled_input(touch(Vector2(300, 80), true))
	controller.enabled = false
	controller.enabled = true
	controller._unhandled_input(touch(Vector2(500, 90), true, 1))
	controller._unhandled_input(touch(Vector2(500, 90), false, 1))
	assert_signal_emitted_with_parameters(controller, "drop_requested", [500.0],
		"after a disable/enable cycle a new finger (any index) must aim cleanly")
```

Note: the existing `touch()` helper already takes an optional index parameter (added in the Plan 2 multi-touch fix); if its signature is `touch(pos, pressed)` only, extend it with `index := 0` as a third parameter and pass it through to `event.index`.

- [ ] **Step 2: Run tests to verify they fail**

```bash
$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: FAIL. The sweep test fails because `_on_run_over` frees pods without setting the meta; the controller test fails because the stale `_touch_index` from the pre-disable press blocks the index-1 finger.

- [ ] **Step 3: Implement**

In `game/run/salvage_run.gd`, replace the pod sweep inside `_on_run_over`:

```gdscript
	for pod in get_tree().get_nodes_in_group("pods"):
		pod.set_meta("caught", true)
		pod.queue_free()
```

In `game/run/drop_controller.gd`, replace the `var enabled := true` declaration with:

```gdscript
var enabled := true:
	set(value):
		enabled = value
		if not enabled:
			_aiming = false
			_touch_index = -1
		queue_redraw()
```

(If the Plan 2 fix named the tracked-finger variable something other than `_touch_index`, keep that existing name; the reset must clear whatever variable gates the index match.)

- [ ] **Step 4: Run tests to verify they pass**

Same command. Expected: PASS, 2 new tests green, full suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/run/salvage_run.gd game/run/drop_controller.gd tests/test_salvage_run.gd tests/test_drop_controller.gd
git commit -m "fix: mark swept pods caught and reset aim state when the controller disables"
```

---

### Task 2: Gizmo data, schema v2, and the first real migration

**Files:**
- Create: `game/data/gizmos.json`
- Modify: `game/autoload/data_defs.gd`
- Modify: `game/core/save_schema.gd`
- Modify: `game/autoload/game_state.gd`
- Test: `tests/test_save_schema.gd` (modify 1 existing test, append 3)

**Interfaces:**
- Consumes: existing `SaveSchema`/`GameState`/`DataDefs`.
- Produces:
  - `DataDefs.gizmos: Dictionary` with keys `"starting_inventory"` (id -> level) and `"defs"` (id -> {name, scene, per-gizmo tuning}).
  - `SaveSchema.CURRENT_VERSION == 2`; `default_data(defs, gizmo_defs = {})` whose `"gizmos"` value is `{"owned": <starting_inventory duplicate>, "loadout": {}}`; `migrate(data, gizmo_defs = {})` migrating v1 -> v2 via `_migrate_1_to_2` (replaces the old empty `"gizmos"` dict with the v2 structure, granting the starting inventory) and still returning `{}` for version <= 0 or > CURRENT_VERSION.
  - `GameState.load_game(defs, now, gizmo_defs = {})` passing `gizmo_defs` to both `migrate` and `default_data`; `_ready` passes `DataDefs.gizmos`.
  - Save shape consumed by T3/T4/T8: `data["gizmos"] = {"owned": {gizmo_id: level_int}, "loadout": {region_id: {slot_name: gizmo_id}}}`.

- [ ] **Step 1: Write the data file**

`game/data/gizmos.json` (levels are upgrade levels per spec 3.3; `scaled()` in T4 applies +25% per level above 1; scenes for ids beyond this plan land in Plan 3b):

```json
{
	"starting_inventory": {
		"wind_fan": 1,
		"balloon_cluster": 1,
		"crystal_prism": 1
	},
	"defs": {
		"wind_fan": {
			"name": "Wind Fan",
			"scene": "res://game/run/gizmos/wind_fan.tscn",
			"force": 260.0,
			"direction": 1.0,
			"column_width": 90.0,
			"column_height": 420.0
		},
		"balloon_cluster": {
			"name": "Balloon Cluster",
			"scene": "res://game/run/gizmos/balloon_cluster.tscn",
			"impulse": 420.0,
			"max_hits": 3,
			"radius": 26.0
		},
		"crystal_prism": {
			"name": "Crystal Prism",
			"scene": "res://game/run/gizmos/crystal_prism.tscn",
			"multiplier": 1.5,
			"radius": 30.0
		}
	}
}
```

- [ ] **Step 2: Write the failing tests**

In `tests/test_save_schema.gd`, REPLACE the `assert_eq(data["gizmos"], {})` line inside `test_default_data_shape` with:

```gdscript
	assert_eq(data["gizmos"], {"owned": {}, "loadout": {}})
```

Append:

```gdscript
const GIZMO_DEFS := {"starting_inventory": {"wind_fan": 1, "crystal_prism": 1}}


func test_default_data_grants_starting_gizmos() -> void:
	var data := SaveSchema.default_data(DEFS, GIZMO_DEFS)
	assert_eq(data["gizmos"]["owned"], {"wind_fan": 1, "crystal_prism": 1})
	data["gizmos"]["owned"]["wind_fan"] = 5
	assert_eq(int(GIZMO_DEFS["starting_inventory"]["wind_fan"]), 1,
		"granting must not alias the defs")

func test_migrate_v1_to_v2_grants_gizmo_structure() -> void:
	var v1 := SaveSchema.default_data(DEFS)
	v1["version"] = 1
	v1["gizmos"] = {}
	v1["currencies"]["scrap"] = 777
	var migrated := SaveSchema.migrate(v1, GIZMO_DEFS)
	assert_eq(int(migrated["version"]), 2)
	assert_eq(migrated["gizmos"], {"owned": {"wind_fan": 1, "crystal_prism": 1}, "loadout": {}})
	assert_eq(int(migrated["currencies"]["scrap"]), 777, "migration must be lossless")

func test_migrate_v1_without_gizmo_defs_still_structures() -> void:
	var v1 := SaveSchema.default_data(DEFS)
	v1["version"] = 1
	v1["gizmos"] = {}
	var migrated := SaveSchema.migrate(v1)
	assert_eq(migrated["gizmos"], {"owned": {}, "loadout": {}})
```

- [ ] **Step 3: Run tests to verify they fail**

Expected: FAIL. `test_default_data_shape` fails on the new gizmos shape; the migration tests fail because `migrate` takes one argument and CURRENT_VERSION is 1 (a v1 dict passes through unchanged).

- [ ] **Step 4: Implement**

`game/autoload/data_defs.gd`: add below `RUN_PATH`:

```gdscript
const GIZMOS_PATH := "res://game/data/gizmos.json"
```

Add `var gizmos: Dictionary = {}` below `var run`, and extend `_ready`:

```gdscript
func _ready() -> void:
	economy = load_json(ECONOMY_PATH)
	run = load_json(RUN_PATH)
	gizmos = load_json(GIZMOS_PATH)
```

`game/core/save_schema.gd`: set `const CURRENT_VERSION := 2`. Change `default_data` to:

```gdscript
static func default_data(defs: Dictionary, gizmo_defs: Dictionary = {}) -> Dictionary:
```

and its `"gizmos"` entry to:

```gdscript
		"gizmos": _fresh_gizmos(gizmo_defs),
```

Replace `migrate` and add the helpers:

```gdscript
static func migrate(data: Dictionary, gizmo_defs: Dictionary = {}) -> Dictionary:
	var version := int(data.get("version", 0))
	if version <= 0 or version > CURRENT_VERSION:
		return {}
	if version == 1:
		data = _migrate_1_to_2(data, gizmo_defs)
	return data


static func _migrate_1_to_2(data: Dictionary, gizmo_defs: Dictionary) -> Dictionary:
	# v1 shipped "gizmos" as a reserved empty dict; v2 gives it structure and
	# grants the starting inventory so pre-gizmo saves get the same starters
	# a fresh save does.
	data["gizmos"] = _fresh_gizmos(gizmo_defs)
	data["version"] = 2
	return data


static func _fresh_gizmos(gizmo_defs: Dictionary) -> Dictionary:
	return {
		"owned": (gizmo_defs.get("starting_inventory", {}) as Dictionary).duplicate(),
		"loadout": {},
	}
```

`game/autoload/game_state.gd`: change `_ready` and `load_game` to:

```gdscript
func _ready() -> void:
	load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos)


func load_game(defs: Dictionary, now: int, gizmo_defs: Dictionary = {}) -> void:
	var raw := _io.read()
	var migrated: Dictionary = SaveSchema.migrate(raw, gizmo_defs) if not raw.is_empty() else {}
	if migrated.is_empty():
		migrated = SaveSchema.default_data(defs, gizmo_defs)
		migrated["created_at"] = now
		migrated["fuel"]["updated_at"] = now
	data = migrated
	loaded.emit()
```

- [ ] **Step 5: Run tests to verify they pass**

Same command. Expected: PASS, full suite exit 0. Pre-existing tests keep passing because both new parameters are optional with `{}` defaults (empty grants). Note: on the first run after this lands, the real `user://save.json` (v1) migrates to v2 with starters; that is the intended production behavior.

- [ ] **Step 6: Commit**

```bash
git add game/data/gizmos.json game/autoload/data_defs.gd game/core/save_schema.gd game/autoload/game_state.gd tests/test_save_schema.gd
git commit -m "feat: add gizmo defs and save schema v2 with starting-inventory migration"
```

---

### Task 3: GizmoLoadout pure model

**Files:**
- Create: `game/run/gizmo_loadout.gd`
- Test: `tests/test_gizmo_loadout.gd`

**Interfaces:**
- Consumes: the `data["gizmos"]` shape from T2.
- Produces: `class_name GizmoLoadout` statics consumed by T4 (install) and T8 (UI):
  - `static func owned(gizmos_state: Dictionary) -> Dictionary` (id -> level)
  - `static func loadout_for(gizmos_state: Dictionary, region_id: String) -> Dictionary` (slot -> id)
  - `static func set_slot(gizmos_state: Dictionary, region_id: String, slot: String, gizmo_id: String) -> bool` (`""` clears; false when unowned or already slotted in another slot of that region; mutates in place)
  - `static func next_choice(current: String, owned_ids: Array, used_elsewhere: Array) -> String` (cycles `"" -> ids... -> ""` skipping ids used in other slots)

- [ ] **Step 1: Write the failing tests**

`tests/test_gizmo_loadout.gd`:

```gdscript
extends GutTest


func fresh_state() -> Dictionary:
	return {"owned": {"wind_fan": 1, "balloon_cluster": 2}, "loadout": {}}


func test_owned_reads_levels() -> void:
	assert_eq(GizmoLoadout.owned(fresh_state()), {"wind_fan": 1, "balloon_cluster": 2})
	assert_eq(GizmoLoadout.owned({}), {})

func test_set_slot_and_loadout_for() -> void:
	var state := fresh_state()
	assert_true(GizmoLoadout.set_slot(state, "region_1", "slot_0", "wind_fan"))
	assert_eq(GizmoLoadout.loadout_for(state, "region_1"), {"slot_0": "wind_fan"})
	assert_eq(GizmoLoadout.loadout_for(state, "region_2"), {})

func test_set_slot_rejects_unowned() -> void:
	var state := fresh_state()
	assert_false(GizmoLoadout.set_slot(state, "region_1", "slot_0", "chime_bell"))
	assert_eq(GizmoLoadout.loadout_for(state, "region_1"), {})

func test_set_slot_rejects_double_slotting() -> void:
	var state := fresh_state()
	GizmoLoadout.set_slot(state, "region_1", "slot_0", "wind_fan")
	assert_false(GizmoLoadout.set_slot(state, "region_1", "slot_1", "wind_fan"),
		"one owned copy occupies one slot")
	assert_true(GizmoLoadout.set_slot(state, "region_1", "slot_0", "wind_fan"),
		"re-setting the same slot is allowed")

func test_clear_slot() -> void:
	var state := fresh_state()
	GizmoLoadout.set_slot(state, "region_1", "slot_0", "wind_fan")
	assert_true(GizmoLoadout.set_slot(state, "region_1", "slot_0", ""))
	assert_eq(GizmoLoadout.loadout_for(state, "region_1"), {})

func test_next_choice_cycles_and_skips_used() -> void:
	var owned_ids := ["wind_fan", "balloon_cluster", "crystal_prism"]
	assert_eq(GizmoLoadout.next_choice("", owned_ids, []), "wind_fan")
	assert_eq(GizmoLoadout.next_choice("wind_fan", owned_ids, []), "balloon_cluster")
	assert_eq(GizmoLoadout.next_choice("crystal_prism", owned_ids, []), "")
	assert_eq(GizmoLoadout.next_choice("", owned_ids, ["wind_fan"]), "balloon_cluster",
		"ids used in other slots are skipped")
	assert_eq(GizmoLoadout.next_choice("wind_fan", owned_ids, ["balloon_cluster", "crystal_prism"]), "",
		"current id cycles out even when everything else is used")
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL with parse errors on `GizmoLoadout`.

- [ ] **Step 3: Implement**

`game/run/gizmo_loadout.gd`:

```gdscript
class_name GizmoLoadout
## Pure helpers over GameState.data["gizmos"] (schema v2): who owns what and
## which gizmo sits in which skyfield slot (spec 3.3: owned permanently,
## slotted by the player). All functions mutate/read the passed dict in place;
## persistence stays GameState's job.


static func owned(gizmos_state: Dictionary) -> Dictionary:
	return gizmos_state.get("owned", {})


static func loadout_for(gizmos_state: Dictionary, region_id: String) -> Dictionary:
	return (gizmos_state.get("loadout", {}) as Dictionary).get(region_id, {})


static func set_slot(gizmos_state: Dictionary, region_id: String, slot: String, gizmo_id: String) -> bool:
	if gizmo_id != "" and not owned(gizmos_state).has(gizmo_id):
		return false
	if not gizmos_state.has("loadout"):
		gizmos_state["loadout"] = {}
	var all_regions: Dictionary = gizmos_state["loadout"]
	if not all_regions.has(region_id):
		all_regions[region_id] = {}
	var region: Dictionary = all_regions[region_id]
	if gizmo_id == "":
		region.erase(slot)
		return true
	for other_slot in region:
		if other_slot != slot and region[other_slot] == gizmo_id:
			return false
	region[slot] = gizmo_id
	return true


static func next_choice(current: String, owned_ids: Array, used_elsewhere: Array) -> String:
	var options: Array = [""]
	for id in owned_ids:
		if id == current or not used_elsewhere.has(id):
			options.append(id)
	var index := options.find(current)
	return options[(index + 1) % options.size()]
```

- [ ] **Step 4: Run tests to verify they pass**

Same command. Expected: PASS, 6 new tests green, full suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/run/gizmo_loadout.gd tests/test_gizmo_loadout.gd
git commit -m "feat: add GizmoLoadout pure inventory and slotting model"
```

---

### Task 4: GizmoBase interface and board installation

**Files:**
- Create: `game/run/gizmos/gizmo_base.gd`
- Create: `tests/fixtures/test_gizmo.gd`
- Create: `tests/fixtures/test_gizmo.tscn`
- Modify: `game/run/skyfield.gd` and `game/run/skyfield.tscn` (Gizmos container + `install_gizmos`)
- Modify: `game/run/salvage_run.gd` (`_ready` installs the loadout)
- Test: `tests/test_skyfield.gd` (append 3), `tests/test_salvage_run.gd` (append 1)

**Interfaces:**
- Consumes: `GizmoLoadout` (T3), `DataDefs.gizmos` shape (T2), `GizmoSlots` markers (Plan 2).
- Produces:
  - `class_name GizmoBase extends Node2D`: `var defs: Dictionary`, `var level: int`, `var context: Node`; `func setup(gizmo_defs: Dictionary, gizmo_level: int, run_context: Node) -> void` (stores all three, then calls `_configure()`); `func _configure() -> void` (override point); `func scaled(base: float) -> float` returning `base * (1.0 + 0.25 * float(level - 1))`. The context duck-type contract (documented in the class comment; methods land in Plan 3b): `add_bonus(payout: Dictionary)`, `set_next_barge_multiplier(factor: float)`, `request_split(pod: RigidBody2D) -> bool`. T5/T6/T7 gizmos extend this; Plan 3b's five more do too.
  - `Skyfield.install_gizmos(loadout: Dictionary, gizmo_defs: Dictionary, owned: Dictionary, context: Node) -> void`: instantiates each slotted gizmo's scene at its marker position under the `Gizmos` container; skips (with `push_warning`) unknown ids, missing markers, and unloadable scenes.
  - `salvage_run._ready` installs `GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1")` with `self` as context, right after `board.build(...)`.

- [ ] **Step 1: Write the fixture double and the failing tests**

`tests/fixtures/test_gizmo.gd`:

```gdscript
extends GizmoBase
## Framework test double: records what setup gave it.

var configured := false


func _configure() -> void:
	configured = true
```

`tests/fixtures/test_gizmo.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/fixtures/test_gizmo.gd" id="1_tg"]

[node name="TestGizmo" type="Node2D"]
script = ExtResource("1_tg")
```

Append to `tests/test_skyfield.gd`:

```gdscript
const TEST_GIZMO_DEFS := {
	"defs": {
		"test_gizmo": {"name": "Test Gizmo", "scene": "res://tests/fixtures/test_gizmo.tscn", "power": 10.0}
	}
}


func test_install_gizmos_places_scene_at_marker() -> void:
	var board := build_board(DataDefs.skyfield("region_1"))
	board.install_gizmos({"slot_1": "test_gizmo"}, TEST_GIZMO_DEFS, {"test_gizmo": 3}, self)
	var gizmos: Node = board.get_node("Gizmos")
	assert_eq(gizmos.get_child_count(), 1)
	var gizmo: GizmoBase = gizmos.get_child(0)
	assert_eq(gizmo.position, board.get_node("GizmoSlots/slot_1").position)
	assert_eq(gizmo.level, 3)
	assert_eq(float(gizmo.defs["power"]), 10.0)
	assert_true(gizmo.context == self)
	assert_true(gizmo.configured, "_configure must run during setup")

func test_install_gizmos_skips_unknown_entries() -> void:
	var board := build_board(DataDefs.skyfield("region_1"))
	board.install_gizmos(
		{"slot_0": "no_such_gizmo", "slot_99": "test_gizmo", "slot_2": "test_gizmo"},
		TEST_GIZMO_DEFS, {"test_gizmo": 1}, self)
	assert_eq(board.get_node("Gizmos").get_child_count(), 1, "only the valid entry installs")

func test_gizmo_base_scaled() -> void:
	var gizmo: GizmoBase = autofree(GizmoBase.new())
	gizmo.level = 1
	assert_almost_eq(gizmo.scaled(100.0), 100.0, 0.001)
	gizmo.level = 3
	assert_almost_eq(gizmo.scaled(100.0), 150.0, 0.001)
```

Two changes in `tests/test_salvage_run.gd`. First, update `before_each` so the fresh defaults grant the real starting inventory (needed by this task's test and by T7's):

```gdscript
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
```

Second, append this test. It uses the fixture double rather than a real gizmo because the wind_fan scene does not exist until T5; the temporary def injected into the shared `DataDefs.gizmos` autoload is erased on the last line to restore it (GUT continues past failed asserts, so the erase always runs):

```gdscript
func test_ready_installs_loadout_gizmos() -> void:
	GameState.data["gizmos"]["owned"]["test_gizmo"] = 1
	DataDefs.gizmos["defs"]["test_gizmo"] = {"name": "Test Gizmo", "scene": "res://tests/fixtures/test_gizmo.tscn"}
	GizmoLoadout.set_slot(GameState.data["gizmos"], "region_1", "slot_0", "test_gizmo")
	var second = add_child_autofree(RunScene.instantiate())
	assert_eq(second.get_node("Skyfield/Gizmos").get_child_count(), 1,
		"the run scene installs the persisted loadout at boot")
	DataDefs.gizmos["defs"].erase("test_gizmo")
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL (`GizmoBase` and `install_gizmos` do not exist; the fixture scene cannot even parse until GizmoBase exists).

- [ ] **Step 3: Implement**

`game/run/gizmos/gizmo_base.gd`:

```gdscript
class_name GizmoBase
extends Node2D
## Common interface for all gizmos (spec 3.3, 7.2): self-contained scenes,
## configured from game/data/gizmos.json, installed at skyfield slot markers.
## `context` is the run scene; the duck-type methods gizmos may call on it
## (landing in Plan 3b) are:
##   add_bonus(payout: Dictionary) -> void
##   set_next_barge_multiplier(factor: float) -> void
##   request_split(pod: RigidBody2D) -> bool
## Pod-carried effects use pod metadata; "value_mult" (float) multiplies the
## pod's payouts at resolution.

var defs: Dictionary = {}
var level: int = 1
var context: Node = null


func setup(gizmo_defs: Dictionary, gizmo_level: int, run_context: Node) -> void:
	defs = gizmo_defs
	level = gizmo_level
	context = run_context
	_configure()


func _configure() -> void:
	pass


func scaled(base: float) -> float:
	# Upgrade levels (crafted duplicates merge, spec 3.3): +25% per level.
	return base * (1.0 + 0.25 * float(level - 1))
```

`game/run/skyfield.tscn`: add a container node after `GizmoSlots`:

```
[node name="Gizmos" type="Node2D" parent="."]
```

`game/run/skyfield.gd`: append:

```gdscript
func install_gizmos(loadout: Dictionary, gizmo_defs: Dictionary, owned: Dictionary, context: Node) -> void:
	var defs_by_id: Dictionary = gizmo_defs.get("defs", {})
	for slot in loadout:
		var gizmo_id: String = String(loadout[slot])
		var marker: Marker2D = $GizmoSlots.get_node_or_null(NodePath(slot))
		var def: Dictionary = defs_by_id.get(gizmo_id, {})
		var scene_path := String(def.get("scene", ""))
		if marker == null or def.is_empty() or not ResourceLoader.exists(scene_path):
			push_warning("Skipping gizmo '%s' in slot '%s' (unknown id, slot, or scene)" % [gizmo_id, slot])
			continue
		var gizmo: GizmoBase = (load(scene_path) as PackedScene).instantiate()
		gizmo.position = marker.position
		$Gizmos.add_child(gizmo)
		gizmo.setup(def, int(owned.get(gizmo_id, 1)), context)
```

`game/run/salvage_run.gd`: in `_ready`, immediately after `board.build(region, run_defs)`, insert:

```gdscript
	var gizmos_state: Dictionary = GameState.data["gizmos"]
	board.install_gizmos(
		GizmoLoadout.loadout_for(gizmos_state, "region_1"),
		DataDefs.gizmos,
		GizmoLoadout.owned(gizmos_state),
		self)
```

- [ ] **Step 4: Run tests to verify they pass**

Same command. Expected: PASS, 4 new tests green (the two skip warnings in the skip test are expected `push_warning` output, which GUT does not fail on), full suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/run/gizmos/gizmo_base.gd tests/fixtures/test_gizmo.gd tests/fixtures/test_gizmo.tscn game/run/skyfield.gd game/run/skyfield.tscn game/run/salvage_run.gd tests/test_skyfield.gd tests/test_salvage_run.gd
git commit -m "feat: add GizmoBase interface and data-driven board installation"
```

---

### Task 5: Wind Fan (passive-force archetype)

**Files:**
- Create: `game/run/gizmos/wind_fan.gd`
- Create: `game/run/gizmos/wind_fan.tscn`
- Test: `tests/test_wind_fan.gd`

**Interfaces:**
- Consumes: `GizmoBase` (T4), wind_fan defs shape (T2).
- Produces: `res://game/run/gizmos/wind_fan.tscn`, spec 3.3 "applies steady lateral push in its column". The column is a rect zone extending upward from the fan; every physics frame, overlapping RigidBody2D bodies receive `apply_central_force(Vector2(force * direction, 0))`, `force` level-scaled.

- [ ] **Step 1: Write the failing tests**

`tests/test_wind_fan.gd`:

```gdscript
extends GutTest

const WindFanScene := preload("res://game/run/gizmos/wind_fan.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var fan_defs: Dictionary


func before_each() -> void:
	fan_defs = (DataDefs.gizmos["defs"]["wind_fan"] as Dictionary).duplicate()


func test_configure_builds_column_from_defs() -> void:
	var fan := add_child_autofree(WindFanScene.instantiate())
	fan.setup(fan_defs, 1, self)
	var shape: RectangleShape2D = fan.get_node("Zone/Shape").shape
	assert_almost_eq(shape.size.x, 90.0, 0.001)
	assert_almost_eq(shape.size.y, 420.0, 0.001)

func test_pod_in_column_gains_lateral_velocity() -> void:
	var fan := add_child_autofree(WindFanScene.instantiate())
	fan.position = Vector2(360, 600)
	fan.setup(fan_defs, 1, self)
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	pod.position = Vector2(360, 250)
	pod.setup({"radius": 12.0, "bounce": 0.55, "friction": 0.2})
	await wait_seconds(0.5)
	assert_true(pod.linear_velocity.x > 10.0,
		"a pod falling through the column must be pushed in +x (direction 1)")

func test_level_scales_force() -> void:
	var fan := add_child_autofree(WindFanScene.instantiate())
	fan.setup(fan_defs, 3, self)
	assert_almost_eq(fan._force_vector.x, 260.0 * 1.5, 0.001)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL (wind_fan scene does not exist).

- [ ] **Step 3: Implement**

`game/run/gizmos/wind_fan.gd`:

```gdscript
extends GizmoBase
## Wind Fan (spec 3.3): steady lateral push on any pod inside its column.

var _force_vector := Vector2.ZERO

@onready var zone: Area2D = $Zone


func _configure() -> void:
	var force := scaled(float(defs.get("force", 260.0)))
	_force_vector = Vector2(force * float(defs.get("direction", 1.0)), 0.0)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(float(defs.get("column_width", 90.0)), float(defs.get("column_height", 420.0)))
	$Zone/Shape.shape = rect
	zone.position = Vector2(0.0, -rect.size.y / 2.0)
	var visual: Polygon2D = $Visual
	visual.polygon = PackedVector2Array([
		Vector2(-22, -12), Vector2(22, -12), Vector2(22, 12), Vector2(-22, 12),
	])
	visual.color = Color(0.6, 0.8, 0.95)


func _physics_process(_delta: float) -> void:
	for body in zone.get_overlapping_bodies():
		if body is RigidBody2D:
			body.apply_central_force(_force_vector)
```

`game/run/gizmos/wind_fan.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://game/run/gizmos/wind_fan.gd" id="1_wf"]

[node name="WindFan" type="Node2D"]
script = ExtResource("1_wf")

[node name="Zone" type="Area2D" parent="."]

[node name="Shape" type="CollisionShape2D" parent="Zone"]

[node name="Visual" type="Polygon2D" parent="."]
```

- [ ] **Step 4: Run tests to verify they pass**

Same command. Expected: PASS, 3 new tests green (the physics test takes ~0.5s), full suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/run/gizmos/wind_fan.gd game/run/gizmos/wind_fan.tscn tests/test_wind_fan.gd
git commit -m "feat: add Wind Fan gizmo with data-driven lateral force column"
```

---

### Task 6: Balloon Cluster (contact archetype)

**Files:**
- Create: `game/run/gizmos/balloon_cluster.gd`
- Create: `game/run/gizmos/balloon_cluster.tscn`
- Test: `tests/test_balloon_cluster.gd`

**Interfaces:**
- Consumes: `GizmoBase`, balloon defs shape (T2), `Geometry.circle_points`.
- Produces: spec 3.3 "bounces the pod sharply upward; pops after N hits per run": Area2D zone; on RigidBody2D contact, zeroes vertical velocity and applies an upward impulse (level-scaled); after `max_hits` contacts it deflates (visual alpha 0.25) and stops monitoring.

- [ ] **Step 1: Write the failing tests**

`tests/test_balloon_cluster.gd`:

```gdscript
extends GutTest

const BalloonScene := preload("res://game/run/gizmos/balloon_cluster.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var balloon
var balloon_defs: Dictionary


func before_each() -> void:
	balloon_defs = (DataDefs.gizmos["defs"]["balloon_cluster"] as Dictionary).duplicate()
	balloon = add_child_autofree(BalloonScene.instantiate())
	balloon.setup(balloon_defs, 1, self)


func make_falling_pod() -> Pod:
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	pod.setup({"radius": 12.0, "bounce": 0.55, "friction": 0.2})
	pod.linear_velocity = Vector2(0, 300)
	return pod


func test_contact_bounces_pod_upward() -> void:
	var pod := make_falling_pod()
	balloon._on_body_entered(pod)
	assert_true(pod.linear_velocity.y < 0.0, "pod must be moving up after the bounce")

func test_pops_after_max_hits() -> void:
	for i in int(balloon_defs["max_hits"]):
		balloon._on_body_entered(make_falling_pod())
	assert_eq(balloon._hits_left, 0)
	var late_pod := make_falling_pod()
	balloon._on_body_entered(late_pod)
	assert_true(late_pod.linear_velocity.y > 0.0, "a popped balloon must not bounce")
	assert_almost_eq(balloon.get_node("Visual").modulate.a, 0.25, 0.001)

func test_level_scales_impulse() -> void:
	var strong = add_child_autofree(BalloonScene.instantiate())
	strong.setup(balloon_defs, 2, self)
	assert_almost_eq(strong._impulse, 420.0 * 1.25, 0.001)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL (balloon scene does not exist).

- [ ] **Step 3: Implement**

`game/run/gizmos/balloon_cluster.gd`:

```gdscript
extends GizmoBase
## Balloon Cluster (spec 3.3): bounces the pod sharply upward; pops after N
## hits per run. Gizmos are re-instantiated per expedition, so hits reset
## naturally each run.

var _hits_left := 0
var _impulse := 0.0

@onready var zone: Area2D = $Zone


func _configure() -> void:
	_impulse = scaled(float(defs.get("impulse", 420.0)))
	_hits_left = int(defs.get("max_hits", 3))
	var circle := CircleShape2D.new()
	circle.radius = float(defs.get("radius", 26.0))
	$Zone/Shape.shape = circle
	var visual: Polygon2D = $Visual
	visual.polygon = Geometry.circle_points(circle.radius)
	visual.color = Color(0.95, 0.5, 0.55)
	zone.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _hits_left <= 0 or not (body is RigidBody2D):
		return
	_hits_left -= 1
	body.linear_velocity = Vector2(body.linear_velocity.x, 0.0)
	body.apply_central_impulse(Vector2(0.0, -_impulse))
	if _hits_left <= 0:
		$Visual.modulate.a = 0.25
		zone.set_deferred("monitoring", false)
```

`game/run/gizmos/balloon_cluster.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://game/run/gizmos/balloon_cluster.gd" id="1_bc"]

[node name="BalloonCluster" type="Node2D"]
script = ExtResource("1_bc")

[node name="Zone" type="Area2D" parent="."]

[node name="Shape" type="CollisionShape2D" parent="Zone"]

[node name="Visual" type="Polygon2D" parent="."]
```

- [ ] **Step 4: Run tests to verify they pass**

Same command. Expected: PASS, 3 new tests green, full suite exit 0. (The impulse math: a fresh pod falling at +300 gets vertical velocity zeroed then `-_impulse / mass` applied; default RigidBody2D mass is 1, so it moves up. The popped-balloon test's pod keeps its +300 downward velocity.)

- [ ] **Step 5: Commit**

```bash
git add game/run/gizmos/balloon_cluster.gd game/run/gizmos/balloon_cluster.tscn tests/test_balloon_cluster.gd
git commit -m "feat: add Balloon Cluster gizmo with limited upward bounces"
```

---

### Task 7: Crystal Prism and the payout pipeline

**Files:**
- Create: `game/run/gizmos/crystal_prism.gd`
- Create: `game/run/gizmos/crystal_prism.tscn`
- Modify: `game/run/salvage_run.gd` (`_compute_payout`, applied in `_on_pod_caught`)
- Test: `tests/test_crystal_prism.gd`, `tests/test_salvage_run.gd` (append 2)

**Interfaces:**
- Consumes: `GizmoBase`, prism defs (T2), the pod-meta convention from T4's GizmoBase doc.
- Produces:
  - Prism: spec 3.3 "multiplies the value of everything the pod collects below it": on contact, multiplies the pod's `"value_mult"` meta by the (level-scaled) multiplier, once per pod per prism instance (per-instance meta guard `"prism_<instance_id>"`).
  - `salvage_run._compute_payout(pod: Node, base: Dictionary) -> Dictionary`: applies the pod's `"value_mult"` meta (default 1.0) to every currency with `roundi`, dropping zero results; `_on_pod_caught` passes every payout (barge, sea, timeout) through it before crediting. Plan 3b's Chime Bell extends this same function with the next-barge multiplier.

- [ ] **Step 1: Write the failing tests**

`tests/test_crystal_prism.gd`:

```gdscript
extends GutTest

const PrismScene := preload("res://game/run/gizmos/crystal_prism.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var prism
var prism_defs: Dictionary


func before_each() -> void:
	prism_defs = (DataDefs.gizmos["defs"]["crystal_prism"] as Dictionary).duplicate()
	prism = add_child_autofree(PrismScene.instantiate())
	prism.setup(prism_defs, 1, self)


func test_contact_multiplies_pod_value_meta() -> void:
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	prism._on_body_entered(pod)
	assert_almost_eq(float(pod.get_meta("value_mult")), 1.5, 0.001)

func test_same_prism_applies_once_per_pod() -> void:
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	prism._on_body_entered(pod)
	prism._on_body_entered(pod)
	assert_almost_eq(float(pod.get_meta("value_mult")), 1.5, 0.001)

func test_two_prisms_stack() -> void:
	var second = add_child_autofree(PrismScene.instantiate())
	second.setup(prism_defs, 1, self)
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	prism._on_body_entered(pod)
	second._on_body_entered(pod)
	assert_almost_eq(float(pod.get_meta("value_mult")), 2.25, 0.001)
```

Append to `tests/test_salvage_run.gd`:

```gdscript
func test_compute_payout_applies_pod_value_mult() -> void:
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	pod.set_meta("value_mult", 1.5)
	assert_eq(scene._compute_payout(pod, {"scrap": 2, "cloudsilk": 1}), {"scrap": 3, "cloudsilk": 2})

func test_catch_credits_multiplied_payout() -> void:
	var scrap_before := Economy.balance("scrap")
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	pod.set_meta("value_mult", 2.0)
	scene._on_pod_caught(pod, {"scrap": 5})
	assert_eq(Economy.balance("scrap"), scrap_before + 10)
	assert_eq(scene.model.loot, {"scrap": 10}, "the model banks the multiplied value too")
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL (prism scene and `_compute_payout` do not exist).

- [ ] **Step 3: Implement**

`game/run/gizmos/crystal_prism.gd`:

```gdscript
extends GizmoBase
## Crystal Prism (spec 3.3): multiplies the value of everything the pod
## collects below it. Implemented as a pod-carried multiplier consumed by the
## run scene's _compute_payout at resolution. Applies once per pod per prism.

var _multiplier := 1.5

@onready var zone: Area2D = $Zone


func _configure() -> void:
	_multiplier = scaled(float(defs.get("multiplier", 1.5)))
	var circle := CircleShape2D.new()
	circle.radius = float(defs.get("radius", 30.0))
	$Zone/Shape.shape = circle
	var visual: Polygon2D = $Visual
	visual.polygon = PackedVector2Array([Vector2(0, -34), Vector2(30, 20), Vector2(-30, 20)])
	visual.color = Color(0.75, 0.6, 0.95, 0.85)
	zone.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not (body is RigidBody2D):
		return
	var guard := "prism_%d" % get_instance_id()
	if body.has_meta(guard):
		return
	body.set_meta(guard, true)
	body.set_meta("value_mult", float(body.get_meta("value_mult", 1.0)) * _multiplier)
```

`game/run/gizmos/crystal_prism.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://game/run/gizmos/crystal_prism.gd" id="1_cp"]

[node name="CrystalPrism" type="Node2D"]
script = ExtResource("1_cp")

[node name="Zone" type="Area2D" parent="."]

[node name="Shape" type="CollisionShape2D" parent="Zone"]

[node name="Visual" type="Polygon2D" parent="."]
```

`game/run/salvage_run.gd`: add above `_refresh_hud`:

```gdscript
func _compute_payout(pod: Node, base: Dictionary) -> Dictionary:
	# Central payout resolution: pod-carried multipliers (Crystal Prism,
	# Splitter Vane) apply here so every catch path (barge, sea, watchdog)
	# gets identical treatment. Plan 3b adds the next-barge multiplier.
	var mult := 1.0
	if is_instance_valid(pod) and pod.has_meta("value_mult"):
		mult = float(pod.get_meta("value_mult"))
	if is_equal_approx(mult, 1.0):
		return base.duplicate()
	var out := {}
	for currency in base:
		var value := roundi(float(base[currency]) * mult)
		if value > 0:
			out[currency] = value
	return out
```

In `_on_pod_caught`, insert as the FIRST line of the function body:

```gdscript
	payout = _compute_payout(pod, payout)
```

(The parameter is reassigned before the pod is freed, so the meta read happens while the pod is still valid.)

- [ ] **Step 4: Run tests to verify they pass**

Same command. Expected: PASS, 5 new tests green, full suite exit 0. (Existing catch/timeout tests keep passing: pods without the meta hit the `mult == 1.0` fast path.)

- [ ] **Step 5: Commit**

```bash
git add game/run/gizmos/crystal_prism.gd game/run/gizmos/crystal_prism.tscn game/run/salvage_run.gd tests/test_crystal_prism.gd tests/test_salvage_run.gd
git commit -m "feat: add Crystal Prism gizmo and central payout multiplier pipeline"
```

---

### Task 8: Loadout screen

**Files:**
- Create: `game/ui/loadout_screen.gd`
- Create: `game/ui/loadout_screen.tscn`
- Modify: `game/main.gd` and `game/main.tscn` (Gizmos button)
- Test: `tests/test_loadout_screen.gd`, `tests/test_main_boot.gd` (append 1)

**Interfaces:**
- Consumes: `GizmoLoadout` (T3), `DataDefs.gizmos` / `DataDefs.skyfield` (T2), `GameState.data["gizmos"]`, `GameState.save_game`.
- Produces: `res://game/ui/loadout_screen.tscn`: one tappable row per region slot cycling `empty -> owned gizmos (not used in another slot) -> empty`; every change writes through `GizmoLoadout.set_slot`; Back saves and returns to main. `game/main.tscn` gains `GizmosButton` navigating to the screen. Spec 3.2/3.3: gizmos are installed before/between runs, placement is the skill expression.

- [ ] **Step 1: Write the failing tests**

`tests/test_loadout_screen.gd`:

```gdscript
extends GutTest

const LoadoutScene := preload("res://game/ui/loadout_screen.tscn")
const TEST_SAVE := "user://test_loadout.json"

var screen


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	screen = add_child_autofree(LoadoutScene.instantiate())
	await wait_frames(1)

func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_loadout.json", "test_loadout.json.tmp", "test_loadout.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos)


func test_builds_one_row_per_region_slot() -> void:
	assert_eq(screen.get_node("Rows").get_child_count(), 6, "region_1 has 6 gizmo slots")

func test_tapping_a_row_cycles_the_slot() -> void:
	screen._on_slot_pressed("slot_0")
	var loadout := GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1")
	assert_true(loadout.has("slot_0"))
	assert_true(GizmoLoadout.owned(GameState.data["gizmos"]).has(loadout["slot_0"]))

func test_cycling_past_all_options_returns_to_empty() -> void:
	var owned_count: int = GizmoLoadout.owned(GameState.data["gizmos"]).size()
	for i in owned_count + 1:
		screen._on_slot_pressed("slot_0")
	assert_eq(GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1"), {},
		"one full cycle lands back on empty")

func test_same_gizmo_cannot_occupy_two_slots() -> void:
	screen._on_slot_pressed("slot_0")
	var first: String = GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1")["slot_0"]
	screen._on_slot_pressed("slot_1")
	var second: String = GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1").get("slot_1", "")
	assert_ne(first, second, "slot_1's first option skips what slot_0 holds")
```

Append to `tests/test_main_boot.gd`:

```gdscript
func test_gizmos_button_exists() -> void:
	assert_not_null(main.get_node_or_null("GizmosButton"))
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL (loadout scene and GizmosButton do not exist).

- [ ] **Step 3: Implement**

`game/ui/loadout_screen.gd`:

```gdscript
extends Control
## Pre-run gizmo slotting (spec 3.3): one row per skyfield slot; tapping a
## row cycles through the owned gizmos not already used in another slot.
## Placement is the player's skill expression, so this screen stays dumb:
## all rules live in GizmoLoadout.

var region_id := "region_1"

var _slots: Array = []

@onready var rows: VBoxContainer = $Rows


func _ready() -> void:
	var region: Dictionary = DataDefs.skyfield(region_id)
	_slots = []
	for i in (region.get("gizmo_slots", []) as Array).size():
		_slots.append("slot_%d" % i)
	$BackButton.pressed.connect(_on_back_pressed)
	_rebuild()


func _rebuild() -> void:
	for child in rows.get_children():
		child.queue_free()
	var loadout := GizmoLoadout.loadout_for(GameState.data["gizmos"], region_id)
	for slot in _slots:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 72)
		button.text = _row_text(slot, String(loadout.get(slot, "")))
		button.pressed.connect(_on_slot_pressed.bind(slot))
		rows.add_child(button)


func _row_text(slot: String, gizmo_id: String) -> String:
	if gizmo_id == "":
		return "%s: (empty)" % slot
	var def: Dictionary = (DataDefs.gizmos.get("defs", {}) as Dictionary).get(gizmo_id, {})
	var level := int(GizmoLoadout.owned(GameState.data["gizmos"]).get(gizmo_id, 1))
	return "%s: %s (Lv %d)" % [slot, String(def.get("name", gizmo_id)), level]


func _on_slot_pressed(slot: String) -> void:
	var gizmos_state: Dictionary = GameState.data["gizmos"]
	var loadout := GizmoLoadout.loadout_for(gizmos_state, region_id)
	var used: Array = []
	for other_slot in loadout:
		if other_slot != slot:
			used.append(loadout[other_slot])
	var next := GizmoLoadout.next_choice(String(loadout.get(slot, "")), GizmoLoadout.owned(gizmos_state).keys(), used)
	GizmoLoadout.set_slot(gizmos_state, region_id, slot, next)
	_rebuild()


func _on_back_pressed() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/main.tscn")
```

`game/ui/loadout_screen.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://game/ui/loadout_screen.gd" id="1_ls"]

[node name="LoadoutScreen" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_ls")

[node name="Title" type="Label" parent="."]
offset_left = 24.0
offset_top = 24.0
offset_right = 500.0
offset_bottom = 64.0
text = "Skyfield Gizmos"

[node name="Rows" type="VBoxContainer" parent="."]
offset_left = 40.0
offset_top = 100.0
offset_right = 680.0
offset_bottom = 640.0

[node name="BackButton" type="Button" parent="."]
offset_left = 160.0
offset_top = 1080.0
offset_right = 560.0
offset_bottom = 1160.0
text = "Back to Island"
```

`game/main.gd`: in `_ready`, add:

```gdscript
	$GizmosButton.pressed.connect(_on_gizmos_pressed)
```

and add at the bottom of the file:

```gdscript
func _on_gizmos_pressed() -> void:
	get_tree().change_scene_to_file("res://game/ui/loadout_screen.tscn")
```

`game/main.tscn`: add before the RefreshTimer node:

```
[node name="GizmosButton" type="Button" parent="."]
offset_left = 160.0
offset_top = 980.0
offset_right = 560.0
offset_bottom = 1050.0
text = "Gizmos"
```

- [ ] **Step 4: Run tests to verify they pass**

Same command. Expected: PASS, 5 new tests green, full suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/ui/loadout_screen.gd game/ui/loadout_screen.tscn game/main.gd game/main.tscn tests/test_loadout_screen.gd tests/test_main_boot.gd
git commit -m "feat: add gizmo loadout screen with slot cycling and persistence"
```

---

### Task 9: End-to-end integration proof

No production code: proves a slotted gizmo affects a real physics run, and that the run scene installs from persisted state.

**Files:**
- Create: `tests/fixtures/test_region_slot.json`
- Test: `tests/test_gizmo_integration.gd`

**Interfaces:**
- Consumes: everything above.
- Produces: recorded evidence, plus the single-slot fixture Plan 3b's gizmo tests reuse.

- [ ] **Step 1: Write the fixture and tests**

`tests/fixtures/test_region_slot.json` (no pegs, one slot dead-center in the drop line, catch-all barge below):

```json
{
	"name": "Test Single Slot",
	"board": {"left": 20, "right": 700, "top": 140, "bottom": 1020},
	"pegs": [],
	"gizmo_slots": [{"x": 360, "y": 500}],
	"barges": [
		{"id": "catch_all", "x": 360, "y": 900, "half_width": 340, "half_height": 25, "payout": {"scrap": 12}}
	]
}
```

`tests/test_gizmo_integration.gd`:

```gdscript
extends GutTest

const SkyfieldScene := preload("res://game/run/skyfield.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var run_defs := {"sea_payout": {"scrap": 1}, "pod": {"radius": 12.0, "bounce": 0.55, "friction": 0.2}}


func test_slotted_balloon_bounces_a_real_drop_then_pod_lands() -> void:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	board.build(DataDefs.load_json("res://tests/fixtures/test_region_slot.json"), run_defs)
	board.install_gizmos({"slot_0": "balloon_cluster"}, DataDefs.gizmos, {"balloon_cluster": 1}, self)
	var balloon: GizmoBase = board.get_node("Gizmos").get_child(0)
	var pod: Pod = PodScene.instantiate()
	pod.position = Vector2(360, 160)
	pod.setup(run_defs["pod"])
	board.add_child(pod)
	var caught: bool = await wait_for_signal(board.pod_caught, 10.0)
	assert_true(caught, "the pod must still reach the barge after bouncing")
	assert_true(balloon._hits_left < int(DataDefs.gizmos["defs"]["balloon_cluster"]["max_hits"]),
		"the balloon consumed at least one bounce on the way down")

func test_prism_multiplies_a_real_catch() -> void:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	board.build(DataDefs.load_json("res://tests/fixtures/test_region_slot.json"), run_defs)
	board.install_gizmos({"slot_0": "crystal_prism"}, DataDefs.gizmos, {"crystal_prism": 1}, self)
	var pod: Pod = PodScene.instantiate()
	pod.position = Vector2(360, 160)
	pod.setup(run_defs["pod"])
	board.add_child(pod)
	var caught: bool = await wait_for_signal(board.pod_caught, 10.0)
	assert_true(caught)
	assert_almost_eq(float(pod.get_meta("value_mult")), 1.5, 0.001,
		"falling through the prism must mark the pod before the catch")
```

- [ ] **Step 2: Run and record**

```bash
$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: PASS, 2 new tests green (each 2-5s of simulated physics; the balloon test bounces at least once before the pod escapes sideways or repeatedly falls through after the pop), full suite exit 0. As with Plan 2's Task 6, these may pass on the first run; the deliverable is the recorded evidence, and a timeout is a real finding to report, never to paper over.

- [ ] **Step 3: Manual smoke check (skip in a non-interactive environment; note the skip in the report)**

```bash
$GODOT
```

Expected: on the island, tap Gizmos, assign Wind Fan / Balloon Cluster / Crystal Prism to slots, Back, Launch Expedition: the gizmos are visible on the board and pods visibly react (lateral drift in the fan column, sharp bounces off the balloon that stop after 3, bigger payouts after passing the prism).

- [ ] **Step 4: Commit**

```bash
git add tests/fixtures/test_region_slot.json tests/test_gizmo_integration.gd
git commit -m "test: prove slotted gizmos affect real physics runs end to end"
```
