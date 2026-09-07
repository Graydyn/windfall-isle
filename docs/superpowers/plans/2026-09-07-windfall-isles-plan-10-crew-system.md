# Windfall Isles Plan 10: Crew System

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rescue an authored cast of eight survivors during salvage runs and assign them to island buildings, where they multiply production rates (Gardens trickle, Workshop craft speed, Wind Still regen).

**Architecture:** A new pure `CrewModel` owns rescue state, one-to-one assignments, and the single rate seam `multiplier_for` (1.0 unmanned, 1.25 generalist, per-member bonus on specialty match) that Plan 11's chains will reuse. A `Survivor` Area2D drifts across the run board and is rescued by pod contact through the run scene. Rate wiring goes through optional trailing `crew_defs` parameters so every existing caller and test keeps compiling. Save schema bumps to v8.

**Tech Stack:** Godot 4.6.3 (GDScript), GUT 9.6.1, JSON data files.

**Spec:** docs/superpowers/specs/2026-09-07-crew-system-design.md

## Global Constraints

- Godot binary: `GODOT=/Applications/Godot-4.6.app/Contents/MacOS/Godot` (4.6.3; NEVER `/Applications/Godot.app`, which is 4.7 and breaks GUT 9.6.1).
- Full suite (must exit 0): `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- Single file: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit`
- After creating any new .gd or .json file, run `$GODOT --headless --import` and commit the generated `.gd.uid` sidecars; `git status --porcelain` must show no untracked `.gd.uid` (test files included).
- Indentation: tabs. No em dashes anywhere, including comments and player-facing strings.
- Raw JSON numbers: cast with `int()` / `float()` at use and assert sites; never normalize in DataDefs. Dictionary `==` does not coerce.
- Pure models (CrewModel, TrickleModel, CraftModel, IslandModel, IslandEffects) never read autoloads, wall clocks, or RNG; `now` and RNG are injected.
- Save mutations follow the write-back discipline: never mutate a dict obtained via `data.get(key, {})` when the key might be missing or wrong-typed; heal the section in place first.
- GUT 9.6 auto-fails on pushed/engine errors; error-path tests declare error counts AFTER the trigger. GUT strict warnings reject `:=` inference from untyped Array/Dictionary chains; declare explicit types on JSON-sourced reads (`var row := row_v as Dictionary`).
- UI tests call handlers directly and NEVER invoke scene-changing handlers (`_on_back_pressed`, `_on_return_pressed`, `_on_setup_back_pressed`, `_on_workshop_pressed`, `_on_launch_pressed`).
- Timer-lifetime rules: scene-owned child Timer nodes, never SceneTreeTimers bound to freeable objects with typed parameters; `weakref` or untyped where a bound object can be freed; `is_instance_valid` guards in handlers.
- Physics: never `add_child` a physics body inside a `body_entered` callback chain; build fully then `add_child.call_deferred`. (The Survivor is an Area2D added outside any physics callback, so plain `add_child` is correct there.)
- Screens follow the refresh discipline: `_refresh_tick` rebuilds the row tree only when the structural signature changes; labels update in place otherwise; detach-then-free (`remove_child` before `queue_free`) in rebuilds.
- Signature growth pattern: new parameters are optional with `{}` / `0` defaults so existing callers and tests stay valid; production callers that should pass real values are enumerated per task and must all be updated in that task.
- Do not state cumulative suite totals anywhere (in reports too); per-task new-test lists only.
- Commit after every task; every commit leaves the full suite green.

---

### Task 1: crew.json and DataDefs loading

**Files:**
- Create: `game/data/crew.json`
- Modify: `game/autoload/data_defs.gd`
- Test: `tests/test_crew_defs.gd` (create)

**Interfaces:**
- Consumes: `DataDefs.load_json`.
- Produces: `DataDefs.crew: Dictionary` loaded at boot; the exact JSON shape below (keys `generalist_bonus`, `workable`, `survivor`, `crew`). Later tasks read `DataDefs.crew` and pass it into pure models as `crew_defs`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_crew_defs.gd`:

```gdscript
extends GutTest

const DataDefsScript := preload("res://game/autoload/data_defs.gd")


func crew_defs() -> Dictionary:
	return DataDefsScript.load_json("res://game/data/crew.json")


func test_crew_load_with_required_keys() -> void:
	var defs := crew_defs()
	assert_eq((defs.get("crew", []) as Array).size(), 8, "the authored cast is eight")
	assert_almost_eq(float(defs.get("generalist_bonus", 0.0)), 1.25, 0.001)
	var survivor: Dictionary = defs.get("survivor", {})
	assert_true(float(survivor.get("chance_per_run", 0.0)) > 0.0)
	assert_true(float(survivor.get("drift_speed", 0.0)) > 0.0)
	for row_v in defs.get("crew", []):
		var row := row_v as Dictionary
		assert_true(String(row.get("id", "")) != "")
		assert_true(String(row.get("name", "")) != "")
		assert_true(String(row.get("line", "")) != "", "every rescue needs a line: %s" % row.get("id"))
		assert_true(float(row.get("bonus", 0.0)) > 1.0, "a specialist must beat a generalist: %s" % row.get("id"))

func test_crew_ids_are_unique() -> void:
	var seen := {}
	for row_v in crew_defs().get("crew", []):
		var id := String((row_v as Dictionary).get("id", ""))
		assert_false(seen.has(id), "duplicate crew id: %s" % id)
		seen[id] = true

func test_specialties_are_workable_and_workable_ids_are_real_buildings() -> void:
	var defs := crew_defs()
	var workable: Array = defs.get("workable", [])
	assert_true(workable.size() > 0)
	for building_v in workable:
		assert_has(DataDefs.buildings.get("defs", {}), String(building_v),
			"workable entry is not a building def: %s" % String(building_v))
	for row_v in defs.get("crew", []):
		var row := row_v as Dictionary
		assert_true(workable.has(String(row.get("specialty", ""))),
			"specialty outside workable: %s" % row.get("id"))

func test_autoload_exposes_crew() -> void:
	assert_eq((DataDefs.crew.get("crew", []) as Array).size(), 8,
		"DataDefs must load crew.json at boot")
```

- [ ] **Step 2: Run to verify failure**

Run: `$GODOT --headless --import` then `$GODOT --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_crew_defs.gd -gexit`
Expected: FAIL (missing data file; `DataDefs.crew` does not exist).

- [ ] **Step 3: Create the data file and loader**

Create `game/data/crew.json` exactly (the lines are final authored copy from the spec; do not paraphrase):

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

In `game/autoload/data_defs.gd`: add after `const ISLETS_PATH := "res://game/data/islets.json"`:

```gdscript
const CREW_PATH := "res://game/data/crew.json"
```

Add after `var islets: Dictionary = {}`:

```gdscript
var crew: Dictionary = {}
```

Add at the end of `_ready()` after `islets = load_json(ISLETS_PATH)`:

```gdscript
	crew = load_json(CREW_PATH)
```

- [ ] **Step 4: Run the test file, then the full suite**

Both must pass; `git status --porcelain` shows no untracked `.gd.uid`.

- [ ] **Step 5: Commit**

```bash
git add game/data/crew.json game/autoload/data_defs.gd tests/test_crew_defs.gd tests/test_crew_defs.gd.uid
git commit -m "feat: crew.json authored cast and DataDefs loading"
```

---

### Task 2: Save schema v8

**Files:**
- Modify: `game/core/save_schema.gd`
- Test: `tests/test_save_schema.gd` (modify)

**Interfaces:**
- Consumes: existing schema machinery.
- Produces: `SaveSchema.CURRENT_VERSION == 8`; `data["crew"] == {"rescued": {}, "assignments": {}}` on fresh saves, v7 migration, and backfill.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_save_schema.gd`:

```gdscript
func test_migrate_7_to_8_adds_crew_losslessly() -> void:
	var v7 := SaveSchema.default_data(DEFS, GIZMO_DEFS)
	v7["version"] = 7
	v7.erase("crew")
	v7["currencies"]["scrap"] = 777
	var out := SaveSchema.migrate(v7, GIZMO_DEFS)
	assert_eq(int(out["version"]), 8)
	assert_eq(out["crew"], {"rescued": {}, "assignments": {}})
	assert_eq(int(out["currencies"]["scrap"]), 777, "balances untouched")

func test_default_data_has_crew_section() -> void:
	assert_eq(SaveSchema.default_data(DEFS)["crew"], {"rescued": {}, "assignments": {}})
```

Update the existing version-pinned assertions from 7 to 8. Apply these exact edits:

1. Rename `test_current_version_is_seven_and_defaults_grant_eight` to `test_current_version_is_eight_and_defaults_grant_eight` and change `assert_eq(SaveSchema.CURRENT_VERSION, 7)` to `assert_eq(SaveSchema.CURRENT_VERSION, 8)`.
2. In `test_migrate_v3_to_v4_adds_island_losslessly`, change `assert_eq(int(migrated["version"]), 7)` to `assert_eq(int(migrated["version"]), 8)`.
3. In `test_migrate_v1_hops_all_the_way_to_v4`, change `assert_eq(int(migrated["version"]), 7)` to `assert_eq(int(migrated["version"]), 8)`.
4. In `test_migrate_5_to_6_adds_expedition_losslessly`, change `assert_eq(int(out["version"]), 7)` to `assert_eq(int(out["version"]), 8)`.
5. In `test_migrate_6_to_7_adds_islets_losslessly`, change `assert_eq(int(out["version"]), 7)` to `assert_eq(int(out["version"]), 8)`.
6. In `test_backfill_heals_missing_keys_on_current_version`, change `var damaged := {"version": 7, "currencies": {"scrap": 7}}` to `var damaged := {"version": 8, "currencies": {"scrap": 7}}` and change the key-list line to:

```gdscript
	for key in ["fuel", "timers", "island", "trickle", "daily_crate", "gizmos", "ads", "notifications", "expedition", "islets", "crew"]:
```

- [ ] **Step 2: Run to verify failure**

Run the schema file. Expected: FAIL (`CURRENT_VERSION` is 7, no crew key).

- [ ] **Step 3: Implement**

In `game/core/save_schema.gd`:

1. Change `const CURRENT_VERSION := 7` to `const CURRENT_VERSION := 8`.
2. In `default_data`, add after the `"islets": _fresh_islets(),` line:

```gdscript
		"crew": _fresh_crew(),
```

3. In `migrate`, add after the `if int(data["version"]) == 6:` block:

```gdscript
	if int(data["version"]) == 7:
		data = _migrate_7_to_8(data)
```

4. Add after `_fresh_islets`:

```gdscript
static func _migrate_7_to_8(data: Dictionary) -> Dictionary:
	# The crew arrive: rescued survivors and their building assignments
	# (crew spec section 3).
	data["crew"] = _fresh_crew()
	data["version"] = 8
	return data


static func _fresh_crew() -> Dictionary:
	return {"rescued": {}, "assignments": {}}
```

- [ ] **Step 4: Run the schema file, then the full suite**

Both must pass.

- [ ] **Step 5: Commit**

```bash
git add game/core/save_schema.gd tests/test_save_schema.gd
git commit -m "feat: save schema v8 adds the crew section"
```

---

### Task 3: CrewModel and the Gardens trickle wiring

**Files:**
- Create: `game/base/crew_model.gd`
- Modify: `game/base/trickle_model.gd`
- Modify: `game/base/island_model.gd:85-112` (the `complete_build` gardens branch)
- Test: `tests/test_crew_model.gd` (create), `tests/test_trickle_model.gd` (modify)

**Interfaces:**
- Consumes: `data["crew"]` (Task 2), crew.json shape (Task 1), `TrickleModel` internals.
- Produces (later tasks call these exact signatures):
  - `CrewModel.members(defs) -> Array`, `entry(defs, crew_id) -> Dictionary`, `workable(defs) -> Array`
  - `CrewModel.is_rescued(data, crew_id) -> bool`, `rescued_ids(data, defs) -> Array[String]`, `unrescued_ids(data, defs) -> Array[String]`
  - `CrewModel.rescue(data, crew_id) -> bool`
  - `CrewModel.crew_at(data, building_id) -> String`, `building_of(data, crew_id) -> String`
  - `CrewModel.assign(data, defs, building_id, crew_id, building_defs: Dictionary = {}, now: int = 0) -> bool`
  - `CrewModel.unassign(data, defs, building_id, building_defs: Dictionary = {}, now: int = 0) -> void`
  - `CrewModel.multiplier_for(data, defs, building_id) -> float` (1.0 / generalist_bonus / member bonus)
  - `TrickleModel.rate_per_hour(data, building_defs, crew_defs: Dictionary = {}) -> float`
  - `TrickleModel.pending(data, building_defs, now, crew_defs: Dictionary = {}) -> int` and `collect(...)` with the same trailing param.
  - `IslandModel.complete_build(island, payload, data, now, building_defs: Dictionary = {}, crew_defs: Dictionary = {})`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_crew_model.gd`:

```gdscript
extends GutTest


func fresh_data() -> Dictionary:
	var data := SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	data["trickle"]["last_collect"] = 10000
	return data


func rescue_all(data: Dictionary) -> void:
	for row_v in CrewModel.members(DataDefs.crew):
		CrewModel.rescue(data, String((row_v as Dictionary).get("id", "")))


func test_fresh_save_has_nobody() -> void:
	var data := fresh_data()
	assert_eq(CrewModel.rescued_ids(data, DataDefs.crew), [] as Array[String])
	assert_eq((CrewModel.unrescued_ids(data, DataDefs.crew) as Array).size(), 8)

func test_rescue_marks_and_is_idempotent() -> void:
	var data := fresh_data()
	assert_true(CrewModel.rescue(data, "odo"))
	assert_true(CrewModel.rescue(data, "odo"))
	assert_true(CrewModel.is_rescued(data, "odo"))
	assert_false(CrewModel.rescue(data, ""), "empty id is rejected")
	assert_eq((CrewModel.rescued_ids(data, DataDefs.crew) as Array).size(), 1)

func test_rescue_heals_a_wrong_typed_section() -> void:
	var data := fresh_data()
	data["crew"] = 7
	assert_true(CrewModel.rescue(data, "odo"))
	assert_true(CrewModel.is_rescued(data, "odo"),
		"write-back discipline: the mangled section is rebuilt in place")

func test_assign_requires_rescued_and_workable() -> void:
	var data := fresh_data()
	assert_false(CrewModel.assign(data, DataDefs.crew, "gardens", "odo"), "not rescued yet")
	CrewModel.rescue(data, "odo")
	assert_false(CrewModel.assign(data, DataDefs.crew, "observatory", "odo"), "not workable")
	assert_true(CrewModel.assign(data, DataDefs.crew, "gardens", "odo"))
	assert_eq(CrewModel.crew_at(data, "gardens"), "odo")
	assert_eq(CrewModel.building_of(data, "odo"), "gardens")

func test_assign_moves_and_displaces() -> void:
	var data := fresh_data()
	rescue_all(data)
	CrewModel.assign(data, DataDefs.crew, "gardens", "odo")
	assert_true(CrewModel.assign(data, DataDefs.crew, "workshop", "odo"), "a move")
	assert_eq(CrewModel.crew_at(data, "gardens"), "", "the old post empties")
	CrewModel.assign(data, DataDefs.crew, "workshop", "maren")
	assert_eq(CrewModel.crew_at(data, "workshop"), "maren", "the newcomer takes the post")
	assert_eq(CrewModel.building_of(data, "odo"), "", "the displaced crew is idle, not duplicated")

func test_unassign_clears() -> void:
	var data := fresh_data()
	rescue_all(data)
	CrewModel.assign(data, DataDefs.crew, "gardens", "odo")
	CrewModel.unassign(data, DataDefs.crew, "gardens")
	assert_eq(CrewModel.crew_at(data, "gardens"), "")

func test_multiplier_tiers() -> void:
	var data := fresh_data()
	rescue_all(data)
	assert_almost_eq(CrewModel.multiplier_for(data, DataDefs.crew, "gardens"), 1.0, 0.001, "unmanned")
	CrewModel.assign(data, DataDefs.crew, "gardens", "maren")
	assert_almost_eq(CrewModel.multiplier_for(data, DataDefs.crew, "gardens"), 1.25, 0.001,
		"Maren is a workshop specialist, a generalist in the gardens")
	CrewModel.assign(data, DataDefs.crew, "gardens", "odo")
	assert_almost_eq(CrewModel.multiplier_for(data, DataDefs.crew, "gardens"), 1.5, 0.001,
		"Odo is a gardens specialist")

func test_assignment_flip_preserves_pending_trickle_value() -> void:
	var data := fresh_data()
	rescue_all(data)
	var now := 10000 + 3600
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, now, DataDefs.crew), 20, "1h unmanned at Lv1")
	assert_true(CrewModel.assign(data, DataDefs.crew, "gardens", "odo", DataDefs.buildings, now))
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, now, DataDefs.crew), 20,
		"the flip must not re-rate scrap already accrued")
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, now + 3600, DataDefs.crew), 20 + 30,
		"the next hour accrues at the 1.5x specialist rate")

func test_unassign_rebases_too() -> void:
	var data := fresh_data()
	rescue_all(data)
	CrewModel.assign(data, DataDefs.crew, "gardens", "odo", DataDefs.buildings, 10000)
	var now := 10000 + 3600
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, now, DataDefs.crew), 30, "1h at 1.5x")
	CrewModel.unassign(data, DataDefs.crew, "gardens", DataDefs.buildings, now)
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, now, DataDefs.crew), 30,
		"accrued value survives the departure")
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, now + 3600, DataDefs.crew), 30 + 20,
		"the next hour is back to baseline")

func test_non_gardens_assignment_does_not_touch_the_trickle_clock() -> void:
	var data := fresh_data()
	rescue_all(data)
	var stamp := int(data["trickle"]["last_collect"])
	CrewModel.assign(data, DataDefs.crew, "workshop", "maren", DataDefs.buildings, 99999)
	assert_eq(int(data["trickle"]["last_collect"]), stamp,
		"only a gardens-rate change rebases the clock")
```

Append to `tests/test_trickle_model.gd`:

```gdscript
func test_crewed_gardens_trickles_faster() -> void:
	var data := make_data(1, 10000)
	CrewModel.rescue(data, "odo")
	(data["crew"]["assignments"] as Dictionary)["gardens"] = "odo"
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, 10000 + 3600, DataDefs.crew), 30,
		"20/hour x 1.5 specialist")
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, 10000 + 3600), 20,
		"callers without crew defs still get the baseline rate")

func test_upgrade_rebase_respects_the_crew_rate() -> void:
	var data := make_data(1, 10000)
	CrewModel.rescue(data, "odo")
	(data["crew"]["assignments"] as Dictionary)["gardens"] = "odo"
	var now := 10000 + 3600
	var pending_before := TrickleModel.pending(data, DataDefs.buildings, now, DataDefs.crew)
	IslandModel.complete_build(data["island"],
		{"plot": "plot_2", "building": "gardens", "to_level": 2}, data, now, DataDefs.buildings, DataDefs.crew)
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, now, DataDefs.crew), pending_before,
		"the upgrade rebase must price the carried value at the crewed rate")
```

For the second test to be honest, the plot must already exist at level 1 in `make_data` (it does: `plot_2`), and `complete_build` requires the plot present, which it is.

- [ ] **Step 2: Run to verify failure**

Run `--import`, then both files. Expected: FAIL (`CrewModel` missing; `pending` takes 3 args).

- [ ] **Step 3: Implement CrewModel**

Create `game/base/crew_model.gd`:

```gdscript
class_name CrewModel
## Pure crew rules over save.crew (crew spec sections 3-5): who is rescued,
## who works where, and the production multiplier a building earns from its
## worker. Buildings run at 1.0 unmanned (the pre-crew baseline), at the
## generalist bonus with any worker, and at the worker's own bonus on a
## specialty match. multiplier_for is the seam Plan 11 chains reuse.


static func members(defs: Dictionary) -> Array:
	return defs.get("crew", [])


static func entry(defs: Dictionary, crew_id: String) -> Dictionary:
	for row_v in members(defs):
		var row := row_v as Dictionary
		if String(row.get("id", "")) == crew_id:
			return row
	return {}


static func workable(defs: Dictionary) -> Array:
	return defs.get("workable", [])


static func _section(data: Dictionary) -> Dictionary:
	# Write-back discipline: heal a missing or wrong-typed crew section in
	# place so no mutation can land in a detached dict.
	if not data.has("crew") or not (data["crew"] is Dictionary):
		data["crew"] = {"rescued": {}, "assignments": {}}
	var section: Dictionary = data["crew"]
	if not section.has("rescued") or not (section["rescued"] is Dictionary):
		section["rescued"] = {}
	if not section.has("assignments") or not (section["assignments"] is Dictionary):
		section["assignments"] = {}
	return section


static func is_rescued(data: Dictionary, crew_id: String) -> bool:
	var raw: Variant = data.get("crew", {})
	var section: Dictionary = raw if raw is Dictionary else {}
	return bool((section.get("rescued", {}) as Dictionary).get(crew_id, false))


static func rescued_ids(data: Dictionary, defs: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for row_v in members(defs):
		var id := String((row_v as Dictionary).get("id", ""))
		if is_rescued(data, id):
			out.append(id)
	return out


static func unrescued_ids(data: Dictionary, defs: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for row_v in members(defs):
		var id := String((row_v as Dictionary).get("id", ""))
		if not is_rescued(data, id):
			out.append(id)
	return out


static func rescue(data: Dictionary, crew_id: String) -> bool:
	if crew_id == "":
		return false
	(_section(data)["rescued"] as Dictionary)[crew_id] = true
	return true


static func crew_at(data: Dictionary, building_id: String) -> String:
	var raw: Variant = data.get("crew", {})
	var section: Dictionary = raw if raw is Dictionary else {}
	return String((section.get("assignments", {}) as Dictionary).get(building_id, ""))


static func building_of(data: Dictionary, crew_id: String) -> String:
	var raw: Variant = data.get("crew", {})
	var section: Dictionary = raw if raw is Dictionary else {}
	var assignments: Dictionary = section.get("assignments", {})
	for building in assignments:
		if String(assignments[building]) == crew_id:
			return String(building)
	return ""


static func assign(data: Dictionary, defs: Dictionary, building_id: String, crew_id: String, building_defs: Dictionary = {}, now: int = 0) -> bool:
	if crew_id == "" or not is_rescued(data, crew_id):
		return false
	if not workable(defs).has(building_id):
		return false
	var pending_before := TrickleModel.pending(data, building_defs, now, defs)
	var mult_before := multiplier_for(data, defs, "gardens")
	var assignments: Dictionary = _section(data)["assignments"]
	var previous := building_of(data, crew_id)
	if previous != "":
		assignments.erase(previous)
	assignments[building_id] = crew_id
	_rebase_trickle(data, defs, building_defs, now, pending_before, mult_before)
	return true


static func unassign(data: Dictionary, defs: Dictionary, building_id: String, building_defs: Dictionary = {}, now: int = 0) -> void:
	var pending_before := TrickleModel.pending(data, building_defs, now, defs)
	var mult_before := multiplier_for(data, defs, "gardens")
	(_section(data)["assignments"] as Dictionary).erase(building_id)
	_rebase_trickle(data, defs, building_defs, now, pending_before, mult_before)


static func multiplier_for(data: Dictionary, defs: Dictionary, building_id: String) -> float:
	var crew_id := crew_at(data, building_id)
	if crew_id == "":
		return 1.0
	var member := entry(defs, crew_id)
	if String(member.get("specialty", "")) == building_id:
		return float(member.get("bonus", 1.5))
	return float(defs.get("generalist_bonus", 1.25))


static func _rebase_trickle(data: Dictionary, defs: Dictionary, building_defs: Dictionary, now: int, pending_before: int, mult_before: float) -> void:
	# An assignment flip must not re-rate scrap already accrued (same rule as
	# the gardens-upgrade rebase in IslandModel.complete_build). Only a real
	# gardens-rate change rebases, so unrelated moves leave the clock alone.
	if building_defs.is_empty():
		return
	if is_equal_approx(multiplier_for(data, defs, "gardens"), mult_before):
		return
	var rate := TrickleModel.rate_per_hour(data, building_defs, defs)
	if rate <= 0.0:
		return
	(data.get("trickle", {}) as Dictionary)["last_collect"] = now - int(float(pending_before) * 3600.0 / rate)
```

- [ ] **Step 4: Rewire TrickleModel and the upgrade rebase**

Replace the whole body of `game/base/trickle_model.gd` with:

```gdscript
class_name TrickleModel
## Gardens & Cisterns idle faucet (spec 4.1, 5): scrap trickles while away,
## capped, must be collected. Lazy math over trickle.last_collect, same
## pattern as FuelModel. The rate scales with the assigned crew's multiplier
## (crew spec section 5); callers that pass no crew defs get the baseline.


static func rate_per_hour(data: Dictionary, building_defs: Dictionary, crew_defs: Dictionary = {}) -> float:
	var level := IslandModel.building_level(data.get("island", {}), "gardens")
	if level <= 0:
		return 0.0
	var def: Dictionary = (building_defs.get("defs", {}) as Dictionary).get("gardens", {})
	return float(level * int(def.get("scrap_per_hour_per_level", 20))) \
		* CrewModel.multiplier_for(data, crew_defs, "gardens")


static func pending(data: Dictionary, building_defs: Dictionary, now: int, crew_defs: Dictionary = {}) -> int:
	var rate := rate_per_hour(data, building_defs, crew_defs)
	if rate <= 0.0:
		return 0
	var def: Dictionary = (building_defs.get("defs", {}) as Dictionary).get("gardens", {})
	var elapsed_hours := maxf(0.0, float(now - int((data.get("trickle", {}) as Dictionary).get("last_collect", 0))) / 3600.0)
	var capped_hours: float = minf(elapsed_hours, float(def.get("cap_hours", 8.0)))
	return int(floor(capped_hours * rate))


static func collect(data: Dictionary, building_defs: Dictionary, now: int, crew_defs: Dictionary = {}) -> int:
	var amount := pending(data, building_defs, now, crew_defs)
	(data.get("trickle", {}) as Dictionary)["last_collect"] = now
	return amount
```

In `game/base/island_model.gd`, change `complete_build`'s signature to:

```gdscript
static func complete_build(island: Dictionary, payload: Dictionary, data: Dictionary, now: int, building_defs: Dictionary = {}, crew_defs: Dictionary = {}) -> void:
```

and replace its gardens branch (the `if building_id == "gardens":` block) with:

```gdscript
	if building_id == "gardens":
		var to_level := int(payload.get("to_level", 1))
		if to_level == 1:
			plots[plot]["level"] = to_level
			(data.get("trickle", {}) as Dictionary)["last_collect"] = now
		elif not building_defs.is_empty():
			# Rebase last_collect at the new rate so the pending VALUE carries
			# over unchanged instead of being re-rated retroactively (spec
			# 4.1 retention finding), pricing at the CREWED rate when crew
			# defs are provided.
			var pending_old := TrickleModel.pending(data, building_defs, now, crew_defs)
			plots[plot]["level"] = to_level
			var new_rate := TrickleModel.rate_per_hour(data, building_defs, crew_defs)
			if new_rate > 0.0:
				(data.get("trickle", {}) as Dictionary)["last_collect"] = now - int(float(pending_old) * 3600.0 / new_rate)
		else:
			plots[plot]["level"] = to_level
	else:
		plots[plot]["level"] = int(payload.get("to_level", 1))
```

- [ ] **Step 5: Run both test files, then the full suite**

Expected: PASS, suite exit 0 (all existing trickle/complete_build tests use the defaults and are value-identical).

- [ ] **Step 6: Commit**

```bash
git add game/base/crew_model.gd game/base/crew_model.gd.uid game/base/trickle_model.gd game/base/island_model.gd tests/test_crew_model.gd tests/test_crew_model.gd.uid tests/test_trickle_model.gd
git commit -m "feat: CrewModel with rate seam and crewed gardens trickle"
```

---

### Task 4: Craft speed and fuel regen wiring

**Files:**
- Modify: `game/base/craft_model.gd` (start_craft), `game/base/island_effects.gd` (apply_fuel), `game/autoload/game_state.gd` (load_game/_ready), `game/base/workshop_screen.gd` (_on_craft_pressed)
- Test: `tests/test_craft_model.gd` (modify), `tests/test_island_effects.gd` (modify)

**Interfaces:**
- Consumes: `CrewModel.multiplier_for` (Task 3).
- Produces: `CraftModel.start_craft(..., building_defs: Dictionary = {}, crew_defs: Dictionary = {})` dividing craft duration; `IslandEffects.apply_fuel(data, economy_defs, building_defs, crew_defs: Dictionary = {})` dividing regen; `GameState.load_game(defs, now, gizmo_defs = {}, building_defs = {}, crew_defs = {})`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_craft_model.gd`:

```gdscript
func test_crewed_workshop_crafts_faster_and_locks_at_start() -> void:
	CrewModel.rescue(state.data, "maren")
	(state.data["crew"]["assignments"] as Dictionary)["workshop"] = "maren"
	assert_true(CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan", 1000, DataDefs.buildings, DataDefs.crew))
	assert_eq(timers.remaining("craft_wind_fan", 1000), 80,
		"120s divided by Maren's 1.5 specialist bonus")
	(state.data["crew"]["assignments"] as Dictionary).erase("workshop")
	assert_eq(timers.remaining("craft_wind_fan", 1000), 80,
		"the duration locked at start; reassignment does not stretch a running craft")

func test_uncrewed_craft_duration_is_baseline() -> void:
	assert_true(CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan", 1000, DataDefs.buildings, DataDefs.crew))
	assert_eq(timers.remaining("craft_wind_fan", 1000), 120)
```

Append to `tests/test_island_effects.gd`:

```gdscript
func test_crewed_wind_still_regenerates_faster() -> void:
	var data := data_with_wind_still(1)
	CrewModel.rescue(data, "brisa")
	(data["crew"]["assignments"] as Dictionary)["wind_still"] = "brisa"
	IslandEffects.apply_fuel(data, ECON_DEFS, DataDefs.buildings, DataDefs.crew)
	assert_eq(int(data["fuel"]["regen_seconds"]), 720,
		"(1200 - 120) / 1.5 specialist bonus")
	IslandEffects.apply_fuel(data, ECON_DEFS, DataDefs.buildings, DataDefs.crew)
	assert_eq(int(data["fuel"]["regen_seconds"]), 720, "idempotent re-application")

func test_regen_floor_survives_crew() -> void:
	var data := data_with_wind_still(3)
	CrewModel.rescue(data, "brisa")
	(data["crew"]["assignments"] as Dictionary)["wind_still"] = "brisa"
	IslandEffects.apply_fuel(data, ECON_DEFS, DataDefs.buildings, DataDefs.crew)
	assert_eq(int(data["fuel"]["regen_seconds"]), 560,
		"(1200 - 360) / 1.5 stays above the 300 floor here; the floor clamps deeper stacks")

func test_apply_fuel_without_crew_defs_is_baseline() -> void:
	var data := data_with_wind_still(1)
	CrewModel.rescue(data, "brisa")
	(data["crew"]["assignments"] as Dictionary)["wind_still"] = "brisa"
	IslandEffects.apply_fuel(data, ECON_DEFS, DataDefs.buildings)
	assert_eq(int(data["fuel"]["regen_seconds"]), 1080, "no crew defs, no crew effect")
```

Note: `data_with_wind_still` builds from `SaveSchema.default_data(ECON_DEFS)`, which after Task 2 contains the crew section, so the direct assignment writes are safe.

- [ ] **Step 2: Run to verify failure**

Run both files. Expected: FAIL (extra args not accepted; durations unchanged).

- [ ] **Step 3: Implement**

In `game/base/craft_model.gd`, change `start_craft` to:

```gdscript
static func start_craft(data: Dictionary, gizmo_defs: Dictionary, economy: Node, timers: Node, gizmo_id: String, now: int, building_defs: Dictionary = {}, crew_defs: Dictionary = {}) -> bool:
	if not can_craft(data, gizmo_defs, economy, timers, gizmo_id, building_defs):
		return false
	var def: Dictionary = (gizmo_defs.get("defs", {}) as Dictionary).get(gizmo_id, {})
	if not economy.pay(effective_cost(def, data.get("island", {}), building_defs)):
		return false
	# The worker's speed is priced into the duration at START and locked in
	# the timer's ends_at; reassignment never retimes a running craft
	# (crew spec section 5).
	var duration := maxi(1, ceili(float(def.get("craft_seconds", 120)) / CrewModel.multiplier_for(data, crew_defs, "workshop")))
	return timers.start("craft_" + gizmo_id, "craft", duration, now, {"gizmo": gizmo_id})
```

In `game/base/island_effects.gd`, replace `apply_fuel` with:

```gdscript
static func apply_fuel(data: Dictionary, economy_defs: Dictionary, building_defs: Dictionary, crew_defs: Dictionary = {}) -> void:
	var base: Dictionary = economy_defs.get("fuel", {})
	var def: Dictionary = (building_defs.get("defs", {}) as Dictionary).get("wind_still", {})
	var level := IslandModel.building_level(data.get("island", {}), "wind_still")
	var fuel: Dictionary = data.get("fuel", {})
	fuel["cap"] = int(base.get("cap", 5)) + level * int(def.get("fuel_cap_bonus_per_level", 1))
	var crew_mult := CrewModel.multiplier_for(data, crew_defs, "wind_still")
	fuel["regen_seconds"] = maxi(MIN_REGEN_SECONDS,
		roundi((float(base.get("regen_seconds", 1200)) + float(level) * float(def.get("regen_delta_per_level", -120.0))) / crew_mult))
	fuel["amount"] = mini(int(fuel.get("amount", 0)), int(fuel["cap"]))
```

In `game/autoload/game_state.gd`: change `load_game`'s signature to

```gdscript
func load_game(defs: Dictionary, now: int, gizmo_defs: Dictionary = {}, building_defs: Dictionary = {}, crew_defs: Dictionary = {}) -> void:
```

change its `IslandEffects.apply_fuel(data, defs, building_defs)` line to

```gdscript
		IslandEffects.apply_fuel(data, defs, building_defs, crew_defs)
```

and change `_ready()`'s load call to

```gdscript
	load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings, DataDefs.crew)
```

In `game/base/workshop_screen.gd`, change the `_on_craft_pressed` model call to:

```gdscript
	if CraftModel.start_craft(GameState.data, DataDefs.gizmos, Economy, TimerService, gizmo_id, TimeUtil.now(), DataDefs.buildings, DataDefs.crew):
```

- [ ] **Step 4: Run both files, then the full suite**

Expected: PASS, suite exit 0 (baseline math: 1200 + 1x(-120) = 1080 with multiplier 1.0; every existing caller uses the defaults).

Arithmetic check for the new tests before accepting them as green: `ceili(120 / 1.5) = 80`; `roundi(1080 / 1.5) = 720`; `roundi((1200 - 360) / 1.5) = 560`.

- [ ] **Step 5: Commit**

```bash
git add game/base/craft_model.gd game/base/island_effects.gd game/autoload/game_state.gd game/base/workshop_screen.gd tests/test_craft_model.gd tests/test_island_effects.gd
git commit -m "feat: crew speed up crafts and fuel regen"
```

---

### Task 5: The drifting survivor (run side)

**Files:**
- Create: `game/run/survivor.gd`
- Modify: `game/run/salvage_run.gd`, `game/run/salvage_run.tscn`
- Test: `tests/test_survivor_rescue.gd` (create)

**Interfaces:**
- Consumes: `CrewModel.unrescued_ids/rescue/entry` (Task 3), `DataDefs.crew` (Task 1), the run scene's phase machine and `_rng`.
- Produces: `Survivor` (class_name, extends Area2D): `setup(id: String, survivor_defs: Dictionary, from_left: bool, board: Dictionary)`, signal `rescued(crew_id: String)`, group `"survivors"`, self-frees off the far edge. salvage_run members `_survivor_id`, `_survivor_from_left`; functions `_maybe_schedule_survivor()`, `_spawn_survivor(timer)`, `_on_survivor_rescued(crew_id)`, `_hide_banner(timer)`; tscn node `UI/RescueBanner`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_survivor_rescue.gd`:

```gdscript
extends GutTest
## Run-side rescue (crew spec section 6): a survivor drifts across the board,
## pod contact rescues and persists instantly, the banner announces, and the
## whole channel stays out of the payout pipeline.

const RunScene := preload("res://game/run/salvage_run.tscn")
const TEST_SAVE := "user://test_survivor_rescue.json"

var scene


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	GameState.data["created_at"] = 1000
	GameState.data["fuel"]["updated_at"] = 1000
	scene = add_child_autofree(RunScene.instantiate())


func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_survivor_rescue.json", "test_survivor_rescue.json.tmp", "test_survivor_rescue.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings, DataDefs.crew)


func force_spawn(id: String) -> Node:
	scene._survivor_id = id
	scene._survivor_from_left = true
	var timer := Timer.new()
	scene.add_child(timer)
	scene._spawn_survivor(timer)
	var survivors: Array = get_tree().get_nodes_in_group("survivors")
	return survivors[0] if survivors.size() > 0 else null


func test_no_spawn_scheduling_when_everyone_is_home() -> void:
	for row_v in CrewModel.members(DataDefs.crew):
		CrewModel.rescue(GameState.data, String((row_v as Dictionary).get("id", "")))
	scene._on_start_pressed()
	scene._rng.seed = 1
	scene._maybe_schedule_survivor()
	assert_eq(scene._survivor_id, "", "a complete cast schedules nothing")

func test_spawn_is_seed_deterministic() -> void:
	# Force the roll to always draw and clear any survivor the natural Start
	# roll may have picked, so the assertion sees only the seeded draw.
	var survivor_defs: Dictionary = DataDefs.crew["survivor"]
	var old_chance: float = float(survivor_defs["chance_per_run"])
	survivor_defs["chance_per_run"] = 1.0
	scene._on_start_pressed()
	scene._survivor_id = ""
	scene._rng.seed = 7
	scene._maybe_schedule_survivor()
	var first := String(scene._survivor_id)
	assert_ne(first, "", "chance 1.0 always draws")
	var again = add_child_autofree(RunScene.instantiate())
	again._on_start_pressed()
	again._survivor_id = ""
	again._rng.seed = 7
	again._maybe_schedule_survivor()
	assert_eq(String(again._survivor_id), first, "same seed, same draw")
	survivor_defs["chance_per_run"] = old_chance

func test_spawn_timer_is_a_noop_outside_running() -> void:
	scene._survivor_id = "odo"
	var timer := Timer.new()
	scene.add_child(timer)
	scene._spawn_survivor(timer)
	assert_eq(get_tree().get_nodes_in_group("survivors").size(), 0,
		"still in SETUP: the survivor never appears")

func test_pod_contact_rescues_persists_and_banners() -> void:
	scene._on_start_pressed()
	var survivor := force_spawn("odo")
	assert_not_null(survivor)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	survivor._on_body(pod)
	assert_true(CrewModel.is_rescued(GameState.data, "odo"))
	var saved := SaveIO.new(TEST_SAVE).read()
	assert_true(bool((saved["crew"]["rescued"] as Dictionary).get("odo", false)),
		"a rescue must survive an OS kill the same frame")
	assert_true(scene.get_node("UI/RescueBanner").visible)
	assert_string_contains(String(scene.get_node("UI/RescueBanner").text), "Odo")
	assert_string_contains(String(scene.get_node("UI/RescueBanner").text), "Soil remembers")
	await wait_physics_frames(2)
	assert_eq(get_tree().get_nodes_in_group("survivors").size(), 0, "the raft leaves with them")

func test_contact_rescues_only_once() -> void:
	scene._on_start_pressed()
	var survivor := force_spawn("odo")
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	survivor._on_body(pod)
	survivor._on_body(pod)
	assert_eq((CrewModel.rescued_ids(GameState.data, DataDefs.crew) as Array).size(), 1,
		"a double contact in one frame claims one rescue")

func test_non_pod_contact_is_ignored() -> void:
	scene._on_start_pressed()
	var survivor := force_spawn("odo")
	survivor._on_body(autofree(Area2D.new()))
	assert_false(CrewModel.is_rescued(GameState.data, "odo"))

func test_run_over_sweeps_the_survivor() -> void:
	scene.model = RunModel.new({"drops_per_run": 1, "max_active_pods": 4})
	scene.model.run_over.connect(scene._on_run_over)
	scene._on_start_pressed()
	force_spawn("odo")
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(pod, {"scrap": 3})
	await wait_physics_frames(2)
	assert_eq(get_tree().get_nodes_in_group("survivors").size(), 0, "run over clears the board")
	assert_false(CrewModel.is_rescued(GameState.data, "odo"), "no rescue happened")

func test_survivor_drifts_and_frees_itself_offscreen() -> void:
	scene._on_start_pressed()
	var survivor := force_spawn("odo")
	survivor.position.x = 1000.0
	await wait_physics_frames(2)
	assert_eq(get_tree().get_nodes_in_group("survivors").size(), 0,
		"past the far edge the raft cleans itself up")
```

Notes for the implementer: `test_spawn_is_seed_deterministic` re-seeds AFTER `_on_start_pressed` because Start's flow may consume rng; `_maybe_schedule_survivor` must therefore also be callable directly (it is called once inside Start with the natural seed, and tests re-invoke it deterministically; a second invocation may schedule a second timer in a test context, which is fine because `force_spawn` bypasses timers entirely and the scheduled timer's `_spawn_survivor` no-ops once `_phase` leaves RUNNING or simply spawns a raft the test ignores).

- [ ] **Step 2: Run to verify failure**

Run `--import`, then the file. Expected: FAIL (`Survivor` unknown; salvage_run lacks the members and functions; no RescueBanner node).

- [ ] **Step 3: Implement the Survivor**

Create `game/run/survivor.gd`:

```gdscript
class_name Survivor
extends Area2D
## A stranded crewmember drifting across the run board on a raft (crew spec
## section 6). Any live pod touching the raft rescues them; the scene owns
## persistence and the banner. Frees itself past the far edge. Never touches
## the payout pipeline.

signal rescued(crew_id: String)

var crew_id := ""
var _speed := 60.0
var _direction := 1.0
var _exit_x := 800.0
var _claimed := false


func setup(id: String, survivor_defs: Dictionary, from_left: bool, board: Dictionary) -> void:
	crew_id = id
	_speed = float(survivor_defs.get("drift_speed", 60.0))
	_direction = 1.0 if from_left else -1.0
	var left := float(board.get("left", 20.0))
	var right := float(board.get("right", 700.0))
	_exit_x = right + 60.0 if from_left else left - 60.0
	position = Vector2(left - 60.0 if from_left else right + 60.0, float(survivor_defs.get("drift_y", 480.0)))
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = float(survivor_defs.get("radius", 26.0))
	shape.shape = circle
	add_child(shape)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-24, 10), Vector2(24, 10), Vector2(16, -8), Vector2(-16, -8),
	])
	visual.color = Color(0.9, 0.75, 0.3)
	add_child(visual)
	add_to_group("survivors")
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	position.x += _speed * _direction * delta
	if (_direction > 0.0 and position.x > _exit_x) or (_direction < 0.0 and position.x < _exit_x):
		queue_free()


func _on_body(body: Node2D) -> void:
	# One rescue per raft: two pods in one physics frame claim once.
	if _claimed or not (body is RigidBody2D):
		return
	_claimed = true
	rescued.emit(crew_id)
	queue_free()
```

- [ ] **Step 4: Wire the run scene**

In `game/run/salvage_run.tscn`, append at the end:

```
[node name="RescueBanner" type="Label" parent="UI"]
visible = false
offset_left = 60.0
offset_top = 70.0
offset_right = 660.0
offset_bottom = 130.0
```

In `game/run/salvage_run.gd`:

1. Add members after `var _region_id := ""`:

```gdscript
var _survivor_id := ""
var _survivor_from_left := true
```

2. In `_on_start_pressed`, add directly after `controller.enabled = true` (before `_refresh_hud()`):

```gdscript
	_maybe_schedule_survivor()
```

3. In `_on_run_over`, add directly after the pods sweep loop:

```gdscript
	for survivor in get_tree().get_nodes_in_group("survivors"):
		survivor.queue_free()
```

4. Add after `_setup_tick`:

```gdscript
func _maybe_schedule_survivor() -> void:
	# Crew spec section 6: at most one survivor per run, drawn on the scene's
	# injected rng, only while someone is still out there.
	var pool := CrewModel.unrescued_ids(GameState.data, DataDefs.crew)
	if pool.is_empty():
		return
	var survivor_defs: Dictionary = DataDefs.crew.get("survivor", {})
	if _rng.randf() >= float(survivor_defs.get("chance_per_run", 0.25)):
		return
	_survivor_id = String(pool[_rng.randi_range(0, pool.size() - 1)])
	_survivor_from_left = _rng.randf() < 0.5
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = _rng.randf_range(float(survivor_defs.get("spawn_delay_min", 2.0)), float(survivor_defs.get("spawn_delay_max", 8.0)))
	add_child(timer)
	timer.timeout.connect(_spawn_survivor.bind(timer))
	timer.start()


func _spawn_survivor(timer: Timer) -> void:
	timer.queue_free()
	if _phase != Phase.RUNNING or _survivor_id == "":
		return
	var survivor := Survivor.new()
	var board_rect: Dictionary = DataDefs.skyfield(_region_id).get("board", {})
	survivor.setup(_survivor_id, DataDefs.crew.get("survivor", {}), _survivor_from_left, board_rect)
	survivor.rescued.connect(_on_survivor_rescued)
	board.add_child(survivor)


func _on_survivor_rescued(crew_id: String) -> void:
	if not CrewModel.rescue(GameState.data, crew_id):
		return
	# Persist instantly: a rescue must survive an OS kill (save-anywhere).
	GameState.save_game()
	var member := CrewModel.entry(DataDefs.crew, crew_id)
	$UI/RescueBanner.text = "Rescued %s! \"%s\"" % [String(member.get("name", crew_id)), String(member.get("line", ""))]
	$UI/RescueBanner.visible = true
	var hide := Timer.new()
	hide.one_shot = true
	hide.wait_time = 4.0
	add_child(hide)
	hide.timeout.connect(_hide_banner.bind(hide))
	hide.start()


func _hide_banner(timer: Timer) -> void:
	timer.queue_free()
	$UI/RescueBanner.visible = false
```

- [ ] **Step 5: Run the file, then the full suite**

Run `--import` first. Expected: PASS, suite exit 0. `git status --porcelain` shows no untracked `.gd.uid`.

- [ ] **Step 6: Commit**

```bash
git add game/run/survivor.gd game/run/survivor.gd.uid game/run/salvage_run.gd game/run/salvage_run.tscn tests/test_survivor_rescue.gd tests/test_survivor_rescue.gd.uid
git commit -m "feat: drifting survivor rescue during runs"
```

---

### Task 6: Island crew panel

**Files:**
- Modify: `game/base/island_screen.gd`
- Test: `tests/test_island_screen.gd` (modify)

**Interfaces:**
- Consumes: `CrewModel` (Task 3), `IslandEffects.apply_fuel` 4-arg (Task 4), `FuelModel.materialize`, `DataDefs.crew`.
- Produces: crew rows in `_rebuild` with `_crew_row_text(member)`, `_assign_text(crew_id)`, handler `_on_assign_pressed(crew_id)`; the refresh signature covers rescued/assignment state; worker suffix in `_row_text`; trickle calls pass crew defs.

- [ ] **Step 1: Write the failing tests**

First, two existing row-count tests in `tests/test_island_screen.gd` must learn about crew rows. Replace `test_builds_one_row_per_plot_plus_one_per_islet` with:

```gdscript
func test_builds_one_row_per_plot_plus_islets_plus_crew() -> void:
	assert_eq(screen.get_node("Rows").get_child_count(),
		int(DataDefs.buildings["plot_count"]) + IsletModel.islets(DataDefs.islets).size()
			+ CrewModel.members(DataDefs.crew).size(),
		"fresh save: home plots, one status row per islet, one row per crew def")
```

and in `test_restored_islet_contributes_its_plot_row`, change the expected count expression to:

```gdscript
		int(DataDefs.buildings["plot_count"]) + 1 + IsletModel.islets(DataDefs.islets).size()
			+ CrewModel.members(DataDefs.crew).size(),
```

Then append to `tests/test_island_screen.gd`:

```gdscript
func rescue_and_rebuild(ids: Array) -> void:
	for id in ids:
		CrewModel.rescue(GameState.data, String(id))
	screen._rebuild()


func crew_row_count() -> int:
	return screen.get_node("Rows").get_child_count()


func test_crew_rows_exist_for_the_whole_cast() -> void:
	var base := int(DataDefs.buildings["plot_count"]) + IsletModel.islets(DataDefs.islets).size()
	assert_eq(crew_row_count(), base + CrewModel.members(DataDefs.crew).size(),
		"every crew def gets a row, rescued or not")

func test_unrescued_crew_show_as_silhouettes() -> void:
	assert_string_contains(screen._crew_row_text(CrewModel.entry(DataDefs.crew, "odo")),
		"still out there")

func test_rescued_crew_show_name_and_specialty() -> void:
	rescue_and_rebuild(["odo"])
	var text: String = screen._crew_row_text(CrewModel.entry(DataDefs.crew, "odo"))
	assert_string_contains(text, "Odo")
	assert_string_contains(text, "Gardens")

func test_assign_cycle_walks_workable_then_idle() -> void:
	rescue_and_rebuild(["odo"])
	screen._on_assign_pressed("odo")
	assert_eq(CrewModel.building_of(GameState.data, "odo"), "gardens", "first workable")
	screen._on_assign_pressed("odo")
	assert_eq(CrewModel.building_of(GameState.data, "odo"), "workshop")
	for i in 3:
		screen._on_assign_pressed("odo")
	assert_eq(CrewModel.building_of(GameState.data, "odo"), "foundry_annex", "last workable")
	screen._on_assign_pressed("odo")
	assert_eq(CrewModel.building_of(GameState.data, "odo"), "", "then back to idle")

func test_assignment_persists() -> void:
	rescue_and_rebuild(["odo"])
	screen._on_assign_pressed("odo")
	var saved := SaveIO.new(TEST_SAVE).read()
	assert_eq(String((saved["crew"]["assignments"] as Dictionary).get("gardens", "")), "odo")

func test_wind_still_assignment_reapplies_fuel_effects() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "wind_still", "level": 1}
	rescue_and_rebuild(["brisa"])
	screen._on_assign_pressed("brisa")
	screen._on_assign_pressed("brisa")
	screen._on_assign_pressed("brisa")
	assert_eq(CrewModel.building_of(GameState.data, "brisa"), "wind_still")
	assert_eq(int(GameState.data["fuel"]["regen_seconds"]), 720,
		"(1200 - 120) / 1.5: the handler re-applies fuel effects")

func test_worker_suffix_on_building_rows() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	rescue_and_rebuild(["odo"])
	screen._on_assign_pressed("odo")
	assert_string_contains(screen._row_text("plot_2", GameState.data["island"], TimeUtil.now()),
		"Odo working")

func test_rescue_and_assignment_are_structural_signature_changes() -> void:
	screen._refresh_tick()
	var before: String = screen._last_signature
	CrewModel.rescue(GameState.data, "odo")
	screen._refresh_tick()
	assert_ne(screen._last_signature, before, "a rescue rebuilds the rows")
	var mid: String = screen._last_signature
	screen._on_assign_pressed("odo")
	screen._refresh_tick()
	assert_ne(screen._last_signature, mid, "an assignment rebuilds too")

func test_gardens_collect_pays_the_crewed_rate() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	rescue_and_rebuild(["odo"])
	var now := TimeUtil.now()
	CrewModel.assign(GameState.data, DataDefs.crew, "gardens", "odo", DataDefs.buildings, now - 3600)
	GameState.data["trickle"]["last_collect"] = now - 3600
	var scrap_before := Economy.balance("scrap")
	screen._on_gardens_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 30, "20/hour x 1.5 specialist")
```

- [ ] **Step 2: Run to verify failure**

Run the island screen file. Expected: FAIL (row count, missing `_crew_row_text` and handler).

- [ ] **Step 3: Implement**

In `game/base/island_screen.gd`:

1. In `_signature`, add after the islet loop (before `return`):

```gdscript
	for row_v in CrewModel.members(DataDefs.crew):
		var crew_id := String((row_v as Dictionary).get("id", ""))
		if not CrewModel.is_rescued(GameState.data, crew_id):
			parts.append("u")
		else:
			parts.append("@" + CrewModel.building_of(GameState.data, crew_id))
```

2. In `_rebuild`, add after the islet-row loop (before `_refresh_static_controls(now)`):

```gdscript
	for row_v in CrewModel.members(DataDefs.crew):
		var member := row_v as Dictionary
		var member_id := String(member.get("id", ""))
		var crew_row := HBoxContainer.new()
		crew_row.custom_minimum_size = Vector2(0, 56)
		var crew_label := Label.new()
		crew_label.custom_minimum_size = Vector2(320, 0)
		crew_label.text = _crew_row_text(member)
		crew_row.add_child(crew_label)
		if CrewModel.is_rescued(GameState.data, member_id):
			var assign_button := Button.new()
			assign_button.text = _assign_text(member_id)
			assign_button.pressed.connect(_on_assign_pressed.bind(member_id))
			crew_row.add_child(assign_button)
		else:
			crew_label.modulate.a = 0.5
		rows.add_child(crew_row)
```

3. Add after `_cost_text`:

```gdscript
func _crew_row_text(member: Dictionary) -> String:
	var member_id := String(member.get("id", ""))
	if not CrewModel.is_rescued(GameState.data, member_id):
		return "Someone is still out there..."
	var specialty := String(member.get("specialty", ""))
	var def: Dictionary = (DataDefs.buildings.get("defs", {}) as Dictionary).get(specialty, {})
	return "%s (knows the %s)" % [String(member.get("name", member_id)), String(def.get("name", specialty))]


func _assign_text(crew_id: String) -> String:
	var building := CrewModel.building_of(GameState.data, crew_id)
	if building == "":
		return "Assign: (idle)"
	var def: Dictionary = (DataDefs.buildings.get("defs", {}) as Dictionary).get(building, {})
	return "Assign: %s" % String(def.get("name", building))


func _on_assign_pressed(crew_id: String) -> void:
	var options: Array = CrewModel.workable(DataDefs.crew)
	var now := TimeUtil.now()
	var current := CrewModel.building_of(GameState.data, crew_id)
	var next_index := options.find(current) + 1
	# Bank fuel accrued at the old regen rate before the rate can change.
	FuelModel.materialize(GameState.data["fuel"], now)
	if next_index >= options.size():
		if current != "":
			CrewModel.unassign(GameState.data, DataDefs.crew, current, DataDefs.buildings, now)
	else:
		CrewModel.assign(GameState.data, DataDefs.crew, String(options[next_index]), crew_id, DataDefs.buildings, now)
	IslandEffects.apply_fuel(GameState.data, DataDefs.economy, DataDefs.buildings, DataDefs.crew)
	GameState.save_game()
	_rebuild()
```

4. In `_row_text`, add directly before the `if String(entry["building"]) == "observatory"` line (inside the built-plot branch, after `var text := ...`):

```gdscript
		var worker := CrewModel.crew_at(GameState.data, String(entry["building"]))
		if worker != "":
			text += ", %s working" % String(CrewModel.entry(DataDefs.crew, worker).get("name", worker))
```

5. Update the trickle call sites to pass crew defs: in `_refresh_static_controls`, change the pending line to

```gdscript
	var pending := TrickleModel.pending(GameState.data, DataDefs.buildings, now, DataDefs.crew)
```

in `_on_gardens_pressed`, change the collect line to

```gdscript
	var amount := TrickleModel.collect(GameState.data, DataDefs.buildings, TimeUtil.now(), DataDefs.crew)
```

in `_on_collect_pressed`, change the complete_build and apply_fuel lines to

```gdscript
	IslandModel.complete_build(GameState.data["island"], payload, GameState.data, now, DataDefs.buildings, DataDefs.crew)
```

```gdscript
	IslandEffects.apply_fuel(GameState.data, DataDefs.economy, DataDefs.buildings, DataDefs.crew)
```

- [ ] **Step 4: Run the file, then the full suite**

Expected: PASS, suite exit 0 (Step 1 already updated both pre-existing row-count tests for the crew rows; no other test in this file counts Rows children).

- [ ] **Step 5: Commit**

```bash
git add game/base/island_screen.gd tests/test_island_screen.gd
git commit -m "feat: island crew panel with assignment cycling"
```

---

### Task 7: End-to-end integration proof and roadmap note

**Files:**
- Test: `tests/test_crew_integration.gd` (create)
- Modify: `docs/ROADMAP.md`

**Interfaces:**
- Consumes: everything from Tasks 1-6.
- Produces: one fixed-clock, fixed-seed proof of the full loop: run rescues a survivor, assignment speeds the trickle. Standing ruling: integration proofs run no-strict-RED (written after the features exist; must pass first try; a failure is a real bug to fix in production code, never in the test's arithmetic).

- [ ] **Step 1: Write the integration test**

Create `tests/test_crew_integration.gd`:

```gdscript
extends GutTest
## End-to-end crew loop (crew spec): a run rescues a drifting survivor, the
## island assigns them, and the Gardens trickle measurably speeds up on an
## injected clock. Fixed rng seeds; no wall-clock dependence beyond the
## scene's own TimeUtil stamps.

const RunScene := preload("res://game/run/salvage_run.tscn")
const TEST_SAVE := "user://test_crew_integration.json"
const T0 := 1_800_000_000


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	GameState.data["created_at"] = T0
	GameState.data["fuel"]["updated_at"] = T0
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}


func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_crew_integration.json", "test_crew_integration.json.tmp", "test_crew_integration.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings, DataDefs.crew)


func test_rescue_assign_and_the_gardens_speed_up() -> void:
	# 1. A run with a forced survivor: pod contact rescues and persists.
	var scene = add_child_autofree(RunScene.instantiate())
	scene._on_start_pressed()
	scene._survivor_id = "odo"
	scene._survivor_from_left = true
	var timer := Timer.new()
	scene.add_child(timer)
	scene._spawn_survivor(timer)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	var survivor: Node = get_tree().get_nodes_in_group("survivors")[0]
	survivor._on_body(pod)
	assert_true(CrewModel.is_rescued(GameState.data, "odo"))
	# 2. Assign Odo to the Gardens on a fixed clock; the rate rises 1.5x and
	#    already-accrued value is preserved by the rebase.
	GameState.data["trickle"]["last_collect"] = T0
	var mid := T0 + 3600
	assert_eq(TrickleModel.pending(GameState.data, DataDefs.buildings, mid, DataDefs.crew), 20)
	assert_true(CrewModel.assign(GameState.data, DataDefs.crew, "gardens", "odo", DataDefs.buildings, mid))
	assert_eq(TrickleModel.pending(GameState.data, DataDefs.buildings, mid, DataDefs.crew), 20,
		"assignment preserves the accrued hour")
	assert_eq(TrickleModel.pending(GameState.data, DataDefs.buildings, mid + 3600, DataDefs.crew), 50,
		"20 baseline + 30 crewed for the second hour")

func test_rescue_survives_a_full_save_reload_cycle() -> void:
	CrewModel.rescue(GameState.data, "brisa")
	CrewModel.assign(GameState.data, DataDefs.crew, "wind_still", "brisa", DataDefs.buildings, T0)
	GameState.save_game()
	GameState.load_game(DataDefs.economy, T0 + 100, DataDefs.gizmos, DataDefs.buildings, DataDefs.crew)
	assert_true(CrewModel.is_rescued(GameState.data, "brisa"))
	assert_eq(CrewModel.crew_at(GameState.data, "wind_still"), "brisa")
	assert_eq(int(GameState.data["fuel"]["regen_seconds"]), 800,
		"load re-applies crew effects: 1200 / 1.5 with no wind still built")
```

Arithmetic check before trusting first-run green: with no Wind Still building, level 0, regen is `1200 / 1.5 = 800`; with the gardens at level 1 the crewed rate is 30/hour so the second-hour pending is `floor(1h x 20) + floor... ` computed as one window: `pending = floor(2h capped x rate)` after the rebase places `last_collect` at `mid - (20/30)h`, giving `floor((1 + 20/30)h x 30) = floor(50.0) = 50`.

- [ ] **Step 2: Run the file and confirm first-try pass (no-strict-RED ruling)**

Run `--import`, then the file. A failure is a production bug: investigate, fix production, never bend the test.

- [ ] **Step 3: Update the roadmap**

In `docs/ROADMAP.md`, replace the section:

```markdown
### Island mechanic rework (new, owner priority)
- The owner finds the island loop as it stands not interesting enough; it needs to become much more engaging than build-wait-collect rows. Direction is undecided: needs a brainstorm with the owner, then a spec. Raw material already in place: six home buildings plus two islet buildings, timed constructions on slot-capped plots, the trickle/crate/build-slot retention hooks, two restored islets with re-readable letters, and the two design-doc open questions below are natural inputs to the same conversation.
```

with:

```markdown
### Island mechanic rework (owner priority): crew + chains + run kit
- Direction settled 2026-09-07 (spec: docs/superpowers/specs/2026-09-07-crew-system-design.md, section 0): a closed bidirectional economy in three plans. Plan 10 (crew: rescued survivors staff buildings, rate seam CrewModel.multiplier_for): SHIPPED. Plan 11 (production chains: worked parts and provisions, conversion recipes, gizmo component costs): next, needs its spec. Plan 12 (run kit: setup-phase consumables and expedition provisioning): after 11.
```

- [ ] **Step 4: Run the full suite**

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add tests/test_crew_integration.gd tests/test_crew_integration.gd.uid docs/ROADMAP.md
git commit -m "test: prove the crew loop end to end"
```

---

## Manual smoke steps (owner runs these windowed/on-device, per the ongoing practice)

1. Start runs until a raft drifts across; steer a pod into it; the banner names the survivor and quotes their line.
2. On the island: the rescued crewmember's row appears; cycle their assignment; the building row shows them working.
3. With Odo on the Gardens, the trickle button's pending amount grows visibly faster than before.
4. With Brisa on the Wind Still, the fuel timer on main shortens.
5. Kill the app right after a rescue; relaunch; the crewmember is still home.
