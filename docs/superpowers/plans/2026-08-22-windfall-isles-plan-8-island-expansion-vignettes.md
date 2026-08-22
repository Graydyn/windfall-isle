# Windfall Isles Plan 8: Island Expansion and Story Vignettes

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two restorable islets (Lantern Shoal, Foundry Rock) that open new build plots holding two islet-exclusive buildings (Lens Array, Foundry Annex), each restoration delivering a skippable, re-readable found-letter vignette.

**Architecture:** A new data file `game/data/islets.json` plus a new pure static `IsletModel` own restoration rules (TimerService kind "restoration", one at a time, never consuming a build slot). Save schema bumps to v7 with an `islets` section. Two new building defs carry an `"islet"` field enforced by `IslandModel.build_rejection`; their effects plug into a new `IslandEffects.payout_multiplier` seam and a new `CraftModel.effective_cost` helper. The island screen grows islet rows and a letter panel.

**Tech Stack:** Godot 4.6.3 (GDScript), GUT 9.6.1, JSON data files.

**Spec:** docs/superpowers/specs/2026-08-22-island-expansion-vignettes-design.md

## Global Constraints

- Godot binary: `GODOT=/Applications/Godot-4.6.app/Contents/MacOS/Godot` (4.6.3; NEVER `/Applications/Godot.app`, which is 4.7 and breaks GUT 9.6.1).
- Full suite (must exit 0): `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- Single file: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit`
- After creating ANY new .gd, .json, or .tscn file, run `$GODOT --headless --import` and commit the generated `.gd.uid` sidecars and `.import` files. After the import, `git status --porcelain` must show no untracked `.gd.uid`; this applies to TEST files too (forgotten test sidecars have bitten twice).
- Indentation: tabs. No em dashes anywhere, including comments and player-facing strings; use commas, colons, or separate sentences.
- Raw JSON numbers stay raw: `JSON.parse_string` decodes every number as float; cast with `int()` / `float()` at use sites AND at test assert sites. Never normalize inside DataDefs (standing ruling from Plan 6). Dictionary `==` does not coerce, so tests comparing against JSON-sourced dicts must int-cast scalars.
- Pure models take injected clocks (`now: int`) and injected services (Economy/TimerService passed as `Node`); they never read autoloads, wall clocks, or RNG.
- GUT 9.6 auto-fails tests on pushed or engine errors; error-path tests must declare `assert_push_error_count` / `assert_engine_error_count` AFTER the trigger.
- GUT strict warnings reject `:=` inference from untyped Array/Dictionary chains; declare explicit types for anything read out of JSON-sourced containers (`var row := row_v as Dictionary`, `var label: Label = ...`).
- GUT stubbing: use `context_stub` if stubbing is ever needed (name collision with GUT internals); `assert_signal_emitted_with_parameters` takes no message argument.
- UI tests call handlers directly (`screen._on_x_pressed(...)`) and NEVER press scene-changing buttons.
- Screens follow the refresh discipline: per-tick `_refresh_tick` rebuilds the row tree only when the structural signature changes; otherwise labels update in place. Any new timed state MUST join the signature.
- Save mutations follow the write-back discipline: never mutate a dict obtained via `data.get(key, {})` when the key might be missing; write the section back to `data` first (see `NotificationSvc.request_permission_once`).
- Godot physics: never `add_child` a physics body inside a `body_entered` chain (build fully, then `add_child.call_deferred`); never bind a freeable object into a SceneTreeTimer callable with a typed parameter (scene-owned child Timers + `weakref`). Not expected to arise in this plan; listed because it is a standing rule.
- Do not state cumulative suite totals anywhere; report only the new tests a task adds.
- Commit after every task with a conventional-commit message; every commit must leave the full suite green.
- In the local variable and helper names of `island_screen.gd`, never introduce a local named `name` (it shadows `Node.name`); use `islet_name`.

---

### Task 1: islets.json data file and DataDefs loading

**Files:**
- Create: `game/data/islets.json`
- Modify: `game/autoload/data_defs.gd`
- Test: `tests/test_islet_defs.gd` (create)

**Interfaces:**
- Consumes: `DataDefs.load_json` (existing static).
- Produces: `DataDefs.islets: Dictionary` loaded at boot; `game/data/islets.json` with the exact shape below. Later tasks read `DataDefs.islets` and pass it into pure models.

- [ ] **Step 1: Write the failing test**

Create `tests/test_islet_defs.gd`:

```gdscript
extends GutTest

const DataDefsScript := preload("res://game/autoload/data_defs.gd")


func islet_defs() -> Dictionary:
	return DataDefsScript.load_json("res://game/data/islets.json")


func test_islets_load_in_order_with_required_keys() -> void:
	var defs := islet_defs()
	var rows: Array = defs.get("islets", [])
	assert_eq(rows.size(), 2, "this plan ships Lantern Shoal and Foundry Rock")
	assert_eq(String((rows[0] as Dictionary)["id"]), "lantern_shoal", "array order gates offering")
	assert_eq(String((rows[1] as Dictionary)["id"]), "foundry_rock")
	for row_v in rows:
		var row := row_v as Dictionary
		assert_true(String(row.get("name", "")) != "", "islet needs a display name: %s" % row.get("id"))
		assert_true((row.get("cost", {}) as Dictionary).size() > 0, "islet needs a cost: %s" % row.get("id"))
		assert_true(int(row.get("restore_seconds", 0)) > 0, "islet needs a duration: %s" % row.get("id"))
		assert_true((row.get("plots", []) as Array).size() > 0, "islet needs plots: %s" % row.get("id"))
		var vignette: Dictionary = row.get("vignette", {})
		assert_true(String(vignette.get("title", "")) != "", "vignette needs a title: %s" % row.get("id"))
		assert_true((vignette.get("lines", []) as Array).size() > 0, "vignette needs lines: %s" % row.get("id"))

func test_foundry_rock_is_the_brasswork_sink() -> void:
	var rows: Array = islet_defs().get("islets", [])
	var foundry := rows[1] as Dictionary
	assert_true(int((foundry["cost"] as Dictionary).get("brasswork", 0)) > 0,
		"spec: the late islet gates on Region 2 currency")

func test_islet_plot_ids_avoid_the_home_namespace() -> void:
	for row_v in islet_defs().get("islets", []):
		var row := row_v as Dictionary
		for plot in row.get("plots", []):
			assert_false(String(plot).begins_with("plot_"),
				"islet plots must never collide with home plots: %s" % String(plot))

func test_islet_ids_are_unique() -> void:
	var seen := {}
	for row_v in islet_defs().get("islets", []):
		var id := String((row_v as Dictionary).get("id", ""))
		assert_false(seen.has(id), "duplicate islet id: %s" % id)
		seen[id] = true

func test_autoload_exposes_islets() -> void:
	assert_true((DataDefs.islets.get("islets", []) as Array).size() > 0,
		"DataDefs must load islets.json at boot")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `$GODOT --headless --import` then `$GODOT --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_islet_defs.gd -gexit`
Expected: FAIL (missing file push_error makes GUT fail the first test; `DataDefs.islets` does not exist so the script may fail to parse; both count as the RED state).

- [ ] **Step 3: Create the data file and the loader**

Create `game/data/islets.json` exactly (vignette text is final copy from the spec, do not paraphrase):

```json
{
	"islets": [
		{
			"id": "lantern_shoal",
			"name": "Lantern Shoal",
			"cost": {"scrap": 600, "cloudsilk": 4},
			"restore_seconds": 14400,
			"plots": ["islet_lantern_0"],
			"vignette": {
				"title": "A letter, wax-sealed against the wind",
				"lines": [
					"To whoever relights the shoal: the lanterns were never for us. We hung them so the salvage barges could find their way home through the cloud-wrack, and they did, every one, until the winds changed.",
					"If you have mended the bridge, then the winds have changed again. Hang the lights. Somebody out there is squinting for them.",
					"P.S. The lens grinder left her tools in the south workshop. She said whoever came next would need them more than she did."
				]
			}
		},
		{
			"id": "foundry_rock",
			"name": "Foundry Rock",
			"cost": {"scrap": 1500, "brasswork": 12},
			"restore_seconds": 28800,
			"plots": ["islet_foundry_0"],
			"vignette": {
				"title": "A foreman's log, brass-bound",
				"lines": [
					"Day 412. The Reach sends us more brasswork than we can smelt and the crews sing while they pour. I have stopped correcting the ones who call this rock home.",
					"Day 415. Orders came to strip the annex and fall back to the mainline isles. I signed the order because a foreman signs. I did not stay to watch the fires go out.",
					"Day 416, unsent. If the furnaces ever wake, know that we banked the coals on purpose. It is easier to rekindle a fire than to forgive yourself for drowning one."
				]
			}
		}
	]
}
```

Modify `game/autoload/data_defs.gd`: add after `const BOONS_PATH := "res://game/data/boons.json"`:

```gdscript
const ISLETS_PATH := "res://game/data/islets.json"
```

Add after `var boons: Dictionary = {}`:

```gdscript
var islets: Dictionary = {}
```

Add at the end of `_ready()` after `boons = load_json(BOONS_PATH)`:

```gdscript
	islets = load_json(ISLETS_PATH)
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `$GODOT --headless --import` then `$GODOT --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_islet_defs.gd -gexit`
Expected: PASS. Then `git status --porcelain` must show no untracked `.gd.uid`.

- [ ] **Step 5: Run the full suite and commit**

Run the full suite; expect exit 0.

```bash
git add game/data/islets.json game/autoload/data_defs.gd tests/test_islet_defs.gd tests/test_islet_defs.gd.uid
git commit -m "feat: islets.json data file with two islets and vignettes"
```

---

### Task 2: Save schema v7 with the islets section

**Files:**
- Modify: `game/core/save_schema.gd`
- Test: `tests/test_save_schema.gd` (modify)

**Interfaces:**
- Consumes: existing `SaveSchema.migrate` / `default_data` / `_backfill_missing_keys` structure.
- Produces: `SaveSchema.CURRENT_VERSION == 7`; `data["islets"] == {"restored": {}, "letters_seen": {}}` on fresh saves, v6 migrations, and backfill. Later tasks read `data["islets"]`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_save_schema.gd`, append at the end of the file:

```gdscript
func test_migrate_6_to_7_adds_islets_losslessly() -> void:
	var v6 := SaveSchema.default_data(DEFS, GIZMO_DEFS)
	v6["version"] = 6
	v6.erase("islets")
	v6["currencies"]["scrap"] = 777
	var out := SaveSchema.migrate(v6, GIZMO_DEFS)
	assert_eq(int(out["version"]), 7)
	assert_eq(out["islets"], {"restored": {}, "letters_seen": {}})
	assert_eq(int(out["currencies"]["scrap"]), 777, "balances untouched")

func test_default_data_has_islets_section() -> void:
	assert_eq(SaveSchema.default_data(DEFS)["islets"], {"restored": {}, "letters_seen": {}})
```

Update the existing version-pinned assertions to v7. Apply these exact edits:

1. In `test_current_version_is_six_and_defaults_grant_eight`, rename the function to `test_current_version_is_seven_and_defaults_grant_eight` and change `assert_eq(SaveSchema.CURRENT_VERSION, 6)` to `assert_eq(SaveSchema.CURRENT_VERSION, 7)`.
2. In `test_migrate_v3_to_v4_adds_island_losslessly`, change `assert_eq(int(migrated["version"]), 6)` to `assert_eq(int(migrated["version"]), 7)`.
3. In `test_migrate_v1_hops_all_the_way_to_v4`, change `assert_eq(int(migrated["version"]), 6)` to `assert_eq(int(migrated["version"]), 7)`.
4. In `test_migrate_5_to_6_adds_expedition_losslessly`, change `assert_eq(int(out["version"]), 6)` to `assert_eq(int(out["version"]), 7)`.
5. In `test_backfill_heals_missing_keys_on_current_version`, change `var damaged := {"version": 6, "currencies": {"scrap": 7}}` to `var damaged := {"version": 7, "currencies": {"scrap": 7}}` and change the key list line to:

```gdscript
	for key in ["fuel", "timers", "island", "trickle", "daily_crate", "gizmos", "ads", "notifications", "expedition", "islets"]:
```

- [ ] **Step 2: Run the tests to verify the new ones fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_schema.gd -gexit`
Expected: FAIL (`CURRENT_VERSION` is 6, no `islets` key, migrate of version 7 returns `{}`).

- [ ] **Step 3: Implement schema v7**

In `game/core/save_schema.gd`:

1. Change `const CURRENT_VERSION := 6` to `const CURRENT_VERSION := 7`.
2. In `default_data`, add after the `"expedition": _fresh_expedition(),` line:

```gdscript
		"islets": _fresh_islets(),
```

3. In `migrate`, add after the `if int(data["version"]) == 5:` block:

```gdscript
	if int(data["version"]) == 6:
		data = _migrate_6_to_7(data)
```

4. Add after `_fresh_expedition`:

```gdscript
static func _migrate_6_to_7(data: Dictionary) -> Dictionary:
	# Island expansion arrives: restored islets and read letters (spec 4.4).
	data["islets"] = _fresh_islets()
	data["version"] = 7
	return data


static func _fresh_islets() -> Dictionary:
	return {"restored": {}, "letters_seen": {}}
```

- [ ] **Step 4: Run the schema tests, then the full suite**

Run the single file; expected PASS. Run the full suite; expect exit 0 (the migration chain tests and `test_smoke`/`test_game_state` run against the new version).

- [ ] **Step 5: Commit**

```bash
git add game/core/save_schema.gd tests/test_save_schema.gd
git commit -m "feat: save schema v7 adds the islets section"
```

---

### Task 3: IsletModel, the pure restoration rules

**Files:**
- Create: `game/base/islet_model.gd`
- Test: `tests/test_islet_model.gd` (create)

**Interfaces:**
- Consumes: `data["islets"]` from Task 2; `DataDefs.islets` shape from Task 1; Economy node API (`can_afford(cost)`, `pay(cost)`); TimerService node API (`start(id, kind, duration_sec, now, payload)`, `active_timers()`, `collect(id, now)`).
- Produces (later tasks call these exact signatures):
  - `IsletModel.islets(defs: Dictionary) -> Array`
  - `IsletModel.entry(defs: Dictionary, islet_id: String) -> Dictionary`
  - `IsletModel.is_restored(data: Dictionary, islet_id: String) -> bool`
  - `IsletModel.open_plots(data: Dictionary, defs: Dictionary) -> Array[String]`
  - `IsletModel.islet_of_plot(defs: Dictionary, plot: String) -> String`
  - `IsletModel.active_restoration(timers: Node) -> String`
  - `IsletModel.next_offered(data: Dictionary, defs: Dictionary) -> String`
  - `IsletModel.restore_rejection(data: Dictionary, defs: Dictionary, economy: Node, timers: Node, islet_id: String) -> String`
  - `IsletModel.start_restore(data: Dictionary, defs: Dictionary, economy: Node, timers: Node, islet_id: String, now: int) -> bool`
  - `IsletModel.complete_restore(data: Dictionary, payload: Dictionary) -> void`
  - `IsletModel.duplicate_plot_ids(defs: Dictionary) -> Array`
  - Timer ids are `"restore_" + islet_id`, kind `"restoration"`, payload `{"islet": islet_id}`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_islet_model.gd`:

```gdscript
extends GutTest

const TimerServiceScript := preload("res://game/autoload/timer_service.gd")
const EconomyScript := preload("res://game/autoload/economy.gd")
const GameStateScript := preload("res://game/autoload/game_state.gd")

var state: Node
var econ: Node
var timers: Node
var defs: Dictionary


func before_each() -> void:
	defs = DataDefs.islets
	state = autofree(GameStateScript.new())
	state.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	state.data["currencies"]["scrap"] = 5000
	state.data["currencies"]["cloudsilk"] = 20
	state.data["currencies"]["brasswork"] = 30
	econ = autofree(EconomyScript.new())
	econ.setup(state)
	timers = autofree(TimerServiceScript.new())
	timers.setup(state)


func test_fresh_save_offers_the_first_islet_only() -> void:
	assert_eq(IsletModel.next_offered(state.data, defs), "lantern_shoal")
	assert_ne(IsletModel.restore_rejection(state.data, defs, econ, timers, "foundry_rock"), "",
		"islets restore in array order")

func test_start_restore_pays_and_starts_its_own_timer_lane() -> void:
	assert_true(IsletModel.start_restore(state.data, defs, econ, timers, "lantern_shoal", 1000))
	assert_eq(econ.balance("scrap"), 5000 - 600)
	assert_eq(econ.balance("cloudsilk"), 20 - 4)
	assert_eq(timers.remaining("restore_lantern_shoal", 1000), 14400)
	assert_eq(String((timers.active_timers()["restore_lantern_shoal"] as Dictionary)["kind"]), "restoration",
		"spec: restoration never rides the construction lane")

func test_restoration_does_not_consume_a_build_slot() -> void:
	IsletModel.start_restore(state.data, defs, econ, timers, "lantern_shoal", 1000)
	assert_eq(IslandModel.active_constructions(timers, 1000), 0,
		"a running restoration must leave the free build slot open")
	assert_true(IslandModel.can_start_build(state.data["island"], DataDefs.buildings, econ, timers, "plot_0", "workshop", 1000))

func test_one_restoration_at_a_time() -> void:
	IsletModel.start_restore(state.data, defs, econ, timers, "lantern_shoal", 1000)
	assert_string_contains(
		IsletModel.restore_rejection(state.data, defs, econ, timers, "lantern_shoal"),
		"already underway")

func test_rejection_names_the_cost_shortfall() -> void:
	state.data["currencies"]["scrap"] = 0
	assert_string_contains(
		IsletModel.restore_rejection(state.data, defs, econ, timers, "lantern_shoal"),
		"Not enough")

func test_complete_restore_marks_restored_and_opens_plots() -> void:
	IsletModel.start_restore(state.data, defs, econ, timers, "lantern_shoal", 1000)
	var payload: Dictionary = timers.collect("restore_lantern_shoal", 1000 + 14400)
	IsletModel.complete_restore(state.data, payload)
	assert_true(IsletModel.is_restored(state.data, "lantern_shoal"))
	assert_eq(IsletModel.open_plots(state.data, defs), ["islet_lantern_0"] as Array[String])
	assert_eq(IsletModel.next_offered(state.data, defs), "foundry_rock",
		"restoring the first islet offers the second")

func test_complete_restore_is_idempotent_and_ignores_junk() -> void:
	IsletModel.complete_restore(state.data, {})
	IsletModel.complete_restore(state.data, {"islet": "no_such_islet"})
	IsletModel.complete_restore(state.data, {"islet": "lantern_shoal"})
	IsletModel.complete_restore(state.data, {"islet": "lantern_shoal"})
	assert_true(IsletModel.is_restored(state.data, "lantern_shoal"))
	assert_eq(((state.data["islets"] as Dictionary)["restored"] as Dictionary).size(), 2,
		"junk ids do not crash; unknown ids are recorded harmlessly or skipped")

func test_complete_restore_heals_a_wrong_typed_section() -> void:
	state.data["islets"] = 7
	IsletModel.complete_restore(state.data, {"islet": "lantern_shoal"})
	assert_true(IsletModel.is_restored(state.data, "lantern_shoal"),
		"write-back discipline: a mangled islets section is rebuilt, never mutated detached")

func test_already_restored_is_rejected() -> void:
	IsletModel.complete_restore(state.data, {"islet": "lantern_shoal"})
	assert_string_contains(
		IsletModel.restore_rejection(state.data, defs, econ, timers, "lantern_shoal"),
		"already restored")

func test_unknown_islet_is_rejected() -> void:
	assert_ne(IsletModel.restore_rejection(state.data, defs, econ, timers, "atlantis"), "")

func test_islet_of_plot_maps_both_ways() -> void:
	assert_eq(IsletModel.islet_of_plot(defs, "islet_lantern_0"), "lantern_shoal")
	assert_eq(IsletModel.islet_of_plot(defs, "plot_0"), "")

func test_shipped_data_has_no_duplicate_plot_ids() -> void:
	assert_eq(IsletModel.duplicate_plot_ids(DataDefs.islets), [],
		"authoring guard, mirrors the barge-id uniqueness check")
```

Note the `test_complete_restore_is_idempotent_and_ignores_junk` expectation: `complete_restore` accepts any non-empty islet id (the model does not validate against defs, matching `IslandModel.complete_build`'s permissiveness); the size assertion of 2 counts `lantern_shoal` plus `no_such_islet`. Implement to match.

- [ ] **Step 2: Run to verify failure**

Run: `$GODOT --headless --import` then the single file.
Expected: FAIL with parse errors on `IsletModel` (class does not exist).

- [ ] **Step 3: Implement IsletModel**

Create `game/base/islet_model.gd`:

```gdscript
class_name IsletModel
## Pure restoration rules over save.islets (spec 4.4): islets restore in
## islets.json array order, one restoration at a time, riding TimerService
## kind "restoration" with id "restore_<islet_id>" so a bridge repair never
## consumes a build slot. Vignette text stays in the defs; the save stores
## only flags.


static func islets(defs: Dictionary) -> Array:
	return defs.get("islets", [])


static func entry(defs: Dictionary, islet_id: String) -> Dictionary:
	for row_v in islets(defs):
		var row := row_v as Dictionary
		if String(row.get("id", "")) == islet_id:
			return row
	return {}


static func is_restored(data: Dictionary, islet_id: String) -> bool:
	var section: Dictionary = data.get("islets", {}) if data.get("islets", {}) is Dictionary else {}
	return bool((section.get("restored", {}) as Dictionary).get(islet_id, false))


static func open_plots(data: Dictionary, defs: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for row_v in islets(defs):
		var row := row_v as Dictionary
		if is_restored(data, String(row.get("id", ""))):
			for plot in row.get("plots", []):
				out.append(String(plot))
	return out


static func islet_of_plot(defs: Dictionary, plot: String) -> String:
	for row_v in islets(defs):
		var row := row_v as Dictionary
		for candidate in row.get("plots", []):
			if String(candidate) == plot:
				return String(row.get("id", ""))
	return ""


static func active_restoration(timers: Node) -> String:
	for id in timers.active_timers():
		if String((timers.active_timers()[id] as Dictionary).get("kind", "")) == "restoration":
			return String(id)
	return ""


static func next_offered(data: Dictionary, defs: Dictionary) -> String:
	for row_v in islets(defs):
		var row := row_v as Dictionary
		var id := String(row.get("id", ""))
		if not is_restored(data, id):
			return id
	return ""


static func restore_rejection(data: Dictionary, defs: Dictionary, economy: Node, timers: Node, islet_id: String) -> String:
	# "" means startable; anything else is a short player-facing reason.
	var def := entry(defs, islet_id)
	if def.is_empty():
		return "There is no such islet."
	if is_restored(data, islet_id):
		return "%s is already restored." % String(def.get("name", islet_id))
	if islet_id != next_offered(data, defs):
		return "Another islet must be restored first."
	if active_restoration(timers) != "":
		return "A restoration is already underway."
	if not economy.can_afford(def.get("cost", {})):
		return "Not enough resources."
	return ""


static func start_restore(data: Dictionary, defs: Dictionary, economy: Node, timers: Node, islet_id: String, now: int) -> bool:
	if restore_rejection(data, defs, economy, timers, islet_id) != "":
		return false
	var def := entry(defs, islet_id)
	if not economy.pay(def.get("cost", {})):
		return false
	return timers.start("restore_" + islet_id, "restoration", int(def.get("restore_seconds", 3600)), now,
		{"islet": islet_id})


static func complete_restore(data: Dictionary, payload: Dictionary) -> void:
	var islet_id := String(payload.get("islet", ""))
	if islet_id == "":
		return
	# Write-back discipline: heal a missing or wrong-typed section in place so
	# the flag can never land in a detached dict.
	if not data.has("islets") or not (data["islets"] is Dictionary):
		data["islets"] = {"restored": {}, "letters_seen": {}}
	var section: Dictionary = data["islets"]
	if not section.has("restored") or not (section["restored"] is Dictionary):
		section["restored"] = {}
	(section["restored"] as Dictionary)[islet_id] = true


static func duplicate_plot_ids(defs: Dictionary) -> Array:
	# Authoring guard for islet 3+ (mirrors Skyfield.duplicate_barge_ids).
	var seen := {}
	var dupes := {}
	for row_v in islets(defs):
		var row := row_v as Dictionary
		for plot in row.get("plots", []):
			if seen.has(String(plot)):
				dupes[String(plot)] = true
			seen[String(plot)] = true
	return dupes.keys()
```

- [ ] **Step 4: Run the file, then the full suite**

Both must pass. `git status --porcelain` must show no untracked `.gd.uid`.

- [ ] **Step 5: Commit**

```bash
git add game/base/islet_model.gd game/base/islet_model.gd.uid tests/test_islet_model.gd tests/test_islet_model.gd.uid
git commit -m "feat: IsletModel pure restoration rules"
```

---

### Task 4: New building defs and islet placement rules in IslandModel

**Files:**
- Modify: `game/data/buildings.json`
- Modify: `game/base/island_model.gd`
- Test: `tests/test_island_model.gd` (modify), `tests/test_building_defs.gd` (modify)

**Interfaces:**
- Consumes: `IsletModel.islet_of_plot` and `IsletModel.entry` from Task 3.
- Produces:
  - `buildings.json` defs `lens_array` (with `payout_bonus_per_level`) and `foundry_annex` (with `craft_discount_per_level`), each with an `"islet"` field.
  - `IslandModel.build_rejection(island, defs, economy, timers, plot, building_id, now, islet_defs: Dictionary = {}, islets_state: Dictionary = {}) -> String` and the same two trailing optional params on `can_start_build` and `start_build`. With the defaults, behavior for home buildings on home plots is unchanged.

- [ ] **Step 1: Write the failing tests**

In `tests/test_building_defs.gd`, replace the whole `test_buildings_load_with_six_defs` function with:

```gdscript
func test_buildings_load_with_eight_defs() -> void:
	assert_eq((DataDefs.buildings["defs"] as Dictionary).size(), 8,
		"six home buildings plus the two islet buildings")
	for id in ["workshop", "wind_still", "dock", "balloonworks", "observatory", "gardens", "lens_array", "foundry_annex"]:
		assert_has(DataDefs.buildings["defs"], id)
	for id in DataDefs.buildings["defs"]:
		var def: Dictionary = DataDefs.buildings["defs"][id]
		assert_eq((def["levels"] as Array).size(), int(def["max_level"]),
			"every level needs a cost/time row: %s" % id)

func test_islet_buildings_declare_their_islet() -> void:
	assert_eq(String((DataDefs.buildings["defs"]["lens_array"] as Dictionary)["islet"]), "lantern_shoal")
	assert_eq(String((DataDefs.buildings["defs"]["foundry_annex"] as Dictionary)["islet"]), "foundry_rock")
	for id in ["workshop", "wind_still", "dock", "balloonworks", "observatory", "gardens"]:
		assert_false((DataDefs.buildings["defs"][id] as Dictionary).has("islet"),
			"home buildings carry no islet field: %s" % id)
```

In `tests/test_island_model.gd`, append at the end of the file:

```gdscript
func restored_islets() -> Dictionary:
	return {"restored": {"lantern_shoal": true, "foundry_rock": true}, "letters_seen": {}}


func test_islet_building_rejected_on_a_home_plot() -> void:
	state.data["currencies"]["cloudsilk"] = 50
	assert_string_contains(
		IslandModel.build_rejection(island, defs, econ, timers, "plot_0", "lens_array", 1000, DataDefs.islets, restored_islets()),
		"belongs on Lantern Shoal")

func test_home_building_rejected_on_an_islet_plot() -> void:
	assert_string_contains(
		IslandModel.build_rejection(island, defs, econ, timers, "islet_lantern_0", "workshop", 1000, DataDefs.islets, restored_islets()),
		"awaits its own building")

func test_islet_building_rejected_while_unrestored() -> void:
	state.data["currencies"]["cloudsilk"] = 50
	assert_string_contains(
		IslandModel.build_rejection(island, defs, econ, timers, "islet_lantern_0", "lens_array", 1000, DataDefs.islets, {"restored": {}, "letters_seen": {}}),
		"Restore the bridge")

func test_islet_building_builds_on_its_restored_plot() -> void:
	state.data["currencies"]["cloudsilk"] = 50
	assert_eq(
		IslandModel.build_rejection(island, defs, econ, timers, "islet_lantern_0", "lens_array", 1000, DataDefs.islets, restored_islets()),
		"")
	assert_true(IslandModel.start_build(island, defs, econ, timers, "islet_lantern_0", "lens_array", 1000, DataDefs.islets, restored_islets()))
	var payload: Dictionary = timers.collect("build_islet_lantern_0", 1000 + 1800)
	IslandModel.complete_build(island, payload, state.data, 2800)
	assert_eq(IslandModel.building_level(island, "lens_array"), 1)

func test_islet_building_rejected_everywhere_without_islet_context() -> void:
	state.data["currencies"]["cloudsilk"] = 50
	assert_ne(IslandModel.build_rejection(island, defs, econ, timers, "plot_0", "lens_array", 1000), "",
		"the default empty islet context can never place an islet building")
```

- [ ] **Step 2: Run to verify failure**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_building_defs.gd -gexit` and the island model file.
Expected: FAIL (defs count is 6; `build_rejection` takes 7 arguments).

- [ ] **Step 3: Implement**

In `game/data/buildings.json`, add inside `"defs"` after the `"gardens"` entry (add a comma after the gardens closing brace):

```json
		"lens_array": {
			"name": "Lens Array",
			"islet": "lantern_shoal",
			"max_level": 2,
			"payout_bonus_per_level": 0.05,
			"levels": [
				{"cost": {"scrap": 400, "cloudsilk": 3}, "build_seconds": 1800},
				{"cost": {"scrap": 1200, "cloudsilk": 8, "crystals": 3}, "build_seconds": 5400}
			]
		},
		"foundry_annex": {
			"name": "Foundry Annex",
			"islet": "foundry_rock",
			"max_level": 2,
			"craft_discount_per_level": 0.1,
			"levels": [
				{"cost": {"scrap": 900, "brasswork": 6}, "build_seconds": 3600},
				{"cost": {"scrap": 2000, "brasswork": 14}, "build_seconds": 7200}
			]
		}
```

In `game/base/island_model.gd`, replace the `build_rejection`, `can_start_build`, and `start_build` functions with:

```gdscript
static func placement_rejection(defs: Dictionary, islet_defs: Dictionary, islets_state: Dictionary, plot: String, building_id: String) -> String:
	# Islet buildings live only on their islet's restored plots; home buildings
	# never leave the home island (spec 4.4). "" means placement is fine.
	var def: Dictionary = (defs.get("defs", {}) as Dictionary).get(building_id, {})
	var home_islet := String(def.get("islet", ""))
	var plot_islet := IsletModel.islet_of_plot(islet_defs, plot)
	if home_islet == "" and plot_islet == "":
		return ""
	if home_islet == "":
		return "This plot awaits its own building."
	if plot_islet != home_islet:
		var islet_name := String(IsletModel.entry(islet_defs, home_islet).get("name", home_islet))
		return "%s belongs on %s." % [String(def.get("name", building_id)), islet_name]
	if not bool((islets_state.get("restored", {}) as Dictionary).get(home_islet, false)):
		return "Restore the bridge first."
	return ""


static func build_rejection(island: Dictionary, defs: Dictionary, economy: Node, timers: Node, plot: String, building_id: String, now: int, islet_defs: Dictionary = {}, islets_state: Dictionary = {}) -> String:
	# "" means buildable; anything else is a short player-facing reason
	# (Plan 5 polish: a rejected Build tap must say why).
	if timers.active_timers().has("build_" + plot):
		return "This plot is already under construction."
	if active_constructions(timers, now) >= int(island.get("build_slots", 1)):
		return "All build slots are busy."
	var placement := placement_rejection(defs, islet_defs, islets_state, plot, building_id)
	if placement != "":
		return placement
	var row := _next_level_row(defs, island, plot, building_id)
	if row.is_empty():
		return "%s cannot be built here." % building_id
	if not economy.can_afford(row.get("cost", {})):
		return "Not enough resources."
	return ""


static func can_start_build(island: Dictionary, defs: Dictionary, economy: Node, timers: Node, plot: String, building_id: String, now: int, islet_defs: Dictionary = {}, islets_state: Dictionary = {}) -> bool:
	return build_rejection(island, defs, economy, timers, plot, building_id, now, islet_defs, islets_state) == ""


static func start_build(island: Dictionary, defs: Dictionary, economy: Node, timers: Node, plot: String, building_id: String, now: int, islet_defs: Dictionary = {}, islets_state: Dictionary = {}) -> bool:
	if not can_start_build(island, defs, economy, timers, plot, building_id, now, islet_defs, islets_state):
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
```

Everything else in the file is unchanged.

- [ ] **Step 4: Run both test files, then the full suite**

Expected: PASS, suite exit 0. Watch for `test_island_screen.test_select_cycles_unbuilt_buildings`: it still passes because `_unbuilt_ids` (not yet plot-aware) offers `lens_array`/`foundry_annex` only after the six home defs alphabetically later in dict order, and the test only advances twice. If it fails on ordering, report it; do not silently reorder defs.

- [ ] **Step 5: Commit**

```bash
git add game/data/buildings.json game/base/island_model.gd tests/test_island_model.gd tests/test_building_defs.gd
git commit -m "feat: islet-exclusive building defs and placement rules"
```

---

### Task 5: Lens Array payout multiplier

**Files:**
- Modify: `game/base/island_effects.gd`
- Modify: `game/run/salvage_run.gd`
- Test: `tests/test_island_effects.gd` (modify), `tests/test_salvage_run.gd` (modify)

**Interfaces:**
- Consumes: `IslandModel.building_level`; `lens_array` def with `payout_bonus_per_level` from Task 4.
- Produces: `IslandEffects.payout_multiplier(island: Dictionary, building_defs: Dictionary) -> float` (exactly 1.0 at level 0 or with empty defs). `salvage_run` member `_island_mult` folded into `_compute_payout`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_island_effects.gd`:

```gdscript
func test_payout_multiplier_is_identity_without_a_lens_array() -> void:
	assert_eq(IslandEffects.payout_multiplier({"plots": {}, "build_slots": 1}, DataDefs.buildings), 1.0)
	assert_eq(IslandEffects.payout_multiplier({"plots": {}, "build_slots": 1}, {}), 1.0,
		"empty defs must never scale payouts")

func test_payout_multiplier_scales_with_lens_array_level() -> void:
	var island := {"plots": {"islet_lantern_0": {"building": "lens_array", "level": 2}}, "build_slots": 1}
	assert_almost_eq(IslandEffects.payout_multiplier(island, DataDefs.buildings), 1.1, 0.0001,
		"base 1.0 + 2 levels x 0.05")
```

Append to `tests/test_salvage_run.gd`:

```gdscript
func test_lens_array_multiplies_every_catch_payout() -> void:
	GameState.data["island"]["plots"]["islet_lantern_0"] = {"building": "lens_array", "level": 1}
	var boosted = add_child_autofree(RunScene.instantiate())
	assert_eq(boosted._compute_payout(null, {"scrap": 20}), {"scrap": 21},
		"20 scrap x 1.05 lens bonus rounds to 21")
	assert_eq(scene._compute_payout(null, {"scrap": 20}), {"scrap": 20},
		"the before_each scene was built without a lens array and stays neutral")
```

- [ ] **Step 2: Run to verify failure**

Run both single files. Expected: FAIL (`payout_multiplier` does not exist; `_compute_payout` returns `{"scrap": 20}` for the boosted scene).

- [ ] **Step 3: Implement**

Append to `game/base/island_effects.gd`:

```gdscript
static func payout_multiplier(island: Dictionary, building_defs: Dictionary) -> float:
	var def: Dictionary = (building_defs.get("defs", {}) as Dictionary).get("lens_array", {})
	var level := IslandModel.building_level(island, "lens_array")
	return 1.0 + float(level) * float(def.get("payout_bonus_per_level", 0.0))
```

In `game/run/salvage_run.gd`:

1. Add after `var _pending_offers := 0`:

```gdscript
var _island_mult := 1.0
```

2. In `_ready()`, add directly after the `model = RunModel.new(run_config)` line:

```gdscript
	# Island state cannot change mid-run; read the Lens Array bonus once.
	_island_mult = IslandEffects.payout_multiplier(GameState.data["island"], DataDefs.buildings)
```

3. In `_compute_payout`, change the line `var mult := model.payout_multiplier()` to:

```gdscript
	var mult := model.payout_multiplier() * _island_mult
```

- [ ] **Step 4: Run both files, then the full suite**

Expected: PASS, suite exit 0 (the `is_equal_approx(mult, 1.0)` early return in `_compute_payout` keeps all existing payout tests byte-identical because `_island_mult` is 1.0 without a Lens Array).

- [ ] **Step 5: Commit**

```bash
git add game/base/island_effects.gd game/run/salvage_run.gd tests/test_island_effects.gd tests/test_salvage_run.gd
git commit -m "feat: lens array run payout multiplier"
```

---

### Task 6: Foundry Annex craft discount

**Files:**
- Modify: `game/base/craft_model.gd`
- Modify: `game/base/workshop_screen.gd`
- Test: `tests/test_craft_model.gd` (modify), `tests/test_workshop_screen.gd` (modify)

**Interfaces:**
- Consumes: `IslandModel.building_level`; `foundry_annex` def with `craft_discount_per_level` from Task 4.
- Produces: `CraftModel.effective_cost(def: Dictionary, island: Dictionary, building_defs: Dictionary) -> Dictionary`; `can_craft` and `start_craft` gain a trailing `building_defs: Dictionary = {}` parameter and both price through `effective_cost` (check and pay must agree). Workshop rows show the cost via a new `_cost_text` helper.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_craft_model.gd`:

```gdscript
func with_annex(level: int) -> void:
	state.data["island"]["plots"]["islet_foundry_0"] = {"building": "foundry_annex", "level": level}


func test_effective_cost_is_the_raw_cost_without_an_annex() -> void:
	var def: Dictionary = DataDefs.gizmos["defs"]["wind_fan"]
	assert_eq(int(CraftModel.effective_cost(def, state.data["island"], DataDefs.buildings)["scrap"]), 80)
	assert_eq(int(CraftModel.effective_cost(def, state.data["island"], {})["scrap"]), 80,
		"empty building defs never discount")

func test_effective_cost_discounts_and_ceils() -> void:
	with_annex(1)
	var def := {"craft_cost": {"scrap": 85, "brasswork": 3}}
	var cost := CraftModel.effective_cost(def, state.data["island"], DataDefs.buildings)
	assert_eq(int(cost["scrap"]), 77, "ceil(85 x 0.9) = 77")
	assert_eq(int(cost["brasswork"]), 3, "ceil(3 x 0.9) = 3")
	with_annex(2)
	var cost2 := CraftModel.effective_cost(def, state.data["island"], DataDefs.buildings)
	assert_eq(int(cost2["scrap"]), 68, "ceil(85 x 0.8) = 68")

func test_effective_cost_never_reaches_zero() -> void:
	with_annex(2)
	var cost := CraftModel.effective_cost({"craft_cost": {"brasswork": 1}}, state.data["island"], DataDefs.buildings)
	assert_eq(int(cost["brasswork"]), 1, "no craft is ever free")

func test_start_craft_pays_the_discounted_price_it_checked() -> void:
	with_annex(1)
	assert_true(CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan", 1000, DataDefs.buildings))
	assert_eq(econ.balance("scrap"), 5000 - 72, "ceil(80 x 0.9) = 72: pay what was checked")

func test_discount_unlocks_a_craft_at_the_margin() -> void:
	with_annex(1)
	state.data["currencies"]["scrap"] = 72
	assert_true(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan", DataDefs.buildings),
		"72 scrap affords the discounted 72 price")
	assert_false(CraftModel.can_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan"),
		"without building defs the raw 80 price applies")
```

Append to `tests/test_workshop_screen.gd` (this file's `before_each` builds `screen` over `GameState.data`; follow its existing local conventions when placing the function at the end):

```gdscript
func test_idle_rows_show_the_effective_craft_cost() -> void:
	var text: String = screen._gizmo_label_text("wind_fan", TimeUtil.now())
	assert_string_contains(text, "80 scrap", "raw cost without an annex")
	GameState.data["island"]["plots"]["islet_foundry_0"] = {"building": "foundry_annex", "level": 1}
	text = screen._gizmo_label_text("wind_fan", TimeUtil.now())
	assert_string_contains(text, "72 scrap", "the label shows the discounted price the tap will pay")
```

- [ ] **Step 2: Run to verify failure**

Run both single files. Expected: FAIL (`effective_cost` does not exist; label has no cost text).

- [ ] **Step 3: Implement**

In `game/base/craft_model.gd`, replace `can_craft` and `start_craft`, and add `effective_cost`:

```gdscript
static func effective_cost(def: Dictionary, island: Dictionary, building_defs: Dictionary) -> Dictionary:
	# Foundry Annex discount (spec 4.4): ceil keeps every price a positive int
	# and the 1 floor keeps crafts from ever becoming free. can_craft and
	# start_craft must BOTH price through here so check and pay agree.
	var annex: Dictionary = (building_defs.get("defs", {}) as Dictionary).get("foundry_annex", {})
	var level := IslandModel.building_level(island, "foundry_annex")
	var discount := float(level) * float(annex.get("craft_discount_per_level", 0.0))
	var base: Dictionary = def.get("craft_cost", {})
	if discount <= 0.0:
		return base.duplicate()
	var out := {}
	for currency in base:
		out[currency] = maxi(1, ceili(float(base[currency]) * (1.0 - discount)))
	return out


static func can_craft(data: Dictionary, gizmo_defs: Dictionary, economy: Node, timers: Node, gizmo_id: String, building_defs: Dictionary = {}) -> bool:
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
	return economy.can_afford(effective_cost(def, data.get("island", {}), building_defs))


static func start_craft(data: Dictionary, gizmo_defs: Dictionary, economy: Node, timers: Node, gizmo_id: String, now: int, building_defs: Dictionary = {}) -> bool:
	if not can_craft(data, gizmo_defs, economy, timers, gizmo_id, building_defs):
		return false
	var def: Dictionary = (gizmo_defs.get("defs", {}) as Dictionary).get(gizmo_id, {})
	if not economy.pay(effective_cost(def, data.get("island", {}), building_defs)):
		return false
	return timers.start("craft_" + gizmo_id, "craft", int(def.get("craft_seconds", 120)), now, {"gizmo": gizmo_id})
```

In `game/base/workshop_screen.gd`:

1. In `_gizmo_label_text`, replace the block from `var timer_id := "craft_" + gizmo_id` to the end of the function with:

```gdscript
	var timer_id := "craft_" + gizmo_id
	if TimerService.active_timers().has(timer_id) and not TimerService.is_done(timer_id, now):
		text += "  (%ds)" % TimerService.remaining(timer_id, now)
	elif not TimerService.active_timers().has(timer_id):
		text += "  cost: %s" % _cost_text(CraftModel.effective_cost(def, GameState.data["island"], DataDefs.buildings))
	return text


func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for currency in cost:
		parts.append("%d %s" % [int(cost[currency]), String(currency)])
	return ", ".join(parts)
```

2. In `_on_craft_pressed`, change the `CraftModel.start_craft(...)` call to:

```gdscript
	if CraftModel.start_craft(GameState.data, DataDefs.gizmos, Economy, TimerService, gizmo_id, TimeUtil.now(), DataDefs.buildings):
```

- [ ] **Step 4: Run both files, then the full suite**

Expected: PASS, suite exit 0 (existing craft tests use the default `{}` and are price-identical).

- [ ] **Step 5: Commit**

```bash
git add game/base/craft_model.gd game/base/workshop_screen.gd tests/test_craft_model.gd tests/test_workshop_screen.gd
git commit -m "feat: foundry annex craft discount priced at check and pay"
```

---

### Task 7: Restoration notifications

**Files:**
- Modify: `game/core/notification_planner.gd`
- Modify: `game/autoload/notification_svc.gd`
- Test: `tests/test_notifications.gd` (modify)

**Interfaces:**
- Consumes: `IsletModel.entry` from Task 3; timer kind "restoration" with payload `{"islet": id}` from Task 3.
- Produces: `NotificationPlanner.plan(data, building_defs, gizmo_defs, now, islet_defs: Dictionary = {})`; restoration entries `{"id": <timer id>, "title": "Bridge restored", "body": "The way to <name> is open.", "fire_at": <ends_at>}`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_notifications.gd`:

```gdscript
func test_restoration_entry_names_the_islet() -> void:
	var data := make_data()
	data["timers"]["restore_lantern_shoal"] = {"kind": "restoration", "ends_at": NOW + 14400, "payload": {"islet": "lantern_shoal"}}
	var plan := NotificationPlanner.plan(data, DataDefs.buildings, DataDefs.gizmos, NOW, DataDefs.islets)
	assert_eq(plan.size(), 1)
	assert_eq(String(plan[0]["id"]), "restore_lantern_shoal")
	assert_eq(String(plan[0]["title"]), "Bridge restored")
	assert_string_contains(String(plan[0]["body"]), "Lantern Shoal")
	assert_eq(int(plan[0]["fire_at"]), NOW + 14400)

func test_restoration_entry_survives_missing_islet_defs() -> void:
	var data := make_data()
	data["timers"]["restore_lantern_shoal"] = {"kind": "restoration", "ends_at": NOW + 600, "payload": {"islet": "lantern_shoal"}}
	var plan := NotificationPlanner.plan(data, DataDefs.buildings, DataDefs.gizmos, NOW)
	assert_eq(plan.size(), 1, "the default empty islet defs still notify")
	assert_string_contains(String(plan[0]["body"]), "lantern_shoal", "falls back to the id")
```

- [ ] **Step 2: Run to verify failure**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_notifications.gd -gexit`
Expected: FAIL (no 5th parameter; restoration timers produce no entry).

- [ ] **Step 3: Implement**

In `game/core/notification_planner.gd`:

1. Change the `plan` signature to:

```gdscript
static func plan(data: Dictionary, building_defs: Dictionary, gizmo_defs: Dictionary, now: int, islet_defs: Dictionary = {}) -> Array:
```

2. Add after the `elif kind == "craft":` block (as a sibling `elif`):

```gdscript
		elif kind == "restoration":
			var islet: Dictionary = IsletModel.entry(islet_defs, String(payload.get("islet", "")))
			out.append({
				"id": String(id),
				"title": "Bridge restored",
				"body": "The way to %s is open." % String(islet.get("name", payload.get("islet", "an islet"))),
				"fire_at": fire_at,
			})
```

3. Update the file's doc comment first line to mention restoration:

```gdscript
## Pure computation of the local notifications to schedule at background time
## (spec 5): construction complete, craft complete, restoration complete,
## fuel full, daily crate ready. Reads the persisted timers dict READ-ONLY;
## nothing here mutates state, which is what makes the plan testable and
## idempotent.
```

In `game/autoload/notification_svc.gd`, change the `schedule_all` loop line to:

```gdscript
	for entry in NotificationPlanner.plan(GameState.data, DataDefs.buildings, DataDefs.gizmos, now, DataDefs.islets):
```

- [ ] **Step 4: Run the file, then the full suite**

Expected: PASS, suite exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/core/notification_planner.gd game/autoload/notification_svc.gd tests/test_notifications.gd
git commit -m "feat: restoration timers join the notification plan"
```

---

### Task 8: Island screen islet rows and the letter panel

**Files:**
- Modify: `game/base/island_screen.gd`
- Modify: `game/base/island_screen.tscn`
- Test: `tests/test_island_screen.gd` (modify)

**Interfaces:**
- Consumes: everything from Tasks 1 to 4 (`IsletModel.*`, `DataDefs.islets`, the 9-arg `IslandModel.build_rejection`/`start_build`, `data["islets"]`).
- Produces: islet rows with the five lifecycle states, handlers `_on_restore_pressed(islet_id)`, `_on_restore_collect_pressed(islet_id)`, `_on_read_letter_pressed(islet_id)`, `_on_letter_close_pressed()`, `_open_letter(islet_id)`; `_unbuilt_ids(plot: String)` becomes plot-aware; `_plot_ids()` includes restored islet plots; the signature covers islet states; new tscn nodes `LetterPanel/VBox/LetterTitle`, `LetterPanel/VBox/LetterBody`, `LetterPanel/VBox/LetterClose`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_island_screen.gd`, replace `test_builds_one_row_per_plot` with:

```gdscript
func test_builds_one_row_per_plot_plus_one_per_islet() -> void:
	assert_eq(screen.get_node("Rows").get_child_count(),
		int(DataDefs.buildings["plot_count"]) + IsletModel.islets(DataDefs.islets).size(),
		"fresh save: home plots plus one status row per islet, no islet plots open yet")
```

Append at the end of the file:

```gdscript
func restore_lantern() -> void:
	(GameState.data["islets"]["restored"] as Dictionary)["lantern_shoal"] = true
	screen._rebuild()


func test_restore_pays_and_starts_the_restoration_timer() -> void:
	GameState.data["currencies"]["cloudsilk"] = 10
	screen._on_restore_pressed("lantern_shoal")
	assert_true(TimerService.active_timers().has("restore_lantern_shoal"))
	assert_eq(Economy.balance("scrap"), 2000 - 600)
	assert_eq(screen.get_node("StatusLabel").text, "")

func test_rejected_restore_explains_itself() -> void:
	GameState.data["currencies"]["scrap"] = 0
	screen._on_restore_pressed("lantern_shoal")
	assert_false(TimerService.active_timers().has("restore_lantern_shoal"))
	assert_string_contains(screen.get_node("StatusLabel").text, "Not enough")

func test_out_of_order_restore_is_rejected_with_a_reason() -> void:
	GameState.data["currencies"]["brasswork"] = 50
	screen._on_restore_pressed("foundry_rock")
	assert_false(TimerService.active_timers().has("restore_foundry_rock"))
	assert_string_contains(screen.get_node("StatusLabel").text, "Another islet")

func test_restore_collect_marks_restored_and_opens_the_letter() -> void:
	GameState.data["currencies"]["cloudsilk"] = 10
	screen._on_restore_pressed("lantern_shoal")
	TimerService._state.data["timers"]["restore_lantern_shoal"]["ends_at"] = 0
	screen._on_restore_collect_pressed("lantern_shoal")
	assert_true(IsletModel.is_restored(GameState.data, "lantern_shoal"))
	assert_true(screen.get_node("LetterPanel").visible)
	assert_string_contains(String(screen.get_node("LetterPanel/VBox/LetterBody").text), "lanterns were never for us")

func test_letter_close_records_letters_seen() -> void:
	restore_lantern()
	screen._on_read_letter_pressed("lantern_shoal")
	assert_true(screen.get_node("LetterPanel").visible, "letters stay re-readable forever")
	screen._on_letter_close_pressed()
	assert_false(screen.get_node("LetterPanel").visible)
	assert_true(bool((GameState.data["islets"]["letters_seen"] as Dictionary)["lantern_shoal"]))

func test_restored_islet_contributes_its_plot_row() -> void:
	restore_lantern()
	assert_eq(screen.get_node("Rows").get_child_count(),
		int(DataDefs.buildings["plot_count"]) + 1 + IsletModel.islets(DataDefs.islets).size(),
		"the restored islet's plot joins the list")

func test_islet_plot_offers_only_its_islet_building() -> void:
	restore_lantern()
	screen._on_select_pressed("islet_lantern_0")
	assert_eq(String(screen._selection["islet_lantern_0"]), "lens_array")
	screen._on_select_pressed("islet_lantern_0")
	assert_eq(String(screen._selection["islet_lantern_0"]), "lens_array",
		"the cycle contains exactly the one islet building")

func test_home_plot_never_offers_islet_buildings() -> void:
	var offered: Array[String] = screen._unbuilt_ids("plot_0")
	assert_false("lens_array" in offered)
	assert_false("foundry_annex" in offered)

func test_building_on_an_islet_plot_goes_through_the_model() -> void:
	restore_lantern()
	GameState.data["currencies"]["cloudsilk"] = 10
	screen._on_select_pressed("islet_lantern_0")
	screen._on_build_pressed("islet_lantern_0")
	assert_true(TimerService.active_timers().has("build_islet_lantern_0"))

func test_finishing_a_restoration_changes_the_signature() -> void:
	GameState.data["currencies"]["cloudsilk"] = 10
	screen._on_restore_pressed("lantern_shoal")
	screen._refresh_tick()
	var running_signature: String = screen._last_signature
	TimerService._state.data["timers"]["restore_lantern_shoal"]["ends_at"] = 0
	screen._refresh_tick()
	assert_ne(screen._last_signature, running_signature,
		"done is structural: the collect button must appear")
```

- [ ] **Step 2: Run to verify failure**

Run the island screen file. Expected: FAIL (row count, missing handlers, missing LetterPanel node).

- [ ] **Step 3: Implement the scene additions**

In `game/base/island_screen.tscn`, append at the end of the file:

```
[node name="LetterPanel" type="PanelContainer" parent="."]
visible = false
offset_left = 40.0
offset_top = 200.0
offset_right = 680.0
offset_bottom = 700.0

[node name="VBox" type="VBoxContainer" parent="LetterPanel"]

[node name="LetterTitle" type="Label" parent="LetterPanel/VBox"]
text = "A letter"

[node name="LetterBody" type="Label" parent="LetterPanel/VBox"]
custom_minimum_size = Vector2(600, 0)
autowrap_mode = 3

[node name="LetterClose" type="Button" parent="LetterPanel/VBox"]
text = "Close"
```

- [ ] **Step 4: Implement the script changes**

In `game/base/island_screen.gd`:

1. Add members after `var _plot_labels: Dictionary = {}`:

```gdscript
var _islet_labels: Dictionary = {}
var _letter_islet := ""
```

2. In `_ready()`, add before `_rebuild()`:

```gdscript
	$LetterPanel/VBox/LetterClose.pressed.connect(_on_letter_close_pressed)
```

3. Replace `_plot_ids` with:

```gdscript
func _plot_ids() -> Array[String]:
	var ids: Array[String] = []
	for i in int(DataDefs.buildings.get("plot_count", 6)):
		ids.append("plot_%d" % i)
	ids.append_array(IsletModel.open_plots(GameState.data, DataDefs.islets))
	return ids
```

4. Replace `_unbuilt_ids` with the plot-aware version:

```gdscript
func _unbuilt_ids(plot: String) -> Array[String]:
	# A home plot offers home buildings; an islet plot offers exactly its
	# islet's buildings (spec 4.4).
	var plot_islet := IsletModel.islet_of_plot(DataDefs.islets, plot)
	var ids: Array[String] = []
	for id in DataDefs.buildings.get("defs", {}):
		var def: Dictionary = (DataDefs.buildings["defs"] as Dictionary)[id]
		if String(def.get("islet", "")) != plot_islet:
			continue
		if IslandModel.building_level(GameState.data["island"], String(id)) == 0 \
				and IslandModel.plot_of(GameState.data["island"], String(id)) == "":
			ids.append(String(id))
	return ids
```

5. In `_on_select_pressed`, change `var options := _unbuilt_ids()` to `var options := _unbuilt_ids(plot)`.

6. Replace `_signature` with:

```gdscript
func _signature(now: int) -> String:
	var parts := PackedStringArray()
	for plot in _plot_ids():
		var timer_id := "build_" + plot
		if TimerService.active_timers().has(timer_id):
			parts.append("d" if TimerService.is_done(timer_id, now) else "r")
		else:
			parts.append("i")
	for row_v in IsletModel.islets(DataDefs.islets):
		parts.append(_islet_state(String((row_v as Dictionary).get("id", "")), now))
	return ",".join(parts)


func _islet_state(islet_id: String, now: int) -> String:
	# One char per islet: R restored, r restoring, d done-uncollected,
	# o offered, L locked behind an earlier islet. All five are structural.
	if IsletModel.is_restored(GameState.data, islet_id):
		return "R"
	var timer_id := "restore_" + islet_id
	if TimerService.active_timers().has(timer_id):
		return "d" if TimerService.is_done(timer_id, now) else "r"
	return "o" if IsletModel.next_offered(GameState.data, DataDefs.islets) == islet_id else "L"
```

7. Replace `_refresh_labels` with:

```gdscript
func _refresh_labels(now: int) -> void:
	var island: Dictionary = GameState.data["island"]
	for plot in _plot_labels:
		var label: Label = _plot_labels[plot]
		if is_instance_valid(label):
			label.text = _row_text(String(plot), island, now)
	for islet_id in _islet_labels:
		var islet_label: Label = _islet_labels[islet_id]
		if is_instance_valid(islet_label):
			islet_label.text = _islet_row_text(IsletModel.entry(DataDefs.islets, String(islet_id)), now)
	_refresh_static_controls(now)
```

8. In `_rebuild`, add `_islet_labels.clear()` directly after `_plot_labels.clear()`, and add the islet row loop directly after the `rows.add_child(row)` line that closes the plot loop (before `_refresh_static_controls(now)`):

```gdscript
	for row_v in IsletModel.islets(DataDefs.islets):
		var islet := row_v as Dictionary
		var islet_id := String(islet.get("id", ""))
		var islet_row := HBoxContainer.new()
		islet_row.custom_minimum_size = Vector2(0, 64)
		var islet_label := Label.new()
		islet_label.custom_minimum_size = Vector2(320, 0)
		islet_label.text = _islet_row_text(islet, now)
		islet_row.add_child(islet_label)
		_islet_labels[islet_id] = islet_label
		match _islet_state(islet_id, now):
			"o":
				var restore := Button.new()
				restore.text = "Restore"
				restore.pressed.connect(_on_restore_pressed.bind(islet_id))
				islet_row.add_child(restore)
			"d":
				var cross := Button.new()
				cross.text = "Cross over!"
				cross.pressed.connect(_on_restore_collect_pressed.bind(islet_id))
				islet_row.add_child(cross)
			"R":
				var read := Button.new()
				read.text = "Read letter"
				read.pressed.connect(_on_read_letter_pressed.bind(islet_id))
				islet_row.add_child(read)
		rows.add_child(islet_row)
```

9. Add the row-text and cost helpers after `_selection_text`:

```gdscript
func _islet_row_text(islet: Dictionary, now: int) -> String:
	var islet_id := String(islet.get("id", ""))
	var islet_name := String(islet.get("name", islet_id))
	match _islet_state(islet_id, now):
		"R":
			return "%s: restored" % islet_name
		"r":
			return "%s: restoring (%ds)" % [islet_name, TimerService.remaining("restore_" + islet_id, now)]
		"d":
			return "%s: the bridge is ready" % islet_name
		"o":
			return "%s: %s" % [islet_name, _cost_text(islet.get("cost", {}))]
	return "%s: beyond a broken bridge" % islet_name


func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for currency in cost:
		parts.append("%d %s" % [int(cost[currency]), String(currency)])
	return ", ".join(parts)
```

10. Add the islet handlers after `_on_collect_pressed`:

```gdscript
func _on_restore_pressed(islet_id: String) -> void:
	var reason := IsletModel.restore_rejection(GameState.data, DataDefs.islets, Economy, TimerService, islet_id)
	if reason != "":
		$StatusLabel.text = reason
		return
	if IsletModel.start_restore(GameState.data, DataDefs.islets, Economy, TimerService, islet_id, TimeUtil.now()):
		$StatusLabel.text = ""
		GameState.save_game()
	_rebuild()


func _on_restore_collect_pressed(islet_id: String) -> void:
	var payload := TimerService.collect("restore_" + islet_id, TimeUtil.now())
	if payload.is_empty():
		return
	IsletModel.complete_restore(GameState.data, payload)
	GameState.save_game()
	_open_letter(islet_id)
	_rebuild()


func _on_read_letter_pressed(islet_id: String) -> void:
	_open_letter(islet_id)


func _open_letter(islet_id: String) -> void:
	var islet := IsletModel.entry(DataDefs.islets, islet_id)
	var vignette: Dictionary = islet.get("vignette", {})
	_letter_islet = islet_id
	$LetterPanel/VBox/LetterTitle.text = String(vignette.get("title", String(islet.get("name", islet_id))))
	var lines := PackedStringArray()
	for line in vignette.get("lines", []):
		lines.append(String(line))
	$LetterPanel/VBox/LetterBody.text = "\n\n".join(lines)
	$LetterPanel.visible = true


func _on_letter_close_pressed() -> void:
	if _letter_islet != "":
		# Write-back discipline: heal a mangled section before flagging.
		if not GameState.data.has("islets") or not (GameState.data["islets"] is Dictionary):
			GameState.data["islets"] = {"restored": {}, "letters_seen": {}}
		var section: Dictionary = GameState.data["islets"]
		if not section.has("letters_seen") or not (section["letters_seen"] is Dictionary):
			section["letters_seen"] = {}
		(section["letters_seen"] as Dictionary)[_letter_islet] = true
		GameState.save_game()
	_letter_islet = ""
	$LetterPanel.visible = false
```

11. In `_on_build_pressed`, change the two model calls to pass the islet context:

```gdscript
	var reason := IslandModel.build_rejection(island, DataDefs.buildings, Economy, TimerService, plot, building_id, now, DataDefs.islets, GameState.data.get("islets", {}))
	if reason != "":
		$StatusLabel.text = reason
		return
	if IslandModel.start_build(island, DataDefs.buildings, Economy, TimerService, plot, building_id, now, DataDefs.islets, GameState.data.get("islets", {})):
```

- [ ] **Step 5: Run the file, then the full suite**

Run: `$GODOT --headless --import` then the island screen file, then the full suite.
Expected: PASS, suite exit 0. If `test_select_cycles_unbuilt_buildings` fails on def ordering, the plot-aware `_unbuilt_ids` filter is wrong (home plots must still cycle exactly the six home defs).

- [ ] **Step 6: Commit**

```bash
git add game/base/island_screen.gd game/base/island_screen.tscn tests/test_island_screen.gd
git commit -m "feat: islet rows, restoration flow, and the letter panel"
```

---

### Task 9: End-to-end integration proof and roadmap update

**Files:**
- Test: `tests/test_islet_integration.gd` (create)
- Modify: `docs/roadmap.md`

**Interfaces:**
- Consumes: everything shipped in Tasks 1 to 8.
- Produces: one fixed-clock proof of the whole chain: restore, build, boosted run payout. Standing ruling: integration proofs run no-strict-RED (write the test after the features exist; it must pass on first run and is still committed as a test).

- [ ] **Step 1: Write the integration test**

Create `tests/test_islet_integration.gd`:

```gdscript
extends GutTest
## End-to-end proof of the island expansion flywheel on a fixed clock:
## restore Lantern Shoal, build the Lens Array on the opened plot, and a
## salvage-run catch pays the multiplied payout. No RNG is involved.

const RunScene := preload("res://game/run/salvage_run.tscn")
const TEST_SAVE := "user://test_islet_integration.json"
const T0 := 1_800_000_000


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	GameState.data["created_at"] = T0
	GameState.data["fuel"]["updated_at"] = T0
	GameState.data["currencies"]["scrap"] = 5000
	GameState.data["currencies"]["cloudsilk"] = 20


func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_islet_integration.json", "test_islet_integration.json.tmp", "test_islet_integration.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings)


func test_restore_build_and_run_pays_the_lens_bonus() -> void:
	# 1. Pay for the bridge and wait out the 4-hour repair on a fake clock.
	assert_true(IsletModel.start_restore(GameState.data, DataDefs.islets, Economy, TimerService, "lantern_shoal", T0))
	assert_eq(Economy.balance("scrap"), 5000 - 600)
	var payload := TimerService.collect("restore_lantern_shoal", T0 + 14400)
	IsletModel.complete_restore(GameState.data, payload)
	assert_true(IsletModel.is_restored(GameState.data, "lantern_shoal"))
	# 2. The opened plot accepts exactly its own building.
	assert_true(IslandModel.start_build(GameState.data["island"], DataDefs.buildings, Economy, TimerService,
		"islet_lantern_0", "lens_array", T0 + 14400, DataDefs.islets, GameState.data["islets"]))
	var build_payload := TimerService.collect("build_islet_lantern_0", T0 + 14400 + 1800)
	IslandModel.complete_build(GameState.data["island"], build_payload, GameState.data, T0 + 16200)
	assert_eq(IslandModel.building_level(GameState.data["island"], "lens_array"), 1)
	# 3. A run built from this island multiplies every catch by 1.05.
	var scene = add_child_autofree(RunScene.instantiate())
	assert_eq(scene._compute_payout(null, {"scrap": 20}), {"scrap": 21},
		"20 scrap x 1.05 rounds to 21: the flywheel feeds back")

func test_restoration_survives_a_save_reload_cycle() -> void:
	IsletModel.start_restore(GameState.data, DataDefs.islets, Economy, TimerService, "lantern_shoal", T0)
	GameState.save_game()
	GameState.load_game(DataDefs.economy, T0 + 100, DataDefs.gizmos, DataDefs.buildings)
	assert_true(TimerService.active_timers().has("restore_lantern_shoal"),
		"a running restoration persists like any other timer")
	assert_eq(TimerService.remaining("restore_lantern_shoal", T0 + 100), 14300)
```

- [ ] **Step 2: Run the file and confirm it passes first try (no-strict-RED ruling)**

Run: `$GODOT --headless --import` then the single file.
Expected: PASS. If it fails, a real integration bug exists; fix the production code, never the test's arithmetic.

- [ ] **Step 3: Update the roadmap**

In `docs/roadmap.md`, replace the section:

```markdown
### Island expansion + story vignettes (spec 4.4)
- Restored bridges/balloon lines to neighboring islets open new build plots; each islet carries a skippable found-letter vignette. Needs a spec (plot data model, restoration costs/timers, vignette storage); no schema work exists yet.
```

with:

```markdown
### Island expansion + story vignettes (spec 4.4): SHIPPED (Plan 8)
- Two data-driven islets (islets.json), IsletModel restoration lane, Lens Array and Foundry Annex, letter panel, schema v7. Spec: docs/superpowers/specs/2026-08-22-island-expansion-vignettes-design.md. Islet 3+ is JSON authoring plus one new building effect if desired. Restoration timers are deliberately not ad-skippable yet (revisit after playtest).
```

- [ ] **Step 4: Run the full suite**

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add tests/test_islet_integration.gd tests/test_islet_integration.gd.uid docs/roadmap.md
git commit -m "test: prove the islet expansion flywheel end to end"
```

---

## Manual smoke steps (waived in the non-interactive environment, noted for the on-device pass)

1. Open the island screen: two dimmed/offered islet rows sit below the six plots.
2. Restore Lantern Shoal, background the app: a "Bridge restored" notification is scheduled.
3. Collect the restoration: the letter panel opens; Close it; Read letter reopens it.
4. Build the Lens Array; run a salvage run; payouts land 5% higher.
5. Restore Foundry Rock, build the Annex, open the Workshop: craft costs show discounted.
