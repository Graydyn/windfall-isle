# Windfall Isles Plan 2: Salvage Run Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the playable salvage-drop loop: a data-driven skyfield peg board, physics pods dropped by tap/drag, collection barges that pay out into the Economy, and a complete run flow (spend fuel, 8 drops, results, abandon-anytime with loot intact).

**Architecture:** All run logic that matters lives in `RunModel`, a pure RefCounted state machine tested without physics; the scene layer (Skyfield board, Pod bodies, DropController input) only feeds it events. The board is built entirely from JSON (`game/data/skyfields/region_1.json`), so new regions are data additions. Loot is credited to Economy the moment each pod is caught, which combined with GameState's save-on-pause makes "never lose collected loot" hold under any interruption.

**Tech Stack:** Godot 4.6.3 (GDScript, built-in 2D physics: RigidBody2D pods, StaticBody2D pegs, Area2D catchers), GUT 9.6.1 headless tests.

**Spec:** [docs/design/2026-08-15-windfall-isles-design.md](../design/2026-08-15-windfall-isles-design.md) sections 3.1, 3.2 (skyfield, runs), plus 4.2 (payout currencies) and the pillars in section 1. Plan 1 (landed on main) provides the consumed foundation; its plan is [2026-08-15-windfall-isles-plan-1-foundation.md](2026-08-15-windfall-isles-plan-1-foundation.md).

## Global Constraints

- Engine: Godot 4.6.x pinned. `$GODOT` must point at `/Applications/Godot-4.6.app/Contents/MacOS/Godot` (4.6.3). Never use plain `godot` or `/Applications/Godot.app` (that is 4.7).
- Language: GDScript only. Tabs for indentation.
- Portrait 720x1280. Native touch only: taps and swipes, no virtual joystick (spec section 1 hard constraints).
- Completely offline; no network calls.
- Every tunable number lives in `game/data/*.json`, never in scripts (spec 7.2).
- Physics: hard cap on simultaneous pods for low-end devices (spec 7.1); cap value lives in run.json.
- No fail state: pods that miss all barges pay the minimum sea payout, never zero (spec 3.1); a run can be abandoned at any moment with loot intact (spec 3.2).
- Time discipline from Plan 1: logic takes `now: int` explicitly; only call boundaries use `TimeUtil.now()`.
- Testing: GUT, run headless from the repo root:
  `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (must exit 0)
- Repo conventions from Plan 1: commit auto-generated `.gd.uid` sidecars with their scripts (scenes get no sidecar; Godot may add uid attributes to `.tscn` files on import, commit those rewrites); GUT 9.6 fails tests on pushed/engine errors, so error-path tests declare `assert_push_error_count` / `assert_engine_error_count`.
- Do NOT state or rely on cumulative suite totals (Plan 1's counts drifted); each task names its new tests and requires the full suite to pass with exit 0.
- Commit after every task, conventional-commit messages.

## Interfaces consumed from Plan 1 (all on main, signatures exact)

- `DataDefs` autoload: `economy: Dictionary`, `static load_json(path: String) -> Dictionary` ({} + push_error on missing/malformed).
- `Economy` autoload: `balance(currency) -> int`, `add(currency, amount)`, `spend(currency, amount) -> bool`, `can_afford(cost) -> bool`, `pay(cost) -> bool`, `signal balance_changed(currency: String, amount: int)`.
- `GameState` autoload: `data: Dictionary` (keys version/created_at/currencies/fuel/timers/island/gizmos), `save_game() -> Error`, `load_game(defs, now)`, `_io: SaveIO` (injectable in tests).
- `FuelModel`: `current(fuel, now) -> int`, `spend(fuel, amount, now) -> bool`.
- `SaveSchema`: `default_data(defs) -> Dictionary`.
- `TimeUtil.now() -> int`.

## File Structure

```
game/data/run.json                    # T1  run tunables (fuel cost, drops, pod, cap, sea payout)
game/data/skyfields/region_1.json     # T1  region 1 board layout (pegs, barges, slots, bounds)
game/autoload/data_defs.gd            # T1  modify: add run defs + skyfield loader
game/autoload/economy.gd              # T2  modify: runtime negative-amount guards
game/core/geometry.gd                 # T4  circle_points helper shared by pod/board visuals
game/run/run_model.gd                 # T3  pure run state machine (drops, loot, abandon)
game/run/pod.gd + pod.tscn            # T4  RigidBody2D salvage pod
game/run/skyfield.gd + skyfield.tscn  # T5  board built from region JSON; catch signal (T6)
game/run/drop_controller.gd           # T7  tap/drag top-edge input -> drop_requested
game/run/salvage_run.gd + .tscn       # T8  run scene glue: model + board + input + results UI
game/main.gd + main.tscn              # T9  modify: launch button, fuel spend, scene switch
project.godot                         # T7  modify: emulate_touch_from_mouse
tests/fixtures/test_region.json       # T6  single-barge fixture board
tests/fixtures/test_region_empty.json # T6  no-barge fixture (sea catch)
tests/test_run_defs.gd                # T1
tests/test_economy.gd                 # T2  modify: 3 guard tests
tests/test_run_model.gd               # T3
tests/test_pod.gd                     # T4
tests/test_skyfield.gd                # T5 (build) + T6 (physics catch)
tests/test_drop_controller.gd         # T7
tests/test_salvage_run.gd             # T8
tests/test_main_boot.gd               # T9  modify: launch button asserts
```

Deferred to later plans on purpose: gizmo behavior (Plan 3 attaches to the `GizmoSlots` markers this plan creates), quota tiers and boons (Plan 5 per roadmap), Balloonworks-driven drops upgrades (Plan 4 will override `drops_per_run` from GameState).

---

### Task 1: Run and region tunables

**Files:**
- Create: `game/data/run.json`
- Create: `game/data/skyfields/region_1.json`
- Modify: `game/autoload/data_defs.gd`
- Test: `tests/test_run_defs.gd`

**Interfaces:**
- Consumes: `DataDefs.load_json` (Plan 1).
- Produces: `DataDefs.run: Dictionary` with keys `fuel_cost:int`, `drops_per_run:int`, `max_active_pods:int`, `pod_timeout_seconds:float`, `pod:{radius,bounce,friction}`, `sea_payout:{scrap:1}`; `DataDefs.skyfield(region_id: String) -> Dictionary` loading `res://game/data/skyfields/<region_id>.json` with keys `board:{left,right,top,bottom}`, `pegs:[{x,y,r}]`, `barges:[{id,x,y,half_width,half_height,payout}]`, `gizmo_slots:[{x,y}]`. Tasks 3, 5, 8, 9 consume these.

- [ ] **Step 1: Write the failing tests**

`tests/test_run_defs.gd`:

```gdscript
extends GutTest

const DataDefsScript := preload("res://game/autoload/data_defs.gd")


func test_run_defs_load_with_required_keys() -> void:
	assert_has(DataDefs.run, "fuel_cost")
	assert_has(DataDefs.run, "drops_per_run")
	assert_has(DataDefs.run, "max_active_pods")
	assert_has(DataDefs.run, "pod_timeout_seconds")
	assert_has(DataDefs.run, "pod")
	assert_has(DataDefs.run, "sea_payout")
	assert_true(int(DataDefs.run["fuel_cost"]) > 0)
	assert_true(int(DataDefs.run["drops_per_run"]) >= 8, "spec 3.2: 8-12 drops")
	assert_true(int(DataDefs.run["sea_payout"]["scrap"]) >= 1, "sea payout is never zero (spec 3.1)")

func test_region_1_layout() -> void:
	var region := DataDefs.skyfield("region_1")
	assert_has(region, "board")
	for key in ["left", "right", "top", "bottom"]:
		assert_has(region["board"], key)
	assert_eq(region["pegs"].size(), 32)
	assert_eq(region["barges"].size(), 5, "spec 3.1: 3-5 collection barges")
	for barge in region["barges"]:
		assert_has(barge, "payout")
		assert_true((barge["payout"] as Dictionary).size() > 0)
	assert_eq(region["gizmo_slots"].size(), 6, "spec MVP: ~6 gizmo slots")

func test_unknown_skyfield_returns_empty() -> void:
	assert_eq(DataDefs.skyfield("region_nope"), {})
	assert_push_error_count(1)
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: FAIL (`DataDefs.run` and `DataDefs.skyfield` do not exist).

- [ ] **Step 3: Write the data files and loader additions**

`game/data/run.json`:

```json
{
	"fuel_cost": 1,
	"drops_per_run": 8,
	"max_active_pods": 4,
	"pod_timeout_seconds": 12.0,
	"pod": {
		"radius": 12.0,
		"bounce": 0.55,
		"friction": 0.2
	},
	"sea_payout": {
		"scrap": 1
	}
}
```

`game/data/skyfields/region_1.json` (board coordinates in the 720x1280 viewport; 7 staggered peg rows; 5 barges at y=1060 with ~35px sea gaps between them; richer payouts toward the edges, regional cloudsilk on the far right):

```json
{
	"name": "Home Skies",
	"board": {"left": 20, "right": 700, "top": 140, "bottom": 1020},
	"pegs": [
		{"x": 100, "y": 280, "r": 14}, {"x": 230, "y": 280, "r": 14}, {"x": 360, "y": 280, "r": 14}, {"x": 490, "y": 280, "r": 14}, {"x": 620, "y": 280, "r": 14},
		{"x": 165, "y": 390, "r": 14}, {"x": 295, "y": 390, "r": 14}, {"x": 425, "y": 390, "r": 14}, {"x": 555, "y": 390, "r": 14},
		{"x": 100, "y": 500, "r": 14}, {"x": 230, "y": 500, "r": 14}, {"x": 360, "y": 500, "r": 14}, {"x": 490, "y": 500, "r": 14}, {"x": 620, "y": 500, "r": 14},
		{"x": 165, "y": 610, "r": 14}, {"x": 295, "y": 610, "r": 14}, {"x": 425, "y": 610, "r": 14}, {"x": 555, "y": 610, "r": 14},
		{"x": 100, "y": 720, "r": 14}, {"x": 230, "y": 720, "r": 14}, {"x": 360, "y": 720, "r": 14}, {"x": 490, "y": 720, "r": 14}, {"x": 620, "y": 720, "r": 14},
		{"x": 165, "y": 830, "r": 14}, {"x": 295, "y": 830, "r": 14}, {"x": 425, "y": 830, "r": 14}, {"x": 555, "y": 830, "r": 14},
		{"x": 100, "y": 940, "r": 14}, {"x": 230, "y": 940, "r": 14}, {"x": 360, "y": 940, "r": 14}, {"x": 490, "y": 940, "r": 14}, {"x": 620, "y": 940, "r": 14}
	],
	"gizmo_slots": [
		{"x": 230, "y": 335}, {"x": 490, "y": 335},
		{"x": 165, "y": 555}, {"x": 555, "y": 555},
		{"x": 295, "y": 775}, {"x": 425, "y": 775}
	],
	"barges": [
		{"id": "far_left", "x": 90, "y": 1060, "half_width": 50, "half_height": 25, "payout": {"scrap": 10}},
		{"id": "left", "x": 225, "y": 1060, "half_width": 50, "half_height": 25, "payout": {"scrap": 4}},
		{"id": "center", "x": 360, "y": 1060, "half_width": 50, "half_height": 25, "payout": {"scrap": 2}},
		{"id": "right", "x": 495, "y": 1060, "half_width": 50, "half_height": 25, "payout": {"scrap": 4}},
		{"id": "far_right", "x": 630, "y": 1060, "half_width": 50, "half_height": 25, "payout": {"scrap": 7, "cloudsilk": 1}}
	]
}
```

In `game/autoload/data_defs.gd`, add below `ECONOMY_PATH`:

```gdscript
const RUN_PATH := "res://game/data/run.json"

var run: Dictionary = {}
```

Extend `_ready` to:

```gdscript
func _ready() -> void:
	economy = load_json(ECONOMY_PATH)
	run = load_json(RUN_PATH)
```

Add at the bottom of the file:

```gdscript
func skyfield(region_id: String) -> Dictionary:
	return load_json("res://game/data/skyfields/%s.json" % region_id)
```

- [ ] **Step 4: Run tests to verify they pass**

Same command. Expected: PASS, 3 new tests green, full suite exit 0. (The unknown-skyfield test emits one pushed error by design, declared via `assert_push_error_count(1)`.)

- [ ] **Step 5: Commit**

```bash
git add game/data/run.json game/data/skyfields/region_1.json game/autoload/data_defs.gd tests/test_run_defs.gd
git commit -m "feat: add run tunables and region 1 skyfield layout data"
```

---

### Task 2: Economy runtime guards (Plan 1 carry-forward)

Plan 1's final review deferred this to "the first plan that gives Economy a production caller"; that is this plan (payouts call `Economy.add`).

**Files:**
- Modify: `game/autoload/economy.gd`
- Test: `tests/test_economy.gd` (append 3 tests)

**Interfaces:**
- Consumes: existing Economy (Plan 1).
- Produces: same signatures, hardened semantics relied on by Task 8: `add` with negative amount is a no-op that pushes an error; `spend` with negative amount returns false and pushes an error; `pay` rejects any cost containing a negative value before charging anything.

- [ ] **Step 1: Append the failing tests to `tests/test_economy.gd`**

Match the expected-error declaration placement already established in `tests/test_data_defs.gd` (action first, then the error-count assertion); GUT 9.6 fails tests on undeclared pushed errors.

```gdscript
func test_add_negative_amount_is_rejected() -> void:
	econ.add("scrap", -5)
	assert_eq(econ.balance("scrap"), 100)
	assert_push_error_count(1)

func test_spend_negative_amount_is_rejected() -> void:
	assert_false(econ.spend("scrap", -5))
	assert_eq(econ.balance("scrap"), 100)
	assert_push_error_count(1)

func test_pay_with_negative_cost_value_charges_nothing() -> void:
	assert_false(econ.pay({"scrap": 10, "crystals": -1}))
	assert_eq(econ.balance("scrap"), 100)
	assert_eq(econ.balance("crystals"), 10)
	assert_push_error_count(1)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: `test_add_negative_amount_is_rejected` fails (the existing `assert(amount >= 0)` aborts the test with an assertion error rather than pushing a catchable error); the other two fail on balance/error-count expectations.

- [ ] **Step 3: Amend `game/autoload/economy.gd`**

Replace `add` with:

```gdscript
func add(currency: String, amount: int) -> void:
	if amount < 0:
		push_error("Economy.add rejected negative amount %d for %s" % [amount, currency])
		return
	_currencies()[currency] = balance(currency) + amount
	balance_changed.emit(currency, balance(currency))
```

Replace `spend` with:

```gdscript
func spend(currency: String, amount: int) -> bool:
	if amount < 0:
		push_error("Economy.spend rejected negative amount %d for %s" % [amount, currency])
		return false
	if balance(currency) < amount:
		return false
	_currencies()[currency] = balance(currency) - amount
	balance_changed.emit(currency, balance(currency))
	return true
```

Replace `pay` with:

```gdscript
func pay(cost: Dictionary) -> bool:
	for currency in cost:
		if int(cost[currency]) < 0:
			push_error("Economy.pay rejected negative cost for %s" % currency)
			return false
	if not can_afford(cost):
		return false
	for currency in cost:
		spend(currency, int(cost[currency]))
	return true
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, 3 new tests green, all pre-existing economy tests still green, full suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/autoload/economy.gd tests/test_economy.gd
git commit -m "fix: replace Economy assert-only guards with runtime negative-amount rejection"
```

---

### Task 3: RunModel state machine

**Files:**
- Create: `game/run/run_model.gd`
- Test: `tests/test_run_model.gd`

**Interfaces:**
- Consumes: the run defs shape from Task 1 (`drops_per_run`, `max_active_pods`).
- Produces: `class_name RunModel extends RefCounted`, consumed by Task 8:
  - `_init(config: Dictionary)` reading `drops_per_run` (default 8) and `max_active_pods` (default 4)
  - `signal loot_changed(loot: Dictionary)`; `signal run_over` (emitted exactly once)
  - `drops_remaining() -> int`, `can_drop() -> bool`, `begin_drop() -> bool`
  - `resolve_pod(payout: Dictionary) -> void` (accumulates loot, decrements in-flight, may emit `run_over`)
  - `abandon() -> void`, `is_over() -> bool`, `var loot: Dictionary` (currency -> int)

- [ ] **Step 1: Write the failing tests**

`tests/test_run_model.gd`:

```gdscript
extends GutTest


func make_model(drops := 3, cap := 2) -> RunModel:
	return RunModel.new({"drops_per_run": drops, "max_active_pods": cap})


func test_init_from_config() -> void:
	var model := make_model(8, 4)
	assert_eq(model.drops_remaining(), 8)
	assert_true(model.can_drop())
	assert_false(model.is_over())

func test_begin_drop_consumes_a_drop() -> void:
	var model := make_model()
	assert_true(model.begin_drop())
	assert_eq(model.drops_remaining(), 2)

func test_pod_cap_blocks_drops() -> void:
	var model := make_model(3, 2)
	model.begin_drop()
	model.begin_drop()
	assert_false(model.can_drop(), "2 pods in flight at cap 2")
	assert_false(model.begin_drop())
	model.resolve_pod({"scrap": 1})
	assert_true(model.can_drop(), "capacity freed after resolve")

func test_resolve_accumulates_multi_currency_loot() -> void:
	var model := make_model()
	model.begin_drop()
	model.resolve_pod({"scrap": 7, "cloudsilk": 1})
	model.begin_drop()
	model.resolve_pod({"scrap": 4})
	assert_eq(model.loot, {"scrap": 11, "cloudsilk": 1})

func test_loot_changed_emitted_on_resolve() -> void:
	var model := make_model()
	watch_signals(model)
	model.begin_drop()
	model.resolve_pod({"scrap": 2})
	assert_signal_emitted_with_parameters(model, "loot_changed", [{"scrap": 2}])

func test_run_over_after_last_pod_resolves() -> void:
	var model := make_model(1, 2)
	watch_signals(model)
	model.begin_drop()
	assert_false(model.is_over(), "pod still in flight")
	model.resolve_pod({"scrap": 1})
	assert_true(model.is_over())
	assert_signal_emit_count(model, "run_over", 1)

func test_abandon_ends_run_once_and_keeps_loot() -> void:
	var model := make_model()
	watch_signals(model)
	model.begin_drop()
	model.resolve_pod({"scrap": 5})
	model.abandon()
	model.abandon()
	assert_true(model.is_over())
	assert_signal_emit_count(model, "run_over", 1)
	assert_eq(model.loot, {"scrap": 5}, "abandon never touches collected loot (spec 3.2)")
	assert_false(model.can_drop())

func test_resolve_after_abandon_still_banks_loot() -> void:
	var model := make_model()
	model.begin_drop()
	model.abandon()
	model.resolve_pod({"scrap": 3})
	assert_eq(model.loot, {"scrap": 3}, "a pod already falling at abandon still pays out")
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL with parse errors on `RunModel`.

- [ ] **Step 3: Write the implementation**

`game/run/run_model.gd`:

```gdscript
class_name RunModel
extends RefCounted
## Pure state machine for one salvage expedition (spec 3.2). No nodes, no
## physics, no clock: the scene layer feeds it begin_drop/resolve_pod events.
## The player always keeps everything collected; abandon never forfeits loot.

signal loot_changed(loot: Dictionary)
signal run_over

var drops_total: int
var drops_used := 0
var pods_in_flight := 0
var max_active_pods: int
var loot: Dictionary = {}
var abandoned := false

var _over_emitted := false


func _init(config: Dictionary) -> void:
	drops_total = int(config.get("drops_per_run", 8))
	max_active_pods = int(config.get("max_active_pods", 4))


func drops_remaining() -> int:
	return drops_total - drops_used


func can_drop() -> bool:
	return not abandoned and drops_remaining() > 0 and pods_in_flight < max_active_pods


func begin_drop() -> bool:
	if not can_drop():
		return false
	drops_used += 1
	pods_in_flight += 1
	return true


func resolve_pod(payout: Dictionary) -> void:
	pods_in_flight = maxi(0, pods_in_flight - 1)
	for currency in payout:
		loot[currency] = int(loot.get(currency, 0)) + int(payout[currency])
	loot_changed.emit(loot)
	_check_over()


func abandon() -> void:
	abandoned = true
	_check_over()


func is_over() -> bool:
	return abandoned or (drops_remaining() <= 0 and pods_in_flight == 0)


func _check_over() -> void:
	if is_over() and not _over_emitted:
		_over_emitted = true
		run_over.emit()
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, 8 new tests green, full suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/run/run_model.gd tests/test_run_model.gd
git commit -m "feat: add RunModel pure state machine for salvage expeditions"
```

---

### Task 4: Pod body and Geometry helper

**Files:**
- Create: `game/core/geometry.gd`
- Create: `game/run/pod.gd`
- Create: `game/run/pod.tscn`
- Test: `tests/test_pod.gd`

**Interfaces:**
- Consumes: pod defs shape from Task 1 (`{radius, bounce, friction}`).
- Produces: `class_name Geometry` with `static func circle_points(radius: float, segments: int = 12) -> PackedVector2Array` (Task 5 reuses it for peg visuals). `res://game/run/pod.tscn` whose root is `class_name Pod extends RigidBody2D` with `func setup(pod_defs: Dictionary) -> void`; pods join group `"pods"` in `_ready`. Task 8 instantiates, positions, calls `setup`, adds to the board.

- [ ] **Step 1: Write the failing tests**

`tests/test_pod.gd`:

```gdscript
extends GutTest

const PodScene := preload("res://game/run/pod.tscn")
const POD_DEFS := {"radius": 15.0, "bounce": 0.7, "friction": 0.1}


func test_setup_applies_physics_defs() -> void:
	var pod: Pod = autofree(PodScene.instantiate())
	pod.setup(POD_DEFS)
	assert_eq((pod.get_node("CollisionShape2D").shape as CircleShape2D).radius, 15.0)
	assert_eq(pod.physics_material_override.bounce, 0.7)
	assert_eq(pod.physics_material_override.friction, 0.1)

func test_each_pod_gets_its_own_shape() -> void:
	var a: Pod = autofree(PodScene.instantiate())
	var b: Pod = autofree(PodScene.instantiate())
	a.setup(POD_DEFS)
	b.setup({"radius": 9.0, "bounce": 0.5, "friction": 0.2})
	assert_eq((a.get_node("CollisionShape2D").shape as CircleShape2D).radius, 15.0,
		"mutating one pod's shape must not affect another (no shared resource)")

func test_pod_joins_pods_group_in_tree() -> void:
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	assert_true(pod.is_in_group("pods"))

func test_geometry_circle_points() -> void:
	var pts := Geometry.circle_points(10.0, 8)
	assert_eq(pts.size(), 8)
	assert_almost_eq(pts[0].x, 10.0, 0.001)
	assert_almost_eq(pts[0].y, 0.0, 0.001)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL (pod.tscn, Pod, Geometry do not exist).

- [ ] **Step 3: Write the implementations**

`game/core/geometry.gd`:

```gdscript
class_name Geometry
## Tiny 2D geometry helpers shared by placeholder visuals.


static func circle_points(radius: float, segments: int = 12) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * i / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
```

`game/run/pod.gd`:

```gdscript
class_name Pod
extends RigidBody2D
## A salvage pod: a dumb physics body. Catch detection belongs to the board's
## Area2D catchers; run accounting belongs to RunModel. setup() builds a fresh
## CircleShape2D per instance so pods never share a mutated shape resource.


func _ready() -> void:
	add_to_group("pods")


func setup(pod_defs: Dictionary) -> void:
	var radius := float(pod_defs.get("radius", 12.0))
	var shape := CircleShape2D.new()
	shape.radius = radius
	$CollisionShape2D.shape = shape
	var material := PhysicsMaterial.new()
	material.bounce = float(pod_defs.get("bounce", 0.55))
	material.friction = float(pod_defs.get("friction", 0.2))
	physics_material_override = material
	$Visual.polygon = Geometry.circle_points(radius)
```

`game/run/pod.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://game/run/pod.gd" id="1_pod"]

[sub_resource type="CircleShape2D" id="CircleShape2D_default"]
radius = 12.0

[node name="Pod" type="RigidBody2D"]
script = ExtResource("1_pod")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_default")

[node name="Visual" type="Polygon2D" parent="."]
color = Color(0.98, 0.85, 0.3, 1)
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, 4 new tests green, full suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/core/geometry.gd game/run/pod.gd game/run/pod.tscn tests/test_pod.gd
git commit -m "feat: add salvage pod body with per-instance physics from data"
```

---

### Task 5: Skyfield board builder

**Files:**
- Create: `game/run/skyfield.gd`
- Create: `game/run/skyfield.tscn`
- Test: `tests/test_skyfield.gd`

**Interfaces:**
- Consumes: region defs shape (Task 1), `Geometry.circle_points` (Task 4).
- Produces: `res://game/run/skyfield.tscn`, root `class_name Skyfield extends Node2D` with:
  - `func build(region_defs: Dictionary, run_defs: Dictionary) -> void` (idempotent per fresh instance; builds walls, pegs, barges, sea, slot markers)
  - `signal pod_caught(pod: RigidBody2D, payout: Dictionary)` (emitted at most once per pod, guarded by a `"caught"` meta flag)
  - `var sea_payout: Dictionary` (Task 8 reads it for the pod-timeout fallback)
  - Child containers `Walls`, `Pegs`, `Barges`, `GizmoSlots` (Marker2D children named `slot_0` .. `slot_N`, the anchor interface Plan 3 attaches gizmos to)

  Catch behavior (wired here, physics-proven in Task 6): every barge is an Area2D bound to its data payout; the sea is a full-width Area2D below the barges bound to `sea_payout`.

- [ ] **Step 1: Write the failing tests**

`tests/test_skyfield.gd`:

```gdscript
extends GutTest

const SkyfieldScene := preload("res://game/run/skyfield.tscn")

var run_defs := {"sea_payout": {"scrap": 1}, "pod": {"radius": 12.0, "bounce": 0.55, "friction": 0.2}}


func build_board(region: Dictionary) -> Skyfield:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	board.build(region, run_defs)
	return board


func test_builds_region_1_from_data() -> void:
	var board := build_board(DataDefs.skyfield("region_1"))
	assert_eq(board.get_node("Pegs").get_child_count(), 32)
	assert_eq(board.get_node("Barges").get_child_count(), 5)
	assert_eq(board.get_node("Walls").get_child_count(), 2)
	assert_eq(board.get_node("GizmoSlots").get_child_count(), 6)
	assert_not_null(board.get_node_or_null("Sea"))

func test_peg_positions_come_from_data() -> void:
	var board := build_board(DataDefs.skyfield("region_1"))
	var first_peg: Node2D = board.get_node("Pegs").get_child(0)
	assert_eq(first_peg.position, Vector2(100, 280))

func test_gizmo_slots_are_named_markers() -> void:
	var board := build_board(DataDefs.skyfield("region_1"))
	var slots := board.get_node("GizmoSlots")
	for i in slots.get_child_count():
		var slot: Node = slots.get_child(i)
		assert_true(slot is Marker2D)
		assert_eq(slot.name, "slot_%d" % i)

func test_sea_payout_exposed() -> void:
	var board := build_board(DataDefs.skyfield("region_1"))
	assert_eq(board.sea_payout, {"scrap": 1})
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL (skyfield.tscn and Skyfield do not exist).

- [ ] **Step 3: Write the implementation**

`game/run/skyfield.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://game/run/skyfield.gd" id="1_sky"]

[node name="Skyfield" type="Node2D"]
script = ExtResource("1_sky")

[node name="Walls" type="Node2D" parent="."]

[node name="Pegs" type="Node2D" parent="."]

[node name="Barges" type="Node2D" parent="."]

[node name="GizmoSlots" type="Node2D" parent="."]
```

`game/run/skyfield.gd`:

```gdscript
class_name Skyfield
extends Node2D
## One skyfield board (spec 3.1), built entirely from region JSON so new
## regions are data additions. Natural pegs are static; barges and the cloud
## sea are Area2D catchers. Gizmo slots are Marker2D anchors that Plan 3
## attaches crafted gizmos to.

signal pod_caught(pod: RigidBody2D, payout: Dictionary)

var sea_payout: Dictionary = {}


func build(region_defs: Dictionary, run_defs: Dictionary) -> void:
	sea_payout = (run_defs.get("sea_payout", {"scrap": 1}) as Dictionary).duplicate()
	var board: Dictionary = region_defs.get("board", {})
	_build_walls(board)
	_build_pegs(region_defs.get("pegs", []))
	_build_barges(region_defs.get("barges", []))
	_build_sea()
	_build_slots(region_defs.get("gizmo_slots", []))


func _build_walls(board: Dictionary) -> void:
	for x in [float(board.get("left", 20)) - 10.0, float(board.get("right", 700)) + 10.0]:
		var wall := StaticBody2D.new()
		wall.position = Vector2(x, 640)
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(20, 1400)
		collider.shape = shape
		wall.add_child(collider)
		$Walls.add_child(wall)


func _build_pegs(pegs: Array) -> void:
	for peg in pegs:
		var body := StaticBody2D.new()
		body.position = Vector2(float(peg["x"]), float(peg["y"]))
		var collider := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = float(peg.get("r", 14.0))
		collider.shape = shape
		body.add_child(collider)
		var visual := Polygon2D.new()
		visual.polygon = Geometry.circle_points(shape.radius)
		visual.color = Color(0.55, 0.6, 0.7)
		body.add_child(visual)
		$Pegs.add_child(body)


func _build_barges(barges: Array) -> void:
	for barge in barges:
		var area := Area2D.new()
		area.name = String(barge.get("id", "barge"))
		area.position = Vector2(float(barge["x"]), float(barge["y"]))
		var half := Vector2(float(barge.get("half_width", 50)), float(barge.get("half_height", 25)))
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = half * 2.0
		collider.shape = shape
		area.add_child(collider)
		var visual := Polygon2D.new()
		visual.polygon = PackedVector2Array([
			Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(half.x, half.y), Vector2(-half.x, half.y),
		])
		visual.color = Color(0.35, 0.55, 0.4)
		area.add_child(visual)
		area.body_entered.connect(_on_catcher_body.bind((barge.get("payout", {}) as Dictionary).duplicate()))
		$Barges.add_child(area)


func _build_sea() -> void:
	var sea := Area2D.new()
	sea.name = "Sea"
	sea.position = Vector2(360, 1180)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(760, 80)
	collider.shape = shape
	sea.add_child(collider)
	sea.body_entered.connect(_on_catcher_body.bind(sea_payout.duplicate()))
	add_child(sea)


func _build_slots(slots: Array) -> void:
	for i in slots.size():
		var marker := Marker2D.new()
		marker.name = "slot_%d" % i
		marker.position = Vector2(float(slots[i]["x"]), float(slots[i]["y"]))
		$GizmoSlots.add_child(marker)


func _on_catcher_body(body: Node2D, payout: Dictionary) -> void:
	if not (body is RigidBody2D):
		return
	if body.has_meta("caught"):
		return
	body.set_meta("caught", true)
	pod_caught.emit(body, payout.duplicate())
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, 4 new tests green, full suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/run/skyfield.gd game/run/skyfield.tscn tests/test_skyfield.gd
git commit -m "feat: build skyfield board from region data with barge and sea catchers"
```

---

### Task 6: Physics catch integration

**Files:**
- Create: `tests/fixtures/test_region.json`
- Create: `tests/fixtures/test_region_empty.json`
- Test: `tests/test_skyfield.gd` (append 2 tests)

No production code: this task proves the Task 5 catchers against real falling RigidBody2D pods, headless. Physics runs in GUT because tests execute inside a live SceneTree.

**Interfaces:**
- Consumes: `Skyfield.build`, `pod_caught`, `Pod.setup` (Tasks 4-5).
- Produces: confidence, plus the fixture boards Task 8's tests reuse.

- [ ] **Step 1: Write the fixtures and the failing tests**

`tests/fixtures/test_region.json` (one barge spanning nearly the whole board, no pegs, so a dropped pod must land in it):

```json
{
	"name": "Test Catch-All",
	"board": {"left": 20, "right": 700, "top": 140, "bottom": 1020},
	"pegs": [],
	"gizmo_slots": [],
	"barges": [
		{"id": "catch_all", "x": 360, "y": 900, "half_width": 340, "half_height": 25, "payout": {"scrap": 12}}
	]
}
```

`tests/fixtures/test_region_empty.json` (no barges at all, so every pod reaches the sea):

```json
{
	"name": "Test Open Sea",
	"board": {"left": 20, "right": 700, "top": 140, "bottom": 1020},
	"pegs": [],
	"gizmo_slots": [],
	"barges": []
}
```

Append to `tests/test_skyfield.gd`:

```gdscript
func drop_pod_over(board: Skyfield, x: float) -> Pod:
	var pod: Pod = preload("res://game/run/pod.tscn").instantiate()
	pod.position = Vector2(x, 160)
	pod.setup(run_defs["pod"])
	board.add_child(pod)
	return pod

func test_falling_pod_is_caught_by_barge() -> void:
	var board := build_board(DataDefs.load_json("res://tests/fixtures/test_region.json"))
	watch_signals(board)
	drop_pod_over(board, 360.0)
	var emitted: bool = await wait_for_signal(board.pod_caught, 5.0)
	assert_true(emitted, "pod should fall into the catch-all barge within 5s")
	var params: Array = get_signal_parameters(board, "pod_caught")
	assert_eq(params[1], {"scrap": 12})

func test_pod_missing_all_barges_reaches_the_sea() -> void:
	var board := build_board(DataDefs.load_json("res://tests/fixtures/test_region_empty.json"))
	watch_signals(board)
	drop_pod_over(board, 360.0)
	var emitted: bool = await wait_for_signal(board.pod_caught, 5.0)
	assert_true(emitted, "sea must catch every miss (spec 3.1: never zero)")
	var params: Array = get_signal_parameters(board, "pod_caught")
	assert_eq(params[1], {"scrap": 1})
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Expected: the two new tests FAIL only if catch wiring is broken; if Task 5 was implemented exactly as specified they may already PASS. Either way run and record the result: this task's deliverable is the recorded proof. If a pod stalls and the 5s timeout trips, that is a real finding to report, not to paper over.

- [ ] **Step 3: Run the full suite**

```bash
$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: PASS, 2 new tests green (each takes 1-2 seconds of simulated fall), full suite exit 0.

- [ ] **Step 4: Commit**

```bash
git add tests/fixtures/test_region.json tests/fixtures/test_region_empty.json tests/test_skyfield.gd
git commit -m "test: prove barge and sea catch physics headless with fixture boards"
```

---

### Task 7: DropController input

**Files:**
- Create: `game/run/drop_controller.gd`
- Modify: `project.godot` (add `[input_devices]` section)
- Test: `tests/test_drop_controller.gd`

**Interfaces:**
- Consumes: board bounds shape from Task 1.
- Produces: `class_name DropController extends Node2D`, consumed by Task 8:
  - `signal drop_requested(x: float)`
  - `var enabled: bool` (default true), `var drop_y: float` (where Task 8 spawns pods)
  - `func configure(board: Dictionary, pod_radius: float) -> void` (sets clamp range `min_x/max_x` inset one pod diameter from the walls, `drop_y` 40px above `board.top`, aim starts centered)
  - Input contract (spec 3.2: tap or drag along the top edge, release drops; one thumb): touch press starts aiming at the clamped touch x, drag updates it, release emits `drop_requested(aim_x)`. Mouse works on desktop via `emulate_touch_from_mouse`.

- [ ] **Step 1: Write the failing tests**

`tests/test_drop_controller.gd`:

```gdscript
extends GutTest

const ControllerScript := preload("res://game/run/drop_controller.gd")

var controller: DropController


func before_each() -> void:
	controller = add_child_autofree(ControllerScript.new())
	controller.configure({"left": 20, "right": 700, "top": 140}, 12.0)


func touch(pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.position = pos
	event.pressed = pressed
	return event

func drag_to(pos: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.position = pos
	return event


func test_tap_release_drops_at_tap_x() -> void:
	watch_signals(controller)
	controller._unhandled_input(touch(Vector2(300, 80), true))
	controller._unhandled_input(touch(Vector2(300, 80), false))
	assert_signal_emitted_with_parameters(controller, "drop_requested", [300.0])

func test_drag_updates_aim_before_release() -> void:
	watch_signals(controller)
	controller._unhandled_input(touch(Vector2(300, 80), true))
	controller._unhandled_input(drag_to(Vector2(500, 90)))
	controller._unhandled_input(touch(Vector2(500, 90), false))
	assert_signal_emitted_with_parameters(controller, "drop_requested", [500.0])

func test_aim_is_clamped_inside_walls() -> void:
	watch_signals(controller)
	controller._unhandled_input(touch(Vector2(2, 80), true))
	controller._unhandled_input(touch(Vector2(2, 80), false))
	assert_signal_emitted_with_parameters(controller, "drop_requested", [44.0])

func test_disabled_controller_ignores_input() -> void:
	controller.enabled = false
	watch_signals(controller)
	controller._unhandled_input(touch(Vector2(300, 80), true))
	controller._unhandled_input(touch(Vector2(300, 80), false))
	assert_signal_not_emitted(controller, "drop_requested")

func test_release_without_press_does_not_drop() -> void:
	watch_signals(controller)
	controller._unhandled_input(touch(Vector2(300, 80), false))
	assert_signal_not_emitted(controller, "drop_requested")
```

(Clamp check: `min_x = 20 + 12*2 = 44`.)

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL with parse errors on `DropController`.

- [ ] **Step 3: Write the implementation and project setting**

`game/run/drop_controller.gd`:

```gdscript
class_name DropController
extends Node2D
## One-thumb drop aiming (spec 3.2): touch anywhere to start aiming, drag to
## slide the drop point along the top edge, release to drop. Pure input; the
## run scene decides whether a drop is actually allowed.

signal drop_requested(x: float)

var enabled := true
var drop_y := 100.0
var min_x := 44.0
var max_x := 676.0

var _aiming := false
var _aim_x := 360.0


func configure(board: Dictionary, pod_radius: float) -> void:
	min_x = float(board.get("left", 20)) + pod_radius * 2.0
	max_x = float(board.get("right", 700)) - pod_radius * 2.0
	drop_y = float(board.get("top", 140)) - 40.0
	_aim_x = (min_x + max_x) / 2.0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_aiming = true
			_aim_x = clampf(event.position.x, min_x, max_x)
		elif _aiming:
			_aiming = false
			drop_requested.emit(_aim_x)
	elif event is InputEventScreenDrag and _aiming:
		_aim_x = clampf(event.position.x, min_x, max_x)
	queue_redraw()


func _draw() -> void:
	if enabled:
		draw_circle(Vector2(_aim_x, drop_y), 8.0, Color(1, 1, 1, 0.5))
```

Add a new `[input_devices]` section to `project.godot` (the file has no such section yet; place it between `[editor_plugins]` and `[rendering]`, keeping sections alphabetical as Godot writes them):

```ini
[input_devices]

pointing/emulate_touch_from_mouse=true
```

This makes desktop mouse input arrive as the touch events the controller handles, keeping one input path for both (native touch is the spec's contract; the mouse is a dev convenience).

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, 5 new tests green, full suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/run/drop_controller.gd tests/test_drop_controller.gd project.godot
git commit -m "feat: add one-thumb drop controller with clamped top-edge aiming"
```

---

### Task 8: Salvage run scene

**Files:**
- Create: `game/run/salvage_run.gd`
- Create: `game/run/salvage_run.tscn`
- Test: `tests/test_salvage_run.gd`

**Interfaces:**
- Consumes: `RunModel` (T3), `Pod` + pod.tscn (T4), `Skyfield` + skyfield.tscn (T5), `DropController` (T7), `DataDefs.run` / `DataDefs.skyfield` (T1), `Economy.add` (T2 hardened), `GameState.save_game`, `FuelModel` (fuel is spent by Task 9 BEFORE entering this scene; this scene never touches fuel).
- Produces: `res://game/run/salvage_run.tscn`: the complete expedition scene. Public methods Task 9 and tests rely on: `_on_drop_requested(x: float)`, `_on_pod_caught(pod: Node, payout: Dictionary)`, `_on_pod_timeout(pod: Node)`, `_on_abandon_pressed()`, `_on_return_pressed()`. Behavior contract: every catch credits Economy immediately; results overlay appears on `run_over`; abandoning frees live pods and shows results; `GameState.save_game()` runs when the run ends.

- [ ] **Step 1: Write the failing tests**

`tests/test_salvage_run.gd`:

```gdscript
extends GutTest

const RunScene := preload("res://game/run/salvage_run.tscn")
const TEST_SAVE := "user://test_run_scene.json"

var scene


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy)
	GameState.data["created_at"] = 1000
	GameState.data["fuel"]["updated_at"] = 1000
	scene = add_child_autofree(RunScene.instantiate())

func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_run_scene.json", "test_run_scene.json.tmp", "test_run_scene.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now())


func test_drop_spawns_pod_and_consumes_drop() -> void:
	var drops_before: int = scene.model.drops_remaining()
	scene._on_drop_requested(360.0)
	assert_eq(scene.model.drops_remaining(), drops_before - 1)
	assert_eq(get_tree().get_nodes_in_group("pods").size(), 1)

func test_catch_credits_economy_immediately() -> void:
	var scrap_before := Economy.balance("scrap")
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(pod, {"scrap": 12})
	assert_eq(Economy.balance("scrap"), scrap_before + 12,
		"loot banks the moment it is caught (spec: no run ever loses loot)")
	assert_eq(scene.model.loot, {"scrap": 12})

func test_run_over_shows_results_and_saves() -> void:
	scene.model = RunModel.new({"drops_per_run": 1, "max_active_pods": 4})
	scene.model.run_over.connect(scene._on_run_over)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(pod, {"scrap": 3})
	assert_true(scene.get_node("UI/Results").visible)
	assert_false(scene.get_node("DropController").enabled)
	var saved := SaveIO.new(TEST_SAVE).read()
	assert_eq(int(saved["currencies"]["scrap"]), Economy.balance("scrap"),
		"run end must persist the banked loot")

func test_abandon_shows_results_and_frees_pods() -> void:
	scene._on_drop_requested(360.0)
	scene._on_abandon_pressed()
	assert_true(scene.model.is_over())
	assert_true(scene.get_node("UI/Results").visible)
	await wait_frames(2)
	assert_eq(get_tree().get_nodes_in_group("pods").size(), 0, "live pods freed on abandon")

func test_pod_timeout_pays_sea_minimum() -> void:
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	var scrap_before := Economy.balance("scrap")
	scene._on_pod_timeout(pod)
	assert_eq(Economy.balance("scrap"), scrap_before + 1, "stuck pod resolves as a sea miss")
	scene._on_pod_timeout(pod)
	assert_eq(Economy.balance("scrap"), scrap_before + 1, "timeout after resolution is a no-op")
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL (salvage_run.tscn does not exist).

- [ ] **Step 3: Write the scene and script**

`game/run/salvage_run.tscn`:

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://game/run/salvage_run.gd" id="1_run"]
[ext_resource type="PackedScene" path="res://game/run/skyfield.tscn" id="2_sky"]
[ext_resource type="Script" path="res://game/run/drop_controller.gd" id="3_drop"]

[node name="SalvageRun" type="Node2D"]
script = ExtResource("1_run")

[node name="Skyfield" parent="." instance=ExtResource("2_sky")]

[node name="DropController" type="Node2D" parent="."]
script = ExtResource("3_drop")

[node name="UI" type="CanvasLayer" parent="."]

[node name="HudLabel" type="Label" parent="UI"]
offset_left = 24.0
offset_top = 8.0
offset_right = 520.0
offset_bottom = 64.0

[node name="AbandonButton" type="Button" parent="UI"]
offset_left = 560.0
offset_top = 8.0
offset_right = 700.0
offset_bottom = 48.0
text = "Abandon"

[node name="Results" type="PanelContainer" parent="UI"]
visible = false
offset_left = 110.0
offset_top = 440.0
offset_right = 610.0
offset_bottom = 700.0

[node name="VBox" type="VBoxContainer" parent="UI/Results"]

[node name="Summary" type="Label" parent="UI/Results/VBox"]
text = "Expedition complete"

[node name="ReturnButton" type="Button" parent="UI/Results/VBox"]
text = "Return to Island"
```

`game/run/salvage_run.gd`:

```gdscript
extends Node2D
## Glue for one expedition: DropController -> RunModel -> Pod physics ->
## Skyfield catchers -> Economy. Fuel was already spent by the launcher
## (main.gd); this scene only runs the drops. Loot is credited per catch, so
## abandoning or being killed by the OS never loses anything (spec 3.2).

const PodScene := preload("res://game/run/pod.tscn")

var model: RunModel
var pod_defs: Dictionary

@onready var board: Skyfield = $Skyfield
@onready var controller: DropController = $DropController


func _ready() -> void:
	var run_defs: Dictionary = DataDefs.run
	pod_defs = run_defs.get("pod", {})
	var region: Dictionary = DataDefs.skyfield("region_1")
	model = RunModel.new(run_defs)
	board.build(region, run_defs)
	controller.configure(region.get("board", {}), float(pod_defs.get("radius", 12.0)))
	board.pod_caught.connect(_on_pod_caught)
	controller.drop_requested.connect(_on_drop_requested)
	model.run_over.connect(_on_run_over)
	$UI/AbandonButton.pressed.connect(_on_abandon_pressed)
	$UI/Results/VBox/ReturnButton.pressed.connect(_on_return_pressed)
	_refresh_hud()


func _on_drop_requested(x: float) -> void:
	if not model.begin_drop():
		return
	var pod: Pod = PodScene.instantiate()
	pod.position = Vector2(x, controller.drop_y)
	pod.setup(pod_defs)
	board.add_child(pod)
	var timeout := float(DataDefs.run.get("pod_timeout_seconds", 12.0))
	get_tree().create_timer(timeout).timeout.connect(_on_pod_timeout.bind(pod))
	_refresh_hud()


func _on_pod_caught(pod: Node, payout: Dictionary) -> void:
	if is_instance_valid(pod):
		pod.queue_free()
	for currency in payout:
		Economy.add(currency, int(payout[currency]))
	model.resolve_pod(payout)
	_refresh_hud()


func _on_pod_timeout(pod: Node) -> void:
	# Watchdog: a pod balanced on a peg must never deadlock the run.
	if not is_instance_valid(pod) or pod.has_meta("caught"):
		return
	pod.set_meta("caught", true)
	_on_pod_caught(pod, board.sea_payout.duplicate())


func _on_run_over() -> void:
	controller.enabled = false
	for pod in get_tree().get_nodes_in_group("pods"):
		pod.queue_free()
	GameState.save_game()
	$UI/Results/VBox/Summary.text = _summary_text()
	$UI/Results.visible = true


func _on_abandon_pressed() -> void:
	model.abandon()


func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://game/main.tscn")


func _refresh_hud() -> void:
	var parts := PackedStringArray()
	for currency in model.loot:
		parts.append("%s +%d" % [currency, int(model.loot[currency])])
	$UI/HudLabel.text = "Drops left: %d\n%s" % [model.drops_remaining(), " ".join(parts)]


func _summary_text() -> String:
	if model.loot.is_empty():
		return "Expedition complete.\nNothing salvaged this time."
	var lines := PackedStringArray(["Expedition complete. Salvaged:"])
	for currency in model.loot:
		lines.append("  %s: %d" % [currency, int(model.loot[currency])])
	return "\n".join(lines)
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, 6 new tests green, full suite exit 0. Note: `test_run_over_shows_results_and_saves` replaces `scene.model` and reconnects only `run_over`; that is deliberate test surgery to get a 1-drop run, and the production `_ready` wiring stays covered by the other tests.

- [ ] **Step 5: Commit**

```bash
git add game/run/salvage_run.gd game/run/salvage_run.tscn tests/test_salvage_run.gd
git commit -m "feat: add salvage run scene wiring drops, catches, payouts, and results"
```

---

### Task 9: Launch flow from the island

**Files:**
- Modify: `game/main.gd` (full replacement below)
- Modify: `game/main.tscn` (full replacement below)
- Test: `tests/test_main_boot.gd` (full replacement below)

**Interfaces:**
- Consumes: `FuelModel.spend/current`, `DataDefs.run["fuel_cost"]`, `GameState.data["fuel"]` / `save_game`, `Economy.balance/balance_changed`, `res://game/run/salvage_run.tscn` (T8).
- Produces: the playable loop entry: a Launch Expedition button that is disabled when fuel is short, spends fuel at press, saves, and switches to the run scene. Plan 4 replaces this screen with the real island; the launch contract (spend fuel, save, change scene) carries over.

- [ ] **Step 1: Write the failing tests (replace `tests/test_main_boot.gd`)**

```gdscript
extends GutTest

const MainScene := preload("res://game/main.tscn")

var main


func before_each() -> void:
	GameState.data = SaveSchema.default_data(DataDefs.economy)
	GameState.data["created_at"] = 1000
	GameState.data["fuel"]["updated_at"] = 1000
	main = add_child_autofree(MainScene.instantiate())
	await wait_frames(1)

func after_all() -> void:
	GameState.load_game(DataDefs.economy, TimeUtil.now())


func test_main_scene_boots_and_shows_balances() -> void:
	var text: String = main.get_node("DebugLabel").text
	assert_string_contains(text, "Scrap: ")
	assert_string_contains(text, "Fuel: ")

func test_launch_enabled_with_full_tank() -> void:
	assert_false(main.get_node("LaunchButton").disabled)

func test_launch_disabled_when_fuel_empty() -> void:
	GameState.data["fuel"]["amount"] = 0
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	main._refresh()
	assert_true(main.get_node("LaunchButton").disabled)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL (`LaunchButton` node and `_refresh()` zero-arg signature do not exist yet).

- [ ] **Step 3: Replace the scene and script**

`game/main.gd` (full new content):

```gdscript
extends Control
## Island home screen placeholder: balances readout plus the expedition
## launcher. Fuel is spent HERE, before the run scene loads, so the run scene
## never touches fuel (spec 3.2 step 1). Plan 4 grows this into the island.

@onready var debug_label: Label = $DebugLabel
@onready var launch_button: Button = $LaunchButton


func _ready() -> void:
	Economy.balance_changed.connect(_on_balance_changed)
	launch_button.pressed.connect(_on_launch_pressed)
	$RefreshTimer.timeout.connect(_refresh)
	_refresh()


func _on_balance_changed(_currency: String, _amount: int) -> void:
	_refresh()


func _refresh() -> void:
	var now := TimeUtil.now()
	var fuel: Dictionary = GameState.data["fuel"]
	debug_label.text = "Scrap: %d\nCloudsilk: %d\nCrystals: %d\nFuel: %d/%d" % [
		Economy.balance("scrap"),
		Economy.balance("cloudsilk"),
		Economy.balance("crystals"),
		FuelModel.current(fuel, now),
		int(fuel["cap"]),
	]
	launch_button.disabled = FuelModel.current(fuel, now) < int(DataDefs.run.get("fuel_cost", 1))


func _on_launch_pressed() -> void:
	var cost := int(DataDefs.run.get("fuel_cost", 1))
	if not FuelModel.spend(GameState.data["fuel"], cost, TimeUtil.now()):
		_refresh()
		return
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/run/salvage_run.tscn")
```

`game/main.tscn` (full new content; if the editor previously stamped uid attributes onto this file, keep whatever `uid="..."` values already exist in the checked-out version on the `[gd_scene]` and `[ext_resource]` lines and change only the nodes):

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://game/main.gd" id="1_main"]

[node name="Main" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_main")

[node name="DebugLabel" type="Label" parent="."]
offset_left = 24.0
offset_top = 48.0
offset_right = 500.0
offset_bottom = 300.0

[node name="LaunchButton" type="Button" parent="."]
offset_left = 160.0
offset_top = 1080.0
offset_right = 560.0
offset_bottom = 1160.0
text = "Launch Expedition"

[node name="RefreshTimer" type="Timer" parent="."]
wait_time = 1.0
autostart = true
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS, 3 tests in the boot file green, full suite exit 0.

- [ ] **Step 5: Manual smoke check (skip if the environment is non-interactive; note it in the report)**

```bash
$GODOT
```

Expected: portrait window; Launch Expedition enabled at Fuel 5/5; pressing it opens the board; dragging along the top aims a ghost circle; releasing drops a pod that rattles down the pegs into a barge; HUD counts drops and loot; after 8 drops the results panel lists salvage; Return to Island goes back with fuel now 4/5.

- [ ] **Step 6: Commit**

```bash
git add game/main.gd game/main.tscn tests/test_main_boot.gd
git commit -m "feat: add expedition launcher with fuel spend and scene flow"
```

---

## Notes for Plan 3 (gizmos), recorded here so the interface is explicit

- Gizmo anchors: `Skyfield/GizmoSlots/slot_0..slot_5` (Marker2D, positions from region JSON).
- Pod contact hooks: gizmos will be Area2D/StaticBody2D scenes added at slot positions; the `pod_caught` meta-guard pattern (`has_meta("caught")`) is the convention for one-shot pod interactions.
- `Skyfield.build` takes the full region dict; gizmo definitions will ride in the same JSON.
- `RunModel.resolve_pod` accepts arbitrary currency dicts, so gizmo multipliers can preprocess payouts before resolution without model changes.
