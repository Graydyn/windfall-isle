# Windfall Isles Plan 1: Foundation and Core Services

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the Godot project with a headless test harness and build the offline core every other system depends on: data-driven tunables, currencies, fuel regeneration, wall-clock timers, versioned atomic saves, and the AdService seam.

**Architecture:** All game state lives in one `GameState.data` dictionary that autoload services (Economy, TimerService) operate on by reference, so saving is serializing one dict and loading is deserializing one dict. All time-based logic is pure functions over explicit Unix-second integers passed in by callers, never wall-clock reads inside logic, which makes every offline mechanic unit-testable with fake clocks. Tunables live in JSON under `game/data/`, never in scripts.

**Tech Stack:** Godot 4.6.x, GDScript, GUT 9.x for headless unit tests, JSON saves in `user://`.

**Spec:** [docs/design/2026-08-15-windfall-isles-design.md](../../design/2026-08-15-windfall-isles-design.md) (sections 4.2, 4.3, 6, 7, 8)

## Global Constraints

Copied from the spec; every task's requirements implicitly include these.

- Engine: **Godot 4.6.x**, minor version pinned. All shell commands below use `$GODOT`, which must point at a Godot 4.6 binary (see Task 1 Step 1).
- Language: **GDScript** only. No C#.
- **Portrait only, 2D only**: viewport 720x1280, `window/handheld/orientation=1`, rendering method `mobile`.
- **Completely offline; no backend.** No network calls anywhere in this plan.
- **Every number a designer would tune lives in `game/data/*.json`, not in scripts.**
- Saves: **versioned JSON in `user://` via FileAccess; write-to-temp-then-rename; rolling backup** of the previous good save.
- Timers: **Unix timestamps persisted in the save; elapsed time computed on resume; no background execution assumed.** Logic functions take `now: int` as a parameter; only call-boundary code reads the real clock via `TimeUtil.now()`.
- Ads: **all ad interactions go through the single `AdService` interface.** MVP ships `GrantAdService` behavior only (spec section 8); no ad SDK is compiled in.
- Testing: GUT, run headless:
  `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- GDScript style: snake_case filenames, PascalCase `class_name`, tabs for indentation (Godot default).
- Commit after every task. Conventional-commit messages.

## Conventions used by every task

- JSON numbers parse back as floats in Godot, so **every read out of `GameState.data` or a defs dictionary is wrapped in `int(...)`**. Tests will catch violations because save/load roundtrips are tested.
- GDScript Dictionaries are reference types. Services mutate the state dict in place; that is intentional and is what makes "save = serialize one dict" work.
- Autoload load order in `project.godot` matters and must end up exactly: `DataDefs, GameState, Economy, TimerService, Ads`. Each task adds its own line; never add an autoload entry before the script file exists or the project will error at startup.

## File Structure

```
project.godot                      # created T1, autoload lines added T2/T5/T6/T7/T8, main scene T9
.gitignore                         # T1
addons/gut/                        # T1 (vendored GUT, committed)
game/
  autoload/
    data_defs.gd                   # T2  autoload DataDefs: loads/validates game/data JSON
    game_state.gd                  # T5  autoload GameState: owns save dict, load/save/migrate
    economy.gd                     # T6  autoload Economy: currency balances over GameState
    timer_service.gd               # T7  autoload TimerService: construction/craft timers
    ads.gd                         # T8  autoload Ads: picks the AdService implementation
  core/
    time_util.gd                   # T5  TimeUtil.now()
    fuel_model.gd                  # T3  pure fuel regen math
    save_schema.gd                 # T4  schema version, defaults, migrations
    save_io.gd                     # T4  atomic write + backup + fallback read
    ad_service.gd                  # T8  AdService base interface
    grant_ad_service.gd            # T8  auto-grant implementation (MVP + Play Pass)
  data/
    economy.json                   # T2  starting balances + fuel tuning
  main.gd                          # T9  boot scene script (debug HUD)
  main.tscn                        # T9  boot scene
tests/
  fixtures/bad_data.json           # T2
  test_smoke.gd                    # T1
  test_data_defs.gd                # T2
  test_fuel_model.gd               # T3
  test_save_io.gd                  # T4
  test_save_schema.gd              # T4
  test_game_state.gd               # T5
  test_economy.gd                  # T6
  test_timer_service.gd            # T7
  test_ad_service.gd               # T8
  test_main_boot.gd                # T9
```

---

### Task 1: Project scaffold and test harness

**Files:**
- Create: `project.godot`
- Create: `.gitignore`
- Create: `addons/gut/` (vendored from the GUT repo)
- Test: `tests/test_smoke.gd`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: a Godot 4.6 project where `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` runs and exits 0 when all tests pass. Every later task relies on that exact command.

- [ ] **Step 1: Verify or install Godot 4.6**

```bash
export GODOT="${GODOT:-godot}"
$GODOT --version
```

Expected: output starting with `4.6` (e.g. `4.6.stable.official`).

If the command is missing (macOS):

```bash
brew install --cask godot
export GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
$GODOT --version
```

If `--version` prints a non-4.6 major/minor, stop and install 4.6.x specifically (the spec pins the minor version); do not proceed on 4.5 or 4.7.

- [ ] **Step 2: Create `project.godot` at the repo root**

No autoload section yet; autoloads are added by the tasks that create their scripts.

```ini
config_version=5

[application]

config/name="Windfall Isles"
config/features=PackedStringArray("4.6")

[display]

window/size/viewport_width=720
window/size/viewport_height=1280
window/handheld/orientation=1
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[editor_plugins]

enabled=PackedStringArray("res://addons/gut/plugin.cfg")

[rendering]

renderer/rendering_method="mobile"
```

- [ ] **Step 3: Create `.gitignore`**

```
.godot/
*.tmp
.DS_Store
```

- [ ] **Step 4: Vendor GUT into `addons/gut`**

Find the newest v9.x tag (GUT 9.x is the Godot 4 line), then clone that tag and copy the addon in. `v9.4.0` is a known-good example; prefer the newest v9.x listed.

```bash
git ls-remote --tags https://github.com/bitwes/Gut.git | grep -o 'v9\.[0-9.]*$' | sort -V | tail -3
git clone --depth 1 --branch v9.4.0 https://github.com/bitwes/Gut.git /tmp/gut-checkout
mkdir -p addons
cp -R /tmp/gut-checkout/addons/gut addons/gut
```

GUT is committed to the repo (vendored, pinned), matching the spec's "plugins pinned to match" rule. Record the tag you used in the commit message.

- [ ] **Step 5: Write the smoke test**

`tests/test_smoke.gd`:

```gdscript
extends GutTest


func test_gut_harness_runs() -> void:
	assert_true(true, "GUT harness is alive")
```

- [ ] **Step 6: Import, then run the tests**

The first headless run must import project resources before GUT can load:

```bash
$GODOT --headless --import
$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: `1 passed`, exit code 0 (`echo $?`).

- [ ] **Step 7: Commit**

```bash
git add project.godot .gitignore addons/gut tests/test_smoke.gd
git commit -m "chore: scaffold Godot 4.6 project with GUT test harness (GUT v9.4.0)"
```

---

### Task 2: Data layer, economy tunables

**Files:**
- Create: `game/data/economy.json`
- Create: `game/autoload/data_defs.gd`
- Create: `tests/fixtures/bad_data.json`
- Modify: `project.godot` (add `[autoload]` section)
- Test: `tests/test_data_defs.gd`

**Interfaces:**
- Consumes: test harness from Task 1.
- Produces: autoload `DataDefs` with `var economy: Dictionary` (keys `"starting_balances"`, `"fuel"`) and `static func load_json(path: String) -> Dictionary` (returns `{}` and pushes an error on missing/malformed files). Tasks 4, 5 and 9 read `DataDefs.economy`.

- [ ] **Step 1: Write the failing tests**

`tests/fixtures/bad_data.json` (deliberately invalid JSON):

```
{ this is not valid json
```

`tests/test_data_defs.gd`:

```gdscript
extends GutTest

const DataDefsScript := preload("res://game/autoload/data_defs.gd")


func test_economy_defs_load_with_required_keys() -> void:
	var defs := DataDefsScript.load_json("res://game/data/economy.json")
	assert_has(defs, "starting_balances")
	assert_has(defs, "fuel")
	assert_true(int(defs["fuel"]["cap"]) > 0, "fuel cap must be positive")
	assert_true(int(defs["fuel"]["regen_seconds"]) > 0, "regen_seconds must be positive")

func test_missing_file_returns_empty_dict() -> void:
	assert_eq(DataDefsScript.load_json("res://game/data/does_not_exist.json"), {})

func test_malformed_json_returns_empty_dict() -> void:
	assert_eq(DataDefsScript.load_json("res://tests/fixtures/bad_data.json"), {})
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: FAIL (script `data_defs.gd` does not exist, test script errors).

- [ ] **Step 3: Write the data file and the loader**

`game/data/economy.json`. These are the initial tuning values (spec 4.3: full tank supports 3-5 expeditions; cap 5 at cost 1 per expedition; 20 minutes per fuel unit):

```json
{
	"starting_balances": {
		"scrap": 100,
		"cloudsilk": 0,
		"crystals": 10
	},
	"fuel": {
		"starting": 5,
		"cap": 5,
		"regen_seconds": 1200
	}
}
```

`game/autoload/data_defs.gd`:

```gdscript
extends Node
## Loads and validates the designer-tunable JSON under game/data/.
## All balance numbers live in those files, never in scripts (spec 7.2).

const ECONOMY_PATH := "res://game/data/economy.json"

var economy: Dictionary = {}


func _ready() -> void:
	economy = load_json(ECONOMY_PATH)


static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing data file: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_error("Malformed JSON in %s" % path)
		return {}
	return parsed
```

- [ ] **Step 4: Register the autoload**

Add to `project.godot` (new section, placed after `[application]`):

```ini
[autoload]

DataDefs="*res://game/autoload/data_defs.gd"
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: PASS (4 tests total). The malformed-JSON test prints a pushed error to the log; that is expected output, not a failure.

- [ ] **Step 6: Commit**

```bash
git add game/data/economy.json game/autoload/data_defs.gd tests/fixtures/bad_data.json tests/test_data_defs.gd project.godot
git commit -m "feat: add data-driven economy tunables and DataDefs loader"
```

---

### Task 3: Fuel model (pure regen math)

**Files:**
- Create: `game/core/fuel_model.gd`
- Test: `tests/test_fuel_model.gd`

**Interfaces:**
- Consumes: nothing at runtime; operates on a plain fuel dict with keys `"amount": int`, `"cap": int`, `"regen_seconds": int`, `"updated_at": int` (Unix seconds). Task 4's `SaveSchema.default_data` creates exactly this shape.
- Produces: `class_name FuelModel` with statics:
  - `static func materialize(fuel: Dictionary, now: int) -> void` (mutates in place)
  - `static func current(fuel: Dictionary, now: int) -> int`
  - `static func spend(fuel: Dictionary, amount: int, now: int) -> bool`
  - `static func seconds_until_full(fuel: Dictionary, now: int) -> int`

  Plan 2 (run loop) calls `spend` to launch expeditions; Plan 5 (notifications) calls `seconds_until_full` to schedule the "fuel full" notification.

- [ ] **Step 1: Write the failing tests**

`tests/test_fuel_model.gd`:

```gdscript
extends GutTest


func make_fuel(amount: int, cap := 5, regen := 1200, updated_at := 1000) -> Dictionary:
	return {"amount": amount, "cap": cap, "regen_seconds": regen, "updated_at": updated_at}


func test_full_tank_stays_full() -> void:
	var fuel := make_fuel(5)
	assert_eq(FuelModel.current(fuel, 1000 + 999999), 5)

func test_regenerates_one_unit_per_interval() -> void:
	var fuel := make_fuel(2)
	assert_eq(FuelModel.current(fuel, 1000 + 1200), 3)
	assert_eq(FuelModel.current(fuel, 1000 + 2399), 3)
	assert_eq(FuelModel.current(fuel, 1000 + 2400), 4)

func test_regen_never_exceeds_cap() -> void:
	var fuel := make_fuel(2)
	assert_eq(FuelModel.current(fuel, 1000 + 1200 * 50), 5)

func test_materialize_preserves_partial_progress() -> void:
	var fuel := make_fuel(2)
	FuelModel.materialize(fuel, 1000 + 1800)  # 1.5 regen intervals elapsed
	assert_eq(int(fuel["amount"]), 3)
	# updated_at advances by whole intervals only, keeping the 600s remainder
	assert_eq(int(fuel["updated_at"]), 1000 + 1200)

func test_spend_success_and_failure() -> void:
	var fuel := make_fuel(2)
	assert_true(FuelModel.spend(fuel, 2, 1000))
	assert_eq(int(fuel["amount"]), 0)
	assert_false(FuelModel.spend(fuel, 1, 1000))

func test_spend_from_full_restarts_regen_clock() -> void:
	var fuel := make_fuel(5, 5, 1200, 1000)
	FuelModel.spend(fuel, 1, 50000)
	# Time spent sitting at cap must not bank regen; the clock restarts at spend time
	assert_eq(FuelModel.current(fuel, 50000 + 1199), 4)
	assert_eq(FuelModel.current(fuel, 50000 + 1200), 5)

func test_current_does_not_mutate_input() -> void:
	var fuel := make_fuel(2)
	FuelModel.current(fuel, 1000 + 2400)
	assert_eq(int(fuel["amount"]), 2)
	assert_eq(int(fuel["updated_at"]), 1000)

func test_seconds_until_full() -> void:
	var fuel := make_fuel(3)
	assert_eq(FuelModel.seconds_until_full(fuel, 1000), 2400)
	assert_eq(FuelModel.seconds_until_full(fuel, 1600), 1800)
	var full := make_fuel(5)
	assert_eq(FuelModel.seconds_until_full(full, 1000), 0)
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: FAIL with parse errors on `FuelModel` (identifier not found).

- [ ] **Step 3: Write the implementation**

`game/core/fuel_model.gd`:

```gdscript
class_name FuelModel
## Pure fuel-regeneration math (spec 4.3). Operates on the fuel dict stored in
## the save: {"amount", "cap", "regen_seconds", "updated_at"}, all ints,
## timestamps in Unix seconds. Callers pass `now` explicitly; this class never
## reads the wall clock, which is what makes offline regen testable.


static func materialize(fuel: Dictionary, now: int) -> void:
	var regen: int = maxi(1, int(fuel["regen_seconds"]))
	var elapsed: int = maxi(0, now - int(fuel["updated_at"]))
	@warning_ignore("integer_division")
	var gained: int = elapsed / regen
	if gained > 0 and int(fuel["amount"]) < int(fuel["cap"]):
		fuel["amount"] = mini(int(fuel["cap"]), int(fuel["amount"]) + gained)
		fuel["updated_at"] = int(fuel["updated_at"]) + gained * regen
	if int(fuel["amount"]) >= int(fuel["cap"]):
		# Sitting at cap accrues nothing; restart the clock so a later spend
		# regenerates from spend time, not from a stale timestamp.
		fuel["updated_at"] = now


static func current(fuel: Dictionary, now: int) -> int:
	var copy := fuel.duplicate()
	materialize(copy, now)
	return int(copy["amount"])


static func spend(fuel: Dictionary, amount: int, now: int) -> bool:
	materialize(fuel, now)
	if int(fuel["amount"]) < amount:
		return false
	fuel["amount"] = int(fuel["amount"]) - amount
	return true


static func seconds_until_full(fuel: Dictionary, now: int) -> int:
	var copy := fuel.duplicate()
	materialize(copy, now)
	var missing: int = int(copy["cap"]) - int(copy["amount"])
	if missing <= 0:
		return 0
	var partial: int = now - int(copy["updated_at"])
	return missing * int(copy["regen_seconds"]) - partial
```

- [ ] **Step 4: Run tests to verify they pass**

Same command. Expected: PASS (13 tests total).

- [ ] **Step 5: Commit**

```bash
git add game/core/fuel_model.gd tests/test_fuel_model.gd
git commit -m "feat: add pure fuel regeneration model with lazy timestamp math"
```

---

### Task 4: Save layer (schema, migrations, atomic IO)

**Files:**
- Create: `game/core/save_schema.gd`
- Create: `game/core/save_io.gd`
- Test: `tests/test_save_schema.gd`
- Test: `tests/test_save_io.gd`

**Interfaces:**
- Consumes: the economy defs shape from Task 2 (`{"starting_balances": {...}, "fuel": {"starting", "cap", "regen_seconds"}}`).
- Produces:
  - `class_name SaveSchema`: `const CURRENT_VERSION := 1`, `static func default_data(defs: Dictionary) -> Dictionary`, `static func migrate(data: Dictionary) -> Dictionary` (returns `{}` when the data cannot be migrated, signalling the caller to fall back).
  - `class_name SaveIO extends RefCounted`: `_init(path: String = "user://save.json")`, `func write(data: Dictionary) -> Error`, `func read() -> Dictionary` (returns `{}` when neither save nor backup parses), plus `var save_path/tmp_path/backup_path: String`.
  - The save dict shape (schema v1): `{"version": int, "created_at": int, "currencies": {"scrap": int, "cloudsilk": int, "crystals": int}, "fuel": {"amount", "cap", "regen_seconds", "updated_at"}, "timers": {}, "island": {}, "gizmos": {}}`. `island` and `gizmos` are reserved empty dicts that Plans 3 and 4 will populate.

- [ ] **Step 1: Write the failing tests**

`tests/test_save_schema.gd`:

```gdscript
extends GutTest

const DEFS := {
	"starting_balances": {"scrap": 100, "cloudsilk": 0, "crystals": 10},
	"fuel": {"starting": 5, "cap": 5, "regen_seconds": 1200},
}


func test_default_data_shape() -> void:
	var data := SaveSchema.default_data(DEFS)
	assert_eq(int(data["version"]), SaveSchema.CURRENT_VERSION)
	assert_eq(int(data["currencies"]["scrap"]), 100)
	assert_eq(int(data["currencies"]["crystals"]), 10)
	assert_eq(int(data["fuel"]["amount"]), 5)
	assert_eq(int(data["fuel"]["cap"]), 5)
	assert_eq(int(data["fuel"]["regen_seconds"]), 1200)
	assert_eq(data["timers"], {})
	assert_eq(data["island"], {})
	assert_eq(data["gizmos"], {})

func test_default_data_does_not_alias_defs() -> void:
	var data := SaveSchema.default_data(DEFS)
	data["currencies"]["scrap"] = 0
	assert_eq(int(DEFS["starting_balances"]["scrap"]), 100,
		"mutating a save must never mutate the defs")

func test_migrate_current_version_is_noop() -> void:
	var data := SaveSchema.default_data(DEFS)
	assert_eq(SaveSchema.migrate(data), data)

func test_migrate_rejects_unversioned_data() -> void:
	assert_eq(SaveSchema.migrate({"currencies": {}}), {})

func test_migrate_rejects_future_version() -> void:
	assert_eq(SaveSchema.migrate({"version": 99}), {})
```

`tests/test_save_io.gd`:

```gdscript
extends GutTest

const TEST_PATH := "user://test_save.json"

var io: SaveIO


func before_each() -> void:
	io = SaveIO.new(TEST_PATH)
	_delete_test_files()

func after_all() -> void:
	_delete_test_files()

func _delete_test_files() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_save.json", "test_save.json.tmp", "test_save.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)


func test_read_with_no_files_returns_empty() -> void:
	assert_eq(io.read(), {})

func test_write_read_roundtrip() -> void:
	assert_eq(io.write({"version": 1, "marker": "A"}), OK)
	assert_eq(io.read()["marker"], "A")

func test_no_tmp_file_left_behind() -> void:
	io.write({"marker": "A"})
	assert_false(FileAccess.file_exists(io.tmp_path))

func test_second_write_creates_backup_of_previous_save() -> void:
	io.write({"marker": "A"})
	io.write({"marker": "B"})
	assert_true(FileAccess.file_exists(io.backup_path))
	assert_eq(io.read()["marker"], "B")

func test_corrupted_save_falls_back_to_backup() -> void:
	io.write({"marker": "A"})
	io.write({"marker": "B"})  # backup now holds A
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("{ corrupted garbage")
	f.close()
	assert_eq(io.read()["marker"], "A")
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: FAIL with parse errors on `SaveSchema` and `SaveIO`.

- [ ] **Step 3: Write the implementations**

`game/core/save_schema.gd`:

```gdscript
class_name SaveSchema
## Versioned save schema (spec 7.3). One dict is the whole save.
## "island" and "gizmos" are reserved for the base-builder and gizmo plans.

const CURRENT_VERSION := 1


static func default_data(defs: Dictionary) -> Dictionary:
	var balances: Dictionary = defs.get("starting_balances", {})
	var fuel_defs: Dictionary = defs.get("fuel", {})
	return {
		"version": CURRENT_VERSION,
		"created_at": 0,  # caller stamps with TimeUtil.now()
		"currencies": balances.duplicate(),
		"fuel": {
			"amount": int(fuel_defs.get("starting", 0)),
			"cap": int(fuel_defs.get("cap", 5)),
			"regen_seconds": int(fuel_defs.get("regen_seconds", 1200)),
			"updated_at": 0,  # caller stamps with TimeUtil.now()
		},
		"timers": {},
		"island": {},
		"gizmos": {},
	}


static func migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 0))
	if version <= 0 or version > CURRENT_VERSION:
		return {}
	# When CURRENT_VERSION bumps past 1, add a `while version < CURRENT_VERSION`
	# loop here dispatching to _migrate_N_to_M(data) functions, stamping
	# data["version"] after each hop. v1 has no predecessors to migrate from.
	return data
```

`game/core/save_io.gd`:

```gdscript
class_name SaveIO
extends RefCounted
## Atomic save IO (spec 7.3): write to temp then rename, keep a rolling backup
## of the previous good save, fall back to the backup on corruption.

var save_path: String
var tmp_path: String
var backup_path: String


func _init(path: String = "user://save.json") -> void:
	save_path = path
	tmp_path = path + ".tmp"
	backup_path = path + ".bak"


func write(data: Dictionary) -> Error:
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var dir := DirAccess.open(save_path.get_base_dir())
	if dir == null:
		return DirAccess.get_open_error()
	if FileAccess.file_exists(save_path):
		dir.copy(save_path, backup_path)
	return dir.rename(tmp_path, save_path)


func read() -> Dictionary:
	for path in [save_path, backup_path]:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			return parsed
	return {}
```

- [ ] **Step 4: Run tests to verify they pass**

Same command. Expected: PASS (23 tests total).

- [ ] **Step 5: Commit**

```bash
git add game/core/save_schema.gd game/core/save_io.gd tests/test_save_schema.gd tests/test_save_io.gd
git commit -m "feat: add versioned save schema and atomic save IO with backup fallback"
```

---

### Task 5: GameState autoload and TimeUtil

**Files:**
- Create: `game/core/time_util.gd`
- Create: `game/autoload/game_state.gd`
- Modify: `project.godot` (`[autoload]` section)
- Test: `tests/test_game_state.gd`

**Interfaces:**
- Consumes: `SaveSchema`, `SaveIO` (Task 4), `DataDefs.economy` (Task 2).
- Produces:
  - `class_name TimeUtil`: `static func now() -> int` (Unix seconds). The ONLY place logic code may read the wall clock from.
  - Autoload `GameState` (Node): `var data: Dictionary`, `signal loaded`, `func load_game(defs: Dictionary, now: int) -> void`, `func save_game() -> Error`, and auto-save on `NOTIFICATION_APPLICATION_PAUSED` / `NOTIFICATION_WM_CLOSE_REQUEST` (spec: save-anywhere, OS interruption never loses loot). Tasks 6 and 7 mutate `GameState.data` through their services; Task 9 reads it for the debug HUD.

- [ ] **Step 1: Write the failing tests**

`tests/test_game_state.gd`:

```gdscript
extends GutTest

const GameStateScript := preload("res://game/autoload/game_state.gd")
const TEST_PATH := "user://test_gamestate.json"
const DEFS := {
	"starting_balances": {"scrap": 100, "cloudsilk": 0, "crystals": 10},
	"fuel": {"starting": 5, "cap": 5, "regen_seconds": 1200},
}

var gs


func before_each() -> void:
	_delete_test_files()
	gs = autofree(GameStateScript.new())
	gs._io = SaveIO.new(TEST_PATH)

func after_all() -> void:
	_delete_test_files()

func _delete_test_files() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_gamestate.json", "test_gamestate.json.tmp", "test_gamestate.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)


func test_time_util_returns_plausible_unix_seconds() -> void:
	assert_true(TimeUtil.now() > 1_700_000_000)

func test_fresh_load_creates_stamped_defaults() -> void:
	gs.load_game(DEFS, 5000)
	assert_eq(int(gs.data["version"]), SaveSchema.CURRENT_VERSION)
	assert_eq(int(gs.data["created_at"]), 5000)
	assert_eq(int(gs.data["fuel"]["updated_at"]), 5000)
	assert_eq(int(gs.data["currencies"]["scrap"]), 100)

func test_save_load_roundtrip() -> void:
	gs.load_game(DEFS, 5000)
	gs.data["currencies"]["scrap"] = 123
	assert_eq(gs.save_game(), OK)
	var gs2 = autofree(GameStateScript.new())
	gs2._io = SaveIO.new(TEST_PATH)
	gs2.load_game(DEFS, 6000)
	assert_eq(int(gs2.data["currencies"]["scrap"]), 123)
	assert_eq(int(gs2.data["created_at"]), 5000, "existing save must not be re-stamped")

func test_unmigratable_save_falls_back_to_defaults() -> void:
	var io := SaveIO.new(TEST_PATH)
	io.write({"version": 99, "currencies": {"scrap": 1}})
	gs.load_game(DEFS, 7000)
	assert_eq(int(gs.data["version"]), SaveSchema.CURRENT_VERSION)
	assert_eq(int(gs.data["currencies"]["scrap"]), 100)

func test_loaded_signal_emitted() -> void:
	watch_signals(gs)
	gs.load_game(DEFS, 5000)
	assert_signal_emitted(gs, "loaded")

func test_saves_on_application_pause() -> void:
	gs.load_game(DEFS, 5000)
	gs.data["currencies"]["scrap"] = 777
	gs.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var raw := SaveIO.new(TEST_PATH).read()
	assert_eq(int(raw["currencies"]["scrap"]), 777)
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: FAIL (`game_state.gd` and `TimeUtil` do not exist).

- [ ] **Step 3: Write the implementations**

`game/core/time_util.gd`:

```gdscript
class_name TimeUtil
## The single wall-clock read point. All other code takes `now: int` params.


static func now() -> int:
	return int(Time.get_unix_time_from_system())
```

`game/autoload/game_state.gd`:

```gdscript
extends Node
## Owns the one save dict. Services (Economy, TimerService) mutate sub-dicts
## of `data` by reference; saving is serializing this dict (spec 7.2, 7.3).

signal loaded

var data: Dictionary = {}
var _io: SaveIO = SaveIO.new()


func _ready() -> void:
	load_game(DataDefs.economy, TimeUtil.now())


func load_game(defs: Dictionary, now: int) -> void:
	var raw := _io.read()
	var migrated: Dictionary = SaveSchema.migrate(raw) if not raw.is_empty() else {}
	if migrated.is_empty():
		migrated = SaveSchema.default_data(defs)
		migrated["created_at"] = now
		migrated["fuel"]["updated_at"] = now
	data = migrated
	loaded.emit()


func save_game() -> Error:
	return _io.write(data)


func _notification(what: int) -> void:
	# Save-anywhere: the OS backgrounding or closing the app never loses state.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
```

- [ ] **Step 4: Register the autoload**

The `[autoload]` section of `project.godot` becomes (order matters; GameState reads DataDefs in `_ready`):

```ini
[autoload]

DataDefs="*res://game/autoload/data_defs.gd"
GameState="*res://game/autoload/game_state.gd"
```

- [ ] **Step 5: Run tests to verify they pass**

Same command. Expected: PASS (29 tests total). Note the real `GameState` autoload will now write `user://save.json` on test runs that trigger it; tests only touch `user://test_gamestate.json` via injected `_io`, so they stay isolated.

- [ ] **Step 6: Commit**

```bash
git add game/core/time_util.gd game/autoload/game_state.gd tests/test_game_state.gd project.godot
git commit -m "feat: add GameState autoload with versioned load, fallback, and save-on-pause"
```

---

### Task 6: Economy autoload

**Files:**
- Create: `game/autoload/economy.gd`
- Modify: `project.godot` (`[autoload]` section)
- Test: `tests/test_economy.gd`

**Interfaces:**
- Consumes: `GameState.data["currencies"]` (Task 5), `SaveSchema.default_data` (Task 4, used in tests).
- Produces: autoload `Economy` (Node):
  - `signal balance_changed(currency: String, amount: int)`
  - `func setup(state: Node) -> void` (dependency injection for tests; `_ready` defaults to the `GameState` autoload)
  - `func balance(currency: String) -> int`
  - `func add(currency: String, amount: int) -> void`
  - `func spend(currency: String, amount: int) -> bool`
  - `func can_afford(cost: Dictionary) -> bool` and `func pay(cost: Dictionary) -> bool` (cost is `{currency: amount}`, pay is all-or-nothing)

  Plan 2 pays out runs via `add`; Plan 4 charges building costs via `pay`. Currency ids are the JSON keys: `"scrap"`, `"cloudsilk"`, `"crystals"`.

- [ ] **Step 1: Write the failing tests**

`tests/test_economy.gd`:

```gdscript
extends GutTest

const EconomyScript := preload("res://game/autoload/economy.gd")
const GameStateScript := preload("res://game/autoload/game_state.gd")
const DEFS := {
	"starting_balances": {"scrap": 100, "cloudsilk": 0, "crystals": 10},
	"fuel": {"starting": 5, "cap": 5, "regen_seconds": 1200},
}

var econ
var state


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.data = SaveSchema.default_data(DEFS)
	econ = autofree(EconomyScript.new())
	econ.setup(state)


func test_starting_balances() -> void:
	assert_eq(econ.balance("scrap"), 100)
	assert_eq(econ.balance("crystals"), 10)
	assert_eq(econ.balance("unknown_currency"), 0)

func test_add_increases_balance_and_emits() -> void:
	watch_signals(econ)
	econ.add("scrap", 10)
	assert_eq(econ.balance("scrap"), 110)
	assert_signal_emitted_with_parameters(econ, "balance_changed", ["scrap", 110])

func test_spend_success() -> void:
	assert_true(econ.spend("scrap", 40))
	assert_eq(econ.balance("scrap"), 60)

func test_spend_insufficient_funds_fails_without_change() -> void:
	assert_false(econ.spend("scrap", 101))
	assert_eq(econ.balance("scrap"), 100)

func test_can_afford_multi_currency() -> void:
	assert_true(econ.can_afford({"scrap": 100, "crystals": 10}))
	assert_false(econ.can_afford({"scrap": 100, "crystals": 11}))

func test_pay_is_all_or_nothing() -> void:
	assert_false(econ.pay({"scrap": 50, "crystals": 11}))
	assert_eq(econ.balance("scrap"), 100, "failed pay must not partially charge")
	assert_true(econ.pay({"scrap": 50, "crystals": 5}))
	assert_eq(econ.balance("scrap"), 50)
	assert_eq(econ.balance("crystals"), 5)

func test_mutations_land_in_state_dict() -> void:
	econ.add("scrap", 1)
	assert_eq(int(state.data["currencies"]["scrap"]), 101,
		"Economy must mutate GameState.data so saves capture it")
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: FAIL (`economy.gd` does not exist).

- [ ] **Step 3: Write the implementation**

`game/autoload/economy.gd`:

```gdscript
extends Node
## Currency faucets and sinks (spec 4.2). Operates on GameState.data by
## reference so every mutation is automatically captured by the next save.

signal balance_changed(currency: String, amount: int)

var _state: Node


func setup(state: Node) -> void:
	_state = state


func _ready() -> void:
	if _state == null:
		setup(GameState)


func _currencies() -> Dictionary:
	return _state.data["currencies"]


func balance(currency: String) -> int:
	return int(_currencies().get(currency, 0))


func add(currency: String, amount: int) -> void:
	assert(amount >= 0, "use spend() to remove currency")
	_currencies()[currency] = balance(currency) + amount
	balance_changed.emit(currency, balance(currency))


func spend(currency: String, amount: int) -> bool:
	if balance(currency) < amount:
		return false
	_currencies()[currency] = balance(currency) - amount
	balance_changed.emit(currency, balance(currency))
	return true


func can_afford(cost: Dictionary) -> bool:
	for currency in cost:
		if balance(currency) < int(cost[currency]):
			return false
	return true


func pay(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for currency in cost:
		spend(currency, int(cost[currency]))
	return true
```

- [ ] **Step 4: Register the autoload**

`[autoload]` section becomes:

```ini
[autoload]

DataDefs="*res://game/autoload/data_defs.gd"
GameState="*res://game/autoload/game_state.gd"
Economy="*res://game/autoload/economy.gd"
```

- [ ] **Step 5: Run tests to verify they pass**

Same command. Expected: PASS (36 tests total).

- [ ] **Step 6: Commit**

```bash
git add game/autoload/economy.gd tests/test_economy.gd project.godot
git commit -m "feat: add Economy autoload with balances, all-or-nothing pay, and signals"
```

---

### Task 7: TimerService autoload

**Files:**
- Create: `game/autoload/timer_service.gd`
- Modify: `project.godot` (`[autoload]` section)
- Test: `tests/test_timer_service.gd`

**Interfaces:**
- Consumes: `GameState.data["timers"]` (Task 5).
- Produces: autoload `TimerService` (Node):
  - `signal timer_started(id: String)` and `signal timer_collected(id: String, payload: Dictionary)`
  - `func setup(state: Node) -> void`
  - `func start(id: String, kind: String, duration_sec: int, now: int, payload: Dictionary = {}) -> bool` (false if the id already exists)
  - `func remaining(id: String, now: int) -> int`
  - `func is_done(id: String, now: int) -> bool`
  - `func collect(id: String, now: int) -> Dictionary` (removes the timer and returns its payload; `{}` if not done)
  - `func skip(id: String) -> void` (crystal/ad accelerator hook, spec section 6 placement 1)
  - `func active_timers() -> Dictionary`

  Timer record shape in the save: `{"kind": String, "ends_at": int, "payload": Dictionary}` keyed by id. Plan 4 uses kind `"construction"` and `"craft"`; Plan 5's notification scheduler iterates `active_timers()`.

- [ ] **Step 1: Write the failing tests**

`tests/test_timer_service.gd`:

```gdscript
extends GutTest

const TimerServiceScript := preload("res://game/autoload/timer_service.gd")
const GameStateScript := preload("res://game/autoload/game_state.gd")

var timers
var state


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.data = {"timers": {}}
	timers = autofree(TimerServiceScript.new())
	timers.setup(state)


func test_start_and_remaining() -> void:
	assert_true(timers.start("build_workshop", "construction", 600, 1000))
	assert_eq(timers.remaining("build_workshop", 1300), 300)
	assert_eq(timers.remaining("build_workshop", 2000), 0)

func test_start_emits_signal() -> void:
	watch_signals(timers)
	timers.start("t1", "craft", 600, 1000)
	assert_signal_emitted_with_parameters(timers, "timer_started", ["t1"])

func test_duplicate_id_rejected() -> void:
	timers.start("t1", "craft", 600, 1000)
	assert_false(timers.start("t1", "craft", 600, 1000))

func test_collect_only_when_done() -> void:
	timers.start("t1", "craft", 600, 1000, {"gizmo": "wind_fan"})
	assert_eq(timers.collect("t1", 1599), {})
	assert_true(timers.active_timers().has("t1"), "early collect must not consume the timer")
	assert_eq(timers.collect("t1", 1600), {"gizmo": "wind_fan"})
	assert_false(timers.active_timers().has("t1"))

func test_collect_emits_signal() -> void:
	timers.start("t1", "craft", 600, 1000, {"gizmo": "wind_fan"})
	watch_signals(timers)
	timers.collect("t1", 2000)
	assert_signal_emitted_with_parameters(timers, "timer_collected", ["t1", {"gizmo": "wind_fan"}])

func test_skip_completes_immediately() -> void:
	timers.start("t1", "construction", 99999, 1000)
	timers.skip("t1")
	assert_true(timers.is_done("t1", 1001))

func test_unknown_ids_are_safe() -> void:
	assert_eq(timers.remaining("nope", 1000), 0)
	assert_false(timers.is_done("nope", 1000))
	assert_eq(timers.collect("nope", 1000), {})

func test_timers_land_in_state_dict() -> void:
	timers.start("t1", "craft", 600, 1000)
	assert_true(state.data["timers"].has("t1"),
		"TimerService must mutate GameState.data so saves capture it")
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: FAIL (`timer_service.gd` does not exist).

- [ ] **Step 3: Write the implementation**

`game/autoload/timer_service.gd`:

```gdscript
extends Node
## Construction/craft timers (spec 5, 7.1): Unix timestamps persisted in the
## save, elapsed time computed on resume. No Godot Timer nodes, no background
## execution assumed. Callers pass `now` explicitly.

signal timer_started(id: String)
signal timer_collected(id: String, payload: Dictionary)

var _state: Node


func setup(state: Node) -> void:
	_state = state


func _ready() -> void:
	if _state == null:
		setup(GameState)


func _timers() -> Dictionary:
	return _state.data["timers"]


func start(id: String, kind: String, duration_sec: int, now: int, payload: Dictionary = {}) -> bool:
	if _timers().has(id):
		return false
	_timers()[id] = {"kind": kind, "ends_at": now + duration_sec, "payload": payload}
	timer_started.emit(id)
	return true


func remaining(id: String, now: int) -> int:
	if not _timers().has(id):
		return 0
	return maxi(0, int(_timers()[id]["ends_at"]) - now)


func is_done(id: String, now: int) -> bool:
	return _timers().has(id) and now >= int(_timers()[id]["ends_at"])


func collect(id: String, now: int) -> Dictionary:
	if not is_done(id, now):
		return {}
	var payload: Dictionary = _timers()[id].get("payload", {})
	_timers().erase(id)
	timer_collected.emit(id, payload)
	return payload


func skip(id: String) -> void:
	# Accelerator hook for rewarded ads / crystal timer skips (spec 6).
	if _timers().has(id):
		_timers()[id]["ends_at"] = 0


func active_timers() -> Dictionary:
	return _timers()
```

- [ ] **Step 4: Register the autoload**

`[autoload]` section becomes:

```ini
[autoload]

DataDefs="*res://game/autoload/data_defs.gd"
GameState="*res://game/autoload/game_state.gd"
Economy="*res://game/autoload/economy.gd"
TimerService="*res://game/autoload/timer_service.gd"
```

- [ ] **Step 5: Run tests to verify they pass**

Same command. Expected: PASS (44 tests total).

- [ ] **Step 6: Commit**

```bash
git add game/autoload/timer_service.gd tests/test_timer_service.gd project.godot
git commit -m "feat: add TimerService autoload with persisted unix-timestamp timers"
```

---

### Task 8: AdService seam

**Files:**
- Create: `game/core/ad_service.gd`
- Create: `game/core/grant_ad_service.gd`
- Create: `game/autoload/ads.gd`
- Modify: `project.godot` (`[autoload]` section)
- Test: `tests/test_ad_service.gd`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class_name AdService extends RefCounted`: `enum Placement { TIMER_SKIP, FUEL_REFILL, PAYOUT_DOUBLE, BONUS_CRATE }`, `func is_available(placement: Placement) -> bool` (base: false), `func request_reward(placement: Placement, on_granted: Callable) -> void` (base: never calls back). The four placements map to spec section 6 placements 1-4 (placement 5, boon reroll, is post-MVP).
  - `class_name GrantAdService extends AdService`: always available, grants synchronously.
  - Autoload `Ads` (Node) exposing `var service: AdService`. All game code calls `Ads.service.request_reward(...)`; nothing outside this task may reference a concrete implementation. Plans 4 and 5 wire placements to `TimerService.skip`, fuel refill, payout doubling, and the bonus crate.
  - Naming note: the spec's structure sketch calls the autoload `AdService.gd`; the autoload here is named `Ads` because Godot forbids an autoload sharing its name with a `class_name`, and `AdService` is the interface class.

- [ ] **Step 1: Write the failing tests**

`tests/test_ad_service.gd`:

```gdscript
extends GutTest


func test_base_service_is_never_available() -> void:
	var svc := AdService.new()
	assert_false(svc.is_available(AdService.Placement.FUEL_REFILL))

func test_base_service_never_grants() -> void:
	var svc := AdService.new()
	var granted := [false]
	svc.request_reward(AdService.Placement.FUEL_REFILL, func() -> void: granted[0] = true)
	assert_false(granted[0])

func test_grant_service_is_always_available() -> void:
	var svc := GrantAdService.new()
	assert_true(svc.is_available(AdService.Placement.TIMER_SKIP))

func test_grant_service_grants_immediately() -> void:
	var svc := GrantAdService.new()
	var granted := [false]
	svc.request_reward(AdService.Placement.PAYOUT_DOUBLE, func() -> void: granted[0] = true)
	assert_true(granted[0])

func test_ads_autoload_serves_grant_implementation_in_mvp() -> void:
	assert_true(Ads.service is GrantAdService)
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: FAIL (`AdService`, `GrantAdService`, `Ads` do not exist).

- [ ] **Step 3: Write the implementations**

`game/core/ad_service.gd`:

```gdscript
class_name AdService
extends RefCounted
## The single seam all ad interactions go through (spec 6). Implementations:
## GrantAdService (MVP and Play Pass builds) auto-grants every reward;
## AdmobAdService (post-MVP, free build only) shows real rewarded video.
## Game code must only ever talk to Ads.service, never to an implementation.

enum Placement { TIMER_SKIP, FUEL_REFILL, PAYOUT_DOUBLE, BONUS_CRATE }


func is_available(_placement: Placement) -> bool:
	return false


func request_reward(_placement: Placement, _on_granted: Callable) -> void:
	pass
```

`game/core/grant_ad_service.gd`:

```gdscript
class_name GrantAdService
extends AdService
## Every placement is available and grants instantly. Used by the MVP (spec 8:
## "AdService stubbed") and permanently by the Play Pass build (spec 6).


func is_available(_placement: Placement) -> bool:
	return true


func request_reward(_placement: Placement, on_granted: Callable) -> void:
	on_granted.call()
```

`game/autoload/ads.gd`:

```gdscript
extends Node
## Picks the AdService implementation at boot. The MVP ships GrantAdService
## only (spec 8). Post-MVP, the free build's export preset defines an "admob"
## feature tag and this becomes:
##   service = AdmobAdService.new() if OS.has_feature("admob") else GrantAdService.new()

var service: AdService


func _init() -> void:
	service = GrantAdService.new()
```

- [ ] **Step 4: Register the autoload**

`[autoload]` section becomes (final state for this plan):

```ini
[autoload]

DataDefs="*res://game/autoload/data_defs.gd"
GameState="*res://game/autoload/game_state.gd"
Economy="*res://game/autoload/economy.gd"
TimerService="*res://game/autoload/timer_service.gd"
Ads="*res://game/autoload/ads.gd"
```

- [ ] **Step 5: Run tests to verify they pass**

Same command. Expected: PASS (49 tests total).

- [ ] **Step 6: Commit**

```bash
git add game/core/ad_service.gd game/core/grant_ad_service.gd game/autoload/ads.gd tests/test_ad_service.gd project.godot
git commit -m "feat: add AdService seam with auto-granting MVP implementation"
```

---

### Task 9: Boot scene wiring

**Files:**
- Create: `game/main.gd`
- Create: `game/main.tscn`
- Modify: `project.godot` (`[application]` section: set the main scene)
- Test: `tests/test_main_boot.gd`

**Interfaces:**
- Consumes: `GameState.data`, `Economy.balance` / `balance_changed`, `FuelModel.current`, `TimeUtil.now()`.
- Produces: a runnable game (blank portrait screen with a live debug readout of scrap, crystals, and fuel) proving the whole autoload stack boots on a device-shaped viewport. Plan 2 replaces this scene's body with the skyfield/island navigation; the label pattern (subscribe to `Economy.balance_changed`) becomes the currency HUD.

- [ ] **Step 1: Write the failing test**

`tests/test_main_boot.gd`:

```gdscript
extends GutTest


func test_main_scene_boots_and_shows_balances() -> void:
	var main: Control = add_child_autofree(preload("res://game/main.tscn").instantiate())
	await wait_frames(1)
	var text: String = main.get_node("DebugLabel").text
	assert_string_contains(text, "Scrap: ")
	assert_string_contains(text, "Fuel: ")
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: FAIL (`main.tscn` does not exist).

- [ ] **Step 3: Write the scene and script**

`game/main.gd`:

```gdscript
extends Control
## Temporary boot scene: proves the autoload stack works end to end.
## Plan 2 replaces the body with real island/skyfield navigation.

@onready var debug_label: Label = $DebugLabel


func _ready() -> void:
	Economy.balance_changed.connect(_refresh)
	_refresh("", 0)


func _refresh(_currency: String, _amount: int) -> void:
	var fuel: Dictionary = GameState.data["fuel"]
	debug_label.text = "Scrap: %d\nCrystals: %d\nFuel: %d/%d" % [
		Economy.balance("scrap"),
		Economy.balance("crystals"),
		FuelModel.current(fuel, TimeUtil.now()),
		int(fuel["cap"]),
	]
```

`game/main.tscn` (Godot will add uid attributes on first editor open; that diff is fine to commit):

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
```

- [ ] **Step 4: Set the main scene**

In `project.godot`, the `[application]` section becomes:

```ini
[application]

config/name="Windfall Isles"
run/main_scene="res://game/main.tscn"
config/features=PackedStringArray("4.6")
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
$GODOT --headless --import
$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: PASS (50 tests total).

- [ ] **Step 6: Manual smoke check (optional but recommended)**

```bash
$GODOT
```

Expected: a 720x1280 portrait window showing `Scrap: 100`, `Crystals: 10`, `Fuel: 5/5`. Close the window; confirm `user://save.json` exists (macOS: `ls ~/Library/Application\ Support/Godot/app_userdata/Windfall\ Isles/`).

- [ ] **Step 7: Commit**

```bash
git add game/main.gd game/main.tscn tests/test_main_boot.gd project.godot
git commit -m "feat: add boot scene with live currency and fuel debug readout"
```

---

## Follow-on plans (to be written after this plan is executed)

Each subsequent plan is written only after the previous one lands, so its interfaces reference code that actually exists. Planned sequence:

- **Plan 2, Salvage run loop:** skyfield board scene (StaticBody2D natural pegs, walls, 3-5 collection barges), RigidBody2D pods with a simultaneous-pod hard cap, tap/drag drop controller along the top edge, payout resolution into `Economy.add`, fuel spend via `FuelModel.spend` to launch, 8-12 drops per run, run results screen, abandon-anytime with loot intact. (Spec 3.1, 3.2.)
- **Plan 3, Gizmo system:** the common gizmo trigger interface as self-contained scenes, the 8 MVP gizmos from spec 3.3, gizmo inventory in `GameState.data["gizmos"]`, ~6 slot anchors on the skyfield, and the pre-run slotting UI. (Spec 3.3.)
- **Plan 4, Home island:** island scene with plots in `GameState.data["island"]`, the 6 buildings as data defs in `game/data/buildings.json`, construction via `TimerService` kind `"construction"` with one free build slot, Workshop crafts (kind `"craft"`) producing gizmos, Wind Still raising fuel cap/regen, idle scrap trickle, daily crate. (Spec 4.1-4.4, 5.)
- **Plan 5, Retention and glue:** scene navigation between island and skyfield, shared currency HUD, quota tiers within runs, the notification-scheduler plugin (schedule on background, cancel on resume, POST_NOTIFICATIONS asked at first construction completion), wiring the four `AdService.Placement`s into the UI, Android export preset (AAB, arm64-v8a, portrait lock). (Spec 3.2 step 4, 5, 6, and the export row of 7.1.)

MVP cut line (spec section 8) is fully covered by Plans 1-5; everything the spec lists as "Out" stays out.
