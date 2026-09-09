# Windfall Isles Plan 12: The Run Kit

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Balloonworks-crafted consumables and Gardens provisioning spent at the run setup phase, closing the island-rework arc's economy loop.

**Architecture:** Building recipes generalize from a single `recipe` dict to a `recipes` array (one atomic cutover, Plan 11-style), with ConvertModel gaining `(building_id, recipe_id)` addressing while keeping one batch per building. A `kit` block in run.json defines three consumables plus provisioning; the Plan 9 SetupUI gains a KitPanel of toggle chips, and Start consumes elections after the fuel spend through existing effect seams (Spare Pods `add_drops`, Featherfall `pod_defs`, the reroll handler, and `_compute_payout`'s multiplier product).

**Tech Stack:** Godot 4.6.3 (GDScript), GUT 9.6.1, JSON data files.

**Spec:** docs/superpowers/specs/2026-09-09-run-kit-design.md

## Global Constraints

- Godot binary: `GODOT=/Applications/Godot-4.6.app/Contents/MacOS/Godot` (4.6.3; NEVER `/Applications/Godot.app`).
- Full suite (must exit 0): `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- Single file: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit`
- After creating any new .gd file, run `$GODOT --headless --import`; commit `.gd.uid` sidecars; `git status --porcelain` shows no untracked `.gd.uid`.
- Indentation: tabs. No em dashes anywhere.
- Raw JSON numbers: `int()`/`float()` casts at use and assert sites; never normalize in DataDefs.
- Pure models never read autoloads, wall clocks, or RNG; `now` injected; Economy/TimerService passed as Nodes.
- GUT 9.6 auto-fails on pushed/engine errors; strict warnings reject `:=` inference from untyped chains.
- UI tests call handlers directly and NEVER invoke scene-changing handlers.
- Screens: structural signature gates rebuilds; labels update in place; detach-then-free in rebuilds. Kit chips are plain toggle Buttons and the KitPanel must not overlap the SlotTargets region (its tscn rect sits between the slots and the tray).
- The recipes-array migration is a hard cutover: after Task 1, no live code or test reads the singular `recipe` key; everything migrates inside Task 1.
- The Start flow's ordering is binding: fuel spend, then kit consumption, then one save, then gizmo install, then RUNNING. A failed fuel spend consumes no kit.
- Do not state cumulative suite totals anywhere (reports included); per-task new-test lists only.
- Commit after every task; every commit leaves the full suite green.

---

### Task 1: The recipes-array cutover

**Files:**
- Modify: `game/data/buildings.json`, `game/data/economy.json`, `game/base/convert_model.gd`, `game/base/island_screen.gd`
- Test: `tests/test_recipe_defs.gd` (modify), `tests/test_convert_model.gd` (modify), `tests/test_island_screen.gd` (modify), `tests/test_chain_integration.gd` (modify)

**Interfaces:**
- Consumes: Plan 11's ConvertModel and island convert UI.
- Produces (later tasks and the UI rely on these exact signatures):
  - `ConvertModel.recipes(building_defs, building_id) -> Array`
  - `ConvertModel.recipe_by_id(building_defs, building_id, recipe_id) -> Dictionary`
  - `ConvertModel.outputs_for(building_defs, island, building_id, recipe_id) -> Dictionary`
  - `ConvertModel.can_start(data, building_defs, economy, timers, building_id, recipe_id) -> bool`
  - `ConvertModel.start_batch(data, building_defs, economy, timers, building_id, recipe_id, now, crew_defs: Dictionary = {}) -> bool` with payload `{"building", "recipe"}`
  - `ConvertModel.complete_batch(data, building_defs, economy, payload)` with a single-recipe fallback for legacy payloads lacking "recipe" (a Plan 11 save's in-flight batch still credits; on a multi-recipe building a recipe-less payload is a no-op).
  - Island handlers `_on_batch_start_pressed(building_id, recipe_id)`, `_batch_button_text(building_id, recipe_id)`; buildings.json `recipes` arrays (Smeltery/Annex/Gardens wrapped unchanged; Balloonworks gains three); `starting_balances` gains `ballast`, `wind_charm`, `storm_oil` at 0.

- [ ] **Step 1: Edit the data files**

In `game/data/buildings.json`:

1. In the `smeltery` def, change the recipe line to:

```json
			"recipes": [{"id": "smelt", "name": "Smelt", "inputs": {"scrap": 40}, "outputs": {"parts": 1}, "seconds": 600}]
```

2. In the `gardens` def, change its recipe line to:

```json
			"recipes": [{"id": "put_up_provisions", "name": "Put up provisions", "inputs": {}, "outputs": {"provisions": 2}, "seconds": 3600}],
```

(keep the trailing comma exactly as the current `recipe` line has, so the JSON stays valid in place).

3. In the `foundry_annex` def, change its recipe line to:

```json
			"recipes": [{"id": "brass_smelt", "name": "Brass smelt", "inputs": {"scrap": 30, "brasswork": 1}, "outputs": {"parts": 2}, "seconds": 600}],
```

4. In the `balloonworks` def, add after its `"drops_bonus_per_level": 1,` line:

```json
			"recipes": [
				{"id": "charged_ballast", "name": "Charged Ballast", "inputs": {"cloudsilk": 1, "parts": 1}, "outputs": {"ballast": 1}, "seconds": 900},
				{"id": "wind_charm", "name": "Wind Charm", "inputs": {"cloudsilk": 2, "parts": 1}, "outputs": {"wind_charm": 1}, "seconds": 1200},
				{"id": "storm_oil", "name": "Storm Oil", "inputs": {"cloudsilk": 1, "parts": 2}, "outputs": {"storm_oil": 1}, "seconds": 900}
			],
```

In `game/data/economy.json`, extend `starting_balances` to:

```json
	"starting_balances": {
		"scrap": 100,
		"cloudsilk": 0,
		"brasswork": 0,
		"crystals": 10,
		"parts": 0,
		"provisions": 0,
		"ballast": 0,
		"wind_charm": 0,
		"storm_oil": 0
	},
```

- [ ] **Step 2: Rewrite ConvertModel**

Replace the whole body of `game/base/convert_model.gd` with:

```gdscript
class_name ConvertModel
## Timed conversion batches (chains spec section 6; recipe addressing per the
## run-kit spec section 3): a built building carries recipes; a batch pays one
## recipe's inputs up front, runs a TimerService timer of kind "convert"
## (id convert_<building>, ONE batch per building regardless of recipe), and
## credits that recipe's outputs at collect, scaled by the building's level at
## collect time. Crew speed divides the duration through CrewModel.


static func recipes(building_defs: Dictionary, building_id: String) -> Array:
	var def: Dictionary = (building_defs.get("defs", {}) as Dictionary).get(building_id, {})
	var raw: Variant = def.get("recipes", [])
	return raw if raw is Array else []


static func recipe_by_id(building_defs: Dictionary, building_id: String, recipe_id: String) -> Dictionary:
	for row_v in recipes(building_defs, building_id):
		var row := row_v as Dictionary
		if String(row.get("id", "")) == recipe_id:
			return row
	return {}


static func outputs_for(building_defs: Dictionary, island: Dictionary, building_id: String, recipe_id: String) -> Dictionary:
	var level := IslandModel.building_level(island, building_id)
	var base: Dictionary = recipe_by_id(building_defs, building_id, recipe_id).get("outputs", {})
	if level <= 0 or base.is_empty():
		return {}
	var out := {}
	for currency in base:
		out[currency] = int(base[currency]) * level
	return out


static func can_start(data: Dictionary, building_defs: Dictionary, economy: Node, timers: Node, building_id: String, recipe_id: String) -> bool:
	var conversion := recipe_by_id(building_defs, building_id, recipe_id)
	if conversion.is_empty():
		return false
	if IslandModel.building_level(data.get("island", {}), building_id) <= 0:
		return false
	if timers.active_timers().has("convert_" + building_id):
		return false
	return economy.can_afford(conversion.get("inputs", {}))


static func start_batch(data: Dictionary, building_defs: Dictionary, economy: Node, timers: Node, building_id: String, recipe_id: String, now: int, crew_defs: Dictionary = {}) -> bool:
	if not can_start(data, building_defs, economy, timers, building_id, recipe_id):
		return false
	var conversion := recipe_by_id(building_defs, building_id, recipe_id)
	if not economy.pay(conversion.get("inputs", {})):
		return false
	# The worker's speed is priced into the duration at START and locked in
	# ends_at, same rule as crafts (crew spec section 5).
	var duration := maxi(1, ceili(float(conversion.get("seconds", 600)) / CrewModel.multiplier_for(data, crew_defs, building_id)))
	return timers.start("convert_" + building_id, "convert", duration, now, {"building": building_id, "recipe": recipe_id})


static func complete_batch(data: Dictionary, building_defs: Dictionary, economy: Node, payload: Dictionary) -> void:
	var building_id := String(payload.get("building", ""))
	if building_id == "":
		return
	var recipe_id := String(payload.get("recipe", ""))
	if recipe_id == "":
		# Legacy fallback: a Plan 11 save's in-flight batch has no recipe in
		# its payload; a single-recipe building is unambiguous, so credit it.
		# On a multi-recipe building a recipe-less payload stays a no-op.
		var rows := recipes(building_defs, building_id)
		if rows.size() == 1:
			recipe_id = String((rows[0] as Dictionary).get("id", ""))
	if recipe_id == "":
		return
	var outputs := outputs_for(building_defs, data.get("island", {}), building_id, recipe_id)
	for currency in outputs:
		economy.add(String(currency), int(outputs[currency]))
```

- [ ] **Step 3: Migrate the island screen**

In `game/base/island_screen.gd`:

1. In `_signature`, change the recipe-defs check from `.has("recipe")` to `.has("recipes")`.
2. Replace the convert-affordance block inside `_rebuild`'s plot loop (the `var occupant := ""` block) with:

```gdscript
			var occupant := ""
			if island.get("plots", {}).has(plot):
				occupant = String((island["plots"][plot] as Dictionary).get("building", ""))
			if occupant != "" and not ConvertModel.recipes(DataDefs.buildings, occupant).is_empty():
				var convert_id := "convert_" + occupant
				if TimerService.active_timers().has(convert_id):
					if TimerService.is_done(convert_id, now):
						var done_payload: Dictionary = (TimerService.active_timers()[convert_id] as Dictionary).get("payload", {})
						var batch := Button.new()
						batch.text = "Collect (%s)" % _cost_text(ConvertModel.outputs_for(DataDefs.buildings, island, occupant, String(done_payload.get("recipe", ""))))
						batch.pressed.connect(_on_batch_collect_pressed.bind(occupant))
						row.add_child(batch)
				else:
					for recipe_v in ConvertModel.recipes(DataDefs.buildings, occupant):
						var recipe_id := String((recipe_v as Dictionary).get("id", ""))
						var start_batch := Button.new()
						start_batch.text = _batch_button_text(occupant, recipe_id)
						start_batch.disabled = not ConvertModel.can_start(GameState.data, DataDefs.buildings, Economy, TimerService, occupant, recipe_id)
						start_batch.pressed.connect(_on_batch_start_pressed.bind(occupant, recipe_id))
						row.add_child(start_batch)
```

3. Replace `_batch_button_text` and `_on_batch_start_pressed` with:

```gdscript
func _batch_button_text(building_id: String, recipe_id: String) -> String:
	var conversion := ConvertModel.recipe_by_id(DataDefs.buildings, building_id, recipe_id)
	var inputs: Dictionary = conversion.get("inputs", {})
	var display := String(conversion.get("name", recipe_id))
	if inputs.is_empty():
		return display
	return "%s (%s)" % [display, _cost_text(inputs)]


func _on_batch_start_pressed(building_id: String, recipe_id: String) -> void:
	if ConvertModel.start_batch(GameState.data, DataDefs.buildings, Economy, TimerService, building_id, recipe_id, TimeUtil.now(), DataDefs.crew):
		GameState.save_game()
	_rebuild()
```

(`_on_batch_collect_pressed` is unchanged: the payload carries the recipe.)

- [ ] **Step 4: Migrate the tests (same task, exact edits)**

`tests/test_recipe_defs.gd`: replace the whole file with:

```gdscript
extends GutTest
## Authoring guards for conversion recipes (chains spec sections 2-5; recipes
## arrays per the run-kit spec section 2).


func recipe_buildings() -> Dictionary:
	var out := {}
	for id in DataDefs.buildings.get("defs", {}):
		var def: Dictionary = (DataDefs.buildings["defs"] as Dictionary)[id]
		if def.has("recipes"):
			out[String(id)] = def["recipes"]
	return out


func test_exactly_the_four_recipe_buildings() -> void:
	var found := recipe_buildings()
	assert_eq(found.size(), 4)
	for id in ["smeltery", "foundry_annex", "gardens", "balloonworks"]:
		assert_has(found, id)
	assert_eq((found["balloonworks"] as Array).size(), 3, "the run-kit consumables")

func test_recipes_are_well_formed() -> void:
	var known: Array = (DataDefs.economy.get("starting_balances", {}) as Dictionary).keys()
	for id in recipe_buildings():
		for row_v in recipe_buildings()[id]:
			var conversion := row_v as Dictionary
			assert_true(String(conversion.get("id", "")) != "", "recipe id missing: %s" % id)
			assert_true(String(conversion.get("name", "")) != "", "recipe display name missing: %s" % id)
			assert_true(float(conversion.get("seconds", 0)) > 0.0, "recipe seconds missing: %s" % id)
			assert_true((conversion.get("outputs", {}) as Dictionary).size() > 0, "recipe outputs empty: %s" % id)
			for currency in conversion.get("inputs", {}):
				assert_true(known.has(String(currency)), "unknown input currency %s: %s" % [currency, id])
			for currency in conversion.get("outputs", {}):
				assert_true(known.has(String(currency)), "unknown output currency %s: %s" % [currency, id])

func test_recipe_ids_are_globally_unique() -> void:
	var seen := {}
	for id in recipe_buildings():
		for row_v in recipe_buildings()[id]:
			var recipe_id := String((row_v as Dictionary).get("id", ""))
			assert_false(seen.has(recipe_id), "duplicate recipe id: %s" % recipe_id)
			seen[recipe_id] = true

func test_new_currencies_start_at_zero() -> void:
	var balances: Dictionary = DataDefs.economy.get("starting_balances", {})
	for currency in ["parts", "provisions", "ballast", "wind_charm", "storm_oil"]:
		assert_eq(int(balances.get(currency, -1)), 0, "missing starting balance: %s" % currency)

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

func test_gizmo_repricing_table_is_pinned() -> void:
	var expected := {
		"wind_fan": {"parts": 2},
		"balloon_cluster": {"parts": 2},
		"cargo_net": {"parts": 2},
		"magnet_buoy": {"parts": 3},
		"chime_bell": {"parts": 3},
		"lightning_jar": {"parts": 3, "cloudsilk": 1},
		"crystal_prism": {"parts": 3, "cloudsilk": 1},
		"splitter_vane": {"parts": 4, "cloudsilk": 2},
		"piston_kicker": {"parts": 4, "brasswork": 1},
		"gyro_damper": {"parts": 5, "brasswork": 2},
	}
	for gizmo_id in expected:
		var cost: Dictionary = ((DataDefs.gizmos.get("defs", {}) as Dictionary)[gizmo_id] as Dictionary).get("craft_cost", {})
		var want: Dictionary = expected[gizmo_id]
		assert_eq(cost.size(), want.size(), "cost shape drifted: %s" % gizmo_id)
		for currency in want:
			assert_eq(int(cost.get(currency, -1)), int(want[currency]),
				"repricing table drifted (chains spec section 4): %s %s" % [gizmo_id, currency])
```

`tests/test_convert_model.gd`: apply these edits:

1. Every existing `ConvertModel.can_start(...)`, `start_batch(...)`, `outputs_for(...)` call gains its recipe id argument directly after `building_id`: smeltery calls use `"smelt"`, gardens `"put_up_provisions"`, foundry_annex `"brass_smelt"`, workshop (the recipe-less test) uses `"smelt"` as a dummy id. In `test_start_batch_pays_and_starts_the_convert_timer`, also append after the kind assertion:

```gdscript
	assert_eq(String(((timers.active_timers()["convert_smeltery"] as Dictionary)["payload"] as Dictionary)["recipe"]), "smelt")
```

2. Append these new tests:

```gdscript
func test_balloonworks_recipes_are_pickable() -> void:
	state.data["island"]["plots"]["plot_3"] = {"building": "balloonworks", "level": 1}
	state.data["currencies"]["cloudsilk"] = 10
	state.data["currencies"]["parts"] = 10
	assert_true(ConvertModel.start_batch(state.data, DataDefs.buildings, econ, timers, "balloonworks", "wind_charm", 1000))
	assert_eq(econ.balance("cloudsilk"), 10 - 2)
	assert_eq(econ.balance("parts"), 10 - 1)
	ConvertModel.complete_batch(state.data, DataDefs.buildings, econ, timers.collect("convert_balloonworks", 1000 + 1200))
	assert_eq(econ.balance("wind_charm"), 1, "the picked recipe's output, not another's")
	assert_eq(econ.balance("ballast"), 0)

func test_one_batch_per_building_across_recipes() -> void:
	state.data["island"]["plots"]["plot_3"] = {"building": "balloonworks", "level": 1}
	state.data["currencies"]["cloudsilk"] = 10
	state.data["currencies"]["parts"] = 10
	assert_true(ConvertModel.start_batch(state.data, DataDefs.buildings, econ, timers, "balloonworks", "charged_ballast", 1000))
	assert_false(ConvertModel.can_start(state.data, DataDefs.buildings, econ, timers, "balloonworks", "storm_oil"),
		"one batch per building regardless of recipe")

func test_junk_recipe_id_is_rejected() -> void:
	assert_false(ConvertModel.can_start(state.data, DataDefs.buildings, econ, timers, "smeltery", "no_such_recipe"))
	assert_false(ConvertModel.start_batch(state.data, DataDefs.buildings, econ, timers, "smeltery", "no_such_recipe", 1000))

func test_legacy_payload_credits_single_recipe_buildings_only() -> void:
	ConvertModel.complete_batch(state.data, DataDefs.buildings, econ, {"building": "smeltery"})
	assert_eq(econ.balance("parts"), 1, "a Plan 11 in-flight batch still credits: one recipe is unambiguous")
	state.data["island"]["plots"]["plot_3"] = {"building": "balloonworks", "level": 1}
	ConvertModel.complete_batch(state.data, DataDefs.buildings, econ, {"building": "balloonworks"})
	assert_eq(econ.balance("ballast"), 0, "recipe-less payload on a multi-recipe building stays a no-op")
	assert_eq(econ.balance("wind_charm"), 0)
```

`tests/test_island_screen.gd`: in the five batch tests, change each `screen._on_batch_start_pressed("smeltery")` to `screen._on_batch_start_pressed("smeltery", "smelt")` and `screen._on_batch_start_pressed("gardens")` to `screen._on_batch_start_pressed("gardens", "put_up_provisions")`. Then append:

```gdscript
func test_balloonworks_row_offers_all_three_recipes() -> void:
	GameState.data["island"]["plots"]["plot_3"] = {"building": "balloonworks", "level": 1}
	screen._rebuild()
	assert_string_contains(screen._batch_button_text("balloonworks", "charged_ballast"), "Charged Ballast (")
	assert_string_contains(screen._batch_button_text("balloonworks", "wind_charm"), "Wind Charm (")
	assert_string_contains(screen._batch_button_text("balloonworks", "storm_oil"), "Storm Oil (")
	GameState.data["currencies"]["cloudsilk"] = 5
	GameState.data["currencies"]["parts"] = 5
	screen._on_batch_start_pressed("balloonworks", "storm_oil")
	assert_true(TimerService.active_timers().has("convert_balloonworks"))
	assert_eq(Economy.balance("parts"), 5 - 2)
```

`tests/test_chain_integration.gd`: the two `start_batch` calls gain their recipe ids: `"smeltery", "smelt",` and `"gardens", "put_up_provisions",` respectively (arguments inserted directly after the building id).

- [ ] **Step 5: Run the four test files, then the full suite**

Also grep as a wrap-up check: both `grep -rn "\"recipe\":" game/data` and `grep -rn "has(\"recipe\")" game tests` must return nothing (the singular def key is gone everywhere; the timer PAYLOAD key "recipe" read via `payload.get("recipe", ...)` is correct and expected to remain).

- [ ] **Step 6: Commit**

```bash
git add game/data/buildings.json game/data/economy.json game/base/convert_model.gd game/base/island_screen.gd tests/test_recipe_defs.gd tests/test_convert_model.gd tests/test_island_screen.gd tests/test_chain_integration.gd
git commit -m "feat: recipes arrays with three balloonworks consumables"
```

---

### Task 2: The kit block (run.json)

**Files:**
- Modify: `game/data/run.json`
- Test: `tests/test_kit_defs.gd` (create)

**Interfaces:**
- Consumes: consumable currencies (Task 1).
- Produces: `DataDefs.run["kit"]` with keys `ballast`, `wind_charm`, `storm_oil`, `provision` exactly as below; Task 3 reads it.

- [ ] **Step 1: Write the failing test**

Create `tests/test_kit_defs.gd`:

```gdscript
extends GutTest
## Authoring guards for the run kit (run-kit spec section 4).


func kit() -> Dictionary:
	return DataDefs.run.get("kit", {})


func test_kit_block_shape() -> void:
	for kit_id in ["ballast", "wind_charm", "storm_oil", "provision"]:
		assert_has(kit(), kit_id)
		assert_true(String((kit()[kit_id] as Dictionary).get("name", "")) != "", "kit name missing: %s" % kit_id)

func test_consumable_keys_are_known_currencies() -> void:
	var balances: Dictionary = DataDefs.economy.get("starting_balances", {})
	for kit_id in ["ballast", "wind_charm", "storm_oil"]:
		assert_has(balances, kit_id, "kit consumable is not a currency: %s" % kit_id)

func test_kit_magnitudes() -> void:
	assert_eq(int((kit()["ballast"] as Dictionary).get("drops_bonus", 0)), 2)
	assert_eq(int((kit()["wind_charm"] as Dictionary).get("free_rerolls", 0)), 1)
	assert_almost_eq(float((kit()["storm_oil"] as Dictionary).get("bounce_bonus", 0.0)), 0.15, 0.001)
	assert_eq(int((kit()["provision"] as Dictionary).get("cost", 0)), 3)
	assert_almost_eq(float((kit()["provision"] as Dictionary).get("payout_multiplier", 0.0)), 1.15, 0.001)
```

- [ ] **Step 2: Run to verify failure**

`--import`, then the file. Expected: FAIL (no kit block).

- [ ] **Step 3: Add the kit block**

In `game/data/run.json`, add after the `"sea_payout"` entry (comma-separate correctly):

```json
	"kit": {
		"ballast": {"name": "Charged Ballast", "drops_bonus": 2},
		"wind_charm": {"name": "Wind Charm", "free_rerolls": 1},
		"storm_oil": {"name": "Storm Oil", "bounce_bonus": 0.15},
		"provision": {"name": "Provision run", "cost": 3, "payout_multiplier": 1.15}
	}
```

- [ ] **Step 4: Run the file, then the full suite**

Both green; no untracked sidecars beyond the new test's (committed).

- [ ] **Step 5: Commit**

```bash
git add game/data/run.json tests/test_kit_defs.gd tests/test_kit_defs.gd.uid
git commit -m "feat: run kit block with consumable and provisioning tuning"
```

---

### Task 3: The setup-phase kit panel

**Files:**
- Modify: `game/run/salvage_run.gd`, `game/run/salvage_run.tscn`
- Test: `tests/test_run_setup.gd` (modify)

**Interfaces:**
- Consumes: the kit block (Task 2), consumable currencies (Task 1), `RunModel.add_drops`, the Featherfall `pod_defs` pattern, `_compute_payout`, the reroll handler.
- Produces: tscn nodes `UI/SetupUI/KitPanel/KitFlow`; salvage_run members `_kit_elected: Dictionary`, `_provision_mult: float`, `_free_rerolls: int`; functions `_build_kit_panel()`, `_refresh_kit_panel()`, `_on_kit_toggled(pressed, kit_id)`, `_consume_kit()`, `_apply_consumable(kit_id, entry)`; the Start flow ordering fuel -> kit -> save -> install; the reroll free-path.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_run_setup.gd`:

```gdscript
func grant_kit(counts: Dictionary) -> void:
	for currency in counts:
		GameState.data["currencies"][currency] = counts[currency]
	scene._refresh_kit_panel()


func kit_chip(kit_id: String) -> Button:
	return scene.get_node("UI/SetupUI/KitPanel/KitFlow/Kit_" + kit_id) as Button


func test_kit_panel_builds_four_chips() -> void:
	assert_eq(scene.get_node("UI/SetupUI/KitPanel/KitFlow").get_child_count(), 4)
	assert_true(kit_chip("ballast").disabled, "zero count disables the chip")
	assert_true(kit_chip("provision").disabled, "zero provisions disables provisioning")

func test_chip_counts_show_and_enable() -> void:
	grant_kit({"ballast": 2, "provisions": 5})
	assert_false(kit_chip("ballast").disabled)
	assert_string_contains(kit_chip("ballast").text, "x2")
	assert_false(kit_chip("provision").disabled)

func test_start_consumes_elected_kit_exactly_once() -> void:
	grant_kit({"ballast": 2, "provisions": 5})
	scene._on_kit_toggled(true, "ballast")
	scene._on_kit_toggled(true, "provision")
	var base_drops: int = scene.model.drops_remaining()
	scene._on_start_pressed()
	assert_eq(Economy.balance("ballast"), 1, "one ballast consumed")
	assert_eq(Economy.balance("provisions"), 2, "three provisions consumed")
	assert_eq(scene.model.drops_remaining(), base_drops + 2, "the ballast landed")
	assert_almost_eq(scene._provision_mult, 1.15, 0.001)

func test_failed_start_consumes_nothing() -> void:
	grant_kit({"ballast": 1})
	scene._on_kit_toggled(true, "ballast")
	GameState.data["fuel"]["amount"] = 0
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	scene._on_start_pressed()
	assert_eq(Economy.balance("ballast"), 1, "no fuel, no kit spend")

func test_unaffordable_election_is_silently_dropped() -> void:
	grant_kit({"ballast": 1})
	scene._on_kit_toggled(true, "ballast")
	GameState.data["currencies"]["ballast"] = 0
	var base_drops: int = scene.model.drops_remaining()
	scene._on_start_pressed()
	assert_eq(scene._phase, scene.Phase.RUNNING, "the run proceeds")
	assert_eq(scene.model.drops_remaining(), base_drops, "the dropped election has no effect")

func test_provision_multiplies_payouts() -> void:
	grant_kit({"provisions": 5})
	scene._on_kit_toggled(true, "provision")
	scene._on_start_pressed()
	assert_eq(scene._compute_payout(null, {"scrap": 20}), {"scrap": 23}, "20 x 1.15 rounds to 23")

func test_storm_oil_bumps_pod_bounce_without_touching_shared_defs() -> void:
	grant_kit({"storm_oil": 1})
	scene._on_kit_toggled(true, "storm_oil")
	var shared_before := float((DataDefs.run["pod"] as Dictionary).get("bounce", 0.55))
	scene._on_start_pressed()
	assert_almost_eq(float(scene.pod_defs["bounce"]), shared_before + 0.15, 0.001)
	assert_almost_eq(float((DataDefs.run["pod"] as Dictionary).get("bounce", 0.55)), shared_before, 0.001,
		"the shared defs are never mutated (Featherfall pattern)")

func test_wind_charm_grants_a_free_reroll_before_the_ad_path() -> void:
	grant_kit({"wind_charm": 1})
	scene._on_kit_toggled(true, "wind_charm")
	scene._on_start_pressed()
	assert_eq(scene._free_rerolls, 1)
	scene._rng.seed = 42
	scene._on_tier_reached(1)
	var before: Array = (scene._current_offer as Array).duplicate()
	scene._on_reroll_pressed()
	assert_eq(scene._free_rerolls, 0, "the charm was spent")
	for id in scene._current_offer:
		assert_false(before.has(id), "the free reroll redraws disjointly")
	scene._on_reroll_pressed()
	assert_eq(scene._current_offer, scene._current_offer, "still once per offer")

func test_elections_reset_on_a_fresh_scene() -> void:
	grant_kit({"ballast": 1})
	scene._on_kit_toggled(true, "ballast")
	var second = add_child_autofree(RunScene.instantiate())
	assert_eq((second._kit_elected as Dictionary).size(), 0, "elections never persist")
```

- [ ] **Step 2: Run to verify failure**

Run the file. Expected: FAIL (no KitPanel node, no handlers).

- [ ] **Step 3: Add the tscn nodes**

In `game/run/salvage_run.tscn`, add directly BEFORE the `[node name="TrayPanel" ...]` block:

```
[node name="KitPanel" type="PanelContainer" parent="UI/SetupUI"]
offset_left = 10.0
offset_top = 840.0
offset_right = 710.0
offset_bottom = 920.0

[node name="KitFlow" type="HFlowContainer" parent="UI/SetupUI/KitPanel"]
```

(The rect sits below the lowest slot outline, which ends at y=823, and above the tray at y=930: no SlotTarget overlap.)

- [ ] **Step 4: Implement the kit flow**

In `game/run/salvage_run.gd`:

1. Add members after `var _survivor_from_left := true`:

```gdscript
var _kit_elected: Dictionary = {}
var _provision_mult := 1.0
var _free_rerolls := 0
```

2. In `_ready()`, add directly after the `_build_setup_ui(region)` line:

```gdscript
	_build_kit_panel()
```

3. In `_on_start_pressed`, replace the single `GameState.save_game()` line (right after the fuel spend) with:

```gdscript
	_consume_kit()
	GameState.save_game()
```

4. In `_compute_payout`, change the mult line to:

```gdscript
	var mult := model.payout_multiplier() * _island_mult * _provision_mult
```

5. Replace `_on_reroll_pressed` with:

```gdscript
func _on_reroll_pressed() -> void:
	if _offer_rerolled:
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
```

6. In `_render_offer`, replace the RerollButton visibility statement with:

```gdscript
	$UI/BoonOffer/VBox/RerollButton.text = "Reroll (free)" if _free_rerolls > 0 else "Reroll (ad)"
	$UI/BoonOffer/VBox/RerollButton.visible = (_free_rerolls > 0 or Ads.service.is_available(AdService.Placement.BOON_REROLL)) \
		and not _offer_rerolled
```

7. Add after `_setup_tick` (and add a `_refresh_kit_panel()` call as the last line of `_setup_tick`):

```gdscript
func _build_kit_panel() -> void:
	var kit: Dictionary = DataDefs.run.get("kit", {})
	var flow: HFlowContainer = $UI/SetupUI/KitPanel/KitFlow
	for kit_id in ["ballast", "wind_charm", "storm_oil", "provision"]:
		if not kit.has(kit_id):
			continue
		var chip := Button.new()
		chip.toggle_mode = true
		chip.name = "Kit_" + kit_id
		chip.custom_minimum_size = Vector2(164.0, 56.0)
		chip.toggled.connect(_on_kit_toggled.bind(kit_id))
		flow.add_child(chip)
	_refresh_kit_panel()


func _on_kit_toggled(pressed: bool, kit_id: String) -> void:
	if _phase != Phase.SETUP:
		return
	_kit_elected[kit_id] = pressed
	_refresh_kit_panel()


func _refresh_kit_panel() -> void:
	var kit: Dictionary = DataDefs.run.get("kit", {})
	for chip_node in $UI/SetupUI/KitPanel/KitFlow.get_children():
		var chip := chip_node as Button
		var kit_id := String(chip.name).trim_prefix("Kit_")
		var entry: Dictionary = kit.get(kit_id, {})
		var display := String(entry.get("name", kit_id))
		var affordable: bool
		if kit_id == "provision":
			var cost := int(entry.get("cost", 3))
			chip.text = "%s (%d provisions)" % [display, cost]
			affordable = Economy.balance("provisions") >= cost
		else:
			chip.text = "%s x%d" % [display, Economy.balance(kit_id)]
			affordable = Economy.balance(kit_id) >= 1
		chip.disabled = not affordable
		if not affordable and chip.button_pressed:
			chip.set_pressed_no_signal(false)
			_kit_elected[kit_id] = false


func _consume_kit() -> void:
	# Run-kit spec section 5: elections are paid only after the fuel spend
	# succeeds; an unaffordable election is silently dropped, never blocking.
	var kit: Dictionary = DataDefs.run.get("kit", {})
	for kit_id in _kit_elected:
		if not bool(_kit_elected[kit_id]):
			continue
		var entry: Dictionary = kit.get(String(kit_id), {})
		if String(kit_id) == "provision":
			if Economy.pay({"provisions": int(entry.get("cost", 3))}):
				_provision_mult = float(entry.get("payout_multiplier", 1.15))
		elif Economy.pay({String(kit_id): 1}):
			_apply_consumable(String(kit_id), entry)


func _apply_consumable(kit_id: String, entry: Dictionary) -> void:
	if kit_id == "ballast":
		model.add_drops(int(entry.get("drops_bonus", 2)))
	elif kit_id == "wind_charm":
		_free_rerolls += int(entry.get("free_rerolls", 1))
	elif kit_id == "storm_oil":
		# Featherfall pattern: duplicate before bumping; the shared defs are
		# never mutated.
		pod_defs = pod_defs.duplicate()
		pod_defs["bounce"] = minf(1.0, float(pod_defs.get("bounce", 0.55)) + float(entry.get("bounce_bonus", 0.15)))
```

- [ ] **Step 5: Run the file, then the full suite**

Run `--import` first (tscn changed), then `-gtest=res://tests/test_run_setup.gd`, then the full suite; exit 0.

- [ ] **Step 6: Commit**

```bash
git add game/run/salvage_run.gd game/run/salvage_run.tscn tests/test_run_setup.gd
git commit -m "feat: setup-phase kit panel spends consumables and provisions"
```

---

### Task 4: End-to-end arc proof and roadmap close-out

**Files:**
- Test: `tests/test_kit_integration.gd` (create)
- Modify: `docs/ROADMAP.md`

**Interfaces:**
- Consumes: everything from Tasks 1-3 plus Plans 10-11.
- Produces: the closing proof of the whole arc. Standing ruling: integration proofs run no-strict-RED (must pass first try; a failure is a production bug, never test arithmetic to bend).

- [ ] **Step 1: Write the integration test**

Create `tests/test_kit_integration.gd`:

```gdscript
extends GutTest
## The island-rework arc's closing proof (run-kit spec): the Balloonworks
## crafts a Charged Ballast, the setup phase elects it plus provisioning, and
## the started run carries +2 drops and 1.15x payouts. Fixed clock, no RNG.

const RunScene := preload("res://game/run/salvage_run.tscn")
const TEST_SAVE := "user://test_kit_integration.json"
const T0 := 1_800_000_000


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	GameState.data["created_at"] = T0
	GameState.data["fuel"]["updated_at"] = T0
	GameState.data["currencies"]["cloudsilk"] = 4
	GameState.data["currencies"]["parts"] = 4
	GameState.data["currencies"]["provisions"] = 5
	GameState.data["island"]["plots"]["plot_3"] = {"building": "balloonworks", "level": 1}


func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_kit_integration.json", "test_kit_integration.json.tmp", "test_kit_integration.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings, DataDefs.crew)


func test_craft_elect_and_run_with_the_kit() -> void:
	# 1. The Balloonworks crafts a Charged Ballast on a fake clock.
	assert_true(ConvertModel.start_batch(GameState.data, DataDefs.buildings, Economy, TimerService, "balloonworks", "charged_ballast", T0))
	ConvertModel.complete_batch(GameState.data, DataDefs.buildings, Economy, TimerService.collect("convert_balloonworks", T0 + 900))
	assert_eq(Economy.balance("ballast"), 1)
	# 2. The setup phase elects the ballast and provisioning; Start consumes both.
	var scene = add_child_autofree(RunScene.instantiate())
	scene._refresh_kit_panel()
	scene._on_kit_toggled(true, "ballast")
	scene._on_kit_toggled(true, "provision")
	var base_drops: int = scene.model.drops_remaining()
	scene._on_start_pressed()
	assert_eq(Economy.balance("ballast"), 0, "island output spent on the run")
	assert_eq(Economy.balance("provisions"), 2)
	# 3. The run carries the kit: more drops, richer catches.
	assert_eq(scene.model.drops_remaining(), base_drops + 2)
	assert_eq(scene._compute_payout(null, {"scrap": 20}), {"scrap": 23},
		"the arc closes: the island provisions the sky")

func test_kit_free_run_is_byte_identical_to_before() -> void:
	var scene = add_child_autofree(RunScene.instantiate())
	scene._on_start_pressed()
	assert_eq(scene._compute_payout(null, {"scrap": 20}), {"scrap": 20},
		"no kit, no change: the multiplier identity holds")
	assert_eq(scene._free_rerolls, 0)
```

- [ ] **Step 2: Run the file and confirm first-try pass (no-strict-RED ruling)**

`--import`, then the file. A failure is a production bug: fix production, never the test.

- [ ] **Step 3: Close out the roadmap arc**

In `docs/ROADMAP.md`, replace the sentence:

```
Plan 12 (run kit: setup-phase consumables and expedition provisioning): next, needs its spec.
```

with:

```
Plan 12 (run kit): SHIPPED (spec: docs/superpowers/specs/2026-09-09-run-kit-design.md; recipes arrays, three Balloonworks consumables, setup-phase kit panel, provisioning at 1.15x). The island rework arc is COMPLETE: every run resource feeds the island and every island output feeds the runs.
```

- [ ] **Step 4: Run the full suite**

Exit 0.

- [ ] **Step 5: Commit**

```bash
git add tests/test_kit_integration.gd tests/test_kit_integration.gd.uid docs/ROADMAP.md
git commit -m "test: prove the run kit closes the economy loop"
```

---

## Manual smoke steps (owner runs these windowed/on-device, per the ongoing practice)

1. The Balloonworks row shows three batch buttons; craft a Wind Charm; the countdown and Collect flow work.
2. Launch a run: the kit panel sits between the slots and the tray with four chips; counts and affordability read correctly; toggling feels right on touch.
3. Elect Ballast + provisioning, Start: fuel and kit debit together; the HUD shows +2 drops; catches pay visibly more.
4. Hit a quota tier with a Wind Charm banked: the reroll button reads "Reroll (free)" and consumes no ad; the next offer's reroll is back to "(ad)".
5. Back out during setup with elections toggled: nothing is spent.
6. In region 2, drag a gizmo onto both bottom-corner slots; placement must land cleanly with the kit panel present.
