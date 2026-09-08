# Windfall Isles Plan 11: Production Chains

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two new currencies (parts, provisions), timed conversion recipes on the Smeltery/Foundry Annex/Gardens, and every gizmo craft repriced from scrap to parts.

**Architecture:** Recipes live inside building defs; a new pure `ConvertModel` (mirroring CraftModel) runs one timed batch per building on a new `"convert"` timer kind, with crew dividing durations through `CrewModel.multiplier_for`. The gizmo repricing is a hard cutover done in one atomic task together with the removal of `CraftModel.effective_cost` (the Annex percent discount is vestigial at parts prices; owner amendment 2026-09-08). The duplicated trickle-rebase logic folds into `TrickleModel.rebase_preserving`, and the owner's clamp ruling gets its pinning test.

**Tech Stack:** Godot 4.6.3 (GDScript), GUT 9.6.1, JSON data files.

**Spec:** docs/superpowers/specs/2026-09-08-production-chains-design.md

## Global Constraints

- Godot binary: `GODOT=/Applications/Godot-4.6.app/Contents/MacOS/Godot` (4.6.3; NEVER `/Applications/Godot.app`).
- Full suite (must exit 0): `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- Single file: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit`
- After creating any new .gd file, run `$GODOT --headless --import`; commit `.gd.uid` sidecars (test files included); `git status --porcelain` shows no untracked `.gd.uid`.
- Indentation: tabs. No em dashes anywhere.
- Raw JSON numbers: `int()`/`float()` casts at use and assert sites; never normalize in DataDefs. Dictionary `==` does not coerce.
- Pure models never read autoloads, wall clocks, or RNG; `now` is injected; Economy/TimerService are passed as Nodes.
- Write-back discipline for save mutations.
- GUT 9.6 auto-fails on pushed/engine errors; strict warnings reject `:=` inference from untyped chains (explicit types on JSON-sourced reads).
- UI tests call handlers directly and NEVER invoke scene-changing handlers.
- Screens: structural signature gates rebuilds; labels update in place; detach-then-free in rebuilds.
- Timers: durations lock at start (`ends_at` persisted); reassignment never retimes a running timer.
- The repricing is a hard cutover: after Task 2, scrap crafts nothing; every test that asserted scrap craft costs is edited inside Task 2 itself, never later.
- Do not state cumulative suite totals anywhere (reports included); per-task new-test lists only.
- Commit after every task; every commit leaves the full suite green.

---

### Task 1: Data: Smeltery, recipes, currencies, crew edits

**Files:**
- Modify: `game/data/buildings.json`, `game/data/economy.json`, `game/data/crew.json`
- Test: `tests/test_recipe_defs.gd` (create), `tests/test_building_defs.gd` (modify), `tests/test_island_screen.gd` (modify one test), `tests/test_crew_defs.gd` (no change needed; its guards must keep passing)

**Interfaces:**
- Consumes: existing defs shapes.
- Produces: `plot_count` 7; `smeltery` def with `recipe` {id "smelt", name "Smelt", inputs {scrap 40}, outputs {parts 1}, seconds 600}; `foundry_annex.recipe` {id "brass_smelt", name "Brass smelt", inputs {scrap 30, brasswork 1}, outputs {parts 2}, seconds 600}; `gardens.recipe` {id "put_up_provisions", name "Put up provisions", inputs {}, outputs {provisions 2}, seconds 3600}; `starting_balances` gains parts 0 and provisions 0; crew.json `workable` gains "smeltery" (appended LAST) and Reya's `specialty` becomes "smeltery". The `recipe.name` key is a plan-level extension of the spec's recipe shape (the UI needs a display label); note it in your report. Foundry Annex KEEPS `craft_discount_per_level` in this task (Task 2 removes it together with the code that reads it).

- [ ] **Step 1: Write the failing tests**

Create `tests/test_recipe_defs.gd`:

```gdscript
extends GutTest
## Authoring guards for conversion recipes (chains spec sections 2-5).


func recipe_buildings() -> Dictionary:
	var out := {}
	for id in DataDefs.buildings.get("defs", {}):
		var def: Dictionary = (DataDefs.buildings["defs"] as Dictionary)[id]
		if def.has("recipe"):
			out[String(id)] = def["recipe"]
	return out


func test_exactly_the_three_recipe_buildings() -> void:
	var found := recipe_buildings()
	assert_eq(found.size(), 3)
	for id in ["smeltery", "foundry_annex", "gardens"]:
		assert_has(found, id)

func test_recipes_are_well_formed() -> void:
	var known: Array = (DataDefs.economy.get("starting_balances", {}) as Dictionary).keys()
	for id in recipe_buildings():
		var conversion: Dictionary = recipe_buildings()[id]
		assert_true(String(conversion.get("id", "")) != "", "recipe id missing: %s" % id)
		assert_true(String(conversion.get("name", "")) != "", "recipe display name missing: %s" % id)
		assert_true(float(conversion.get("seconds", 0)) > 0.0, "recipe seconds missing: %s" % id)
		assert_true((conversion.get("outputs", {}) as Dictionary).size() > 0, "recipe outputs empty: %s" % id)
		for currency in conversion.get("inputs", {}):
			assert_true(known.has(String(currency)), "unknown input currency %s: %s" % [currency, id])
		for currency in conversion.get("outputs", {}):
			assert_true(known.has(String(currency)), "unknown output currency %s: %s" % [currency, id])

func test_new_currencies_start_at_zero() -> void:
	var balances: Dictionary = DataDefs.economy.get("starting_balances", {})
	assert_eq(int(balances.get("parts", -1)), 0)
	assert_eq(int(balances.get("provisions", -1)), 0)

func test_smeltery_is_workable_and_reya_specializes() -> void:
	assert_true((DataDefs.crew.get("workable", []) as Array).has("smeltery"))
	assert_eq(String(CrewModel.entry(DataDefs.crew, "reya").get("specialty", "")), "smeltery",
		"chains spec section 5: Reya moves to the Smeltery; Petch keeps the Balloonworks")
	assert_eq(String(CrewModel.entry(DataDefs.crew, "petch").get("specialty", "")), "balloonworks")

func test_smeltery_def_shape() -> void:
	var def: Dictionary = (DataDefs.buildings.get("defs", {}) as Dictionary).get("smeltery", {})
	assert_eq(int(def.get("max_level", 0)), 3)
	assert_eq((def.get("levels", []) as Array).size(), 3)
	assert_eq(int(DataDefs.buildings.get("plot_count", 0)), 7, "seventh plot: no softlock")
```

In `tests/test_building_defs.gd`, replace the whole `test_buildings_load_with_eight_defs` function with:

```gdscript
func test_buildings_load_with_nine_defs() -> void:
	assert_eq((DataDefs.buildings["defs"] as Dictionary).size(), 9,
		"seven home buildings plus the two islet buildings")
	for id in ["workshop", "wind_still", "dock", "balloonworks", "observatory", "gardens", "smeltery", "lens_array", "foundry_annex"]:
		assert_has(DataDefs.buildings["defs"], id)
	for id in DataDefs.buildings["defs"]:
		var def: Dictionary = DataDefs.buildings["defs"][id]
		assert_eq((def["levels"] as Array).size(), int(def["max_level"]),
			"every level needs a cost/time row: %s" % id)
```

In `tests/test_island_screen.gd`, replace the whole `test_assign_cycle_walks_workable_then_idle` function with (the workable list grew to six):

```gdscript
func test_assign_cycle_walks_workable_then_idle() -> void:
	rescue_and_rebuild(["odo"])
	screen._on_assign_pressed("odo")
	assert_eq(CrewModel.building_of(GameState.data, "odo"), "gardens", "first workable")
	screen._on_assign_pressed("odo")
	assert_eq(CrewModel.building_of(GameState.data, "odo"), "workshop")
	for i in 4:
		screen._on_assign_pressed("odo")
	assert_eq(CrewModel.building_of(GameState.data, "odo"), "smeltery", "last workable")
	screen._on_assign_pressed("odo")
	assert_eq(CrewModel.building_of(GameState.data, "odo"), "", "then back to idle")
```

- [ ] **Step 2: Run to verify failure**

Run: `$GODOT --headless --import` then `-gtest=res://tests/test_recipe_defs.gd`.
Expected: FAIL (no recipes, no smeltery, no new currencies).

- [ ] **Step 3: Edit the data files**

In `game/data/buildings.json`:

1. Change `"plot_count": 6,` to `"plot_count": 7,`.
2. Add inside `"defs"` after the `"gardens"` entry (comma-separate correctly):

```json
		"smeltery": {
			"name": "Smeltery",
			"max_level": 3,
			"levels": [
				{"cost": {"scrap": 120}, "build_seconds": 180},
				{"cost": {"scrap": 480, "cloudsilk": 3}, "build_seconds": 1800},
				{"cost": {"scrap": 1400, "cloudsilk": 9}, "build_seconds": 5400}
			],
			"recipe": {"id": "smelt", "name": "Smelt", "inputs": {"scrap": 40}, "outputs": {"parts": 1}, "seconds": 600}
		},
```

3. In the `"gardens"` def, add after its `"cap_hours": 8.0,` line:

```json
			"recipe": {"id": "put_up_provisions", "name": "Put up provisions", "inputs": {}, "outputs": {"provisions": 2}, "seconds": 3600},
```

4. In the `"foundry_annex"` def, add after its `"craft_discount_per_level": 0.1,` line (the discount key itself stays until Task 2):

```json
			"recipe": {"id": "brass_smelt", "name": "Brass smelt", "inputs": {"scrap": 30, "brasswork": 1}, "outputs": {"parts": 2}, "seconds": 600},
```

In `game/data/economy.json`, extend `starting_balances` to:

```json
	"starting_balances": {
		"scrap": 100,
		"cloudsilk": 0,
		"brasswork": 0,
		"crystals": 10,
		"parts": 0,
		"provisions": 0
	},
```

In `game/data/crew.json`:

1. Change the workable line to:

```json
	"workable": ["gardens", "workshop", "wind_still", "balloonworks", "foundry_annex", "smeltery"],
```

2. In Reya's entry, change `"specialty": "balloonworks"` to `"specialty": "smeltery"` (her name, bonus, and line are untouched).

- [ ] **Step 4: Run test_recipe_defs, test_building_defs, test_crew_defs, test_island_screen, then the full suite**

All must pass; suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/data/buildings.json game/data/economy.json game/data/crew.json tests/test_recipe_defs.gd tests/test_recipe_defs.gd.uid tests/test_building_defs.gd tests/test_island_screen.gd
git commit -m "feat: smeltery, conversion recipes, parts and provisions currencies"
```

---

### Task 2: The craft cutover, repricing and effective_cost removal

**Files:**
- Modify: `game/data/gizmos.json`, `game/data/buildings.json` (remove one key), `game/base/craft_model.gd`, `game/base/workshop_screen.gd`
- Test: `tests/test_craft_model.gd` (major rework), `tests/test_workshop_screen.gd` (modify), `tests/test_retention_integration.gd` (modify), `tests/test_region_2_integration.gd` (modify), `tests/test_island_integration.gd` (modify)

**Interfaces:**
- Consumes: parts currency (Task 1).
- Produces: gizmo `craft_cost` values per the spec table; `CraftModel.effective_cost` DELETED; `can_craft(data, gizmo_defs, economy, timers, gizmo_id)` (5 args, prices raw craft_cost); `start_craft(data, gizmo_defs, economy, timers, gizmo_id, now, crew_defs: Dictionary = {})` (crew_defs is now the 7th arg; building_defs is gone); `foundry_annex` loses `craft_discount_per_level`.

- [ ] **Step 1: Apply the repricing table to gizmos.json**

Change each def's `craft_cost` exactly (craft_seconds untouched):

- wind_fan: `{"parts": 2}`
- balloon_cluster: `{"parts": 2}`
- cargo_net: `{"parts": 2}`
- magnet_buoy: `{"parts": 3}`
- chime_bell: `{"parts": 3}`
- lightning_jar: `{"parts": 3, "cloudsilk": 1}`
- crystal_prism: `{"parts": 3, "cloudsilk": 1}`
- splitter_vane: `{"parts": 4, "cloudsilk": 2}`
- piston_kicker: `{"parts": 4, "brasswork": 1}`
- gyro_damper: `{"parts": 5, "brasswork": 2}`

In `game/data/buildings.json`, delete the `"craft_discount_per_level": 0.1,` line from `foundry_annex` (added-in-Task-1 recipe line stays).

- [ ] **Step 2: Rewrite CraftModel's pricing**

In `game/base/craft_model.gd`:

1. DELETE the whole `effective_cost` function.
2. Replace `can_craft` and `start_craft` with:

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
	# resources (worked parts and regional materials) are the gate, not
	# ownership. Prices are raw craft_cost: the Annex discount died with the
	# parts repricing (chains spec section 3 amendment).
	var owned: Dictionary = (data.get("gizmos", {}) as Dictionary).get("owned", {})
	if int(owned.get(gizmo_id, 0)) >= int(gizmo_defs.get("craft_max_level", 5)):
		return false
	return economy.can_afford(def.get("craft_cost", {}))


static func start_craft(data: Dictionary, gizmo_defs: Dictionary, economy: Node, timers: Node, gizmo_id: String, now: int, crew_defs: Dictionary = {}) -> bool:
	if not can_craft(data, gizmo_defs, economy, timers, gizmo_id):
		return false
	var def: Dictionary = (gizmo_defs.get("defs", {}) as Dictionary).get(gizmo_id, {})
	if not economy.pay(def.get("craft_cost", {})):
		return false
	# The worker's speed is priced into the duration at START and locked in
	# the timer's ends_at; reassignment never retimes a running craft
	# (crew spec section 5).
	var duration := maxi(1, ceili(float(def.get("craft_seconds", 120)) / CrewModel.multiplier_for(data, crew_defs, "workshop")))
	return timers.start("craft_" + gizmo_id, "craft", duration, now, {"gizmo": gizmo_id})
```

In `game/base/workshop_screen.gd`:

1. In `_gizmo_label_text`, change the cost line to:

```gdscript
		text += "  cost: %s" % _cost_text(def.get("craft_cost", {}))
```

2. In `_on_craft_pressed`, change the model call to:

```gdscript
	if CraftModel.start_craft(GameState.data, DataDefs.gizmos, Economy, TimerService, gizmo_id, TimeUtil.now(), DataDefs.crew):
```

- [ ] **Step 3: Rework the tests (same task, exact edits)**

`tests/test_craft_model.gd`:

1. In `before_each`, add after the cloudsilk line:

```gdscript
	state.data["currencies"]["parts"] = 50
```

2. In `test_start_craft_pays_and_starts_timer`, replace the scrap assertion line with:

```gdscript
	assert_eq(econ.balance("parts"), 50 - 2)
```

3. In `test_brasswork_gates_the_brass_recipes`, change the first assertion's message string to `"50 parts but zero brasswork: locked"`.
4. DELETE these whole functions: `with_annex`, `test_effective_cost_is_the_raw_cost_without_an_annex`, `test_effective_cost_discounts_and_ceils`, `test_effective_cost_never_reaches_zero`, `test_start_craft_pays_the_discounted_price_it_checked`, `test_discount_unlocks_a_craft_at_the_margin`.
5. In `test_crewed_workshop_crafts_faster_and_locks_at_start` and `test_uncrewed_craft_duration_is_baseline`, change each `start_craft(...)` call to drop the `DataDefs.buildings` argument:

```gdscript
	assert_true(CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan", 1000, DataDefs.crew))
```

6. Append one new test:

```gdscript
func test_crafts_cost_parts_not_scrap() -> void:
	state.data["currencies"]["parts"] = 0
	assert_false(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan"),
		"5000 scrap buys nothing at the workshop anymore")
	state.data["currencies"]["parts"] = 2
	assert_true(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan"))
```

`tests/test_workshop_screen.gd`:

1. In `before_each`, add after the scrap line:

```gdscript
	GameState.data["currencies"]["parts"] = 50
```

2. In `test_craft_starts_through_model`, replace the balance assertion with:

```gdscript
	assert_eq(Economy.balance("parts"), 50 - 2)
```

3. Replace the whole `test_idle_rows_show_the_effective_craft_cost` function with:

```gdscript
func test_idle_rows_show_the_parts_cost() -> void:
	var text: String = screen._gizmo_label_text("wind_fan", TimeUtil.now())
	assert_string_contains(text, "2 parts", "the label shows the price the tap will pay")
```

`tests/test_retention_integration.gd`: in `before_each`, add after the scrap line:

```gdscript
	state.data["currencies"]["parts"] = 10
```

`tests/test_region_2_integration.gd`: directly after the two `econ.add(...)` lines (scrap 35, brasswork 2), add:

```gdscript
	econ.add("parts", 5)
```

`tests/test_island_integration.gd`: in `before_each`, add after the crystals line:

```gdscript
	state.data["currencies"]["parts"] = 20
```

- [ ] **Step 4: Run the five test files, then the full suite**

Run each edited file with `-gtest=`, then the full suite; must exit 0. Also grep as a wrap-up check: `grep -rn "effective_cost\|craft_discount_per_level" game tests` must return nothing.

- [ ] **Step 5: Commit**

```bash
git add game/data/gizmos.json game/data/buildings.json game/base/craft_model.gd game/base/workshop_screen.gd tests/test_craft_model.gd tests/test_workshop_screen.gd tests/test_retention_integration.gd tests/test_region_2_integration.gd tests/test_island_integration.gd
git commit -m "feat: gizmo crafts repriced to parts; annex discount retired"
```

---

### Task 3: ConvertModel

**Files:**
- Create: `game/base/convert_model.gd`
- Test: `tests/test_convert_model.gd` (create)

**Interfaces:**
- Consumes: recipes (Task 1), `CrewModel.multiplier_for`, `IslandModel.building_level`, Economy/TimerService node APIs.
- Produces (Task 6 calls these exact signatures):
  - `ConvertModel.recipe(building_defs, building_id) -> Dictionary`
  - `ConvertModel.outputs_for(building_defs, island, building_id) -> Dictionary` (scaled by level; `{}` when unbuilt or recipe-less)
  - `ConvertModel.can_start(data, building_defs, economy, timers, building_id) -> bool`
  - `ConvertModel.start_batch(data, building_defs, economy, timers, building_id, now, crew_defs: Dictionary = {}) -> bool`
  - `ConvertModel.complete_batch(data, building_defs, economy, payload) -> void`
  - Timer ids `convert_<building_id>`, kind `"convert"`, payload `{"building": building_id}`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_convert_model.gd`:

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
	state.data["currencies"]["scrap"] = 1000
	state.data["currencies"]["brasswork"] = 10
	state.data["island"]["plots"]["plot_1"] = {"building": "smeltery", "level": 1}
	econ = autofree(EconomyScript.new())
	econ.setup(state)
	timers = autofree(TimerServiceScript.new())
	timers.setup(state)


func test_unbuilt_building_cannot_convert() -> void:
	state.data["island"]["plots"].clear()
	assert_false(ConvertModel.can_start(state.data, DataDefs.buildings, econ, timers, "smeltery"))
	assert_eq(ConvertModel.outputs_for(DataDefs.buildings, state.data["island"], "smeltery"), {})

func test_recipe_less_building_cannot_convert() -> void:
	state.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	assert_false(ConvertModel.can_start(state.data, DataDefs.buildings, econ, timers, "workshop"))

func test_start_batch_pays_and_starts_the_convert_timer() -> void:
	assert_true(ConvertModel.start_batch(state.data, DataDefs.buildings, econ, timers, "smeltery", 1000))
	assert_eq(econ.balance("scrap"), 1000 - 40)
	assert_eq(timers.remaining("convert_smeltery", 1000), 600)
	assert_eq(String((timers.active_timers()["convert_smeltery"] as Dictionary)["kind"]), "convert")

func test_one_batch_per_building() -> void:
	ConvertModel.start_batch(state.data, DataDefs.buildings, econ, timers, "smeltery", 1000)
	assert_false(ConvertModel.can_start(state.data, DataDefs.buildings, econ, timers, "smeltery"))

func test_zero_input_recipe_starts_for_free() -> void:
	state.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	state.data["currencies"]["scrap"] = 0
	assert_true(ConvertModel.start_batch(state.data, DataDefs.buildings, econ, timers, "gardens", 1000))
	assert_eq(timers.remaining("convert_gardens", 1000), 3600)

func test_outputs_scale_with_building_level() -> void:
	assert_eq(ConvertModel.outputs_for(DataDefs.buildings, state.data["island"], "smeltery"), {"parts": 1})
	state.data["island"]["plots"]["plot_1"]["level"] = 3
	assert_eq(ConvertModel.outputs_for(DataDefs.buildings, state.data["island"], "smeltery"), {"parts": 3})

func test_complete_batch_credits_at_collect_time_level() -> void:
	ConvertModel.start_batch(state.data, DataDefs.buildings, econ, timers, "smeltery", 1000)
	state.data["island"]["plots"]["plot_1"]["level"] = 2
	var payload: Dictionary = timers.collect("convert_smeltery", 1000 + 600)
	ConvertModel.complete_batch(state.data, DataDefs.buildings, econ, payload)
	assert_eq(econ.balance("parts"), 2,
		"outputs are read at collect time; the mid-batch upgrade pays the new level")

func test_complete_batch_ignores_junk_payloads() -> void:
	ConvertModel.complete_batch(state.data, DataDefs.buildings, econ, {})
	ConvertModel.complete_batch(state.data, DataDefs.buildings, econ, {"building": "no_such"})
	assert_eq(econ.balance("parts"), 0)

func test_crew_divides_the_duration_and_locks_at_start() -> void:
	CrewModel.rescue(state.data, "reya")
	(state.data["crew"]["assignments"] as Dictionary)["smeltery"] = "reya"
	assert_true(ConvertModel.start_batch(state.data, DataDefs.buildings, econ, timers, "smeltery", 1000, DataDefs.crew))
	assert_eq(timers.remaining("convert_smeltery", 1000), 400, "600s / Reya's 1.5 specialist bonus")
	(state.data["crew"]["assignments"] as Dictionary).erase("smeltery")
	assert_eq(timers.remaining("convert_smeltery", 1000), 400, "duration locked at start")

func test_missing_currency_key_defaults_to_zero_and_add_creates() -> void:
	(state.data["currencies"] as Dictionary).erase("parts")
	assert_eq(econ.balance("parts"), 0, "a pre-parts save reads zero")
	econ.add("parts", 3)
	assert_eq(econ.balance("parts"), 3, "the first add creates the key")

func test_brass_smelt_consumes_both_inputs() -> void:
	state.data["island"]["plots"]["islet_foundry_0"] = {"building": "foundry_annex", "level": 1}
	assert_true(ConvertModel.start_batch(state.data, DataDefs.buildings, econ, timers, "foundry_annex", 1000))
	assert_eq(econ.balance("scrap"), 1000 - 30)
	assert_eq(econ.balance("brasswork"), 10 - 1)
	ConvertModel.complete_batch(state.data, DataDefs.buildings, econ, timers.collect("convert_foundry_annex", 1000 + 600))
	assert_eq(econ.balance("parts"), 2, "the efficient late-game converter")
```

- [ ] **Step 2: Run to verify failure**

`--import`, then the file. Expected: FAIL (ConvertModel missing).

- [ ] **Step 3: Implement**

Create `game/base/convert_model.gd`:

```gdscript
class_name ConvertModel
## Timed conversion batches (chains spec section 6): a built building with a
## recipe pays the inputs up front, runs a TimerService timer of kind
## "convert" (id convert_<building>), and credits the outputs at collect,
## scaled by the building's level at collect time. One batch per building.
## Crew speed divides the duration through CrewModel.multiplier_for.


static func recipe(building_defs: Dictionary, building_id: String) -> Dictionary:
	var def: Dictionary = (building_defs.get("defs", {}) as Dictionary).get(building_id, {})
	var raw: Variant = def.get("recipe", {})
	return raw if raw is Dictionary else {}


static func outputs_for(building_defs: Dictionary, island: Dictionary, building_id: String) -> Dictionary:
	var level := IslandModel.building_level(island, building_id)
	var base: Dictionary = recipe(building_defs, building_id).get("outputs", {})
	if level <= 0 or base.is_empty():
		return {}
	var out := {}
	for currency in base:
		out[currency] = int(base[currency]) * level
	return out


static func can_start(data: Dictionary, building_defs: Dictionary, economy: Node, timers: Node, building_id: String) -> bool:
	var conversion := recipe(building_defs, building_id)
	if conversion.is_empty():
		return false
	if IslandModel.building_level(data.get("island", {}), building_id) <= 0:
		return false
	if timers.active_timers().has("convert_" + building_id):
		return false
	return economy.can_afford(conversion.get("inputs", {}))


static func start_batch(data: Dictionary, building_defs: Dictionary, economy: Node, timers: Node, building_id: String, now: int, crew_defs: Dictionary = {}) -> bool:
	if not can_start(data, building_defs, economy, timers, building_id):
		return false
	var conversion := recipe(building_defs, building_id)
	if not economy.pay(conversion.get("inputs", {})):
		return false
	# The worker's speed is priced into the duration at START and locked in
	# ends_at, same rule as crafts (crew spec section 5).
	var duration := maxi(1, ceili(float(conversion.get("seconds", 600)) / CrewModel.multiplier_for(data, crew_defs, building_id)))
	return timers.start("convert_" + building_id, "convert", duration, now, {"building": building_id})


static func complete_batch(data: Dictionary, building_defs: Dictionary, economy: Node, payload: Dictionary) -> void:
	var building_id := String(payload.get("building", ""))
	if building_id == "":
		return
	var outputs := outputs_for(building_defs, data.get("island", {}), building_id)
	for currency in outputs:
		economy.add(String(currency), int(outputs[currency]))
```

- [ ] **Step 4: Run the file, then the full suite**

Both green; no untracked sidecars.

- [ ] **Step 5: Commit**

```bash
git add game/base/convert_model.gd game/base/convert_model.gd.uid tests/test_convert_model.gd tests/test_convert_model.gd.uid
git commit -m "feat: ConvertModel timed conversion batches"
```

---

### Task 4: Rebase helper fold and the clamp pinning test

**Files:**
- Modify: `game/base/trickle_model.gd`, `game/base/crew_model.gd`, `game/base/island_model.gd`
- Test: `tests/test_trickle_model.gd` (modify), `tests/test_crew_model.gd` (modify)

**Interfaces:**
- Consumes: existing rebase behavior (pinned by existing tests, which must keep passing unchanged).
- Produces: `TrickleModel.rebase_preserving(data, building_defs, crew_defs, now, pending_before) -> void`; `CrewModel._rebase_trickle` and `IslandModel.complete_build`'s gardens branch both delegate to it.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_trickle_model.gd`:

```gdscript
func test_rebase_preserving_relocates_the_clock() -> void:
	var data := make_data(1, 10000)
	var now := 10000 + 1800
	TrickleModel.rebase_preserving(data, DataDefs.buildings, {}, now, 10)
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, now), 10, "value preserved at the current rate")
	TrickleModel.rebase_preserving(data, {}, {}, now, 999)
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, now), 10, "empty defs is a no-op")
```

Append to `tests/test_crew_model.gd`:

```gdscript
func test_downward_rebase_clamps_to_the_new_cap_window() -> void:
	var data := fresh_data()
	rescue_all(data)
	CrewModel.assign(data, DataDefs.crew, "gardens", "odo", DataDefs.buildings, 10000)
	var now := 10000 + 3600 * 20
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, now, DataDefs.crew), 240, "8h cap at 30/hour")
	CrewModel.unassign(data, DataDefs.crew, "gardens", DataDefs.buildings, now)
	assert_eq(TrickleModel.pending(data, DataDefs.buildings, now, DataDefs.crew), 160,
		"owner ruling 2026-09-08: pending clamps to the new rate's cap window (8h x 20)")
```

- [ ] **Step 2: Run to verify failure**

Run both files. Expected: FAIL (`rebase_preserving` missing; the clamp test passes only once the helper exists, run it to see the current state either way and report which assertions failed).

- [ ] **Step 3: Implement the fold**

Append to `game/base/trickle_model.gd`:

```gdscript
static func rebase_preserving(data: Dictionary, building_defs: Dictionary, crew_defs: Dictionary, now: int, pending_before: int) -> void:
	# Relocates last_collect so pending_before is preserved at the CURRENT
	# rate (never re-rated). Pending stays subject to the cap window at the
	# new rate: a downward rate change may clamp excess (owner ruling,
	# 2026-09-08). No-op when the rate is zero or defs are missing.
	if building_defs.is_empty():
		return
	var rate := rate_per_hour(data, building_defs, crew_defs)
	if rate <= 0.0:
		return
	(data.get("trickle", {}) as Dictionary)["last_collect"] = now - int(float(pending_before) * 3600.0 / rate)
```

In `game/base/crew_model.gd`, replace the whole `_rebase_trickle` function with:

```gdscript
static func _rebase_trickle(data: Dictionary, defs: Dictionary, building_defs: Dictionary, now: int, pending_before: int, mult_before: float) -> void:
	# An assignment flip must not re-rate scrap already accrued. Only a real
	# gardens-rate change rebases; the shared helper owns the relocation math.
	if building_defs.is_empty():
		return
	if is_equal_approx(multiplier_for(data, defs, "gardens"), mult_before):
		return
	TrickleModel.rebase_preserving(data, building_defs, defs, now, pending_before)
```

In `game/base/island_model.gd`, in `complete_build`'s gardens branch, replace the `elif not building_defs.is_empty():` block's body with:

```gdscript
		elif not building_defs.is_empty():
			# Rebase at the new rate so the pending VALUE carries over (spec
			# 4.1 retention finding), priced at the crewed rate when crew defs
			# are provided; the shared helper owns the relocation math.
			var pending_old := TrickleModel.pending(data, building_defs, now, crew_defs)
			plots[plot]["level"] = to_level
			TrickleModel.rebase_preserving(data, building_defs, crew_defs, now, pending_old)
```

- [ ] **Step 4: Run test_trickle_model, test_crew_model, test_island_model, then the full suite**

All existing rebase tests must pass unchanged through the shared helper; suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/base/trickle_model.gd game/base/crew_model.gd game/base/island_model.gd tests/test_trickle_model.gd tests/test_crew_model.gd
git commit -m "refactor: shared trickle rebase helper; clamp ruling pinned"
```

---

### Task 5: Convert notifications

**Files:**
- Modify: `game/core/notification_planner.gd`
- Test: `tests/test_notifications.gd` (modify)

**Interfaces:**
- Consumes: kind `"convert"` payload `{"building": id}` (Task 3), building defs already passed to `plan`.
- Produces: convert entries `{"id": <timer id>, "title": "Batch complete", "body": "The <name>'s batch is ready.", "fire_at": ends_at}`. No signature change.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_notifications.gd`:

```gdscript
func test_convert_entry_names_the_building() -> void:
	var data := make_data()
	data["timers"]["convert_smeltery"] = {"kind": "convert", "ends_at": NOW + 600, "payload": {"building": "smeltery"}}
	var plan := NotificationPlanner.plan(data, DataDefs.buildings, DataDefs.gizmos, NOW)
	assert_eq(plan.size(), 1)
	assert_eq(String(plan[0]["id"]), "convert_smeltery")
	assert_eq(String(plan[0]["title"]), "Batch complete")
	assert_string_contains(String(plan[0]["body"]), "Smeltery")
	assert_eq(int(plan[0]["fire_at"]), NOW + 600)
```

- [ ] **Step 2: Run to verify failure**

Run the file. Expected: FAIL (no convert branch, plan size 0).

- [ ] **Step 3: Implement**

In `game/core/notification_planner.gd`:

1. Add a sibling `elif` after the `elif kind == "restoration":` block:

```gdscript
		elif kind == "convert":
			var recipe_def: Dictionary = (building_defs.get("defs", {}) as Dictionary).get(String(payload.get("building", "")), {})
			out.append({
				"id": String(id),
				"title": "Batch complete",
				"body": "The %s's batch is ready." % String(recipe_def.get("name", payload.get("building", "a building"))),
				"fire_at": fire_at,
			})
```

2. Update the doc comment's enumeration to include "conversion batch".

- [ ] **Step 4: Run the file, then the full suite**

Both green.

- [ ] **Step 5: Commit**

```bash
git add game/core/notification_planner.gd tests/test_notifications.gd
git commit -m "feat: conversion batches join the notification plan"
```

---

### Task 6: Island convert UI and main balance lines

**Files:**
- Modify: `game/base/island_screen.gd`, `game/main.gd`
- Test: `tests/test_island_screen.gd` (modify), `tests/test_main_boot.gd` (modify)

**Interfaces:**
- Consumes: `ConvertModel` (Task 3), recipes with `name` (Task 1).
- Produces: convert affordances on built recipe-building rows; handlers `_on_batch_start_pressed(building_id)`, `_on_batch_collect_pressed(building_id)`; helper `_batch_button_text(building_id)`; convert timers in the refresh signature; batch countdowns in `_row_text`; Parts/Provisions lines on main's balance readout.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_island_screen.gd`:

```gdscript
func with_smeltery(level: int) -> void:
	GameState.data["island"]["plots"]["plot_1"] = {"building": "smeltery", "level": level}
	GameState.data["currencies"]["scrap"] = 2000
	screen._rebuild()


func test_batch_start_pays_and_starts() -> void:
	with_smeltery(1)
	screen._on_batch_start_pressed("smeltery")
	assert_true(TimerService.active_timers().has("convert_smeltery"))
	assert_eq(Economy.balance("scrap"), 2000 - 40)

func test_batch_collect_credits_scaled_outputs() -> void:
	with_smeltery(2)
	screen._on_batch_start_pressed("smeltery")
	TimerService._state.data["timers"]["convert_smeltery"]["ends_at"] = 0
	screen._on_batch_collect_pressed("smeltery")
	assert_eq(Economy.balance("parts"), 2, "level 2 pays double")
	assert_false(TimerService.active_timers().has("convert_smeltery"))

func test_batch_start_persists() -> void:
	with_smeltery(1)
	screen._on_batch_start_pressed("smeltery")
	var saved := SaveIO.new(TEST_SAVE).read()
	assert_true((saved["timers"] as Dictionary).has("convert_smeltery"),
		"a paid batch must survive an OS kill")

func test_running_batch_joins_the_signature_and_row_text() -> void:
	with_smeltery(1)
	screen._refresh_tick()
	var idle_signature: String = screen._last_signature
	screen._on_batch_start_pressed("smeltery")
	screen._refresh_tick()
	assert_ne(screen._last_signature, idle_signature, "a starting batch is structural")
	var running_signature: String = screen._last_signature
	assert_string_contains(screen._row_text("plot_1", GameState.data["island"], TimeUtil.now()), "batch",
		"the countdown rides the row label")
	TimerService._state.data["timers"]["convert_smeltery"]["ends_at"] = 0
	screen._refresh_tick()
	assert_ne(screen._last_signature, running_signature, "done is structural: Collect must appear")

func test_zero_input_gardens_batch_starts_broke() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	GameState.data["currencies"]["scrap"] = 0
	screen._rebuild()
	screen._on_batch_start_pressed("gardens")
	assert_true(TimerService.active_timers().has("convert_gardens"))
```

In `tests/test_main_boot.gd`, append:

```gdscript
func test_debug_label_shows_parts_and_provisions() -> void:
	assert_string_contains(main.get_node("DebugLabel").text, "Parts: ")
	assert_string_contains(main.get_node("DebugLabel").text, "Provisions: ")
```

- [ ] **Step 2: Run to verify failure**

Run both files. Expected: FAIL (no handlers, no label lines).

- [ ] **Step 3: Implement the island screen changes**

In `game/base/island_screen.gd`:

1. In `_signature`, add after the crew loop (before `return`):

```gdscript
	for id in DataDefs.buildings.get("defs", {}):
		if not ((DataDefs.buildings["defs"] as Dictionary)[id] as Dictionary).has("recipe"):
			continue
		var convert_id := "convert_" + String(id)
		if TimerService.active_timers().has(convert_id):
			parts.append("cd" if TimerService.is_done(convert_id, now) else "cr")
		else:
			parts.append("ci")
```

2. In `_rebuild`'s plot loop, add directly before the `rows.add_child(row)` line:

```gdscript
			var occupant := ""
			if island.get("plots", {}).has(plot):
				occupant = String((island["plots"][plot] as Dictionary).get("building", ""))
			if occupant != "" and not ConvertModel.recipe(DataDefs.buildings, occupant).is_empty():
				var convert_id := "convert_" + occupant
				if TimerService.active_timers().has(convert_id):
					if TimerService.is_done(convert_id, now):
						var batch := Button.new()
						batch.text = "Collect (%s)" % _cost_text(ConvertModel.outputs_for(DataDefs.buildings, island, occupant))
						batch.pressed.connect(_on_batch_collect_pressed.bind(occupant))
						row.add_child(batch)
				else:
					var start_batch := Button.new()
					start_batch.text = _batch_button_text(occupant)
					start_batch.disabled = not ConvertModel.can_start(GameState.data, DataDefs.buildings, Economy, TimerService, occupant)
					start_batch.pressed.connect(_on_batch_start_pressed.bind(occupant))
					row.add_child(start_batch)
```

Note the indentation: this block sits inside the `for plot in _plot_ids():` loop body at the same depth as the `if TimerService.active_timers().has(timer_id):` branch, after it.

3. In `_row_text`, add directly after the worker-suffix block (before the observatory teaser):

```gdscript
			var convert_id := "convert_" + String(entry["building"])
			if TimerService.active_timers().has(convert_id) and not TimerService.is_done(convert_id, now):
				text += "  (batch %ds)" % TimerService.remaining(convert_id, now)
```

4. Add after `_assign_text`:

```gdscript
func _batch_button_text(building_id: String) -> String:
	var conversion := ConvertModel.recipe(DataDefs.buildings, building_id)
	var inputs: Dictionary = conversion.get("inputs", {})
	var display := String(conversion.get("name", building_id))
	if inputs.is_empty():
		return display
	return "%s (%s)" % [display, _cost_text(inputs)]


func _on_batch_start_pressed(building_id: String) -> void:
	if ConvertModel.start_batch(GameState.data, DataDefs.buildings, Economy, TimerService, building_id, TimeUtil.now(), DataDefs.crew):
		GameState.save_game()
	_rebuild()


func _on_batch_collect_pressed(building_id: String) -> void:
	var payload := TimerService.collect("convert_" + building_id, TimeUtil.now())
	if payload.is_empty():
		return
	ConvertModel.complete_batch(GameState.data, DataDefs.buildings, Economy, payload)
	GameState.save_game()
	_rebuild()
```

In `game/main.gd`, replace the `debug_label.text` assignment with:

```gdscript
	debug_label.text = "Scrap: %d\nCloudsilk: %d\nBrasswork: %d\nCrystals: %d\nParts: %d\nProvisions: %d\nFuel: %d/%d" % [
		Economy.balance("scrap"),
		Economy.balance("cloudsilk"),
		Economy.balance("brasswork"),
		Economy.balance("crystals"),
		Economy.balance("parts"),
		Economy.balance("provisions"),
		FuelModel.current(fuel, now),
		int(fuel["cap"]),
	]
```

- [ ] **Step 4: Run both files, then the full suite**

Both green; suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/base/island_screen.gd game/main.gd tests/test_island_screen.gd tests/test_main_boot.gd
git commit -m "feat: conversion batches on the island screen; new balances on main"
```

---

### Task 7: End-to-end integration proof and roadmap note

**Files:**
- Test: `tests/test_chain_integration.gd` (create)
- Modify: `docs/ROADMAP.md`

**Interfaces:**
- Consumes: everything from Tasks 1-6.
- Produces: one fixed-clock proof: crewed Smeltery smelts parts, a gizmo crafts with them. Standing ruling: integration proofs run no-strict-RED (must pass first try; a failure is a production bug, never test arithmetic to bend).

- [ ] **Step 1: Write the integration test**

Create `tests/test_chain_integration.gd`:

```gdscript
extends GutTest
## End-to-end chain proof (chains spec): scrap smelts into parts at a crewed
## Smeltery, and the parts price a gizmo craft. Fixed clock, no RNG.

const TEST_SAVE := "user://test_chain_integration.json"
const T0 := 1_800_000_000


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	GameState.data["created_at"] = T0
	GameState.data["fuel"]["updated_at"] = T0
	GameState.data["currencies"]["scrap"] = 500
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	GameState.data["island"]["plots"]["plot_1"] = {"building": "smeltery", "level": 1}


func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_chain_integration.json", "test_chain_integration.json.tmp", "test_chain_integration.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings, DataDefs.crew)


func test_smelt_then_craft_end_to_end() -> void:
	# 1. Reya works the Smeltery: the batch runs at the specialist rate.
	CrewModel.rescue(GameState.data, "reya")
	assert_true(CrewModel.assign(GameState.data, DataDefs.crew, "smeltery", "reya", DataDefs.buildings, T0))
	assert_true(ConvertModel.start_batch(GameState.data, DataDefs.buildings, Economy, TimerService, "smeltery", T0, DataDefs.crew))
	assert_eq(Economy.balance("scrap"), 500 - 40)
	assert_eq(TimerService.remaining("convert_smeltery", T0), 400, "600s / 1.5 specialist")
	# 2. Collect the parts.
	var payload := TimerService.collect("convert_smeltery", T0 + 400)
	ConvertModel.complete_batch(GameState.data, DataDefs.buildings, Economy, payload)
	assert_eq(Economy.balance("parts"), 1)
	# 3. Parts price the craft: one short, then enough.
	assert_false(CraftModel.can_craft(GameState.data, DataDefs.gizmos, Economy, TimerService, "wind_fan"),
		"one part is not two")
	Economy.add("parts", 1)
	assert_true(CraftModel.start_craft(GameState.data, DataDefs.gizmos, Economy, TimerService, "wind_fan", T0 + 400))
	assert_eq(Economy.balance("parts"), 0, "the chain's output is the craft's input")
	CraftModel.complete_craft(GameState.data, TimerService.collect("craft_wind_fan", T0 + 400 + 120))
	assert_eq(int(GameState.data["gizmos"]["owned"]["wind_fan"]), 2, "the loop closes: island production upgrades the board")

func test_provisions_accumulate_for_plan_12() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	assert_true(ConvertModel.start_batch(GameState.data, DataDefs.buildings, Economy, TimerService, "gardens", T0))
	ConvertModel.complete_batch(GameState.data, DataDefs.buildings, Economy, TimerService.collect("convert_gardens", T0 + 3600))
	assert_eq(Economy.balance("provisions"), 2, "the stock builds ahead of the run kit")
```

- [ ] **Step 2: Run the file and confirm first-try pass (no-strict-RED ruling)**

`--import`, then the file. A failure is a production bug: fix production, never the test's arithmetic.

- [ ] **Step 3: Update the roadmap**

In `docs/ROADMAP.md`, in the island-rework section, replace the sentence:

```
Plan 11 (production chains: worked parts and provisions, conversion recipes, gizmo component costs): next, needs its spec. Plan 12 (run kit: setup-phase consumables and expedition provisioning): after 11.
```

with:

```
Plan 11 (production chains): SHIPPED (spec: docs/superpowers/specs/2026-09-08-production-chains-design.md; parts and provisions currencies, Smeltery + Annex + Gardens batch recipes on the "convert" timer kind, all gizmo crafts repriced to parts, Annex discount retired). Plan 12 (run kit: setup-phase consumables and expedition provisioning): next, needs its spec.
```

- [ ] **Step 4: Run the full suite**

Exit 0.

- [ ] **Step 5: Commit**

```bash
git add tests/test_chain_integration.gd tests/test_chain_integration.gd.uid docs/ROADMAP.md
git commit -m "test: prove the production chain end to end"
```

---

## Manual smoke steps (owner runs these windowed/on-device, per the ongoing practice)

1. Build the Smeltery on the new seventh plot; the Smelt button shows "(40 scrap)"; start a batch and watch the countdown ride the row.
2. Assign Reya to the Smeltery; the next batch runs visibly faster.
3. Collect the batch; Parts appears on main's readout; the Workshop rows now price in parts and a craft consumes them.
4. Start "Put up provisions" at the Gardens with zero scrap; it runs.
5. Background the app mid-batch; the "Batch complete" notification is scheduled; relaunch and collect.
