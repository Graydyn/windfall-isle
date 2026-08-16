# Windfall Isles Plan 3b: Gizmo Set Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the MVP gizmo vocabulary: the run-context methods (`add_bonus`, `set_next_barge_multiplier`, `request_split`), catch-source tagging, save schema v3 with a merge-grant migration, and the five remaining gizmos (Lightning Jar, Chime Bell, Magnet Buoy, Cargo Net, Splitter Vane), plus the three cleanup items queued by Plan 3a's final review.

**Architecture:** The context duck-type documented on `GizmoBase` becomes real: the run scene implements the three methods, `RunModel` gains bonus-loot and split-pod bookkeeping, and `Skyfield.pod_caught` gains a `source` tag ("barge"/"sea") so the Chime Bell's next-barge multiplier applies only to barges. Each gizmo remains a self-contained scene configured from `gizmos.json`; schema v3's `_migrate_2_to_3` merge-grants newly introduced starters into existing saves without touching owned levels, proving the multi-hop migration loop (v1 to v3).

**Tech Stack:** Godot 4.6.3 (GDScript; Area2D contact zones; RigidBody2D freeze for the net; scene-owned Timer + weakref per the established footgun rule), GUT 9.6.1 headless.

**Spec:** [docs/design/2026-08-15-windfall-isles-design.md](../design/2026-08-15-windfall-isles-design.md) section 3.3 (the gizmo table), 7.2, 7.3. Plans 1-3a are merged on main; Plan 3a's plan is [2026-08-16-windfall-isles-plan-3a-gizmo-framework.md](2026-08-16-windfall-isles-plan-3a-gizmo-framework.md).

## Global Constraints

- Engine: Godot 4.6.x pinned; `$GODOT` = `/Applications/Godot-4.6.app/Contents/MacOS/Godot` (4.6.3). Never plain `godot` or `/Applications/Godot.app` (4.7).
- GDScript only; tabs for indentation.
- Every tunable number lives in `game/data/*.json` (spec 7.2); gizmos are self-contained scenes on the common interface so new gizmos are additive.
- Save schema versioned with per-version migrations (spec 7.3); this plan bumps to v3. Existing v2 saves (the project owner's) must gain the five new starters without losing anything; v1 saves must hop cleanly to v3.
- Canonical test command (must exit 0): `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- Binding repo lessons (Plans 1-3a): commit `.gd.uid` sidecars with scripts and verify with `git status --porcelain` after `--import`; error-count assertions declared AFTER the triggering call; `int()`/`float()` wrap every JSON-sourced read; tests assert int-cast scalars, never whole dicts, against JSON-sourced data; never bind a freeable object into a `SceneTreeTimer` callable with a typed parameter (scene-owned child Timer + `weakref()` instead); reading `linear_velocity` right after an impulse needs `await wait_physics_frames(2)`; production impulses stay mass-respecting (`apply_central_impulse`), never direct velocity substitution; `assert_signal_emitted_with_parameters` takes NO message argument (its 4th positional is an emission index); GUT strict warnings reject `:=` inference from untyped Array chains; no cumulative suite totals in expectations.
- Contact-gizmo convention (new in this plan, from 3a's final review): any contact gizmo early-returns on `body.has_meta("caught")`.
- Commit after every task, conventional-commit messages.

## Interfaces consumed from Plans 1-3a (merged on main, exact)

- `GizmoBase`: `defs/level/context` vars, `setup(gizmo_defs, gizmo_level, run_context)`, `_configure()` override, `scaled(base) -> float` (+25% per level above 1). Context duck-type doc lists `add_bonus(payout)`, `set_next_barge_multiplier(factor)`, `request_split(pod) -> bool` (implemented by this plan).
- `Skyfield`: `build`, `install_gizmos(loadout, gizmo_defs, owned, context)`, `signal pod_caught(pod, payout)` (this plan adds a `source` param), `_on_catcher_body`, `sea_payout`, containers, `"caught"` meta convention, `Gizmos` container.
- `salvage_run.gd`: `model: RunModel`, `pod_defs`, `board`, `_on_pod_caught(pod, payout)` (gains `source`), `_on_pod_timeout(pod_ref, watchdog)`, `_start_watchdog(pod)`, `_compute_payout(pod, base)`, `PodScene` const.
- `RunModel`: `loot`, `pods_in_flight`, `max_active_pods`, `abandoned`, `resolve_pod`, `loot_changed`, `run_over`.
- `SaveSchema`: `CURRENT_VERSION == 2`, `default_data(defs, gizmo_defs={})`, `migrate(data, gizmo_defs={})`, `_migrate_1_to_2`, `_fresh_gizmos`.
- `DataDefs.gizmos` (`starting_inventory`, `defs`); `GizmoLoadout`; `Geometry.circle_points`; `Pod` (`setup`, group `"pods"`); `Economy.add`.
- Existing gizmo scene pattern: root Node2D + `Zone` (Area2D) + `Shape` (CollisionShape2D) + `Visual` (Polygon2D); per-instance shapes built in `_configure`; `class_name` additions for typed tests are an allowed disclosed deviation.

## File Structure

```
tests/ (several files)                 # T1 wait_frames -> wait_physics_frames sweep
game/run/gizmos/gizmo_base.gd          # T1 modify (caught-convention doc line)
game/core/save_schema.gd               # T1 modify (empty-grant warning), T2 modify (v3 + _migrate_2_to_3)
game/data/gizmos.json                  # T2 modify (5 new defs + full 8-starter inventory)
tests/test_save_schema.gd              # T2 modify (2 updated tests, 3 new)
game/run/run_model.gd                  # T3 modify (add_bonus_loot, add_split_pod)
game/run/skyfield.gd                   # T3 modify (source tag on catchers), T4 modify (pegs group)
game/run/salvage_run.gd                # T3 modify (context methods, barge multiplier, source param)
tests/test_run_model.gd                # T3 append
tests/test_salvage_run.gd              # T3 append
tests/test_skyfield.gd                 # T3 append 1, T4 append 1
game/run/gizmos/lightning_jar.gd/.tscn # T4
tests/test_lightning_jar.gd            # T4
game/run/gizmos/chime_bell.gd/.tscn    # T5
tests/test_chime_bell.gd               # T5
game/run/gizmos/magnet_buoy.gd/.tscn   # T6
tests/test_magnet_buoy.gd              # T6
game/run/gizmos/cargo_net.gd/.tscn     # T7
tests/test_cargo_net.gd                # T7
game/run/gizmos/splitter_vane.gd/.tscn # T8
tests/test_splitter_vane.gd            # T8
tests/test_gizmo_integration.gd        # T9 append (net physics, splitter through the real scene)
```

---

### Task 1: Cleanup trio from Plan 3a's final review

**Files:**
- Modify: every test file using `wait_frames` (find with `grep -rln "wait_frames(" tests/`)
- Modify: `game/run/gizmos/gizmo_base.gd` (doc comment)
- Modify: `game/core/save_schema.gd` (`_migrate_1_to_2` warning)
- Test: existing suite (this task adds no new tests; its deliverable is zero deprecation warnings and the guard line)

**Interfaces:**
- Consumes: existing tests and schema.
- Produces: `await wait_physics_frames(N)` replaces every `await wait_frames(N)`; GizmoBase's doc comment gains the line "Contact gizmos that can overlap catchers must early-return on body.has_meta(\"caught\")."; `_migrate_1_to_2` pushes a warning when the grant would be empty.

- [ ] **Step 1: Sweep the deprecated waits**

```bash
grep -rln "wait_frames(" tests/
```

In every hit, replace `await wait_frames(` with `await wait_physics_frames(` (same argument). Do not touch `wait_seconds` or `wait_for_signal`.

- [ ] **Step 2: Add the convention line and the guard**

In `game/run/gizmos/gizmo_base.gd`, append to the class doc comment (the `##` block):

```gdscript
## Contact gizmos that can overlap catchers must early-return on
## body.has_meta("caught") so resolved pods trigger nothing further.
```

In `game/core/save_schema.gd`, at the top of `_migrate_1_to_2`, insert:

```gdscript
	if (gizmo_defs.get("starting_inventory", {}) as Dictionary).is_empty():
		push_warning("Migrating v1 save with no gizmo defs; starting grant will be empty until a later merge-grant hop")
```

- [ ] **Step 3: Run the full suite**

```bash
$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: all green, exit 0, and the summary's `Deprecated` count drops to 0. One pre-existing schema test (`test_migrate_v1_without_gizmo_defs_still_structures`) exercises the empty-grant path and will now emit one push_warning; GUT does not fail on warnings.

- [ ] **Step 4: Commit**

```bash
git add -A tests game/run/gizmos/gizmo_base.gd game/core/save_schema.gd
git commit -m "chore: migrate to wait_physics_frames, document caught convention, warn on empty grant"
```

---

### Task 2: Schema v3 and the five new gizmo defs

**Files:**
- Modify: `game/data/gizmos.json`
- Modify: `game/core/save_schema.gd`
- Test: `tests/test_save_schema.gd` (update 2 existing tests, append 3)

**Interfaces:**
- Consumes: v2 schema (3a).
- Produces:
  - `gizmos.json` `starting_inventory` lists all 8 gizmos at level 1; `defs` gains `lightning_jar`, `chime_bell`, `magnet_buoy`, `cargo_net`, `splitter_vane` with the exact keys below (T4-T8 consume them). Scenes do not exist yet; `install_gizmos` skips missing scenes gracefully (verified in 3a), so data may land first.
  - `SaveSchema.CURRENT_VERSION == 3`; `_migrate_2_to_3(data, gizmo_defs)` merge-grants starters absent from `owned` WITHOUT touching existing levels; `migrate` chains hops sequentially (v1 -> v2 -> v3).

- [ ] **Step 1: Extend the data file**

In `game/data/gizmos.json`, replace `starting_inventory` with:

```json
	"starting_inventory": {
		"wind_fan": 1,
		"balloon_cluster": 1,
		"crystal_prism": 1,
		"lightning_jar": 1,
		"chime_bell": 1,
		"magnet_buoy": 1,
		"cargo_net": 1,
		"splitter_vane": 1
	},
```

and add to `defs` (after `crystal_prism`):

```json
		"lightning_jar": {
			"name": "Lightning Jar",
			"scene": "res://game/run/gizmos/lightning_jar.tscn",
			"zone_radius": 24.0,
			"zap_radius": 150.0,
			"pegs_zapped": 3,
			"scrap_per_peg": 2,
			"charges": 2
		},
		"chime_bell": {
			"name": "Chime Bell",
			"scene": "res://game/run/gizmos/chime_bell.tscn",
			"radius": 26.0,
			"barge_multiplier": 2.0,
			"uses_per_run": 2
		},
		"magnet_buoy": {
			"name": "Magnet Buoy",
			"scene": "res://game/run/gizmos/magnet_buoy.tscn",
			"radius": 160.0,
			"force": 240.0
		},
		"cargo_net": {
			"name": "Cargo Net",
			"scene": "res://game/run/gizmos/cargo_net.tscn",
			"radius": 34.0,
			"hold_seconds": 0.8,
			"redrop_angle_degrees": 60.0,
			"redrop_speed": 420.0,
			"board_center_x": 360.0,
			"uses": 1
		},
		"splitter_vane": {
			"name": "Splitter Vane",
			"scene": "res://game/run/gizmos/splitter_vane.tscn",
			"radius": 24.0,
			"value_multiplier": 0.5
		}
```

- [ ] **Step 2: Update and write the failing tests**

In `tests/test_save_schema.gd`:

UPDATE `test_migrate_v1_to_v2_grants_gizmo_structure`: rename it to `test_migrate_v1_hops_to_current_with_grant` and change its assertions to:

```gdscript
	assert_eq(int(migrated["version"]), SaveSchema.CURRENT_VERSION)
	assert_eq(migrated["gizmos"]["owned"], {"wind_fan": 1, "crystal_prism": 1})
	assert_eq(int(migrated["currencies"]["scrap"]), 777, "migration must be lossless")
```

(The GIZMO_DEFS const in this file lists only two starters, so the merged grant is those two; the hop count is what changed.)

UPDATE `test_migrate_v1_without_gizmo_defs_still_structures`: its final assertion keeps the empty structure, and it still passes (v1 -> v2 empty grant with the T1 warning -> v3 merge-grant of nothing).

APPEND:

```gdscript
func test_migrate_v2_merge_grants_new_starters_preserving_levels() -> void:
	var v2 := SaveSchema.default_data(DEFS, {"starting_inventory": {"wind_fan": 1}})
	v2["version"] = 2
	v2["gizmos"]["owned"]["wind_fan"] = 4
	var migrated := SaveSchema.migrate(v2, GIZMO_DEFS)
	assert_eq(int(migrated["version"]), SaveSchema.CURRENT_VERSION)
	assert_eq(int(migrated["gizmos"]["owned"]["wind_fan"]), 4,
		"merge-grant must not reset an upgraded level")
	assert_eq(int(migrated["gizmos"]["owned"]["crystal_prism"]), 1,
		"newly introduced starters are granted")

func test_migrate_v2_preserves_loadout() -> void:
	var v2 := SaveSchema.default_data(DEFS, GIZMO_DEFS)
	v2["version"] = 2
	v2["gizmos"]["loadout"] = {"region_1": {"slot_0": "wind_fan"}}
	var migrated := SaveSchema.migrate(v2, GIZMO_DEFS)
	assert_eq(migrated["gizmos"]["loadout"], {"region_1": {"slot_0": "wind_fan"}})

func test_current_version_is_three_and_defaults_grant_eight() -> void:
	assert_eq(SaveSchema.CURRENT_VERSION, 3)
	var data := SaveSchema.default_data(DEFS, DataDefs.gizmos)
	assert_eq((data["gizmos"]["owned"] as Dictionary).size(), 8,
		"all eight MVP gizmos are starters until the Workshop lands (Plan 4)")
```

- [ ] **Step 3: Run tests to verify they fail**

Expected: FAIL (CURRENT_VERSION is 2; no merge-grant hop; the renamed test's version assertion fails against 2).

- [ ] **Step 4: Implement**

In `game/core/save_schema.gd`, set `const CURRENT_VERSION := 3`, replace `migrate` with:

```gdscript
static func migrate(data: Dictionary, gizmo_defs: Dictionary = {}) -> Dictionary:
	var version := int(data.get("version", 0))
	if version <= 0 or version > CURRENT_VERSION:
		return {}
	if version == 1:
		data = _migrate_1_to_2(data, gizmo_defs)
	if int(data["version"]) == 2:
		data = _migrate_2_to_3(data, gizmo_defs)
	return data
```

and add after `_migrate_1_to_2`:

```gdscript
static func _migrate_2_to_3(data: Dictionary, gizmo_defs: Dictionary) -> Dictionary:
	# New gizmos joined the starting inventory; merge-grant the missing ones
	# without touching levels the player already upgraded or their loadout.
	var owned: Dictionary = (data.get("gizmos", {}) as Dictionary).get("owned", {})
	var starters: Dictionary = gizmo_defs.get("starting_inventory", {})
	for id in starters:
		if not owned.has(id):
			owned[id] = int(starters[id])
	data["version"] = 3
	return data
```

- [ ] **Step 5: Run tests to verify they pass**

Expected: PASS, 3 new + 2 updated tests green, full suite exit 0.

- [ ] **Step 6: Commit**

```bash
git add game/data/gizmos.json game/core/save_schema.gd tests/test_save_schema.gd
git commit -m "feat: add five gizmo defs and schema v3 merge-grant migration"
```

---

### Task 3: Run context and catch sources

**Files:**
- Modify: `game/run/run_model.gd`
- Modify: `game/run/skyfield.gd`
- Modify: `game/run/salvage_run.gd`
- Test: `tests/test_run_model.gd` (append 3), `tests/test_salvage_run.gd` (append 4), `tests/test_skyfield.gd` (append 1)

**Interfaces:**
- Consumes: everything 3a shipped.
- Produces (T4/T5/T8 gizmos call these on `context`):
  - `RunModel.add_bonus_loot(payout: Dictionary) -> void` (accumulates into loot, emits `loot_changed`; never touches drops or pods_in_flight) and `RunModel.add_split_pod() -> bool` (false when abandoned, when nothing is in flight, or at the pod cap; otherwise increments pods_in_flight).
  - `Skyfield.pod_caught(pod, payout, source: String)` where source is `"barge"` or `"sea"`; `_on_catcher_body(body, payout, source)`.
  - `salvage_run`: `add_bonus(payout)` (Economy-credits and banks into model loot), `set_next_barge_multiplier(factor)` (non-stacking: keeps the strongest pending factor; consumed by the next BARGE catch only), `request_split(pod) -> bool` (model bookkeeping, spawns a mirrored clone carrying the original's `value_mult` and a `"split"` meta, watchdogged); `_on_pod_caught(pod, payout, source := "barge")` applies `_compute_payout` then the pending barge multiplier (roundi, reset to 1.0 after use); `_on_pod_timeout` resolves with source `"sea"`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_run_model.gd`:

```gdscript
func test_add_bonus_loot_accumulates_without_pod_bookkeeping() -> void:
	var model := make_model()
	watch_signals(model)
	model.begin_drop()
	model.add_bonus_loot({"scrap": 6})
	assert_eq(model.loot, {"scrap": 6})
	assert_eq(model.drops_remaining(), 2, "bonus loot consumes no drops")
	assert_eq(model.pods_in_flight, 1, "bonus loot resolves no pods")
	assert_signal_emitted(model, "loot_changed")

func test_add_split_pod_respects_cap_and_flight() -> void:
	var model := make_model(3, 2)
	assert_false(model.add_split_pod(), "nothing in flight yet")
	model.begin_drop()
	assert_true(model.add_split_pod())
	assert_eq(model.pods_in_flight, 2)
	assert_false(model.add_split_pod(), "at cap 2")

func test_split_pod_extends_run_until_both_resolve() -> void:
	var model := make_model(1, 4)
	model.begin_drop()
	model.add_split_pod()
	model.resolve_pod({"scrap": 1})
	assert_false(model.is_over(), "the split twin is still falling")
	model.resolve_pod({"scrap": 1})
	assert_true(model.is_over())
```

Append to `tests/test_salvage_run.gd`:

```gdscript
func test_add_bonus_credits_and_banks() -> void:
	var scrap_before := Economy.balance("scrap")
	scene.add_bonus({"scrap": 6})
	assert_eq(Economy.balance("scrap"), scrap_before + 6)
	assert_eq(scene.model.loot, {"scrap": 6})

func test_next_barge_multiplier_applies_to_barge_only_and_once() -> void:
	# The await after each catch lets the freed pod leave the "pods" group
	# before the next drop's group lookup (queue_free defers to frame end).
	var scrap_before := Economy.balance("scrap")
	scene.set_next_barge_multiplier(2.0)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(pod, {"scrap": 5}, "sea")
	await wait_physics_frames(1)
	assert_eq(Economy.balance("scrap"), scrap_before + 5, "sea catches never consume the chime")
	scene._on_drop_requested(360.0)
	var second: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(second, {"scrap": 5}, "barge")
	await wait_physics_frames(1)
	assert_eq(Economy.balance("scrap"), scrap_before + 5 + 10, "the barge catch doubles once")
	scene._on_drop_requested(360.0)
	var third: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(third, {"scrap": 5}, "barge")
	assert_eq(Economy.balance("scrap"), scrap_before + 5 + 10 + 5, "the multiplier is consumed")

func test_chime_does_not_stack() -> void:
	scene.set_next_barge_multiplier(2.0)
	scene.set_next_barge_multiplier(2.0)
	assert_almost_eq(scene._next_barge_multiplier, 2.0, 0.001)

func test_request_split_spawns_mirrored_clone() -> void:
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	pod.linear_velocity = Vector2(120, 200)
	pod.set_meta("value_mult", 0.5)
	assert_true(scene.request_split(pod))
	await wait_physics_frames(1)
	var pods: Array = get_tree().get_nodes_in_group("pods")
	assert_eq(pods.size(), 2)
	assert_eq(scene.model.pods_in_flight, 2)
	assert_eq(scene.model.drops_remaining(), int(DataDefs.run["drops_per_run"]) - 1,
		"the split consumed no extra drop")
	var clone: Node = pods[1] if pods[0] == pod else pods[0]
	assert_almost_eq(float(clone.get_meta("value_mult")), 0.5, 0.001)
	assert_true(clone.has_meta("split"))
	assert_almost_eq(clone.linear_velocity.x, -120.0, 2.0)
```

Append to `tests/test_skyfield.gd`:

```gdscript
func test_pod_caught_carries_source_tag() -> void:
	var board := build_board(DataDefs.load_json("res://tests/fixtures/test_region.json"))
	watch_signals(board)
	drop_pod_over(board, 360.0)
	var emitted: bool = await wait_for_signal(board.pod_caught, 5.0)
	assert_true(emitted)
	var params: Array = get_signal_parameters(board, "pod_caught")
	assert_eq(params[2], "barge")
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL (new methods and the source parameter do not exist; `_on_pod_caught` rejects a third argument).

- [ ] **Step 3: Implement**

`game/run/run_model.gd`: append:

```gdscript
func add_bonus_loot(payout: Dictionary) -> void:
	# Gizmo bonuses (Lightning Jar): loot without pod bookkeeping.
	for currency in payout:
		loot[currency] = int(loot.get(currency, 0)) + int(payout[currency])
	loot_changed.emit(loot)


func add_split_pod() -> bool:
	# Splitter Vane: one more pod in flight without consuming a drop.
	if abandoned or pods_in_flight <= 0 or pods_in_flight >= max_active_pods:
		return false
	pods_in_flight += 1
	return true
```

`game/run/skyfield.gd`: change the signal declaration to:

```gdscript
signal pod_caught(pod: RigidBody2D, payout: Dictionary, source: String)
```

In `_build_barges`, change the connect line to:

```gdscript
		area.body_entered.connect(_on_catcher_body.bind((barge.get("payout", {}) as Dictionary).duplicate(), "barge"))
```

In `_build_sea`, change the connect line to:

```gdscript
	sea.body_entered.connect(_on_catcher_body.bind(sea_payout.duplicate(), "sea"))
```

Replace `_on_catcher_body` with:

```gdscript
func _on_catcher_body(body: Node2D, payout: Dictionary, source: String) -> void:
	if not (body is RigidBody2D):
		return
	if body.has_meta("caught"):
		return
	body.set_meta("caught", true)
	pod_caught.emit(body, payout.duplicate(), source)
```

`game/run/salvage_run.gd`: add below `var pod_defs`:

```gdscript
var _next_barge_multiplier := 1.0
```

Replace `_on_pod_caught` with:

```gdscript
func _on_pod_caught(pod: Node, payout: Dictionary, source: String = "barge") -> void:
	payout = _compute_payout(pod, payout)
	if source == "barge" and _next_barge_multiplier > 1.0:
		var boosted := {}
		for currency in payout:
			boosted[currency] = roundi(float(payout[currency]) * _next_barge_multiplier)
		payout = boosted
		_next_barge_multiplier = 1.0
	if is_instance_valid(pod):
		pod.queue_free()
	for currency in payout:
		Economy.add(currency, int(payout[currency]))
	model.resolve_pod(payout)
	_refresh_hud()
```

In `_on_pod_timeout`, change the final line to:

```gdscript
	_on_pod_caught(pod, board.sea_payout.duplicate(), "sea")
```

Append the context methods:

```gdscript
func add_bonus(payout: Dictionary) -> void:
	# Gizmo context: Lightning Jar bonuses credit like any other loot.
	for currency in payout:
		Economy.add(currency, int(payout[currency]))
	model.add_bonus_loot(payout)
	_refresh_hud()


func set_next_barge_multiplier(factor: float) -> void:
	# Gizmo context: Chime Bell. Non-stacking; the strongest pending ring wins.
	_next_barge_multiplier = maxf(_next_barge_multiplier, factor)


func request_split(pod: RigidBody2D) -> bool:
	# Gizmo context: Splitter Vane. The clone mirrors horizontal velocity and
	# carries the original's value_mult (already halved by the vane).
	if not is_instance_valid(pod) or pod.has_meta("caught"):
		return false
	if not model.add_split_pod():
		return false
	var clone: Pod = PodScene.instantiate()
	clone.position = pod.position + Vector2(18, 0)
	clone.setup(pod_defs)
	board.add_child(clone)
	clone.linear_velocity = Vector2(-pod.linear_velocity.x, pod.linear_velocity.y)
	if pod.has_meta("value_mult"):
		clone.set_meta("value_mult", pod.get_meta("value_mult"))
	clone.set_meta("split", true)
	_start_watchdog(clone)
	_refresh_hud()
	return true
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, 8 new tests green, full suite exit 0. Pre-existing callers are unaffected: `_on_pod_caught`'s `source` defaults to `"barge"` with no pending multiplier, and old `pod_caught` assertions index `params[1]`, which is still the payout.

- [ ] **Step 5: Commit**

```bash
git add game/run/run_model.gd game/run/skyfield.gd game/run/salvage_run.gd tests/test_run_model.gd tests/test_salvage_run.gd tests/test_skyfield.gd
git commit -m "feat: add gizmo run context with catch sources, bonuses, chime, and splits"
```

---

### Task 4: Lightning Jar

**Files:**
- Create: `game/run/gizmos/lightning_jar.gd`, `game/run/gizmos/lightning_jar.tscn`
- Modify: `game/run/skyfield.gd` (`_build_pegs` adds the `"pegs"` group)
- Test: `tests/test_lightning_jar.gd`, `tests/test_skyfield.gd` (append 1)

**Interfaces:**
- Consumes: `GizmoBase`, `context.add_bonus` (T3), lightning defs (T2).
- Produces: spec 3.3 "chain-zaps nearby natural pegs into bonus scrap": on pod contact (respecting the caught convention), removes up to `pegs_zapped` pegs within `zap_radius` and credits `scrap_per_peg` (level-scaled) per removed peg via `context.add_bonus`; `charges` uses per run; dims when spent. Pegs join group `"pegs"` at build time.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_skyfield.gd`:

```gdscript
func test_pegs_join_pegs_group() -> void:
	var board := build_board(DataDefs.skyfield("region_1"))
	var first_peg: Node = board.get_node("Pegs").get_child(0)
	assert_true(first_peg.is_in_group("pegs"))
```

`tests/test_lightning_jar.gd`:

```gdscript
extends GutTest

const JarScene := preload("res://game/run/gizmos/lightning_jar.tscn")
const PodScene := preload("res://game/run/pod.tscn")


class StubContext:
	extends Node

	var bonuses: Array = []

	func add_bonus(payout: Dictionary) -> void:
		bonuses.append(payout)


var jar
var stub: StubContext
var jar_defs: Dictionary


func before_each() -> void:
	jar_defs = (DataDefs.gizmos["defs"]["lightning_jar"] as Dictionary).duplicate()
	stub = add_child_autofree(StubContext.new())
	jar = add_child_autofree(JarScene.instantiate())
	jar.position = Vector2(360, 500)
	jar.setup(jar_defs, 1, stub)


func make_peg(at: Vector2) -> StaticBody2D:
	var peg := StaticBody2D.new()
	peg.position = at
	peg.add_to_group("pegs")
	add_child_autofree(peg)
	return peg

func make_pod() -> Pod:
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	return pod


func test_zap_removes_nearby_pegs_and_credits_bonus() -> void:
	make_peg(Vector2(360, 420))
	make_peg(Vector2(420, 500))
	make_peg(Vector2(360, 900))
	jar._on_body_entered(make_pod())
	await wait_physics_frames(1)
	assert_eq(get_tree().get_nodes_in_group("pegs").size(), 1, "only the far peg survives")
	assert_eq(stub.bonuses.size(), 1)
	assert_eq(int(stub.bonuses[0]["scrap"]), 4, "2 scrap per peg, 2 pegs zapped")

func test_zap_caps_pegs_per_charge() -> void:
	for i in 5:
		make_peg(Vector2(360 + i * 10, 480))
	jar._on_body_entered(make_pod())
	await wait_physics_frames(1)
	assert_eq(get_tree().get_nodes_in_group("pegs").size(), 2, "pegs_zapped is 3")

func test_charges_deplete_and_no_zap_without_pegs() -> void:
	make_peg(Vector2(360, 480))
	jar._on_body_entered(make_pod())
	make_peg(Vector2(360, 480))
	jar._on_body_entered(make_pod())
	make_peg(Vector2(360, 480))
	jar._on_body_entered(make_pod())
	await wait_physics_frames(1)
	assert_eq(stub.bonuses.size(), 2, "charges is 2; the third contact does nothing")
	assert_eq(get_tree().get_nodes_in_group("pegs").size(), 1)

func test_caught_pod_triggers_nothing() -> void:
	make_peg(Vector2(360, 480))
	var pod := make_pod()
	pod.set_meta("caught", true)
	jar._on_body_entered(pod)
	assert_eq(stub.bonuses.size(), 0)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL (jar scene and the pegs group do not exist).

- [ ] **Step 3: Implement**

In `game/run/skyfield.gd`'s `_build_pegs`, after `var body := StaticBody2D.new()`, add:

```gdscript
		body.add_to_group("pegs")
```

`game/run/gizmos/lightning_jar.gd`:

```gdscript
class_name LightningJar
extends GizmoBase
## Lightning Jar (spec 3.3): chain-zaps nearby natural pegs into bonus scrap.
## Zapped pegs are removed from the board; each pays scrap via context.add_bonus.

var _charges := 0
var _zap_radius := 150.0
var _pegs_zapped := 3
var _scrap_per_peg := 2

@onready var zone: Area2D = $Zone


func _configure() -> void:
	_charges = int(defs.get("charges", 2))
	_zap_radius = float(defs.get("zap_radius", 150.0))
	_pegs_zapped = int(defs.get("pegs_zapped", 3))
	_scrap_per_peg = int(round(scaled(float(defs.get("scrap_per_peg", 2)))))
	var circle := CircleShape2D.new()
	circle.radius = float(defs.get("zone_radius", 24.0))
	$Zone/Shape.shape = circle
	var visual: Polygon2D = $Visual
	visual.polygon = Geometry.circle_points(circle.radius, 6)
	visual.color = Color(0.95, 0.9, 0.4)
	zone.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _charges <= 0 or not (body is RigidBody2D) or body.has_meta("caught"):
		return
	var zapped := 0
	for peg in get_tree().get_nodes_in_group("pegs"):
		if zapped >= _pegs_zapped:
			break
		if peg.global_position.distance_to(global_position) <= _zap_radius:
			peg.queue_free()
			peg.remove_from_group("pegs")
			zapped += 1
	if zapped == 0:
		return
	_charges -= 1
	context.add_bonus({"scrap": _scrap_per_peg * zapped})
	if _charges <= 0:
		$Visual.modulate.a = 0.25
```

`game/run/gizmos/lightning_jar.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://game/run/gizmos/lightning_jar.gd" id="1_lj"]

[node name="LightningJar" type="Node2D"]
script = ExtResource("1_lj")

[node name="Zone" type="Area2D" parent="."]

[node name="Shape" type="CollisionShape2D" parent="Zone"]

[node name="Visual" type="Polygon2D" parent="."]
```

(`remove_from_group` makes the removal visible to same-frame group queries; `queue_free` alone defers until end of frame, which is why the tests also await one physics frame.)

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, 5 new tests green, full suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/run/gizmos/lightning_jar.gd game/run/gizmos/lightning_jar.tscn game/run/skyfield.gd tests/test_lightning_jar.gd tests/test_skyfield.gd
git commit -m "feat: add Lightning Jar gizmo zapping pegs into bonus scrap"
```

---

### Task 5: Chime Bell

**Files:**
- Create: `game/run/gizmos/chime_bell.gd`, `game/run/gizmos/chime_bell.tscn`
- Test: `tests/test_chime_bell.gd`

**Interfaces:**
- Consumes: `GizmoBase`, `context.set_next_barge_multiplier` (T3), chime defs (T2).
- Produces: spec 3.3 "rings: next barge payout is doubled": on pod contact (caught convention; once per pod per bell via a per-instance meta guard), calls `context.set_next_barge_multiplier(scaled(barge_multiplier))`; `uses_per_run` limit; dims when spent.

- [ ] **Step 1: Write the failing tests**

`tests/test_chime_bell.gd`:

```gdscript
extends GutTest

const BellScene := preload("res://game/run/gizmos/chime_bell.tscn")
const PodScene := preload("res://game/run/pod.tscn")


class StubContext:
	extends Node

	var factors: Array = []

	func set_next_barge_multiplier(factor: float) -> void:
		factors.append(factor)


var bell
var stub: StubContext


func before_each() -> void:
	stub = add_child_autofree(StubContext.new())
	bell = add_child_autofree(BellScene.instantiate())
	bell.setup((DataDefs.gizmos["defs"]["chime_bell"] as Dictionary).duplicate(), 1, stub)


func make_pod() -> Pod:
	return add_child_autofree(PodScene.instantiate())


func test_ring_sets_barge_multiplier() -> void:
	bell._on_body_entered(make_pod())
	assert_eq(stub.factors.size(), 1)
	assert_almost_eq(float(stub.factors[0]), 2.0, 0.001)

func test_same_pod_rings_once() -> void:
	var pod := make_pod()
	bell._on_body_entered(pod)
	bell._on_body_entered(pod)
	assert_eq(stub.factors.size(), 1)

func test_uses_deplete() -> void:
	bell._on_body_entered(make_pod())
	bell._on_body_entered(make_pod())
	bell._on_body_entered(make_pod())
	assert_eq(stub.factors.size(), 2, "uses_per_run is 2")
	assert_almost_eq(bell.get_node("Visual").modulate.a, 0.25, 0.001)

func test_caught_pod_rings_nothing() -> void:
	var pod := make_pod()
	pod.set_meta("caught", true)
	bell._on_body_entered(pod)
	assert_eq(stub.factors.size(), 0)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL (bell scene does not exist).

- [ ] **Step 3: Implement**

`game/run/gizmos/chime_bell.gd`:

```gdscript
class_name ChimeBell
extends GizmoBase
## Chime Bell (spec 3.3): rings on contact; the next barge payout is doubled.
## The run scene keeps the strongest pending ring (non-stacking).

var _uses_left := 0
var _multiplier := 2.0

@onready var zone: Area2D = $Zone


func _configure() -> void:
	_uses_left = int(defs.get("uses_per_run", 2))
	_multiplier = scaled(float(defs.get("barge_multiplier", 2.0)))
	var circle := CircleShape2D.new()
	circle.radius = float(defs.get("radius", 26.0))
	$Zone/Shape.shape = circle
	var visual: Polygon2D = $Visual
	visual.polygon = PackedVector2Array([
		Vector2(-20, 18), Vector2(20, 18), Vector2(12, -20), Vector2(-12, -20),
	])
	visual.color = Color(0.9, 0.75, 0.35)
	zone.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _uses_left <= 0 or not (body is RigidBody2D) or body.has_meta("caught"):
		return
	var guard := "bell_%d" % get_instance_id()
	if body.has_meta(guard):
		return
	body.set_meta(guard, true)
	_uses_left -= 1
	context.set_next_barge_multiplier(_multiplier)
	if _uses_left <= 0:
		$Visual.modulate.a = 0.25
```

`game/run/gizmos/chime_bell.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://game/run/gizmos/chime_bell.gd" id="1_cb"]

[node name="ChimeBell" type="Node2D"]
script = ExtResource("1_cb")

[node name="Zone" type="Area2D" parent="."]

[node name="Shape" type="CollisionShape2D" parent="Zone"]

[node name="Visual" type="Polygon2D" parent="."]
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, 4 new tests green, full suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/run/gizmos/chime_bell.gd game/run/gizmos/chime_bell.tscn tests/test_chime_bell.gd
git commit -m "feat: add Chime Bell gizmo priming the next barge payout"
```

---

### Task 6: Magnet Buoy

**Files:**
- Create: `game/run/gizmos/magnet_buoy.gd`, `game/run/gizmos/magnet_buoy.tscn`
- Test: `tests/test_magnet_buoy.gd`

**Interfaces:**
- Consumes: `GizmoBase`, magnet defs (T2).
- Produces: spec 3.3 "curves pod trajectories toward itself": every physics frame, RigidBody2D bodies overlapping the radius zone receive a central force toward the buoy (level-scaled).

- [ ] **Step 1: Write the failing tests**

`tests/test_magnet_buoy.gd`:

```gdscript
extends GutTest

const BuoyScene := preload("res://game/run/gizmos/magnet_buoy.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var buoy_defs: Dictionary


func before_each() -> void:
	buoy_defs = (DataDefs.gizmos["defs"]["magnet_buoy"] as Dictionary).duplicate()


func test_configure_builds_radius_zone() -> void:
	var buoy := add_child_autofree(BuoyScene.instantiate())
	buoy.setup(buoy_defs, 1, self)
	assert_almost_eq((buoy.get_node("Zone/Shape").shape as CircleShape2D).radius, 160.0, 0.001)

func test_pod_beside_buoy_is_pulled_toward_it() -> void:
	var buoy := add_child_autofree(BuoyScene.instantiate())
	buoy.position = Vector2(360, 500)
	buoy.setup(buoy_defs, 1, self)
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	pod.position = Vector2(240, 500)
	pod.setup({"radius": 12.0, "bounce": 0.55, "friction": 0.2})
	await wait_seconds(0.4)
	assert_true(pod.linear_velocity.x > 5.0, "the pod left of the buoy accelerates toward +x")

func test_level_scales_force() -> void:
	var buoy := add_child_autofree(BuoyScene.instantiate())
	buoy.setup(buoy_defs, 3, self)
	assert_almost_eq(buoy._force, 240.0 * 1.5, 0.001)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL (buoy scene does not exist).

- [ ] **Step 3: Implement**

`game/run/gizmos/magnet_buoy.gd`:

```gdscript
class_name MagnetBuoy
extends GizmoBase
## Magnet Buoy (spec 3.3): curves pod trajectories toward itself with a
## steady radial pull inside its radius.

var _force := 240.0

@onready var zone: Area2D = $Zone


func _configure() -> void:
	_force = scaled(float(defs.get("force", 240.0)))
	var circle := CircleShape2D.new()
	circle.radius = float(defs.get("radius", 160.0))
	$Zone/Shape.shape = circle
	var visual: Polygon2D = $Visual
	visual.polygon = Geometry.circle_points(16.0, 8)
	visual.color = Color(0.55, 0.65, 0.9)


func _physics_process(_delta: float) -> void:
	for body in zone.get_overlapping_bodies():
		if body is RigidBody2D:
			var offset: Vector2 = global_position - body.global_position
			if offset.length() > 1.0:
				body.apply_central_force(offset.normalized() * _force)
```

`game/run/gizmos/magnet_buoy.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://game/run/gizmos/magnet_buoy.gd" id="1_mb"]

[node name="MagnetBuoy" type="Node2D"]
script = ExtResource("1_mb")

[node name="Zone" type="Area2D" parent="."]

[node name="Shape" type="CollisionShape2D" parent="Zone"]

[node name="Visual" type="Polygon2D" parent="."]
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, 3 new tests green (the physics test takes ~0.4s; the pod also falls under gravity, which does not affect the x-velocity assertion), full suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/run/gizmos/magnet_buoy.gd game/run/gizmos/magnet_buoy.tscn tests/test_magnet_buoy.gd
git commit -m "feat: add Magnet Buoy gizmo pulling pods toward itself"
```

---

### Task 7: Cargo Net

**Files:**
- Create: `game/run/gizmos/cargo_net.gd`, `game/run/gizmos/cargo_net.tscn`
- Test: `tests/test_cargo_net.gd`

**Interfaces:**
- Consumes: `GizmoBase`, net defs (T2), the Timer+weakref footgun rule.
- Produces: spec 3.3 "catches a falling pod once and re-drops it at a chosen angle": on contact (caught convention; once per run via `uses`), freezes the pod (`set_deferred("freeze", true)`), holds `hold_seconds` on a net-owned child Timer, then unfreezes and relaunches at `redrop_angle_degrees` toward the board center (`board_center_x`), speed level-scaled. The release handler survives the pod being freed mid-hold (weakref) and the net dying with the scene (child Timer).

- [ ] **Step 1: Write the failing tests**

`tests/test_cargo_net.gd`:

```gdscript
extends GutTest

const NetScene := preload("res://game/run/gizmos/cargo_net.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var net
var net_defs: Dictionary


func before_each() -> void:
	net_defs = (DataDefs.gizmos["defs"]["cargo_net"] as Dictionary).duplicate()
	net = add_child_autofree(NetScene.instantiate())
	net.position = Vector2(200, 500)
	net.setup(net_defs, 1, self)


func make_pod(at: Vector2 = Vector2(200, 490)) -> Pod:
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	pod.position = at
	pod.setup({"radius": 12.0, "bounce": 0.55, "friction": 0.2})
	return pod


func test_catch_freezes_pod() -> void:
	var pod := make_pod()
	net._on_body_entered(pod)
	await wait_physics_frames(2)
	assert_true(pod.freeze, "the netted pod hangs frozen")

func test_release_relaunches_toward_center() -> void:
	var pod := make_pod()
	net._on_body_entered(pod)
	await wait_physics_frames(2)
	net._release(weakref(pod), add_child_autofree(Timer.new()))
	await wait_physics_frames(2)
	assert_false(pod.freeze)
	assert_true(pod.linear_velocity.x > 0.0, "a net left of center relaunches toward +x")
	assert_true(pod.linear_velocity.y < 0.0, "the relaunch arcs upward")

func test_single_use() -> void:
	net._on_body_entered(make_pod())
	var second := make_pod(Vector2(200, 470))
	net._on_body_entered(second)
	await wait_physics_frames(2)
	assert_false(second.freeze, "a spent net catches nothing")

func test_release_of_freed_pod_is_harmless() -> void:
	var pod := make_pod()
	net._on_body_entered(pod)
	pod.free()
	net._release(weakref(pod), add_child_autofree(Timer.new()))
	assert_true(true, "no error path reached")

func test_caught_pod_is_ignored() -> void:
	var pod := make_pod()
	pod.set_meta("caught", true)
	net._on_body_entered(pod)
	await wait_physics_frames(2)
	assert_false(pod.freeze)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL (net scene does not exist).

- [ ] **Step 3: Implement**

`game/run/gizmos/cargo_net.gd`:

```gdscript
class_name CargoNet
extends GizmoBase
## Cargo Net (spec 3.3): catches a falling pod once and re-drops it at a
## chosen angle toward the board center. The hold Timer is a child of the net
## (dies with the scene) and binds a weakref (survives the pod being freed),
## per the project's timer-lifetime rule.

var _uses_left := 0

@onready var zone: Area2D = $Zone


func _configure() -> void:
	_uses_left = int(defs.get("uses", 1))
	var circle := CircleShape2D.new()
	circle.radius = float(defs.get("radius", 34.0))
	$Zone/Shape.shape = circle
	var visual: Polygon2D = $Visual
	visual.polygon = PackedVector2Array([
		Vector2(-30, -6), Vector2(30, -6), Vector2(22, 22), Vector2(-22, 22),
	])
	visual.color = Color(0.7, 0.55, 0.4)
	zone.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _uses_left <= 0 or not (body is RigidBody2D) or body.has_meta("caught"):
		return
	_uses_left -= 1
	body.set_deferred("freeze", true)
	var hold := Timer.new()
	hold.one_shot = true
	hold.wait_time = float(defs.get("hold_seconds", 0.8))
	add_child(hold)
	hold.timeout.connect(_release.bind(weakref(body), hold))
	hold.start()
	if _uses_left <= 0:
		$Visual.modulate.a = 0.4


func _release(pod_ref: WeakRef, hold: Timer) -> void:
	hold.queue_free()
	var pod: Node = pod_ref.get_ref()
	if pod == null or pod.has_meta("caught"):
		return
	pod.freeze = false
	var angle := deg_to_rad(float(defs.get("redrop_angle_degrees", 60.0)))
	var speed := scaled(float(defs.get("redrop_speed", 420.0)))
	var direction := 1.0 if global_position.x < float(defs.get("board_center_x", 360.0)) else -1.0
	pod.linear_velocity = Vector2(cos(angle) * speed * direction, -sin(angle) * speed)
```

`game/run/gizmos/cargo_net.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://game/run/gizmos/cargo_net.gd" id="1_cn"]

[node name="CargoNet" type="Node2D"]
script = ExtResource("1_cn")

[node name="Zone" type="Area2D" parent="."]

[node name="Shape" type="CollisionShape2D" parent="Zone"]

[node name="Visual" type="Polygon2D" parent="."]
```

(The release's direct `pod.linear_velocity` assignment is a relaunch of a frozen body from a timer context, not a physics-callback impulse substitution; the body has no momentum to respect while frozen, so this is the correct form here, unlike the balloon case.)

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, 5 new tests green, full suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/run/gizmos/cargo_net.gd game/run/gizmos/cargo_net.tscn tests/test_cargo_net.gd
git commit -m "feat: add Cargo Net gizmo holding and re-dropping one pod"
```

---

### Task 8: Splitter Vane

**Files:**
- Create: `game/run/gizmos/splitter_vane.gd`, `game/run/gizmos/splitter_vane.tscn`
- Test: `tests/test_splitter_vane.gd`

**Interfaces:**
- Consumes: `GizmoBase`, `context.request_split` (T3), splitter defs (T2), the `"split"` and `"value_mult"` pod metas.
- Produces: spec 3.3 "splits the pod into two half-value pods (once per drop)": on contact (caught convention; pods already carrying `"split"` are ignored), halves the pod's `value_mult` (level-scaled multiplier, so higher levels lose less value), then asks `context.request_split(pod)`; on success the original keeps the halved value and gains the `"split"` meta (the context clones with the halved value and its own `"split"` meta); on failure (pod cap) the halving is reverted and the pod may retry later.

- [ ] **Step 1: Write the failing tests**

`tests/test_splitter_vane.gd`:

```gdscript
extends GutTest

const VaneScene := preload("res://game/run/gizmos/splitter_vane.tscn")
const PodScene := preload("res://game/run/pod.tscn")


class StubContext:
	extends Node

	var accept := true
	var requests: Array = []

	func request_split(pod: RigidBody2D) -> bool:
		requests.append(pod)
		return accept


var vane
var stub: StubContext


func before_each() -> void:
	stub = add_child_autofree(StubContext.new())
	vane = add_child_autofree(VaneScene.instantiate())
	vane.setup((DataDefs.gizmos["defs"]["splitter_vane"] as Dictionary).duplicate(), 1, stub)


func make_pod() -> Pod:
	return add_child_autofree(PodScene.instantiate())


func test_split_halves_value_and_marks_pod() -> void:
	var pod := make_pod()
	vane._on_body_entered(pod)
	assert_eq(stub.requests.size(), 1)
	assert_almost_eq(float(pod.get_meta("value_mult")), 0.5, 0.001)
	assert_true(pod.has_meta("split"))

func test_rejected_split_reverts_the_halving() -> void:
	stub.accept = false
	var pod := make_pod()
	pod.set_meta("value_mult", 0.8)
	vane._on_body_entered(pod)
	assert_almost_eq(float(pod.get_meta("value_mult")), 0.8, 0.001,
		"no benefit means no penalty")
	assert_false(pod.has_meta("split"), "the pod may retry once capacity frees")

func test_split_pod_never_splits_again() -> void:
	var pod := make_pod()
	vane._on_body_entered(pod)
	vane._on_body_entered(pod)
	assert_eq(stub.requests.size(), 1)

func test_caught_pod_is_ignored() -> void:
	var pod := make_pod()
	pod.set_meta("caught", true)
	vane._on_body_entered(pod)
	assert_eq(stub.requests.size(), 0)

func test_level_softens_the_penalty() -> void:
	var strong = add_child_autofree(VaneScene.instantiate())
	strong.setup((DataDefs.gizmos["defs"]["splitter_vane"] as Dictionary).duplicate(), 3, stub)
	var pod := make_pod()
	strong._on_body_entered(pod)
	assert_almost_eq(float(pod.get_meta("value_mult")), 0.75, 0.001,
		"scaled(0.5) at level 3 is 0.75")
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL (vane scene does not exist).

- [ ] **Step 3: Implement**

`game/run/gizmos/splitter_vane.gd`:

```gdscript
class_name SplitterVane
extends GizmoBase
## Splitter Vane (spec 3.3): splits the pod into two half-value pods, once
## per drop. Halve first so the context's clone copies the halved value;
## revert if the split is rejected (pod cap), so a failed split costs nothing.

var _value_multiplier := 0.5

@onready var zone: Area2D = $Zone


func _configure() -> void:
	_value_multiplier = scaled(float(defs.get("value_multiplier", 0.5)))
	var circle := CircleShape2D.new()
	circle.radius = float(defs.get("radius", 24.0))
	$Zone/Shape.shape = circle
	var visual: Polygon2D = $Visual
	visual.polygon = PackedVector2Array([
		Vector2(0, -24), Vector2(20, 16), Vector2(-20, 16),
	])
	visual.color = Color(0.6, 0.9, 0.7)
	zone.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not (body is RigidBody2D) or body.has_meta("caught") or body.has_meta("split"):
		return
	var previous := float(body.get_meta("value_mult", 1.0))
	body.set_meta("value_mult", previous * _value_multiplier)
	if not context.request_split(body):
		body.set_meta("value_mult", previous)
		return
	body.set_meta("split", true)
```

`game/run/gizmos/splitter_vane.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://game/run/gizmos/splitter_vane.gd" id="1_sv"]

[node name="SplitterVane" type="Node2D"]
script = ExtResource("1_sv")

[node name="Zone" type="Area2D" parent="."]

[node name="Shape" type="CollisionShape2D" parent="Zone"]

[node name="Visual" type="Polygon2D" parent="."]
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, 5 new tests green, full suite exit 0. (Level-3 math: scaled(0.5) = 0.5 * 1.5 = 0.75.)

- [ ] **Step 5: Commit**

```bash
git add game/run/gizmos/splitter_vane.gd game/run/gizmos/splitter_vane.tscn tests/test_splitter_vane.gd
git commit -m "feat: add Splitter Vane gizmo splitting pods into half-value twins"
```

---

### Task 9: Integration proofs

No production code: physics proof for the net's full catch-hold-redrop cycle, and a real-scene splitter proof (two pods from one drop, both crediting at half value).

**Files:**
- Test: `tests/test_gizmo_integration.gd` (append 2)

**Interfaces:**
- Consumes: everything above; reuses the T9-3a fixture `tests/fixtures/test_region_slot.json` and the salvage_run test isolation pattern.
- Produces: recorded evidence.

- [ ] **Step 1: Append the tests**

Append to `tests/test_gizmo_integration.gd`:

```gdscript
func test_cargo_net_catches_holds_and_redrops_to_barge() -> void:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	board.build(DataDefs.load_json("res://tests/fixtures/test_region_slot.json"), run_defs)
	board.install_gizmos({"slot_0": "cargo_net"}, DataDefs.gizmos, {"cargo_net": 1}, self)
	var pod: Pod = PodScene.instantiate()
	pod.position = Vector2(360, 160)
	pod.setup(run_defs["pod"])
	board.add_child(pod)
	var caught: bool = await wait_for_signal(board.pod_caught, 12.0)
	assert_true(caught, "held, re-dropped, and still landed within 12s")
	var net: GizmoBase = board.get_node("Gizmos").get_child(0)
	assert_eq(net._uses_left, 0, "the net consumed its single use on the way down")

func test_splitter_through_the_real_scene_credits_two_half_pods() -> void:
	GameState._io = SaveIO.new("user://test_gizmo_integration.json")
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	var scene = add_child_autofree(preload("res://game/run/salvage_run.tscn").instantiate())
	var scrap_before := Economy.balance("scrap")
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	pod.linear_velocity = Vector2(80, 150)
	var vane = preload("res://game/run/gizmos/splitter_vane.tscn").instantiate()
	scene.board.get_node("Gizmos").add_child(vane)
	vane.setup((DataDefs.gizmos["defs"]["splitter_vane"] as Dictionary).duplicate(), 1, scene)
	vane._on_body_entered(pod)
	await wait_physics_frames(1)
	assert_eq(get_tree().get_nodes_in_group("pods").size(), 2)
	var pods: Array = get_tree().get_nodes_in_group("pods").duplicate()
	scene._on_pod_caught(pods[0], {"scrap": 10}, "barge")
	scene._on_pod_caught(pods[1], {"scrap": 10}, "barge")
	assert_eq(Economy.balance("scrap"), scrap_before + 10,
		"two half-value pods together equal one full payout (5 + 5)")
	assert_eq(scene.model.pods_in_flight, 0, "one drop, two pods, both resolved")
	assert_eq(scene.model.drops_remaining(), int(DataDefs.run["drops_per_run"]) - 1,
		"the split twin consumed no drop")
	var dir := DirAccess.open("user://")
	for f in ["test_gizmo_integration.json", "test_gizmo_integration.json.tmp", "test_gizmo_integration.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos)
```

- [ ] **Step 2: Run and record**

```bash
$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: PASS, 2 new tests green, full suite exit 0. Net timing estimate: fall ~0.83s + hold 0.8s + redrop arc back down to the barge, comfortably under 12s. This is an integration-proof task (no strict RED); a stall or timeout is a real finding to escalate with output, never to paper over.

- [ ] **Step 3: Manual smoke check (skip in a non-interactive environment; note the skip)**

```bash
$GODOT
```

Expected: assign the five new gizmos across the six slots; in a run: the jar zaps pegs into bonus scrap when a pod grazes it, the bell ring doubles the next barge catch, the buoy visibly bends trajectories, the net snags one pod and flings it back toward center, and the vane splits a pod into two half-value twins.

- [ ] **Step 4: Commit**

```bash
git add tests/test_gizmo_integration.gd
git commit -m "test: prove cargo net cycle and real-scene splitting end to end"
```
