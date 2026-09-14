# Plan 13: Gizmo Rarities Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each gizmo gets a fixed rarity tier gated by Workshop level for crafting; starters shrink to the commons; the Cargo Net's level scaling moves from relaunch speed to uses.

**Architecture:** Rarity is data (a `rarity` field per def plus a `rarity_unlocks` map in gizmos.json) enforced by one new CraftModel static helper that `can_craft` consumes and the workshop screen reads for locked-row rendering. No save schema change (stays v8): existing saves are grandfathered, rarity gates crafting only, never slotting.

**Tech Stack:** Godot 4 / GDScript, GUT 9.6.1 (vendored), JSON data defs.

**Spec:** docs/superpowers/specs/2026-09-14-gizmo-rarities-design.md (committed on main). The parent design doc is docs/design/2026-08-15-windfall-isles-design.md section 3.3.

## Global Constraints

- Test command (must exit 0): `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (the `godot` on PATH is 4.7.1 and runs this suite; do NOT use `$GODOT`/4.6 paths from older docs).
- After creating any new file, run `godot --headless --import` and then check `git status --porcelain`: every new `.gd` file's `.gd.uid` sidecar MUST be committed with it (recurring pitfall, bitten twice).
- The sandbox rejects compound bash commands (for-loops, `&&` chains with external scripts); run commands one at a time.
- JSON discipline: `JSON.parse_string` decodes all numbers as float and `Dictionary ==` does not coerce; never normalize in DataDefs; cast with `int()`/`float()`/`String()` at use sites and assert sites.
- GUT 9.6 auto-fails tests on pushed/engine errors; tests that intentionally trigger `push_warning` declare `assert_push_warning_count(...)` AFTER the trigger.
- GUT's strict warnings reject `:=` inference from untyped Array/Dictionary chains; declare explicit types.
- Tabs for indentation in .gd files. No em dashes in any authored text or copy.
- UI tests call handlers directly (`_on_craft_pressed(...)`, `_rebuild()`) and never press scene-changing buttons.
- Never state cumulative suite totals anywhere; list only the new/changed tests per task. The full suite green is the gate, whatever its count.
- Physics rule (not triggered by this plan's code paths, but binding if a task drifts): `add_child` of a physics body inside a `body_entered` chain must be `call_deferred`; velocity reads after impulses need `await wait_physics_frames(2)`.
- Commit messages end with: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`

---

### Task 1: Rarity data in gizmos.json + defs pinning tests

**Files:**
- Modify: `game/data/gizmos.json`
- Create: `tests/test_gizmo_rarity_defs.gd`

**Interfaces:**
- Produces: every entry in `gizmos.json` `defs` carries `"rarity": "common"|"uncommon"|"rare"`; top-level `"rarity_unlocks": {"common": 1, "uncommon": 2, "rare": 3}`. Tasks 2 and 4 read both. `starting_inventory` is NOT changed in this task (Task 3 does that).

- [ ] **Step 1: Write the failing tests**

Create `tests/test_gizmo_rarity_defs.gd`:

```gdscript
extends GutTest
## Authoring pins for gizmo rarity tiers (Plan 13, spec 3.3): rarity is an
## acquisition gate keyed to Workshop level; these tests keep the data honest.


func test_rarity_unlocks_map_exists() -> void:
	var unlocks: Dictionary = DataDefs.gizmos.get("rarity_unlocks", {})
	assert_eq(unlocks, {"common": 1, "uncommon": 2, "rare": 3})


func test_every_def_has_a_known_rarity() -> void:
	var unlocks: Dictionary = DataDefs.gizmos.get("rarity_unlocks", {})
	for gizmo_id in DataDefs.gizmos["defs"]:
		var def: Dictionary = (DataDefs.gizmos["defs"] as Dictionary)[gizmo_id]
		var rarity := String(def.get("rarity", ""))
		assert_true(unlocks.has(rarity),
			"%s has missing or unknown rarity '%s'" % [gizmo_id, rarity])


func test_unlock_levels_fit_the_workshop() -> void:
	var workshop: Dictionary = (DataDefs.buildings["defs"] as Dictionary)["workshop"]
	var max_level := int(workshop.get("max_level", 0))
	var unlocks: Dictionary = DataDefs.gizmos["rarity_unlocks"]
	for rarity in unlocks:
		var lv := int(unlocks[rarity])
		assert_true(lv >= 1 and lv <= max_level,
			"rarity '%s' unlocks at unreachable workshop level %d" % [rarity, lv])


func test_tier_table_is_pinned() -> void:
	var expected := {
		"wind_fan": "common",
		"balloon_cluster": "common",
		"cargo_net": "common",
		"magnet_buoy": "common",
		"crystal_prism": "uncommon",
		"lightning_jar": "uncommon",
		"chime_bell": "uncommon",
		"splitter_vane": "rare",
		"gyro_damper": "rare",
		"piston_kicker": "rare",
	}
	for gizmo_id in expected:
		assert_eq(String(((DataDefs.gizmos["defs"] as Dictionary)[gizmo_id] as Dictionary).get("rarity", "")),
			String(expected[gizmo_id]), gizmo_id)
	assert_eq((DataDefs.gizmos["defs"] as Dictionary).size(), expected.size(),
		"a new gizmo must join this tier table deliberately")
```

- [ ] **Step 2: Run the new file to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_gizmo_rarity_defs.gd -gexit`
Expected: FAIL (rarity_unlocks map missing, rarities missing from every def).

- [ ] **Step 3: Add the data**

In `game/data/gizmos.json`, add a top-level key after `"craft_max_level": 5,`:

```json
	"rarity_unlocks": {
		"common": 1,
		"uncommon": 2,
		"rare": 3
	},
```

Add a `"rarity"` field to each def (place it right after `"name"` in each entry):

| def | rarity value to add |
|---|---|
| wind_fan | `"rarity": "common",` |
| balloon_cluster | `"rarity": "common",` |
| cargo_net | `"rarity": "common",` |
| magnet_buoy | `"rarity": "common",` |
| crystal_prism | `"rarity": "uncommon",` |
| lightning_jar | `"rarity": "uncommon",` |
| chime_bell | `"rarity": "uncommon",` |
| splitter_vane | `"rarity": "rare",` |
| gyro_damper | `"rarity": "rare",` |
| piston_kicker | `"rarity": "rare",` |

Do NOT touch `starting_inventory` in this task. Preserve the file's existing indentation style exactly as found; edit surgically, never reformat the whole file (a Plan 12-era commit wholesale-reformatted this file and polluted diffs).

- [ ] **Step 4: Run the new file to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_gizmo_rarity_defs.gd -gexit`
Expected: PASS (4 tests).

- [ ] **Step 5: Import, sidecar check, full suite**

Run: `godot --headless --import`
Run: `git status --porcelain` (the new `tests/test_gizmo_rarity_defs.gd.uid` must be present; stage it)
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: all green (no behavior changed yet).

- [ ] **Step 6: Commit**

```bash
git add game/data/gizmos.json tests/test_gizmo_rarity_defs.gd tests/test_gizmo_rarity_defs.gd.uid
git commit -m "feat: rarity tiers on gizmo defs with authoring pins

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: CraftModel rarity gate

**Files:**
- Modify: `game/base/craft_model.gd`
- Modify: `tests/test_craft_model.gd`
- Modify: `tests/test_region_2_integration.gd:64-67`
- Modify: `tests/test_island_integration.gd:32-36`
- Modify: `tests/test_workshop_screen.gd:80-89`

**Interfaces:**
- Consumes: `rarity` / `rarity_unlocks` from Task 1; existing `IslandModel.building_level(island: Dictionary, building_id: String) -> int`.
- Produces: `CraftModel.rarity_unlocked(island: Dictionary, gizmo_defs: Dictionary, gizmo_id: String) -> bool` (static; fail-closed with one `push_warning` on missing/unknown rarity). `can_craft` now returns false for rarity-locked gizmos. Task 4's UI reads `rarity_unlocked`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_craft_model.gd`:

```gdscript
func test_rarity_gates_follow_workshop_level() -> void:
	state.data["currencies"]["brasswork"] = 5
	var expectations := {
		1: {"wind_fan": true, "crystal_prism": false, "splitter_vane": false},
		2: {"wind_fan": true, "crystal_prism": true, "splitter_vane": false},
		3: {"wind_fan": true, "crystal_prism": true, "splitter_vane": true},
	}
	for level in expectations:
		(state.data["island"]["plots"]["plot_0"] as Dictionary)["level"] = level
		var expected: Dictionary = expectations[level]
		for gizmo_id in expected:
			assert_eq(CraftModel.rarity_unlocked(state.data["island"], DataDefs.gizmos, String(gizmo_id)),
				bool(expected[gizmo_id]),
				"workshop lv %d vs %s" % [int(level), String(gizmo_id)])


func test_locked_rarity_blocks_can_craft_even_when_affordable() -> void:
	assert_false(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "crystal_prism"),
		"a level 1 workshop cannot craft uncommons no matter the balance")
	(state.data["island"]["plots"]["plot_0"] as Dictionary)["level"] = 2
	assert_true(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "crystal_prism"))


func test_unknown_rarity_fails_closed_with_a_warning() -> void:
	var defs := {
		"defs": {"mystery": {"rarity": "mythic", "craft_cost": {"parts": 1}, "craft_seconds": 60}},
		"rarity_unlocks": {"common": 1},
		"craft_max_level": 5,
	}
	assert_false(CraftModel.rarity_unlocked(state.data["island"], defs, "mystery"),
		"authoring errors lock the recipe, never open it")
	assert_push_warning_count(1)


func test_missing_rarity_fails_closed_with_a_warning() -> void:
	var defs := {
		"defs": {"legacy": {"craft_cost": {"parts": 1}, "craft_seconds": 60}},
		"rarity_unlocks": {"common": 1},
		"craft_max_level": 5,
	}
	assert_false(CraftModel.rarity_unlocked(state.data["island"], defs, "legacy"))
	assert_push_warning_count(1)


func test_owned_but_locked_gizmo_still_cannot_craft() -> void:
	state.data["gizmos"]["owned"]["splitter_vane"] = 2
	state.data["currencies"]["cloudsilk"] = 50
	assert_false(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "splitter_vane"),
		"grandfathered ownership never unlocks CRAFTING below the rarity's workshop level")
```

Note: `before_each` already sets the workshop plot at level 1 and funds parts/cloudsilk; the crystal_prism test needs no extra funding (before_each grants cloudsilk 50).

- [ ] **Step 2: Run the file to verify the new tests fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_craft_model.gd -gexit`
Expected: the five new tests FAIL with "Nonexistent function 'rarity_unlocked'" (and the can_craft assertions fail); the pre-existing tests still pass.

- [ ] **Step 3: Implement the gate**

In `game/base/craft_model.gd`, add after `active_crafts` (before `can_craft`):

```gdscript
static func rarity_unlocked(island: Dictionary, gizmo_defs: Dictionary, gizmo_id: String) -> bool:
	# Rarity is an acquisition gate keyed to Workshop level (Plan 13, spec
	# 3.3). Fail-closed authoring guard: a def whose rarity is missing or
	# absent from rarity_unlocks cannot be crafted.
	var def: Dictionary = (gizmo_defs.get("defs", {}) as Dictionary).get(gizmo_id, {})
	var rarity := String(def.get("rarity", ""))
	var unlocks: Dictionary = gizmo_defs.get("rarity_unlocks", {})
	if not unlocks.has(rarity):
		push_warning("Gizmo '%s' has missing or unknown rarity '%s'; crafting locked" % [gizmo_id, rarity])
		return false
	return IslandModel.building_level(island, "workshop") >= int(unlocks[rarity])
```

In `can_craft`, insert the gate immediately after the `if def.is_empty(): return false` check (so unknown gizmo ids keep failing on emptiness without a rarity warning):

```gdscript
	if not rarity_unlocked(data.get("island", {}), gizmo_defs, gizmo_id):
		return false
```

- [ ] **Step 4: Run the file to verify the new tests pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_craft_model.gd -gexit`
Expected: the five new tests PASS; `test_brasswork_gates_the_brass_recipes` now FAILS (gyro_damper is rare, the test's workshop is level 1). That failure is expected and fixed in the next step.

- [ ] **Step 5: Update the pre-existing tests the gate intentionally broke**

In `tests/test_craft_model.gd`, `test_brasswork_gates_the_brass_recipes`: add a level bump as the first line so the test isolates the brasswork gate again:

```gdscript
func test_brasswork_gates_the_brass_recipes() -> void:
	(state.data["island"]["plots"]["plot_0"] as Dictionary)["level"] = 3
	assert_false(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "gyro_damper"),
		"50 parts but zero brasswork: locked")
	state.data["currencies"]["brasswork"] = 2
	assert_true(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "gyro_damper"))
```

In `tests/test_region_2_integration.gd`, immediately after the `IslandModel.complete_build(...)` line (line 65) and before the `can_craft` assertion, insert:

```gdscript
	# Rarity gate (Plan 13): the Gyro Damper is rare and needs Workshop Lv 3.
	(state.data["island"]["plots"]["plot_1"] as Dictionary)["level"] = 3
```

In `tests/test_island_integration.gd`, `test_flywheel_build_craft_upgrade_with_fake_clock`: the flywheel crafted the rare splitter_vane at a level 1 workshop; switch it to the common wind_fan (craft_seconds 120, cost 2 parts, starter at level 1). Replace lines 32-36 with:

```gdscript
	assert_true(CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan", t))
	t += 121
	CraftModel.complete_craft(state.data, timers.collect("craft_wind_fan", t))
	assert_eq(int(state.data["gizmos"]["owned"]["wind_fan"]), 2,
		"the flywheel: runs feed the base, the base upgrades the board (spec 5)")
```

In `tests/test_workshop_screen.gd`, `test_unowned_recipe_row_is_labeled_and_craftable`: gyro_damper is rare; raise the workshop first. Insert as the first line of the test:

```gdscript
	GameState.data["island"]["plots"]["plot_0"]["level"] = 3
```

- [ ] **Step 6: Run the full suite**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: all green. If any OTHER test fails on a rare/uncommon craft at a low workshop level, apply the same pattern: raise that test's workshop plot level to the rarity's unlock level (never weaken the gate).

- [ ] **Step 7: Commit**

```bash
git add game/base/craft_model.gd tests/test_craft_model.gd tests/test_region_2_integration.gd tests/test_island_integration.gd tests/test_workshop_screen.gd
git commit -m "feat: workshop level gates gizmo crafting by rarity

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Starters shrink to the commons

**Files:**
- Modify: `game/data/gizmos.json` (starting_inventory only)
- Modify: `tests/test_gizmo_rarity_defs.gd` (one new pin)
- Modify: `tests/test_save_schema.gd:82-86`
- Modify: `tests/test_run_setup.gd:169-173`

**Interfaces:**
- Consumes: `rarity` fields from Task 1.
- Produces: `starting_inventory` in gizmos.json contains exactly the four commons at 1. `SaveSchema.default_data`, `_fresh_gizmos`, and the migrate merge-grant are all UNCHANGED (they read `starting_inventory` and inherit the shrink). Existing saves keep everything they own.

- [ ] **Step 1: Write the failing pin test**

Append to `tests/test_gizmo_rarity_defs.gd`:

```gdscript
func test_starting_inventory_is_exactly_the_commons() -> void:
	var starters: Dictionary = DataDefs.gizmos["starting_inventory"]
	for gizmo_id in DataDefs.gizmos["defs"]:
		var rarity := String(((DataDefs.gizmos["defs"] as Dictionary)[gizmo_id] as Dictionary).get("rarity", ""))
		assert_eq(starters.has(gizmo_id), rarity == "common",
			"%s: only commons are starters (Plan 13)" % gizmo_id)
	for gizmo_id in starters:
		assert_eq(int(starters[gizmo_id]), 1, "starters are granted at level 1")
```

- [ ] **Step 2: Run the file to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_gizmo_rarity_defs.gd -gexit`
Expected: the new test FAILS (crystal_prism etc. are still starters); the Task 1 tests still pass.

- [ ] **Step 3: Shrink the starting inventory**

In `game/data/gizmos.json`, replace the `starting_inventory` value with:

```json
	"starting_inventory": {
		"wind_fan": 1,
		"balloon_cluster": 1,
		"cargo_net": 1,
		"magnet_buoy": 1
	},
```

- [ ] **Step 4: Run the file to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_gizmo_rarity_defs.gd -gexit`
Expected: PASS (5 tests).

- [ ] **Step 5: Update the tests that pinned the old eight-starter grant**

In `tests/test_save_schema.gd`, replace `test_current_version_is_eight_and_defaults_grant_eight` (lines 82-86) with:

```gdscript
func test_current_version_is_eight_and_defaults_grant_the_commons() -> void:
	assert_eq(SaveSchema.CURRENT_VERSION, 8)
	var data := SaveSchema.default_data(DEFS, DataDefs.gizmos)
	assert_eq((data["gizmos"]["owned"] as Dictionary).size(), 4,
		"only common gizmos are starters; everything else is craft-to-acquire (Plan 13)")
```

In `tests/test_run_setup.gd`, `test_saved_loadout_prefills_the_board` (line 169): `GizmoLoadout.set_slot` refuses unowned gizmos and chime_bell is no longer a starter. Insert as the first line of the test:

```gdscript
	GameState.data["gizmos"]["owned"]["chime_bell"] = 1
```

- [ ] **Step 6: Run the full suite and sweep the fallout**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: all green. If a test fails because a non-common gizmo is no longer in the default owned dict (a `set_slot`/`place` returning false, an install asserting a gizmo node, or an `owned[...]` KeyError), add a one-line grandfather seed at the top of THAT test, mirroring Step 5's pattern: `GameState.data["gizmos"]["owned"]["<gizmo_id>"] = 1` (or `state.data` in model-level files). Never re-add non-commons to starting_inventory.

- [ ] **Step 7: Commit**

```bash
git add game/data/gizmos.json tests/test_gizmo_rarity_defs.gd tests/test_save_schema.gd tests/test_run_setup.gd
git commit -m "feat: starting inventory shrinks to the common gizmos

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

(Include in the `git add` any additional test files the Step 6 sweep touched.)

---

### Task 4: Workshop screen lock states

**Files:**
- Modify: `game/base/workshop_screen.gd`
- Modify: `tests/test_workshop_screen.gd`

**Interfaces:**
- Consumes: `CraftModel.rarity_unlocked(island, gizmo_defs, gizmo_id) -> bool` from Task 2; `rarity`/`rarity_unlocks` data from Task 1.
- Produces: locked idle rows render label-only (dimmed, "Requires Workshop Lv N"); unlocked idle rows append "[Rarity]" after the cost; lock state joins `_signature` so Workshop upgrades rebuild rows; an in-flight craft timer on a locked gizmo still renders its countdown/Collect (grandfathered).

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_workshop_screen.gd`:

```gdscript
func test_locked_rarity_row_shows_requirement_and_no_button() -> void:
	var text: String = screen._gizmo_label_text("crystal_prism", TimeUtil.now())
	assert_string_contains(text, "Requires Workshop Lv 2")
	var index: int = (DataDefs.gizmos["defs"] as Dictionary).keys().find("crystal_prism")
	var row: HBoxContainer = screen.get_node("Rows").get_child(index) as HBoxContainer
	assert_eq(row.get_child_count(), 1, "label only: no Craft button on a rarity-locked row")
	assert_almost_eq((row.get_child(0) as Label).modulate.a, 0.5, 0.001, "locked rows render dimmed")

func test_unlocked_idle_row_shows_its_rarity() -> void:
	assert_string_contains(screen._gizmo_label_text("wind_fan", TimeUtil.now()), "[Common]")

func test_locked_craft_press_is_refused() -> void:
	GameState.data["currencies"]["cloudsilk"] = 50
	screen._on_craft_pressed("crystal_prism")
	assert_false(TimerService.active_timers().has("craft_crystal_prism"),
		"the model gate holds even if a Craft press sneaks through")

func test_workshop_upgrade_is_structural_for_the_signature() -> void:
	screen._refresh_tick()
	var locked_signature: String = screen._last_signature
	GameState.data["island"]["plots"]["plot_0"]["level"] = 2
	screen._refresh_tick()
	assert_ne(screen._last_signature, locked_signature,
		"unlocking a rarity must rebuild rows, not just relabel them")

func test_inflight_craft_on_a_now_locked_gizmo_still_collects() -> void:
	GameState.data["island"]["plots"]["plot_0"]["level"] = 2
	GameState.data["currencies"]["cloudsilk"] = 50
	screen._rebuild()
	screen._on_craft_pressed("crystal_prism")
	GameState.data["island"]["plots"]["plot_0"]["level"] = 1
	TimerService._state.data["timers"]["craft_crystal_prism"]["ends_at"] = 0
	screen._rebuild()
	var index: int = (DataDefs.gizmos["defs"] as Dictionary).keys().find("crystal_prism")
	var row: HBoxContainer = screen.get_node("Rows").get_child(index) as HBoxContainer
	assert_eq(row.get_child_count(), 2, "a grandfathered in-flight craft keeps its Collect! button")
	screen._on_collect_pressed("crystal_prism")
	assert_eq(int(GameState.data["gizmos"]["owned"]["crystal_prism"]), 1,
		"the craft the player already paid for completes")
```

- [ ] **Step 2: Run the file to verify the new tests fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_workshop_screen.gd -gexit`
Expected: the five new tests FAIL (no requirement text, Craft buttons present on locked rows, signature unchanged by level); pre-existing tests pass. `test_locked_craft_press_is_refused` may already pass thanks to the Task 2 model gate; that is acceptable, note it and move on.

- [ ] **Step 3: Implement the lock rendering**

In `game/base/workshop_screen.gd`:

Replace `_signature` with:

```gdscript
func _signature(now: int) -> String:
	var parts := PackedStringArray()
	for gizmo_id in DataDefs.gizmos["defs"]:
		var timer_id := "craft_" + String(gizmo_id)
		if TimerService.active_timers().has(timer_id):
			parts.append("d" if TimerService.is_done(timer_id, now) else "r")
		elif CraftModel.rarity_unlocked(GameState.data["island"], DataDefs.gizmos, String(gizmo_id)):
			parts.append("i")
		else:
			parts.append("l")
	return ",".join(parts)
```

Replace `_gizmo_label_text` with:

```gdscript
func _gizmo_label_text(gizmo_id: String, now: int) -> String:
	var owned: Dictionary = GameState.data["gizmos"]["owned"]
	var def: Dictionary = (DataDefs.gizmos["defs"] as Dictionary).get(gizmo_id, {})
	var timer_id := "craft_" + gizmo_id
	var rarity := String(def.get("rarity", ""))
	# A locked idle row shows only the unlock requirement; an in-flight craft
	# on a locked gizmo is grandfathered and renders like any other timer.
	if not TimerService.active_timers().has(timer_id) \
			and not CraftModel.rarity_unlocked(GameState.data["island"], DataDefs.gizmos, gizmo_id):
		var unlock_level := int((DataDefs.gizmos.get("rarity_unlocks", {}) as Dictionary).get(rarity, 0))
		return "%s  Requires Workshop Lv %d" % [String(def.get("name", gizmo_id)), unlock_level]
	var text: String
	if owned.has(gizmo_id):
		text = "%s Lv %d" % [String(def.get("name", gizmo_id)), int(owned[gizmo_id])]
	else:
		text = "%s (not owned)" % String(def.get("name", gizmo_id))
	if TimerService.active_timers().has(timer_id) and not TimerService.is_done(timer_id, now):
		text += "  (%ds)" % TimerService.remaining(timer_id, now)
	elif not TimerService.active_timers().has(timer_id):
		text += "  cost: %s [%s]" % [_cost_text(def.get("craft_cost", {})), rarity.capitalize()]
	return text
```

In `_rebuild`, replace the row-button block (the `if TimerService.active_timers().has(timer_id): ... else: var craft ...` section) with:

```gdscript
		var timer_id := "craft_" + String(gizmo_id)
		if TimerService.active_timers().has(timer_id):
			if TimerService.is_done(timer_id, now):
				var collect := Button.new()
				collect.text = "Collect!"
				collect.pressed.connect(_on_collect_pressed.bind(String(gizmo_id)))
				row.add_child(collect)
			elif Ads.service.is_available(AdService.Placement.TIMER_SKIP):
				var skip := Button.new()
				skip.text = "Skip (ad)"
				skip.pressed.connect(_on_skip_pressed.bind(timer_id))
				row.add_child(skip)
		elif CraftModel.rarity_unlocked(GameState.data["island"], DataDefs.gizmos, String(gizmo_id)):
			var craft := Button.new()
			craft.text = "Craft"
			craft.pressed.connect(_on_craft_pressed.bind(String(gizmo_id)))
			row.add_child(craft)
		else:
			label.modulate.a = 0.5
		rows.add_child(row)
```

(Everything above the button block in the row loop stays exactly as it is.)

- [ ] **Step 4: Run the file to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_workshop_screen.gd -gexit`
Expected: PASS, including the pre-existing tests (`test_idle_rows_show_the_parts_cost` still passes: the wind_fan label now reads "... cost: 2 parts [Common]" and the assertion is a substring match).

- [ ] **Step 5: Run the full suite**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add game/base/workshop_screen.gd tests/test_workshop_screen.gd
git commit -m "feat: workshop rows dim and gate rarity-locked recipes

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Cargo Net uses scale with level (speed stops scaling)

**Files:**
- Modify: `game/run/gizmos/cargo_net.gd`
- Modify: `tests/test_cargo_net.gd`
- Modify: `tests/test_gizmo_integration.gd` (one new real-contact test)

**Interfaces:**
- Consumes: existing `GizmoBase.setup(gizmo_defs, gizmo_level, run_context)` / `level` / `scaled()`.
- Produces: `_uses_left = int(defs.get("uses", 1)) * level` at configure and recharge; `_release` reads `redrop_speed` raw (level-independent). No signature changes.

- [ ] **Step 1: Write the failing unit tests**

Append to `tests/test_cargo_net.gd`:

```gdscript
func make_net(level: int) -> Node:
	var scaled_net = add_child_autofree(NetScene.instantiate())
	scaled_net.position = Vector2(200, 500)
	scaled_net.setup(net_defs, level, self)
	return scaled_net

func test_uses_scale_with_level() -> void:
	assert_eq(make_net(2)._uses_left, 2, "uses = base uses x level (Plan 13 rebalance)")
	assert_eq(make_net(5)._uses_left, 5)

func test_recharge_restores_level_scaled_uses() -> void:
	var lv3 = make_net(3)
	lv3._uses_left = 0
	lv3.get_node("Visual").modulate.a = 0.4
	lv3.recharge()
	assert_eq(lv3._uses_left, 3)
	assert_almost_eq(lv3.get_node("Visual").modulate.a, 1.0, 0.001)

func test_relaunch_speed_is_level_independent() -> void:
	var lv5 = make_net(5)
	var pod := make_pod()
	lv5._on_body_entered(pod)
	await wait_physics_frames(2)
	lv5._release(weakref(pod), add_child_autofree(Timer.new()))
	assert_almost_eq(pod.linear_velocity.length(), float(net_defs["redrop_speed"]), 1.0,
		"level scaling moved from speed to uses; the relaunch speed is the raw defs value")
```

Append to `tests/test_gizmo_integration.gd` (after `test_cargo_net_catches_holds_and_redrops_to_barge`):

```gdscript
func test_level_2_cargo_net_keeps_a_use_after_a_real_catch() -> void:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	board.build(DataDefs.load_json("res://tests/fixtures/test_region_slot.json"), run_defs)
	board.install_gizmos({"slot_0": "cargo_net"}, DataDefs.gizmos, {"cargo_net": 2}, self)
	var pod: Pod = PodScene.instantiate()
	pod.position = Vector2(360, 160)
	pod.setup(run_defs["pod"])
	board.add_child(pod)
	var caught: bool = await wait_for_signal(board.pod_caught, 12.0)
	assert_true(caught, "held, re-dropped, and still landed within 12s")
	var net: GizmoBase = board.get_node("Gizmos").get_child(0)
	assert_eq(net._uses_left, 1, "a level 2 net has a second catch left after one real contact")
```

- [ ] **Step 2: Run both files to verify the new tests fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_cargo_net.gd -gexit`
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_gizmo_integration.gd -gexit`
Expected: `test_uses_scale_with_level` and `test_recharge_restores_level_scaled_uses` FAIL (uses stay 1); `test_relaunch_speed_is_level_independent` FAILS (speed is scaled 2.0x at level 5); the new integration test FAILS (`_uses_left` 0, not 1). Pre-existing tests pass.

- [ ] **Step 3: Implement the rebalance**

In `game/run/gizmos/cargo_net.gd`:

In `_configure`, change the first line to:

```gdscript
	_uses_left = int(defs.get("uses", 1)) * level
```

In `_release`, change the speed line to read the defs value raw:

```gdscript
	var speed := float(defs.get("redrop_speed", 420.0))
```

In `recharge`, change the uses line to:

```gdscript
	_uses_left = int(defs.get("uses", 1)) * level
```

Update the class docstring (lines 3-6) to:

```gdscript
## Cargo Net (spec 3.3): catches a falling pod and re-drops it at a chosen
## angle toward the board center. Uses scale with level (Plan 13 rebalance:
## the net's identity is extra passes through the peg field; relaunch speed
## is level-independent). The hold Timer is a child of the net (dies with
## the scene) and binds a weakref (survives the pod being freed), per the
## project's timer-lifetime rule.
```

- [ ] **Step 4: Run both files to verify they pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_cargo_net.gd -gexit`
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_gizmo_integration.gd -gexit`
Expected: PASS, including the pre-existing `test_recharge_restores_the_net` (level 1: 1 x 1 = 1) and `test_single_use` (level 1 net still single-use).

- [ ] **Step 5: Run the full suite**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add game/run/gizmos/cargo_net.gd tests/test_cargo_net.gd tests/test_gizmo_integration.gd
git commit -m "feat: cargo net uses scale with level instead of relaunch speed

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Roadmap update

**Files:**
- Modify: `docs/ROADMAP.md`

**Interfaces:**
- Consumes: nothing from other tasks (docs only).
- Produces: the roadmap reflects Plan 13 shipped and the corrected test environment.

- [ ] **Step 1: Update the roadmap**

In `docs/ROADMAP.md`:

1. Replace the "### Gizmo rarities (spec 3.3)" section body (both bullet lines) with:

```markdown
- SHIPPED (Plan 13, spec: docs/superpowers/specs/2026-09-14-gizmo-rarities-design.md): static rarity per def (`rarity` + `rarity_unlocks` in gizmos.json), Workshop level gates crafting via CraftModel.rarity_unlocked (fail-closed on unknown rarities), starters shrunk to the four commons (existing saves grandfathered, still schema v8), workshop screen dims locked rows. Cargo Net rider landed: uses scale with level, relaunch speed no longer does. Future gizmos: add `rarity` to the def and extend the pinned tier table in tests/test_gizmo_rarity_defs.gd.
```

2. In "## Environment and process", replace the Godot-binary and test-command bullets with:

```markdown
- Godot binary: `godot` on PATH (4.7.1) runs the suite fine with the vendored GUT 9.6.1; the old 4.6.3-only note is obsolete. `/Applications/Godot-4.6.app/Contents/MacOS/Godot` remains available if a regression ever appears.
- Test command (must exit 0): `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
```

3. Update the "**As of:**" header line to reflect the current main commit and date at merge time (fill in the real values when executing; do not state a cumulative test count, write "full suite green").

- [ ] **Step 2: Verify and commit**

Run: `git diff docs/ROADMAP.md` and read it once for typos and em dashes (none allowed).

```bash
git add docs/ROADMAP.md
git commit -m "docs: roadmap marks gizmo rarities shipped, fixes stale env notes

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Final verification (for the whole-branch reviewer)

- Full suite: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` exits 0.
- `git status --porcelain` shows no untracked `.gd.uid` sidecars.
- Spec coverage spot-checks: rarity gates crafting only (GizmoLoadout untouched by this plan); no schema bump (SaveSchema untouched); grandfathering (owned dicts never pruned anywhere); the workshop's locked-row label never shows for a row with an active craft timer.
- Owner smoke additions (windowed/on-device, waived headless): a fresh save shows four gizmo chips in setup; the workshop at Lv1 shows dimmed rows for uncommons/rares; upgrading the Workshop to Lv2 un-dims the uncommons on the next tick.
