# Plan 14: Regions 3 and 4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Region 3 "Rimefall Shallows" (ice pegs, rimeglass) and Region 4 "Stormglass Verge" (storm pegs, stormglass) with Dock levels 3-4, two new rare gizmos, and the boon-pool tripwire fixes that must precede any 3-tier region.

**Architecture:** Regions are pure data additions; the new code is two peg hazards in the skyfield build path (ice = physics-material variant, storm = one small Area2D scene routed through the existing pod_caught flow), two self-contained gizmo scenes, one BoonModel helper, and small salvage_run boon-flow fixes. No save schema change (stays v8; new currencies ride the existing key backfill).

**Tech Stack:** Godot 4 / GDScript, GUT 9.6.1 (vendored), JSON data defs.

**Spec:** docs/superpowers/specs/2026-09-14-regions-3-and-4-design.md (committed on main). Parent design doc: docs/design/2026-08-15-windfall-isles-design.md sections 3.4 and 4.2.

## Global Constraints

- Test command (must exit 0): `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (the `godot` on PATH is 4.7.1 and runs this suite; do NOT use `$GODOT`/4.6 paths from older docs). Per-file: `-gtest=res://tests/<file> -gexit` instead of `-gdir`.
- After creating any new `.gd`, `.tscn`, or `.json` file, run `godot --headless --import` and then `git status --porcelain`: every new `.gd` file's `.gd.uid` sidecar MUST be committed with it (recurring pitfall, bitten twice).
- The sandbox rejects compound bash commands (for-loops, `&&` chains); run every command separately, one per call.
- JSON discipline: `JSON.parse_string` decodes all numbers as float and `Dictionary ==` does not coerce; never normalize in DataDefs; cast with `int()`/`float()`/`String()` at use and assert sites.
- GUT 9.6 auto-fails tests on pushed/engine errors; tests that intentionally trigger warnings declare `assert_push_warning_count(...)` AFTER the trigger. GUT's strict warnings reject `:=` inference from untyped Array/Dictionary chains; declare explicit types.
- Physics rules: velocity reads after impulses need `await wait_physics_frames(2)`; `add_child` of a physics body inside a `body_entered` chain must be `call_deferred`; impulses are mass-respecting; any gizmo handler that mutates the physics world needs one integration proof driven by REAL contact, never only direct handler calls.
- UI tests call handlers directly and never press scene-changing buttons.
- Tabs in .gd files; no em dashes in any authored text; edit JSON files surgically, never reformat whole files.
- Never state cumulative suite totals; list only new/changed tests per task. Full suite green is the gate.
- Commit messages end with: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`

---

### Task 1: Boon tripwire fixes

**Files:**
- Modify: `game/core/boon_model.gd`
- Modify: `game/run/salvage_run.gd:503-514` (_show_next_offer), `game/run/salvage_run.gd:516-528` (_render_offer), `game/run/salvage_run.gd:568-594` (_on_reroll_pressed, _grant_reroll)
- Modify: `tests/test_boon_model.gd`, `tests/test_run_model.gd`, `tests/test_salvage_run.gd`

**Interfaces:**
- Consumes: existing `BoonModel.offer(pool_ids: Array, taken: Array, rng: RandomNumberGenerator) -> Array`; `RunModel.add_boon(boon_id: String, boon_defs: Dictionary)`, `barge_boon_multiplier() -> float`, `sea_boon_multiplier() -> float`; salvage_run's `_close_offer()` (hides the panel, drains `_pending_offers`, re-enables the controller when not over).
- Produces: `BoonModel.reroll_candidates(pool_ids: Array, taken: Array, current: Array) -> Array` (static, pure); salvage_run private helper `_has_reroll_candidates() -> bool`. Task 4's 3-tier region data relies on these fixes being in.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_boon_model.gd`:

```gdscript
func test_reroll_candidates_excludes_taken_and_current() -> void:
	var pool := ["a", "b", "c", "d", "e", "f"]
	assert_eq(BoonModel.reroll_candidates(pool, ["a", "b"], ["c", "d", "e"]), ["f"])


func test_reroll_candidates_empty_when_pool_covered() -> void:
	var pool := ["a", "b", "c", "d"]
	assert_eq(BoonModel.reroll_candidates(pool, ["a"], ["b", "c", "d"]), [],
		"taken plus the current trio cover the pool: nothing to redraw")
```

Append to `tests/test_run_model.gd`:

```gdscript
func test_same_type_boon_multipliers_compose_with_maxf() -> void:
	var model := RunModel.new({"drops_per_run": 8, "max_active_pods": 4})
	var defs := {"defs": {
		"big_barge": {"barge_multiplier": 2.0},
		"small_barge": {"barge_multiplier": 1.5},
		"big_sea": {"sea_multiplier": 3.0},
		"small_sea": {"sea_multiplier": 2.0},
	}}
	model.add_boon("small_barge", defs)
	model.add_boon("big_barge", defs)
	assert_eq(model.barge_boon_multiplier(), 2.0, "the strongest same-type boon wins; they never stack")
	model.add_boon("big_sea", defs)
	model.add_boon("small_sea", defs)
	assert_eq(model.sea_boon_multiplier(), 3.0)
```

Append to `tests/test_salvage_run.gd` (the file's existing before_each already starts the run):

```gdscript
func test_exhausted_pool_offer_reenables_the_controller() -> void:
	for id in (DataDefs.boons.get("defs", {}) as Dictionary).keys():
		scene.model.add_boon(String(id), DataDefs.boons)
	scene._on_tier_reached(3)
	assert_false(scene.get_node("UI/BoonOffer").visible,
		"an empty draw shows no panel")
	assert_true(scene.controller.enabled,
		"an exhausted pool must never lock the remaining drops (Plan 7 tripwire)")


func test_reroll_hidden_when_pool_has_no_disjoint_candidate() -> void:
	var pool: Array = (DataDefs.boons.get("defs", {}) as Dictionary).keys()
	scene._current_offer = [pool[0], pool[1], pool[2]]
	for i in range(3, pool.size()):
		scene.model.add_boon(String(pool[i]), DataDefs.boons)
	scene._render_offer()
	assert_false(scene.get_node("UI/BoonOffer/VBox/RerollButton").visible,
		"a reroll that cannot redraw anything is hidden (Plan 7 tripwire)")


func test_reroll_press_with_no_candidates_consumes_nothing() -> void:
	var pool: Array = (DataDefs.boons.get("defs", {}) as Dictionary).keys()
	scene._current_offer = [pool[0], pool[1], pool[2]]
	for i in range(3, pool.size()):
		scene.model.add_boon(String(pool[i]), DataDefs.boons)
	scene._free_rerolls = 1
	scene._on_reroll_pressed()
	assert_eq(scene._free_rerolls, 1, "the wind charm survives a pointless reroll press")
	assert_false(scene._offer_rerolled)
```

- [ ] **Step 2: Run the three files to verify the new tests fail**

Run each separately:
`godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_boon_model.gd -gexit`
`godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_run_model.gd -gexit`
`godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_salvage_run.gd -gexit`
Expected: the boon_model tests FAIL with "Nonexistent function 'reroll_candidates'"; the salvage_run tests FAIL (controller stays disabled; reroll button visible; free reroll consumed). The run_model maxf test may already PASS (it pins existing behavior that was merely untested); if it passes immediately, note that in your report and keep it, it is a deliberate pin.

- [ ] **Step 3: Implement**

Append to `game/core/boon_model.gd`:

```gdscript
static func reroll_candidates(pool_ids: Array, taken: Array, current: Array) -> Array:
	# A reroll redraw excludes taken boons AND the current trio (spec 6
	# placement 5). When this is empty the reroll cannot change anything, so
	# the scene hides the button and refuses the grant (Plan 7 tripwire).
	var out: Array = []
	for id in pool_ids:
		if not taken.has(id) and not current.has(id):
			out.append(id)
	return out
```

In `game/run/salvage_run.gd`, replace the empty-draw early return inside `_show_next_offer` (the two lines `if _current_offer.is_empty():` / `return`) with:

```gdscript
	if _current_offer.is_empty():
		# Exhausted pool (Plan 7 tripwire): nothing to offer, so close out the
		# way a skip would; _close_offer drains any remaining queued offers and
		# re-enables the controller when the run is not over.
		_close_offer()
		return
```

In `_render_offer`, replace the RerollButton lines (the `.text` assignment stays first) with:

```gdscript
	$UI/BoonOffer/VBox/RerollButton.text = "Reroll (free)" if _free_rerolls > 0 else "Reroll (ad)"
	$UI/BoonOffer/VBox/RerollButton.visible = _has_reroll_candidates() and not _offer_rerolled \
		and (_free_rerolls > 0 or Ads.service.is_available(AdService.Placement.BOON_REROLL))
```

Replace `_on_reroll_pressed` and `_grant_reroll` with:

```gdscript
func _on_reroll_pressed() -> void:
	if _offer_rerolled or not _has_reroll_candidates():
		return
	if _free_rerolls > 0:
		# Wind Charm (run-kit spec section 5): the free reroll consumes no ad
		# and is used before any ad request; still at most one per offer.
		_free_rerolls -= 1
		_grant_reroll()
		return
	if not Ads.service.is_available(AdService.Placement.BOON_REROLL):
		return
	Ads.service.request_reward(AdService.Placement.BOON_REROLL, _grant_reroll)


func _grant_reroll() -> void:
	# One reroll per offer (spec 6 placement 5), granted at reward time. The
	# current trio joins the exclusions so the redraw is always disjoint;
	# the exclusion is per-reroll only, never permanent. The candidate guard
	# repeats here because the pool can be covered between show and grant.
	if _offer_rerolled or not _has_reroll_candidates():
		return
	_offer_rerolled = true
	var exclusions: Array = (model.boons as Array).duplicate()
	exclusions.append_array(_current_offer)
	var redraw := BoonModel.offer((DataDefs.boons.get("defs", {}) as Dictionary).keys(), exclusions, _rng)
	if not redraw.is_empty():
		_current_offer = redraw
	_render_offer()


func _has_reroll_candidates() -> bool:
	return not BoonModel.reroll_candidates(
		(DataDefs.boons.get("defs", {}) as Dictionary).keys(), model.boons, _current_offer).is_empty()
```

- [ ] **Step 4: Run the three files to verify they pass**

Same three commands as Step 2. Expected: PASS, including all pre-existing boon tests (the reroll flow is unchanged when candidates exist).

- [ ] **Step 5: Run the full suite**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add game/core/boon_model.gd game/run/salvage_run.gd tests/test_boon_model.gd tests/test_run_model.gd tests/test_salvage_run.gd
git commit -m "fix: boon offers survive an exhausted pool and pointless rerolls hide

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Currencies, Dock levels 3-4, region unlock rows

**Files:**
- Modify: `game/data/economy.json` (starting_balances only)
- Modify: `game/data/buildings.json` (dock def only)
- Modify: `game/data/run.json` (regions array only)
- Create: `tests/test_regions_3_4_defs.gd`

**Interfaces:**
- Consumes: existing `RegionModel.unlocked(region_entry, island) -> bool` and `fuel_cost(region_entry, island) -> int` (both read `min_dock_level` / `reduced_fuel_cost` / `reduced_at_dock_level` generically); `IslandModel.building_level(island, "dock")`.
- Produces: currencies `rimeglass` and `stormglass` (Task 4's barge payouts and Task 5's craft costs use these exact ids); dock `max_level` 4; run.json regions entries with ids `region_3` and `region_4` (Task 4 creates the matching skyfield JSONs).

- [ ] **Step 1: Write the failing tests**

Create `tests/test_regions_3_4_defs.gd`:

```gdscript
extends GutTest
## Regions 3 and 4 unlock data pins (Plan 14): currencies, dock levels, and
## the run.json region rows. The skyfield JSONs have their own defs tests.


func test_starting_balances_carry_the_new_materials() -> void:
	var balances: Dictionary = DataDefs.economy["starting_balances"]
	assert_eq(int(balances.get("rimeglass", -1)), 0)
	assert_eq(int(balances.get("stormglass", -1)), 0)


func test_dock_reaches_level_four() -> void:
	var dock: Dictionary = (DataDefs.buildings["defs"] as Dictionary)["dock"]
	assert_eq(int(dock.get("max_level", 0)), 4)
	var levels: Array = dock.get("levels", [])
	assert_eq(levels.size(), 4)
	assert_eq(int(((levels[2] as Dictionary).get("cost", {}) as Dictionary).get("brasswork", 0)), 6,
		"region 2's material funds the region 3 unlock")
	assert_eq(int(((levels[3] as Dictionary).get("cost", {}) as Dictionary).get("rimeglass", 0)), 6,
		"region 3's material funds the region 4 unlock")


func test_region_rows_are_pinned() -> void:
	var r3: Dictionary = RegionModel.entry(DataDefs.run, "region_3")
	assert_eq(String(r3.get("name", "")), "Rimefall Shallows")
	assert_eq(int(r3.get("min_dock_level", 0)), 3)
	assert_eq(int(r3.get("fuel_cost", 0)), 3)
	assert_eq(int(r3.get("reduced_fuel_cost", 0)), 2)
	assert_eq(int(r3.get("reduced_at_dock_level", 0)), 4)
	var r4: Dictionary = RegionModel.entry(DataDefs.run, "region_4")
	assert_eq(String(r4.get("name", "")), "Stormglass Verge")
	assert_eq(int(r4.get("min_dock_level", 0)), 4)
	assert_eq(int(r4.get("fuel_cost", 0)), 3)
	assert_false(r4.has("reduced_fuel_cost"),
		"no reduction row until a dock level 5 exists (spec section 8)")


func test_dock_gating_truth_table() -> void:
	var expectations := {
		0: {"region_1": true, "region_2": false, "region_3": false, "region_4": false},
		1: {"region_1": true, "region_2": true, "region_3": false, "region_4": false},
		2: {"region_1": true, "region_2": true, "region_3": false, "region_4": false},
		3: {"region_1": true, "region_2": true, "region_3": true, "region_4": false},
		4: {"region_1": true, "region_2": true, "region_3": true, "region_4": true},
	}
	for dock_level in expectations:
		var island := {"plots": {}, "build_slots": 1}
		if int(dock_level) > 0:
			island["plots"] = {"plot_0": {"building": "dock", "level": int(dock_level)}}
		var expected: Dictionary = expectations[dock_level]
		for region_id in expected:
			assert_eq(RegionModel.unlocked(RegionModel.entry(DataDefs.run, String(region_id)), island),
				bool(expected[region_id]),
				"dock lv %d vs %s" % [int(dock_level), String(region_id)])


func test_region_3_fuel_discount_at_dock_four() -> void:
	var entry := RegionModel.entry(DataDefs.run, "region_3")
	var island := {"plots": {"plot_0": {"building": "dock", "level": 3}}, "build_slots": 1}
	assert_eq(RegionModel.fuel_cost(entry, island), 3)
	(island["plots"]["plot_0"] as Dictionary)["level"] = 4
	assert_eq(RegionModel.fuel_cost(entry, island), 2)


func test_old_saves_read_missing_materials_as_zero() -> void:
	# No migration ships with the new currencies (spec section 7): an old
	# save simply lacks the keys until the first add.
	var state = autofree(preload("res://game/autoload/game_state.gd").new())
	state.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	(state.data["currencies"] as Dictionary).erase("rimeglass")
	(state.data["currencies"] as Dictionary).erase("stormglass")
	var econ = autofree(preload("res://game/autoload/economy.gd").new())
	econ.setup(state)
	assert_eq(econ.balance("rimeglass"), 0)
	econ.add("stormglass", 2)
	assert_eq(econ.balance("stormglass"), 2)
```

- [ ] **Step 2: Run the new file to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_regions_3_4_defs.gd -gexit`
Expected: FAIL on every test (currencies, dock levels, and rows all missing).

- [ ] **Step 3: Add the data**

In `game/data/economy.json`, extend `starting_balances` (after `"storm_oil": 0`):

```json
		"rimeglass": 0,
		"stormglass": 0
```

In `game/data/buildings.json`, in the dock def: change `"max_level": 2` to `"max_level": 4` and append two rows to its `levels` array:

```json
			{
				"cost": {"scrap": 2000, "brasswork": 6},
				"build_seconds": 7200
			},
			{
				"cost": {"scrap": 4000, "rimeglass": 6},
				"build_seconds": 14400
			}
```

In `game/data/run.json`, append two entries to the `regions` array (after the region_2 entry):

```json
		{
			"id": "region_3",
			"name": "Rimefall Shallows",
			"fuel_cost": 3,
			"min_dock_level": 3,
			"reduced_fuel_cost": 2,
			"reduced_at_dock_level": 4
		},
		{
			"id": "region_4",
			"name": "Stormglass Verge",
			"fuel_cost": 3,
			"min_dock_level": 4
		}
```

Match each file's existing indentation exactly; edit surgically.

- [ ] **Step 4: Run the new file to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_regions_3_4_defs.gd -gexit`
Expected: PASS (6 tests).

- [ ] **Step 5: Import, sidecar check, full suite**

Run: `godot --headless --import`
Run: `git status --porcelain` (stage the new `tests/test_regions_3_4_defs.gd.uid`)
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: all green (regions 3/4 are locked at every existing test's dock level, and their skyfield JSONs are never loaded while locked).

- [ ] **Step 6: Commit**

```bash
git add game/data/economy.json game/data/buildings.json game/data/run.json tests/test_regions_3_4_defs.gd tests/test_regions_3_4_defs.gd.uid
git commit -m "feat: rimeglass and stormglass currencies, dock levels 3-4, region rows

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Peg hazards (ice and storm)

**Files:**
- Create: `game/run/storm_peg.gd`
- Modify: `game/run/skyfield.gd:42-57` (_build_pegs, plus one new handler)
- Create: `tests/test_peg_hazards.gd`
- Create: `tests/fixtures/test_region_hazards.json`
- Modify: `tests/test_run_model.gd` (one empty-payout test)

**Interfaces:**
- Consumes: `Skyfield.pod_caught(pod: RigidBody2D, payout: Dictionary, source: String)` signal and the `caught` meta convention; `Geometry.circle_points(radius)`; salvage_run's `_on_pod_caught` (frees the pod, credits nothing for an empty payout, calls `model.resolve_pod`).
- Produces: peg JSON entries accept optional `"type": "ice"` or `"type": "storm"` (Task 4's region JSONs use both); `StormPeg` class (Area2D) with `setup(peg_defs: Dictionary)`, group `"storm_pegs"`; consumed pods arrive at `pod_caught` with payout `{}` and source `"storm"`.

- [ ] **Step 1: Write the failing tests**

Create `tests/fixtures/test_region_hazards.json`:

```json
{
	"name": "Hazard Test",
	"board": {"left": 20, "right": 700, "top": 140, "bottom": 1020},
	"pegs": [
		{"x": 200, "y": 500, "r": 14, "type": "ice"},
		{"x": 500, "y": 500, "r": 14, "type": "storm"}
	],
	"gizmo_slots": [],
	"barges": [
		{"id": "catch_all", "x": 360, "y": 900, "half_width": 340, "half_height": 25, "payout": {"scrap": 12}}
	]
}
```

Create `tests/test_peg_hazards.gd`:

```gdscript
extends GutTest
## Peg hazards (Plan 14, spec 3.4): ice pegs deaden bounce via physics
## material; storm pegs consume uncaught pods through the pod_caught flow.

const SkyfieldScene := preload("res://game/run/skyfield.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var run_defs := {"sea_payout": {"scrap": 1}, "pod": {"radius": 12.0, "bounce": 0.55, "friction": 0.2}}


func build_board() -> Skyfield:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	board.build(DataDefs.load_json("res://tests/fixtures/test_region_hazards.json"), run_defs)
	return board


func make_pod(board: Skyfield, at: Vector2) -> Pod:
	var pod: Pod = PodScene.instantiate()
	pod.position = at
	pod.setup(run_defs["pod"])
	board.add_child(pod)
	return pod


func test_ice_peg_builds_with_dead_bounce_material() -> void:
	var board := build_board()
	var ice: StaticBody2D = board.get_node("Pegs").get_child(0) as StaticBody2D
	assert_not_null(ice.physics_material_override, "ice pegs carry their own material")
	assert_eq(ice.physics_material_override.bounce, 0.0)
	assert_true(ice.physics_material_override.absorbent,
		"absorbent subtracts the peg's bounce during combination, deadening the pod's own material")


func test_storm_peg_builds_as_area_in_group() -> void:
	var board := build_board()
	var storm: Node = board.get_node("Pegs").get_child(1)
	assert_true(storm is StormPeg)
	assert_true(storm.is_in_group("storm_pegs"))


func test_unknown_peg_type_warns_and_builds_a_normal_peg() -> void:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	board.build({
		"board": {"left": 20, "right": 700, "top": 140, "bottom": 1020},
		"pegs": [{"x": 300, "y": 500, "r": 14, "type": "lava"}],
		"gizmo_slots": [], "barges": [],
	}, run_defs)
	assert_push_warning_count(1)
	var peg: StaticBody2D = board.get_node("Pegs").get_child(0) as StaticBody2D
	assert_not_null(peg, "fail-open: a typo costs the hazard, not the board")
	assert_null(peg.physics_material_override)


func test_ice_peg_kills_rebound_on_real_contact() -> void:
	var board := build_board()
	var pod := make_pod(board, Vector2(200, 380))
	var strongest_rebound := 0.0
	for i in 90:
		await wait_physics_frames(1)
		if not is_instance_valid(pod) or pod.has_meta("caught"):
			break
		strongest_rebound = minf(strongest_rebound, pod.linear_velocity.y)
	assert_true(strongest_rebound > -80.0,
		"an ice peg deadens the bounce: the pod never rebounds sharply upward (saw %s)" % strongest_rebound)


func test_storm_peg_consumes_a_real_falling_pod() -> void:
	var board := build_board()
	var captured: Array = []
	board.pod_caught.connect(func(_pod: RigidBody2D, payout: Dictionary, source: String) -> void:
		captured.append([payout, source]))
	var pod := make_pod(board, Vector2(500, 380))
	for i in 180:
		await wait_physics_frames(1)
		if not captured.is_empty():
			break
	assert_eq(captured.size(), 1, "the falling pod was consumed exactly once")
	assert_true((captured[0][0] as Dictionary).is_empty(), "a consumed drop earns nothing")
	assert_eq(String(captured[0][1]), "storm")
	assert_true(pod.has_meta("caught"), "the meta guard keeps catchers and the watchdog off a consumed pod")


func test_storm_peg_ignores_a_caught_pod() -> void:
	var board := build_board()
	var captured: Array = []
	board.pod_caught.connect(func(_pod: RigidBody2D, payout: Dictionary, source: String) -> void:
		captured.append(source))
	var pod := make_pod(board, Vector2(500, 490))
	pod.set_meta("caught", true)
	await wait_physics_frames(4)
	assert_eq(captured, [], "already-resolved pods pass through storm pegs untouched")
```

Append to `tests/test_run_model.gd`:

```gdscript
func test_empty_payout_resolution_spends_the_drop_without_loot() -> void:
	var model := RunModel.new({"drops_per_run": 8, "max_active_pods": 4,
		"quota_tiers": [{"scrap_quota": 5, "payout_multiplier": 1.5}]})
	model.begin_drop()
	model.resolve_pod({})
	assert_eq(model.pods_in_flight, 0, "a consumed pod is resolved, not leaked")
	assert_eq(model.tier, 0, "a consumed pod lifts no tier")
	assert_true(model.loot.is_empty())
	assert_eq(model.drops_remaining(), 7, "the drop is spent")
```

- [ ] **Step 2: Run both files to verify the new tests fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_peg_hazards.gd -gexit`
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_run_model.gd -gexit`
Expected: the hazard tests FAIL (StormPeg does not exist, so the script errors, or the material assertions fail); the run_model test may already PASS (it pins existing resolve behavior); if so, note it and keep it.

- [ ] **Step 3: Implement**

Create `game/run/storm_peg.gd`:

```gdscript
class_name StormPeg
extends Area2D
## Storm peg (spec 3.4 hazard; region JSON pegs with "type": "storm"): a board
## feature that consumes any uncaught pod on contact. The skyfield connects
## body_entered and routes the consumed pod through the normal pod_caught flow
## with an empty payout, so the drop resolves earning nothing.


func setup(peg_defs: Dictionary) -> void:
	position = Vector2(float(peg_defs.get("x", 0)), float(peg_defs.get("y", 0)))
	var shape := CircleShape2D.new()
	shape.radius = float(peg_defs.get("r", 14.0))
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	var visual := Polygon2D.new()
	visual.polygon = Geometry.circle_points(shape.radius)
	visual.color = Color(0.85, 0.45, 0.25)
	add_child(visual)
	add_to_group("storm_pegs")
```

In `game/run/skyfield.gd`, replace `_build_pegs` with:

```gdscript
func _build_pegs(pegs: Array) -> void:
	for peg in pegs:
		var type := String((peg as Dictionary).get("type", ""))
		if type == "storm":
			var storm := StormPeg.new()
			storm.setup(peg as Dictionary)
			storm.body_entered.connect(_on_storm_peg_body)
			$Pegs.add_child(storm)
			continue
		if type != "" and type != "ice":
			# Fail-open authoring guard: a typo costs the hazard, not the board.
			push_warning("Region JSON has unknown peg type '%s'; building a normal peg" % type)
			type = ""
		var body := StaticBody2D.new()
		body.add_to_group("pegs")
		body.position = Vector2(float(peg["x"]), float(peg["y"]))
		var collider := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = float(peg.get("r", 14.0))
		collider.shape = shape
		body.add_child(collider)
		var visual := Polygon2D.new()
		visual.polygon = Geometry.circle_points(shape.radius)
		visual.color = Color(0.55, 0.6, 0.7)
		if type == "ice":
			# Ice peg (spec 3.4 hazard): absorbent + zero bounce subtracts the
			# pod's own restitution during combination, so contact drops dead.
			var material := PhysicsMaterial.new()
			material.bounce = 0.0
			material.absorbent = true
			body.physics_material_override = material
			visual.color = Color(0.7, 0.85, 0.95)
		body.add_child(visual)
		$Pegs.add_child(body)


func _on_storm_peg_body(body: Node2D) -> void:
	# Same guard set as _on_catcher_body: only live, unresolved pods count.
	if not (body is RigidBody2D):
		return
	if body.has_meta("caught"):
		return
	body.set_meta("caught", true)
	pod_caught.emit(body, {}, "storm")
```

- [ ] **Step 4: Run both files to verify they pass**

Same two commands as Step 2. Expected: PASS.

- [ ] **Step 5: Import, sidecar check, full suite**

Run: `godot --headless --import`
Run: `git status --porcelain` (stage `game/run/storm_peg.gd.uid` and `tests/test_peg_hazards.gd.uid`)
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: all green (regions 1 and 2 have no typed pegs, so their builds are byte-identical in behavior).

- [ ] **Step 6: Commit**

```bash
git add game/run/storm_peg.gd game/run/storm_peg.gd.uid game/run/skyfield.gd tests/test_peg_hazards.gd tests/test_peg_hazards.gd.uid tests/fixtures/test_region_hazards.json tests/test_run_model.gd
git commit -m "feat: ice and storm peg hazards in the skyfield build path

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Region 3 and 4 skyfield JSONs and defs tests

**Files:**
- Create: `game/data/skyfields/region_3.json`
- Create: `game/data/skyfields/region_4.json`
- Create: `tests/test_region_3_defs.gd`
- Create: `tests/test_region_4_defs.gd`
- Modify: `tests/test_run_setup.gd:272` (kit clearance region list)

**Interfaces:**
- Consumes: peg `"type"` values `"ice"`/`"storm"` from Task 3; currencies `rimeglass`/`stormglass` from Task 2; `Skyfield.duplicate_barge_ids(barges) -> Array`.
- Produces: the two region JSONs loaded by `DataDefs.skyfield("region_3"/"region_4")`. Nothing later depends on their internals beyond the pins here.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_region_3_defs.gd`:

```gdscript
extends GutTest

const SkyfieldScene := preload("res://game/run/skyfield.tscn")

var run_defs := {"sea_payout": {"scrap": 1}, "pod": {"radius": 12.0, "bounce": 0.55, "friction": 0.2}}


func test_region_3_parses_with_required_keys() -> void:
	var region := DataDefs.skyfield("region_3")
	assert_eq(String(region.get("name", "")), "Rimefall Shallows")
	assert_has(region, "board")
	assert_eq((region.get("gizmo_slots", []) as Array).size(), 9, "spec: 9 slots")
	assert_eq((region.get("barges", []) as Array).size(), 5)
	assert_eq(int((region.get("sea_payout", {}) as Dictionary).get("scrap", 0)), 3)


func test_region_3_barge_ids_are_unique() -> void:
	assert_eq(Skyfield.duplicate_barge_ids(DataDefs.skyfield("region_3").get("barges", [])), [])


func test_region_3_quota_tiers_are_three_and_ascending() -> void:
	var tiers: Array = DataDefs.skyfield("region_3").get("quota_tiers", [])
	assert_eq(tiers.size(), 3, "the first 3-tier region (tripwire fixes landed in this plan)")
	var previous := 0
	for tier in tiers:
		var quota := int((tier as Dictionary).get("scrap_quota", 0))
		assert_true(quota > previous)
		assert_true(float((tier as Dictionary).get("payout_multiplier", 0.0)) > 1.0)
		previous = quota


func test_region_3_drops_rimeglass_on_right_barges() -> void:
	var total := 0
	for barge in DataDefs.skyfield("region_3").get("barges", []):
		total += int(((barge as Dictionary).get("payout", {}) as Dictionary).get("rimeglass", 0))
	assert_true(total >= 3, "spec 3.4: the region drops its distinctive material")


func test_region_3_peg_types_are_known_and_icy() -> void:
	var ice := 0
	for peg in DataDefs.skyfield("region_3").get("pegs", []):
		var type := String((peg as Dictionary).get("type", ""))
		assert_true(type == "" or type == "ice", "region 3 uses only ice hazards")
		if type == "ice":
			ice += 1
	assert_eq(ice, 8)


func test_region_3_board_builds() -> void:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	var region := DataDefs.skyfield("region_3")
	board.build(region, run_defs)
	assert_eq(board.get_node("Pegs").get_child_count(), (region.get("pegs", []) as Array).size())
	assert_eq(board.get_node("GizmoSlots").get_child_count(), 9)
	assert_eq(int(board.sea_payout.get("scrap", 0)), 3)
```

Create `tests/test_region_4_defs.gd`:

```gdscript
extends GutTest

const SkyfieldScene := preload("res://game/run/skyfield.tscn")

var run_defs := {"sea_payout": {"scrap": 1}, "pod": {"radius": 12.0, "bounce": 0.55, "friction": 0.2}}


func test_region_4_parses_with_required_keys() -> void:
	var region := DataDefs.skyfield("region_4")
	assert_eq(String(region.get("name", "")), "Stormglass Verge")
	assert_has(region, "board")
	assert_eq((region.get("gizmo_slots", []) as Array).size(), 10, "spec: 10 slots")
	assert_eq((region.get("barges", []) as Array).size(), 5)
	assert_eq(int((region.get("sea_payout", {}) as Dictionary).get("scrap", 0)), 3)


func test_region_4_barge_ids_are_unique() -> void:
	assert_eq(Skyfield.duplicate_barge_ids(DataDefs.skyfield("region_4").get("barges", [])), [])


func test_region_4_quota_tiers_are_three_and_ascending() -> void:
	var tiers: Array = DataDefs.skyfield("region_4").get("quota_tiers", [])
	assert_eq(tiers.size(), 3)
	var previous := 0
	for tier in tiers:
		var quota := int((tier as Dictionary).get("scrap_quota", 0))
		assert_true(quota > previous)
		assert_true(float((tier as Dictionary).get("payout_multiplier", 0.0)) > 1.0)
		previous = quota


func test_region_4_drops_stormglass_on_right_barges() -> void:
	var total := 0
	for barge in DataDefs.skyfield("region_4").get("barges", []):
		total += int(((barge as Dictionary).get("payout", {}) as Dictionary).get("stormglass", 0))
	assert_true(total >= 3, "spec 3.4: the region drops its distinctive material")


func test_region_4_peg_types_are_known_and_stormy() -> void:
	var storm := 0
	for peg in DataDefs.skyfield("region_4").get("pegs", []):
		var type := String((peg as Dictionary).get("type", ""))
		assert_true(type == "" or type == "storm", "region 4 uses only storm hazards")
		if type == "storm":
			storm += 1
	assert_eq(storm, 6)


func test_region_4_board_builds_with_storm_pegs() -> void:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	var region := DataDefs.skyfield("region_4")
	board.build(region, run_defs)
	assert_eq(board.get_node("Pegs").get_child_count(), (region.get("pegs", []) as Array).size())
	assert_eq(board.get_node("GizmoSlots").get_child_count(), 10)
	assert_eq(get_tree().get_nodes_in_group("storm_pegs").size(), 6)
```

In `tests/test_run_setup.gd`, `test_kit_panel_intersects_no_slot_target_in_any_region` (line 272): change the region list to:

```gdscript
	for region_id in ["region_1", "region_2", "region_3", "region_4"]:
```

- [ ] **Step 2: Run the two new files to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_region_3_defs.gd -gexit`
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_region_4_defs.gd -gexit`
Expected: FAIL (the skyfield JSONs do not exist; DataDefs.skyfield returns empty).

- [ ] **Step 3: Create the region files**

Create `game/data/skyfields/region_3.json` with EXACTLY this content (48 pegs, 8 ice on the right shelves; slot rects verified clear of the kit band x 160-560 / y 830-925):

```json
{
	"name": "Rimefall Shallows",
	"board": {"left": 20, "right": 700, "top": 140, "bottom": 1020},
	"quota_tiers": [
		{"scrap_quota": 50, "payout_multiplier": 1.3},
		{"scrap_quota": 110, "payout_multiplier": 1.6},
		{"scrap_quota": 180, "payout_multiplier": 2.0}
	],
	"sea_payout": {"scrap": 3},
	"pegs": [
		{"x": 194, "y": 250, "r": 14},
		{"x": 268, "y": 250, "r": 14},
		{"x": 342, "y": 250, "r": 14},
		{"x": 416, "y": 250, "r": 14},
		{"x": 490, "y": 250, "r": 14},
		{"x": 564, "y": 250, "r": 14},
		{"x": 157, "y": 340, "r": 14},
		{"x": 231, "y": 340, "r": 14},
		{"x": 305, "y": 340, "r": 14},
		{"x": 379, "y": 340, "r": 14},
		{"x": 453, "y": 340, "r": 14, "type": "ice"},
		{"x": 527, "y": 340, "r": 14, "type": "ice"},
		{"x": 120, "y": 430, "r": 14},
		{"x": 194, "y": 430, "r": 14},
		{"x": 268, "y": 430, "r": 14},
		{"x": 342, "y": 430, "r": 14},
		{"x": 416, "y": 430, "r": 14},
		{"x": 490, "y": 430, "r": 14},
		{"x": 564, "y": 430, "r": 14, "type": "ice"},
		{"x": 638, "y": 430, "r": 14, "type": "ice"},
		{"x": 157, "y": 520, "r": 14},
		{"x": 231, "y": 520, "r": 14},
		{"x": 305, "y": 520, "r": 14},
		{"x": 379, "y": 520, "r": 14},
		{"x": 453, "y": 520, "r": 14, "type": "ice"},
		{"x": 527, "y": 520, "r": 14, "type": "ice"},
		{"x": 120, "y": 610, "r": 14},
		{"x": 194, "y": 610, "r": 14},
		{"x": 268, "y": 610, "r": 14},
		{"x": 342, "y": 610, "r": 14},
		{"x": 416, "y": 610, "r": 14},
		{"x": 490, "y": 610, "r": 14},
		{"x": 564, "y": 610, "r": 14, "type": "ice"},
		{"x": 638, "y": 610, "r": 14, "type": "ice"},
		{"x": 157, "y": 700, "r": 14},
		{"x": 231, "y": 700, "r": 14},
		{"x": 305, "y": 700, "r": 14},
		{"x": 379, "y": 700, "r": 14},
		{"x": 453, "y": 700, "r": 14},
		{"x": 527, "y": 700, "r": 14},
		{"x": 120, "y": 790, "r": 14},
		{"x": 194, "y": 790, "r": 14},
		{"x": 268, "y": 790, "r": 14},
		{"x": 342, "y": 790, "r": 14},
		{"x": 416, "y": 790, "r": 14},
		{"x": 490, "y": 790, "r": 14},
		{"x": 564, "y": 790, "r": 14},
		{"x": 638, "y": 790, "r": 14}
	],
	"gizmo_slots": [
		{"x": 70, "y": 300},
		{"x": 630, "y": 300},
		{"x": 70, "y": 500},
		{"x": 630, "y": 500},
		{"x": 70, "y": 700},
		{"x": 630, "y": 700},
		{"x": 250, "y": 180},
		{"x": 360, "y": 180},
		{"x": 470, "y": 180}
	],
	"barges": [
		{"id": "far_left", "x": 90, "y": 1060, "half_width": 50, "half_height": 25, "payout": {"scrap": 20}},
		{"id": "left", "x": 225, "y": 1060, "half_width": 50, "half_height": 25, "payout": {"scrap": 9}},
		{"id": "center", "x": 360, "y": 1060, "half_width": 50, "half_height": 25, "payout": {"scrap": 4}},
		{"id": "right", "x": 495, "y": 1060, "half_width": 50, "half_height": 25, "payout": {"scrap": 9, "rimeglass": 1}},
		{"id": "far_right", "x": 630, "y": 1060, "half_width": 50, "half_height": 25, "payout": {"scrap": 14, "rimeglass": 2}}
	]
}
```

Create `game/data/skyfields/region_4.json` with EXACTLY this content (44 pegs, 6 storm pegs on a diagonal through the middle lanes):

```json
{
	"name": "Stormglass Verge",
	"board": {"left": 20, "right": 700, "top": 140, "bottom": 1020},
	"quota_tiers": [
		{"scrap_quota": 70, "payout_multiplier": 1.3},
		{"scrap_quota": 150, "payout_multiplier": 1.7},
		{"scrap_quota": 250, "payout_multiplier": 2.2}
	],
	"sea_payout": {"scrap": 3},
	"pegs": [
		{"x": 105, "y": 370, "r": 14},
		{"x": 105, "y": 610, "r": 14},
		{"x": 105, "y": 850, "r": 14},
		{"x": 163, "y": 310, "r": 14},
		{"x": 163, "y": 430, "r": 14},
		{"x": 163, "y": 550, "r": 14},
		{"x": 163, "y": 670, "r": 14},
		{"x": 163, "y": 790, "r": 14},
		{"x": 221, "y": 250, "r": 14},
		{"x": 221, "y": 370, "r": 14, "type": "storm"},
		{"x": 221, "y": 490, "r": 14},
		{"x": 221, "y": 610, "r": 14},
		{"x": 221, "y": 730, "r": 14, "type": "storm"},
		{"x": 221, "y": 850, "r": 14},
		{"x": 279, "y": 310, "r": 14},
		{"x": 279, "y": 430, "r": 14},
		{"x": 279, "y": 550, "r": 14},
		{"x": 279, "y": 670, "r": 14, "type": "storm"},
		{"x": 279, "y": 790, "r": 14},
		{"x": 337, "y": 250, "r": 14},
		{"x": 337, "y": 370, "r": 14},
		{"x": 337, "y": 490, "r": 14},
		{"x": 337, "y": 610, "r": 14, "type": "storm"},
		{"x": 337, "y": 730, "r": 14},
		{"x": 337, "y": 850, "r": 14},
		{"x": 395, "y": 310, "r": 14},
		{"x": 395, "y": 430, "r": 14},
		{"x": 395, "y": 550, "r": 14, "type": "storm"},
		{"x": 395, "y": 670, "r": 14},
		{"x": 395, "y": 790, "r": 14},
		{"x": 453, "y": 250, "r": 14},
		{"x": 453, "y": 370, "r": 14},
		{"x": 453, "y": 490, "r": 14, "type": "storm"},
		{"x": 453, "y": 610, "r": 14},
		{"x": 453, "y": 730, "r": 14},
		{"x": 453, "y": 850, "r": 14},
		{"x": 511, "y": 310, "r": 14},
		{"x": 511, "y": 430, "r": 14},
		{"x": 511, "y": 550, "r": 14},
		{"x": 511, "y": 670, "r": 14},
		{"x": 511, "y": 790, "r": 14},
		{"x": 569, "y": 370, "r": 14},
		{"x": 569, "y": 610, "r": 14},
		{"x": 569, "y": 850, "r": 14}
	],
	"gizmo_slots": [
		{"x": 70, "y": 300},
		{"x": 630, "y": 300},
		{"x": 70, "y": 500},
		{"x": 630, "y": 500},
		{"x": 70, "y": 700},
		{"x": 630, "y": 700},
		{"x": 70, "y": 980},
		{"x": 630, "y": 980},
		{"x": 300, "y": 180},
		{"x": 420, "y": 180}
	],
	"barges": [
		{"id": "far_left", "x": 90, "y": 1060, "half_width": 50, "half_height": 25, "payout": {"scrap": 26}},
		{"id": "left", "x": 225, "y": 1060, "half_width": 50, "half_height": 25, "payout": {"scrap": 12}},
		{"id": "center", "x": 360, "y": 1060, "half_width": 50, "half_height": 25, "payout": {"scrap": 5}},
		{"id": "right", "x": 495, "y": 1060, "half_width": 50, "half_height": 25, "payout": {"scrap": 12, "stormglass": 1}},
		{"id": "far_right", "x": 630, "y": 1060, "half_width": 50, "half_height": 25, "payout": {"scrap": 18, "stormglass": 2}}
	]
}
```

- [ ] **Step 4: Run the two files to verify they pass**

Same two commands as Step 2. Expected: PASS.

- [ ] **Step 5: Import, sidecar check, full suite**

Run: `godot --headless --import`
Run: `git status --porcelain` (stage the two new test `.gd.uid` sidecars)
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: all green, including the extended kit-clearance test over all four regions.

- [ ] **Step 6: Commit**

```bash
git add game/data/skyfields/region_3.json game/data/skyfields/region_4.json tests/test_region_3_defs.gd tests/test_region_3_defs.gd.uid tests/test_region_4_defs.gd tests/test_region_4_defs.gd.uid tests/test_run_setup.gd
git commit -m "feat: Rimefall Shallows and Stormglass Verge skyfields

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Sleet Sail and Gale Vent gizmos

**Files:**
- Create: `game/run/gizmos/sleet_sail.gd`, `game/run/gizmos/sleet_sail.tscn`
- Create: `game/run/gizmos/gale_vent.gd`, `game/run/gizmos/gale_vent.tscn`
- Modify: `game/data/gizmos.json` (two new defs)
- Modify: `tests/test_gizmo_rarity_defs.gd` (tier table gains two rows)
- Create: `tests/test_sleet_sail.gd`, `tests/test_gale_vent.gd`
- Modify: `tests/test_gizmo_integration.gd` (two real-contact proofs)

**Interfaces:**
- Consumes: `GizmoBase.setup(gizmo_defs, gizmo_level, run_context)`, `level`, `scaled(base)`; currencies `rimeglass`/`stormglass` from Task 2; the rarity gate from Plan 13 (`"rarity": "rare"` means Workshop Lv3 to craft).
- Produces: gizmo ids `sleet_sail` and `gale_vent` in gizmos.json defs; classes `SleetSail` and `GaleVent`. Nothing later consumes them.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_sleet_sail.gd`:

```gdscript
extends GutTest

const SailScene := preload("res://game/run/gizmos/sleet_sail.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var sail_defs: Dictionary


func before_each() -> void:
	sail_defs = (DataDefs.gizmos["defs"]["sleet_sail"] as Dictionary).duplicate()


func make_sail(level: int) -> Node:
	var sail = add_child_autofree(SailScene.instantiate())
	sail.position = Vector2(360, 500)
	sail.setup(sail_defs, level, self)
	return sail


func make_pod() -> Pod:
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	pod.position = Vector2(360, 300)
	pod.setup({"radius": 12.0, "bounce": 0.55, "friction": 0.2})
	return pod


func test_pod_falls_slower_inside_the_column() -> void:
	var sail = make_sail(1)
	var pod := make_pod()
	sail._on_body_entered(pod)
	assert_almost_eq(pod.gravity_scale, 0.5, 0.001, "gravity halves inside the sail's column")


func test_gravity_restored_on_exit() -> void:
	var sail = make_sail(1)
	var pod := make_pod()
	sail._on_body_entered(pod)
	sail._on_body_exited(pod)
	assert_almost_eq(pod.gravity_scale, 1.0, 0.001)


func test_caught_pod_is_ignored() -> void:
	var sail = make_sail(1)
	var pod := make_pod()
	pod.set_meta("caught", true)
	sail._on_body_entered(pod)
	assert_almost_eq(pod.gravity_scale, 1.0, 0.001)


func test_column_width_scales_with_level() -> void:
	var lv5 = make_sail(5)
	var shape: RectangleShape2D = lv5.get_node("Zone/Shape").shape as RectangleShape2D
	assert_almost_eq(shape.size.x, 160.0, 0.001, "80 base x 2.0 at level 5; the gravity factor never scales")
```

Create `tests/test_gale_vent.gd`:

```gdscript
extends GutTest

const VentScene := preload("res://game/run/gizmos/gale_vent.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var vent_defs: Dictionary


func before_each() -> void:
	vent_defs = (DataDefs.gizmos["defs"]["gale_vent"] as Dictionary).duplicate()


func make_vent(level: int) -> Node:
	var vent = add_child_autofree(VentScene.instantiate())
	vent.position = Vector2(360, 500)
	vent.setup(vent_defs, level, self)
	return vent


func make_pod() -> Pod:
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	pod.position = Vector2(360, 480)
	pod.setup({"radius": 12.0, "bounce": 0.55, "friction": 0.2})
	return pod


func test_kick_applies_upward_impulse_once_per_vent() -> void:
	var vent = make_vent(1)
	var pod := make_pod()
	vent._on_body_entered(pod)
	await wait_physics_frames(2)
	var vy_after_kick: float = pod.linear_velocity.y
	assert_true(vy_after_kick < 0.0, "the vent kicks the pod upward")
	vent._on_body_entered(pod)
	await wait_physics_frames(2)
	assert_true(pod.linear_velocity.y >= vy_after_kick,
		"a second contact with the SAME vent adds no second kick")


func test_two_vents_each_get_their_own_kick() -> void:
	var first = make_vent(1)
	var second = make_vent(1)
	var pod := make_pod()
	first._on_body_entered(pod)
	second._on_body_entered(pod)
	assert_true(pod.has_meta("gale_vented_%d" % first.get_instance_id()))
	assert_true(pod.has_meta("gale_vented_%d" % second.get_instance_id()))


func test_impulse_scales_with_level() -> void:
	var lv3 = make_vent(3)
	assert_almost_eq(lv3._impulse, 570.0, 0.001, "380 base x 1.5 at level 3")


func test_caught_pod_is_ignored() -> void:
	var vent = make_vent(1)
	var pod := make_pod()
	pod.set_meta("caught", true)
	vent._on_body_entered(pod)
	assert_false(pod.has_meta("gale_vented_%d" % vent.get_instance_id()))
```

In `tests/test_gizmo_rarity_defs.gd`, `test_tier_table_is_pinned`: add two rows to the `expected` dictionary (the size assertion then pins 12):

```gdscript
		"sleet_sail": "rare",
		"gale_vent": "rare",
```

Append to `tests/test_gizmo_integration.gd`:

```gdscript
func test_sleet_sail_slows_a_real_drop_and_restores_gravity() -> void:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	board.build(DataDefs.load_json("res://tests/fixtures/test_region_slot.json"), run_defs)
	board.install_gizmos({"slot_0": "sleet_sail"}, DataDefs.gizmos, {"sleet_sail": 1}, self)
	var pod: Pod = PodScene.instantiate()
	pod.position = Vector2(360, 160)
	pod.setup(run_defs["pod"])
	board.add_child(pod)
	var slowed := false
	var restored := false
	for i in 240:
		await wait_physics_frames(1)
		if not is_instance_valid(pod) or pod.has_meta("caught"):
			break
		if not slowed and is_equal_approx(pod.gravity_scale, 0.5):
			slowed = true
		elif slowed and is_equal_approx(pod.gravity_scale, 1.0):
			restored = true
			break
	assert_true(slowed, "the falling pod entered the column at half gravity")
	assert_true(restored, "gravity came back once the pod left the column")


func test_gale_vent_kicks_a_real_drop_once() -> void:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	board.build(DataDefs.load_json("res://tests/fixtures/test_region_slot.json"), run_defs)
	board.install_gizmos({"slot_0": "gale_vent"}, DataDefs.gizmos, {"gale_vent": 1}, self)
	var vent: GizmoBase = board.get_node("Gizmos").get_child(0)
	var meta_key := "gale_vented_%d" % vent.get_instance_id()
	var pod: Pod = PodScene.instantiate()
	pod.position = Vector2(360, 160)
	pod.setup(run_defs["pod"])
	board.add_child(pod)
	var kicked := false
	for i in 240:
		await wait_physics_frames(1)
		if not is_instance_valid(pod):
			break
		if pod.has_meta(meta_key):
			kicked = true
			break
	assert_true(kicked, "real contact triggers the vent exactly once, without engine errors")
	var caught: bool = await wait_for_signal(board.pod_caught, 12.0)
	assert_true(caught, "the kicked pod still lands within 12s")
```

- [ ] **Step 2: Run the new files to verify they fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_sleet_sail.gd -gexit`
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_gale_vent.gd -gexit`
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_gizmo_rarity_defs.gd -gexit`
Expected: the first two FAIL (scenes do not exist: preload errors); the rarity pin FAILS (tier table has 10 defs, expected 12).

- [ ] **Step 3: Implement**

Create `game/run/gizmos/sleet_sail.gd`:

```gdscript
class_name SleetSail
extends GizmoBase
## Sleet Sail (region 3, rimeglass): pods inside its column fall at reduced
## gravity, drifting long enough to rack up more peg hits. The column WIDTH
## scales with level; the gravity factor is level-independent. gravity_scale
## restores on exit; a pod freed inside the zone exits via body_exited, so
## the is_instance_valid guard keeps the restore safe.

@onready var zone: Area2D = $Zone


func _configure() -> void:
	var rect := RectangleShape2D.new()
	rect.size = Vector2(scaled(float(defs.get("column_width", 80.0))), float(defs.get("column_height", 420.0)))
	$Zone/Shape.shape = rect
	zone.position = Vector2(0.0, -rect.size.y / 2.0)
	var visual: Polygon2D = $Visual
	visual.polygon = PackedVector2Array([
		Vector2(-20, -14), Vector2(20, -14), Vector2(20, 14), Vector2(-20, 14),
	])
	visual.color = Color(0.75, 0.9, 1.0)
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body is RigidBody2D and not body.has_meta("caught"):
		body.gravity_scale = float(defs.get("gravity_factor", 0.5))


func _on_body_exited(body: Node2D) -> void:
	if is_instance_valid(body) and body is RigidBody2D:
		body.gravity_scale = 1.0
```

Create `game/run/gizmos/sleet_sail.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://game/run/gizmos/sleet_sail.gd" id="1_ss"]

[node name="SleetSail" type="Node2D"]
script = ExtResource("1_ss")

[node name="Zone" type="Area2D" parent="."]

[node name="Shape" type="CollisionShape2D" parent="Zone"]

[node name="Visual" type="Polygon2D" parent="."]
```

Create `game/run/gizmos/gale_vent.gd`:

```gdscript
class_name GaleVent
extends GizmoBase
## Gale Vent (region 4, stormglass): one sharp upward kick per pod per vent,
## a re-loft tool for dodging storm pegs. The per-pod meta key carries this
## vent's instance id so two vents each land their own kick on the same pod.
## Impulse inside body_entered is safe per the Piston Kicker precedent.

var _impulse := 0.0

@onready var zone: Area2D = $Zone


func _configure() -> void:
	_impulse = scaled(float(defs.get("impulse", 380.0)))
	var circle := CircleShape2D.new()
	circle.radius = float(defs.get("radius", 28.0))
	$Zone/Shape.shape = circle
	var visual: Polygon2D = $Visual
	visual.polygon = PackedVector2Array([
		Vector2(-22, 10), Vector2(0, -22), Vector2(22, 10),
	])
	visual.color = Color(0.55, 0.75, 0.6)
	zone.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var meta_key := "gale_vented_%d" % get_instance_id()
	if not (body is RigidBody2D) or body.has_meta("caught") or body.has_meta(meta_key):
		return
	body.set_meta(meta_key, true)
	body.apply_central_impulse(Vector2(0.0, -_impulse))
```

Create `game/run/gizmos/gale_vent.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://game/run/gizmos/gale_vent.gd" id="1_gv"]

[node name="GaleVent" type="Node2D"]
script = ExtResource("1_gv")

[node name="Zone" type="Area2D" parent="."]

[node name="Shape" type="CollisionShape2D" parent="Zone"]

[node name="Visual" type="Polygon2D" parent="."]
```

In `game/data/gizmos.json`, append two defs to the `defs` dictionary (after `piston_kicker`, matching the file's indentation):

```json
		"sleet_sail": {
			"name": "Sleet Sail",
			"rarity": "rare",
			"scene": "res://game/run/gizmos/sleet_sail.tscn",
			"column_width": 80.0,
			"column_height": 420.0,
			"gravity_factor": 0.5,
			"craft_cost": {
				"parts": 5,
				"rimeglass": 2
			},
			"craft_seconds": 480
		},
		"gale_vent": {
			"name": "Gale Vent",
			"rarity": "rare",
			"scene": "res://game/run/gizmos/gale_vent.tscn",
			"radius": 28.0,
			"impulse": 380.0,
			"craft_cost": {
				"parts": 5,
				"stormglass": 2
			},
			"craft_seconds": 480
		}
```

- [ ] **Step 4: Run the files to verify they pass**

Run each separately:
`godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_sleet_sail.gd -gexit`
`godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_gale_vent.gd -gexit`
`godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_gizmo_rarity_defs.gd -gexit`
`godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_gizmo_integration.gd -gexit`
Expected: PASS. (Run `godot --headless --import` FIRST so the new .tscn/.gd files are importable.)

- [ ] **Step 5: Sidecar check, full suite**

Run: `git status --porcelain` (stage `sleet_sail.gd.uid`, `gale_vent.gd.uid`, `test_sleet_sail.gd.uid`, `test_gale_vent.gd.uid`)
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: all green (the new defs are rare and unowned, so no starter/workshop test changes; the workshop screen shows two more dimmed rows via its defs iteration).

- [ ] **Step 6: Commit**

```bash
git add game/run/gizmos/sleet_sail.gd game/run/gizmos/sleet_sail.gd.uid game/run/gizmos/sleet_sail.tscn game/run/gizmos/gale_vent.gd game/run/gizmos/gale_vent.gd.uid game/run/gizmos/gale_vent.tscn game/data/gizmos.json tests/test_sleet_sail.gd tests/test_sleet_sail.gd.uid tests/test_gale_vent.gd tests/test_gale_vent.gd.uid tests/test_gizmo_rarity_defs.gd tests/test_gizmo_integration.gd
git commit -m "feat: Sleet Sail and Gale Vent rare gizmos

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Roadmap update

**Files:**
- Modify: `docs/ROADMAP.md`

**Interfaces:**
- Consumes: nothing (docs only). Produces: the roadmap reflects Plan 14 shipped.

- [ ] **Step 1: Update the roadmap**

In `docs/ROADMAP.md`:

1. Replace the entire "### Regions 3+" section (heading line kept, body replaced; the old body's tripwire block is deleted because the fixes shipped) with:

```markdown
### Regions 3+
- Regions 3 and 4 SHIPPED (Plan 14, spec: docs/superpowers/specs/2026-09-14-regions-3-and-4-design.md): Rimefall Shallows (ice pegs, rimeglass, Dock Lv3, 3 quota tiers) and Stormglass Verge (storm pegs, stormglass, Dock Lv4, 3 tiers), plus the Plan 7 boon tripwire fixes (exhausted-pool offers close out and re-enable drops; pointless rerolls hide via BoonModel.reroll_candidates; maxf composition pinned). Peg hazards are data-driven ("type": "ice"/"storm" on peg rows; unknown types warn and build normal pegs). Two new rare gizmos: Sleet Sail (rimeglass) and Gale Vent (stormglass).
- Region 5+ is JSON authoring plus at most one new hazard; a fuel-reduction row for region 4 wants a Dock Lv5 first. The remaining boon latency: growing the pool past six composes fine now, but only one barge and one sea booster exist in data.
```

2. Update the "**As of:**" header line to the merge commit and date at merge time (write "full suite green", never a test count), and bump the "**State:**" line's plan range to include Plan 14.

- [ ] **Step 2: Verify and commit**

Run: `git diff docs/ROADMAP.md` and read it once for typos and em dashes (none allowed).

```bash
git add docs/ROADMAP.md
git commit -m "docs: roadmap marks regions 3 and 4 shipped

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Final verification (for the whole-branch reviewer)

- Full suite exits 0; `git status --porcelain` shows no untracked `.gd.uid` sidecars.
- Spec spot-checks: tripwire fixes landed BEFORE the 3-tier data (commit order); storm pegs route through `pod_caught` with `{}`/`"storm"` and never touch a caught pod; ice pegs are pure physics material; regions 1 and 2 build unchanged; the kit-clearance test covers all four regions; the rarity tier table pins 12 entries; no schema bump anywhere.
- Owner smoke additions (windowed/on-device, waived headless): unlock Dock Lv3 via a hand-edited save and drop pods off the ice shelves in region 3 (the dead thud should feel readable); region 4 storm pegs should read as clearly lethal at a glance (placeholder orange circles until the art pass); the boon offer flow after taking all six boons in one run.
