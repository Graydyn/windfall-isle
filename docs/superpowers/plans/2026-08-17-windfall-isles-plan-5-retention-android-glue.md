# Windfall Isles Plan 5: Retention and Android Glue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the MVP cut line: local notifications for all four return hooks, the four rewarded-ad placements wired through AdService, in-run quota tiers, the deferred save-hardening and UI-polish backlog, board-data-driven skyfield geometry, and the Android export scaffolding (preset, icon, project config).

**Architecture:** All new rules live in pure classes taking explicit `now: int` and defs dicts (`AdLimits`, `NotificationPlanner`, quota logic inside `RunModel`), following the FuelModel pattern. Notifications and ads each go through a single seam (`NotificationScheduler`, the existing `AdService`) whose production Android implementations are vendored at Android-build time; the in-repo implementations are the no-op scheduler and `GrantAdService`. Save schema bumps to v5 (ad daily counters, notification-permission flag) and `migrate` gains a key backfill so structurally damaged current-version saves self-heal. Screens keep their dumb-UI discipline but stop rebuilding rows every second: a structural signature gates rebuilds, labels update in place.

**Tech Stack:** Godot 4.6.3 GDScript, GUT 9.6.1 headless, JSON data files.

**Spec:** [docs/design/2026-08-15-windfall-isles-design.md](../design/2026-08-15-windfall-isles-design.md) sections 3.2 (quota tiers), 5 (return hooks and local notifications), 6 (ad placements and the AdService rule), 7.1 (notification plugin choice), 7.3 (save integrity), 8 (MVP cut line). Plans 1 through 4 are merged on main.

**MVP scoping rulings (recorded here, argued from spec):**

- **Quota tiers are measured in scrap** (the common currency and primary run payout, spec 4.2). Crossing a tier applies that tier's payout multiplier to every LATER catch in the run; the crossing catch pays at the old tier. This is the honest MVP reading of "lifts the airship to a richer tier (denser loot)". Boons, and therefore the boon-reroll ad placement, stay post-MVP exactly as spec 3.2 and 6 mark them; `AdService.Placement` keeps its four members.
- **Notifications ship as complete in-repo logic** (pure planner, autoload service, scheduler seam) running against the no-op base scheduler. Vendoring the cengiz-pz notification-scheduler plugin binary is an Android-build step that happens alongside real AdMob integration (both spec-8 post-MVP externals). Spec 7.1's plugin choice stands; the seam's `schedule/cancel_all/request_permission` methods mirror what that plugin needs.
- **Ad daily limits are data:** fuel refills 2 per day, bonus crate 1 per day, in `retention.json`. Limits are consumed at GRANT time, not request time, so a dismissed real ad never burns the limit. The payout-double placement is once per run and not day-limited (spec 6 places no daily cap on it).
- **The export preset is configuration only.** Producing an AAB needs the Android SDK and export templates, which is outside this repo's test loop. A GUT test pins the preset's load-bearing values (platform, AAB format, arm64, exclude filters) so they cannot silently rot.
- **The icon is a placeholder SVG** pending the image-agent art pass (see docs/art/placeholder-graphics-audit.md section 3.3). It exists so the export preset and `application/config/icon` have a real target.

## Global Constraints

- Engine: Godot 4.6.x pinned; `$GODOT` = `/Applications/Godot-4.6.app/Contents/MacOS/Godot` (4.6.3). Never plain `godot` or `/Applications/Godot.app` (4.7).
- GDScript only; tabs. Every tunable in `game/data/*.json` (spec 7.2). Timers are Unix timestamps persisted in the save, elapsed computed on resume (spec 7.1); logic takes `now: int`, only boundaries call `TimeUtil.now()`.
- Save schema versioned (spec 7.3); this plan bumps to v5. Real v4 saves must gain the new sections losslessly; v1/v2/v3 saves hop the whole chain. A save from a NEWER version must never be destroyed: it is parked as `save.json.incompatible` before defaults are written.
- All ad interactions go through `Ads.service` (spec 6), never an implementation class. When a placement is unavailable, its UI hides (spec 6: offline placements "simply hide").
- `TimerService.active_timers()` is READ-ONLY for consumers: the notification planner reads the persisted timers dict, it never mutates it. `TimerService.skip()` emits no signal; screens rebuild after granting a skip and the player collects through the normal button.
- Crystal sinks are accelerators or breadth, never exclusive progression (spec 4.2). Rewarded ads are optional accelerators only; no placement gates progression (spec 6).
- Canonical test command (must exit 0): `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- Binding repo lessons (Plans 1-4): `.gd.uid` sidecars committed for EVERY new script including tests, verified via `git status --porcelain` after `--import` shows no untracked `.gd.uid`; error-count assertions AFTER the trigger; `int()`/`float()` wrap all JSON reads; int-cast scalar assertions against JSON-sourced dicts; scene-owned child Timer + `weakref()` (never SceneTreeTimer with raw objects); `await wait_physics_frames(2)` before velocity asserts; `assert_signal_emitted_with_parameters` takes no message arg; explicit types where `:=` inference hits untyped chains; no cumulative suite totals (per-task new-test lists only); physics-world-mutating handlers need one real-contact integration proof (not applicable here: this plan adds no physics mutators); `add_child.call_deferred` inside physics-flush paths; GUT stub name collisions avoided via distinct inner-class names (`RecordingScheduler`, not `stub`).
- UI tests never press buttons that change scenes; state assertions via direct handler calls; GameState `_io` swap + `after_all` restore pattern (four-arg `load_game` with `DataDefs.gizmos` and `DataDefs.buildings`).
- The sandbox rejects compound bash commands (for-loops, `&&` chains); run commands one at a time.
- Commit after every task, conventional-commit messages. No em dashes in any file this plan creates.

## Interfaces consumed from Plans 1-4 (merged on main, exact)

- `TimerService` autoload: `start(id, kind, duration_sec, now, payload={}) -> bool`, `remaining(id, now) -> int`, `is_done(id, now) -> bool`, `collect(id, now) -> Dictionary` ({} if not done), `skip(id)` (sets `ends_at` to 0, no signal), `active_timers() -> Dictionary` (the live save sub-dict: `{id: {"kind", "ends_at", "payload"}}`). Timer id conventions: `"build_<plot>"` kind `"construction"` payload `{"plot", "building", "to_level"}`; `"craft_<gizmo_id>"` kind `"craft"` payload `{"gizmo"}`.
- `Economy` autoload: `balance`, `add`, `spend`, `can_afford(cost)`, `pay(cost) -> bool`, signal `balance_changed(currency, amount)`.
- `GameState`: `data`, `save_game() -> Error`, `load_game(defs, now, gizmo_defs = {}, building_defs = {}) -> void`, `_io: SaveIO` injectable, `_notification` saves on `NOTIFICATION_APPLICATION_PAUSED` / `NOTIFICATION_WM_CLOSE_REQUEST`.
- `SaveIO`: `_init(path = "user://save.json")`, `write(data) -> Error` (tmp-then-rename plus `.bak`), `read() -> Dictionary` ({} when nothing parses), fields `save_path/tmp_path/backup_path`.
- `SaveSchema`: `CURRENT_VERSION == 4`, `default_data(defs, gizmo_defs={})`, `migrate(data, gizmo_defs={}) -> Dictionary` ({} on version <= 0 or > CURRENT), `_fresh_island()`, `_fresh_gizmos(gizmo_defs)`.
- `FuelModel`: `materialize(fuel, now)`, `current(fuel, now) -> int`, `spend(fuel, amount, now) -> bool`, `seconds_until_full(fuel, now) -> int`.
- `DailyCrate`: `SECONDS_PER_DAY == 86400`, `day_of(now) -> int`, `can_claim(data, now) -> bool`, `claim(data, retention_defs, now) -> Dictionary`.
- `TrickleModel.pending(data, building_defs, now) -> int`; `CraftModel` (`craft_slots`, `active_crafts`, `start_craft`, `complete_craft`); `IslandModel` (`building_level`, `plot_of`, `active_constructions`, `_next_level_row`, `can_start_build`, `start_build`, `complete_build`, `unlock_second_slot`); `IslandEffects.apply_fuel(data, economy_defs, building_defs)` (idempotent), `IslandEffects.drops_per_run(run_defs, island, building_defs)`.
- `AdService` (RefCounted): `enum Placement { TIMER_SKIP, FUEL_REFILL, PAYOUT_DOUBLE, BONUS_CRATE }`, `is_available(placement) -> bool`, `request_reward(placement, on_granted: Callable) -> void`. `Ads.service` is a `GrantAdService` (always available, grants synchronously).
- `RunModel`: `_init(config)` reading `drops_per_run`/`max_active_pods`, `begin_drop`, `resolve_pod(payout)`, `add_bonus_loot(payout)`, `add_split_pod`, `abandon`, `loot: Dictionary`, signals `loot_changed`, `run_over`.
- `salvage_run.gd`: `model: RunModel`, `_compute_payout(pod, base)`, `_on_pod_caught(pod, payout, source="barge")`, `_refresh_hud()`, `_on_run_over()`; `Skyfield.build(region_defs, run_defs)`, `_build_walls/_build_pegs/_build_barges/_build_sea/_build_slots`, signal `pod_caught(pod, payout, source)`.
- `GizmoLoadout`: `loadout_for(gizmos_state, region_id)`, `owned(gizmos_state)`, `set_slot`, `next_choice`.
- `DataDefs`: `economy/run/gizmos/buildings/retention` dicts, `skyfield(region_id)`, `load_json(path)`.
- `TimeUtil.now() -> int`.

## File Structure

```
game/core/save_io.gd                      # T1 modify (write error checks, preserve_incompatible)
game/core/save_schema.gd                  # T1 modify (is_future_version), T2 modify (v5 + backfill)
game/autoload/game_state.gd               # T1 modify (park future saves, save on _ready)
tests/test_save_io.gd                     # T1 append
tests/test_game_state.gd                  # T1 append + cleanup-list edit
game/core/ad_limits.gd                    # T2 pure daily-cap model
game/data/retention.json                  # T2 modify (ads limits)
tests/test_save_schema.gd                 # T2 append + version-pin edits
tests/test_ad_limits.gd                   # T2
game/run/run_model.gd                     # T3 modify (quota tiers)
game/run/salvage_run.gd                   # T3 modify (tier multiplier + HUD), T4 modify (double button)
game/data/skyfields/region_1.json         # T3 modify (quota_tiers)
tests/test_run_model.gd                   # T3 append
tests/test_salvage_run.gd                 # T3 append, T4 append
game/main.gd + game/main.tscn             # T4 modify (fuel refill button)
game/run/salvage_run.tscn                 # T4 modify (DoubleButton)
tests/test_main_boot.gd                   # T4 modify (_io swap) + append
game/base/island_screen.gd/.tscn          # T5 modify (skips + bonus crate), T6 modify (permission hook), T7 rewrite (polish)
game/base/workshop_screen.gd              # T5 modify (skip), T8 rewrite (signature refresh)
tests/test_island_screen.gd               # T5 append, T6 append, T7 append
tests/test_workshop_screen.gd             # T5 append, T8 append
game/core/notification_scheduler.gd       # T6 seam base (no-op)
game/core/notification_planner.gd         # T6 pure planner
game/autoload/notification_svc.gd         # T6 autoload
project.godot                             # T6 modify (autoload), T10 modify (config/icon)
tests/test_notifications.gd               # T6
game/base/island_model.gd                 # T7 modify (build_rejection)
tests/test_island_model.gd                # T7 append
game/ui/loadout_screen.gd                 # T8 modify (per-tap save)
tests/test_loadout_screen.gd              # T8 append
game/run/skyfield.gd                      # T9 modify (board-driven sea/walls, barge validation)
tests/test_skyfield.gd                    # T9 append
export_presets.cfg                        # T10
icon.svg (+ icon.svg.import)              # T10
.gitignore                                # T10 modify (build/)
tests/test_export_config.gd               # T10
tests/test_retention_integration.gd       # T11 fake-clock end-to-end
```

---

### Task 1: Save hardening and boot persistence

**Files:**
- Modify: `game/core/save_io.gd`
- Modify: `game/core/save_schema.gd` (add `is_future_version`)
- Modify: `game/autoload/game_state.gd`
- Test: `tests/test_save_io.gd` (append), `tests/test_game_state.gd` (append + cleanup edit)

**Interfaces:**
- Consumes: `SaveIO.write/read`, `SaveSchema.migrate/CURRENT_VERSION`, `GameState.load_game`.
- Produces: `SaveIO.write` returns the first real error instead of silently renaming a truncated tmp file; `SaveIO.preserve_incompatible() -> Error` copies `save.json` to `save.json.incompatible`; `SaveSchema.is_future_version(data: Dictionary) -> bool`; `GameState.load_game` parks future-version saves before falling back to defaults; `GameState._ready` persists immediately after loading (headless `--quit-after` and first-session crashes never fire pause/close). T11 asserts the park end to end.

- [ ] **Step 1: Append the failing tests**

In `tests/test_save_io.gd`, extend `_delete_test_files` to also remove the parked copy, then append the new tests at the end of the file. The updated helper:

```gdscript
func _delete_test_files() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_save.json", "test_save.json.tmp", "test_save.json.bak", "test_save.json.incompatible"]:
		if dir.file_exists(f):
			dir.remove(f)
```

Appended tests:

```gdscript
func test_preserve_incompatible_parks_a_copy() -> void:
	io.write({"version": 99, "marker": "future"})
	assert_eq(io.preserve_incompatible(), OK)
	var parked: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH + ".incompatible"))
	assert_eq(String((parked as Dictionary)["marker"]), "future")
	assert_eq(io.read()["marker"], "future", "the original save is untouched")

func test_preserve_incompatible_with_no_save_is_a_quiet_ok() -> void:
	assert_eq(io.preserve_incompatible(), OK)
	assert_false(FileAccess.file_exists(TEST_PATH + ".incompatible"))
```

In `tests/test_game_state.gd`, extend `_delete_test_files` the same way:

```gdscript
func _delete_test_files() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_gamestate.json", "test_gamestate.json.tmp", "test_gamestate.json.bak", "test_gamestate.json.incompatible"]:
		if dir.file_exists(f):
			dir.remove(f)
```

Appended tests:

```gdscript
func test_future_version_save_is_parked_before_fallback() -> void:
	var io := SaveIO.new(TEST_PATH)
	io.write({"version": 99, "currencies": {"scrap": 1}})
	gs.load_game(DEFS, 7000)
	assert_eq(int(gs.data["version"]), SaveSchema.CURRENT_VERSION)
	var parked: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH + ".incompatible"))
	assert_eq(int((parked as Dictionary)["version"]), 99,
		"a save written by a newer app version is preserved for a future upgrade")

func test_garbage_versions_are_not_parked() -> void:
	var io := SaveIO.new(TEST_PATH)
	io.write({"version": 0, "currencies": {"scrap": 1}})
	gs.load_game(DEFS, 7000)
	assert_eq(int(gs.data["version"]), SaveSchema.CURRENT_VERSION)
	assert_false(FileAccess.file_exists(TEST_PATH + ".incompatible"),
		"unversioned garbage is corruption, not a future save")

func test_ready_persists_the_save_without_waiting_for_pause() -> void:
	var fresh = GameStateScript.new()
	fresh._io = SaveIO.new(TEST_PATH)
	add_child_autofree(fresh)
	await wait_physics_frames(1)
	assert_true(FileAccess.file_exists(TEST_PATH),
		"boot must write the (possibly migrated) save immediately")
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL. `preserve_incompatible` is a nonexistent function (script error surface in GUT), the park tests find no `.incompatible` file, and the `_ready` test finds no file at TEST_PATH.

- [ ] **Step 3: Implement**

In `game/core/save_io.gd`, replace `write` and add `preserve_incompatible`:

```gdscript
func write(data: Dictionary) -> Error:
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		# A truncated tmp file (full disk, dying battery) must never be
		# renamed over the good save.
		return write_error
	var dir := DirAccess.open(save_path.get_base_dir())
	if dir == null:
		return DirAccess.get_open_error()
	if FileAccess.file_exists(save_path):
		var copy_error := dir.copy(save_path, backup_path)
		if copy_error != OK:
			return copy_error
	return dir.rename(tmp_path, save_path)


func preserve_incompatible() -> Error:
	# A save written by a NEWER app version (sideload downgrade, rollback)
	# must never be overwritten with defaults; park a copy beside the save so
	# a later app upgrade can recover it (spec 7.3).
	if not FileAccess.file_exists(save_path):
		return OK
	var dir := DirAccess.open(save_path.get_base_dir())
	if dir == null:
		return DirAccess.get_open_error()
	return dir.copy(save_path, save_path + ".incompatible")
```

In `game/core/save_schema.gd`, add after `migrate`:

```gdscript
static func is_future_version(data: Dictionary) -> bool:
	return int(data.get("version", 0)) > CURRENT_VERSION
```

In `game/autoload/game_state.gd`, replace `_ready` and `load_game`:

```gdscript
func _ready() -> void:
	load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings)
	# Persist immediately: headless runs and first-session crashes never fire
	# the pause/close notifications, and a completed migration must not wait
	# for one to become durable.
	save_game()


func load_game(defs: Dictionary, now: int, gizmo_defs: Dictionary = {}, building_defs: Dictionary = {}) -> void:
	var raw := _io.read()
	var migrated: Dictionary = SaveSchema.migrate(raw, gizmo_defs) if not raw.is_empty() else {}
	if migrated.is_empty():
		if SaveSchema.is_future_version(raw):
			_io.preserve_incompatible()
		migrated = SaveSchema.default_data(defs, gizmo_defs)
		migrated["created_at"] = now
		migrated["fuel"]["updated_at"] = now
	data = migrated
	if not building_defs.is_empty():
		IslandEffects.apply_fuel(data, defs, building_defs)
	loaded.emit()
```

Note: the boot-time `save_game()` writes `user://save.json` in the dev/test environment too. That is intended behavior (the real singleton boots once per suite run); tests always replace `GameState.data` or `_io` in `before_each`, so no existing test reads that file.

- [ ] **Step 4: Run tests to verify everything passes**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0. The existing `test_unmigratable_save_falls_back_to_defaults` still passes (fallback behavior is unchanged; the park is additive).

- [ ] **Step 5: Commit**

```bash
git add game/core/save_io.gd game/core/save_schema.gd game/autoload/game_state.gd tests/test_save_io.gd tests/test_game_state.gd
git commit -m "feat: harden save IO and park future-version saves before fallback"
```

---

### Task 2: Save schema v5, key backfill, and the AdLimits model

**Files:**
- Modify: `game/core/save_schema.gd`
- Modify: `game/data/retention.json`
- Create: `game/core/ad_limits.gd`
- Test: `tests/test_save_schema.gd` (append + edits), `tests/test_ad_limits.gd` (new)

**Interfaces:**
- Consumes: `SaveSchema.default_data/migrate`, `DailyCrate.day_of`.
- Produces: `SaveSchema.CURRENT_VERSION == 5`; save gains `"ads": {"day": 0, "counts": {}}` and `"notifications": {"permission_requested": false}`; `migrate` backfills any missing top-level key with neutral defaults; `AdLimits.can_use(data, placement: String, limit: int, now: int) -> bool`, `AdLimits.use(data, placement, limit, now) -> bool` (counts one use, false when capped), `AdLimits.used(data, placement, now) -> int`; `DataDefs.retention["ads"]` carries `fuel_refills_per_day` and `bonus_crates_per_day`. T4/T5 call AdLimits with placement strings `"fuel_refill"` and `"bonus_crate"`; T6 reads the `"notifications"` section.

- [ ] **Step 1: Update version pins and append schema tests**

In `tests/test_save_schema.gd`, make these three edits to existing tests:

1. Replace the whole `test_current_version_is_four_and_defaults_grant_eight` function with:

```gdscript
func test_current_version_is_five_and_defaults_grant_eight() -> void:
	assert_eq(SaveSchema.CURRENT_VERSION, 5)
	var data := SaveSchema.default_data(DEFS, DataDefs.gizmos)
	assert_eq((data["gizmos"]["owned"] as Dictionary).size(), 8,
		"all eight MVP gizmos are starters until the Workshop lands (Plan 4)")
```

2. In `test_default_data_has_v4_island_shape`, change the line `assert_eq(int(data["version"]), 4)` to `assert_eq(int(data["version"]), SaveSchema.CURRENT_VERSION)`.

3. In `test_migrate_v3_to_v4_adds_island_losslessly`, change `assert_eq(int(migrated["version"]), 4)` to `assert_eq(int(migrated["version"]), 5)`. In `test_migrate_v1_hops_all_the_way_to_v4`, change `assert_eq(int(migrated["version"]), 4)` to `assert_eq(int(migrated["version"]), 5)` (leave both function names; renaming them would churn history for no behavior gain, and the bodies now assert the full chain).

Then append at the end of the file:

```gdscript
func test_migrate_4_to_5_adds_ads_and_notifications_losslessly() -> void:
	var v4 := {
		"version": 4, "created_at": 1, "currencies": {"scrap": 5},
		"fuel": {"amount": 1, "cap": 5, "regen_seconds": 1200, "updated_at": 0},
		"timers": {}, "island": {"plots": {}, "build_slots": 1},
		"trickle": {"last_collect": 0}, "daily_crate": {"last_claim_day": 0},
		"gizmos": {"owned": {"wind_fan": 2}, "loadout": {}},
	}
	var out := SaveSchema.migrate(v4)
	assert_eq(int(out["version"]), 5)
	assert_eq(out["ads"], {"day": 0, "counts": {}})
	assert_eq(out["notifications"], {"permission_requested": false})
	assert_eq(int(out["gizmos"]["owned"]["wind_fan"]), 2, "owned levels untouched")
	assert_eq(int(out["currencies"]["scrap"]), 5, "balances untouched")

func test_default_data_has_v5_sections() -> void:
	var data := SaveSchema.default_data(DEFS)
	assert_eq(data["ads"], {"day": 0, "counts": {}})
	assert_false(bool((data["notifications"] as Dictionary)["permission_requested"]))

func test_backfill_heals_missing_keys_on_current_version() -> void:
	var damaged := {"version": 5, "currencies": {"scrap": 7}}
	var out := SaveSchema.migrate(damaged, GIZMO_DEFS)
	assert_eq(int(out["currencies"]["scrap"]), 7, "existing keys untouched")
	for key in ["fuel", "timers", "island", "trickle", "daily_crate", "gizmos", "ads", "notifications"]:
		assert_has(out, key)
	assert_eq(int((out["fuel"] as Dictionary)["cap"]), 5, "neutral fuel defaults")
	assert_eq(out["gizmos"]["owned"], {"wind_fan": 1, "crystal_prism": 1},
		"backfilled gizmos grant the starting inventory")
```

- [ ] **Step 2: Write the failing AdLimits tests**

Create `tests/test_ad_limits.gd`:

```gdscript
extends GutTest

const NOW := 1_800_000_000


func make_data() -> Dictionary:
	return SaveSchema.default_data({}, {})


func test_fresh_data_allows_use_under_limit() -> void:
	assert_true(AdLimits.can_use(make_data(), "fuel_refill", 2, NOW))
	assert_eq(AdLimits.used(make_data(), "fuel_refill", NOW), 0)

func test_use_counts_up_to_the_limit() -> void:
	var data := make_data()
	assert_true(AdLimits.use(data, "fuel_refill", 2, NOW))
	assert_true(AdLimits.use(data, "fuel_refill", 2, NOW))
	assert_false(AdLimits.use(data, "fuel_refill", 2, NOW), "third use is over the cap")
	assert_eq(AdLimits.used(data, "fuel_refill", NOW), 2, "a rejected use never counts")

func test_placements_have_independent_counters() -> void:
	var data := make_data()
	assert_true(AdLimits.use(data, "fuel_refill", 1, NOW))
	assert_true(AdLimits.use(data, "bonus_crate", 1, NOW),
		"the fuel counter does not spend the crate counter")

func test_midnight_rollover_resets_counts() -> void:
	var data := make_data()
	assert_true(AdLimits.use(data, "bonus_crate", 1, NOW))
	assert_false(AdLimits.can_use(data, "bonus_crate", 1, NOW + 100))
	assert_true(AdLimits.can_use(data, "bonus_crate", 1, NOW + DailyCrate.SECONDS_PER_DAY),
		"fresh calendar day, fresh limit")
	assert_eq(AdLimits.used(data, "bonus_crate", NOW + DailyCrate.SECONDS_PER_DAY), 0)

func test_missing_ads_section_self_heals() -> void:
	var data := {"version": 5}
	assert_true(AdLimits.use(data, "fuel_refill", 1, NOW))
	assert_eq(int(((data["ads"] as Dictionary)["counts"] as Dictionary)["fuel_refill"]), 1)

func test_retention_defs_carry_ad_limits() -> void:
	var ads: Dictionary = DataDefs.retention.get("ads", {})
	assert_eq(int(ads.get("fuel_refills_per_day", 0)), 2)
	assert_eq(int(ads.get("bonus_crates_per_day", 0)), 1)
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL. `AdLimits` is an unknown class, `CURRENT_VERSION` is 4, `retention.json` has no `ads` key.

- [ ] **Step 4: Implement**

In `game/core/save_schema.gd`:

1. Change `const CURRENT_VERSION := 4` to `const CURRENT_VERSION := 5`.

2. In `default_data`, add two entries to the returned dict after the `"gizmos"` line:

```gdscript
		"gizmos": _fresh_gizmos(gizmo_defs),
		"ads": _fresh_ads(),
		"notifications": _fresh_notifications(),
```

3. Replace `migrate` with:

```gdscript
static func migrate(data: Dictionary, gizmo_defs: Dictionary = {}) -> Dictionary:
	var version := int(data.get("version", 0))
	if version <= 0 or version > CURRENT_VERSION:
		return {}
	if version == 1:
		data = _migrate_1_to_2(data, gizmo_defs)
	if int(data["version"]) == 2:
		data = _migrate_2_to_3(data, gizmo_defs)
	if int(data["version"]) == 3:
		data = _migrate_3_to_4(data)
	if int(data["version"]) == 4:
		data = _migrate_4_to_5(data)
	_backfill_missing_keys(data, gizmo_defs)
	return data
```

4. Add at the end of the file:

```gdscript
static func _migrate_4_to_5(data: Dictionary) -> Dictionary:
	# Retention/Android glue: rewarded-ad daily counters and the
	# notification-permission flag.
	data["ads"] = _fresh_ads()
	data["notifications"] = _fresh_notifications()
	data["version"] = 5
	return data


static func _fresh_ads() -> Dictionary:
	return {"day": 0, "counts": {}}


static func _fresh_notifications() -> Dictionary:
	return {"permission_requested": false}


static func _backfill_missing_keys(data: Dictionary, gizmo_defs: Dictionary) -> void:
	# A structurally damaged save of the current version (hand-edited, partial
	# write survived by the backup) heals to neutral defaults instead of
	# crashing consumers; healthy saves are untouched because every key exists.
	var defaults := default_data({}, gizmo_defs)
	for key in defaults:
		if not data.has(key):
			data[key] = defaults[key]
```

Replace `game/data/retention.json` with:

```json
{
	"daily_crate": {
		"scrap": 40,
		"crystals": 1
	},
	"ads": {
		"fuel_refills_per_day": 2,
		"bonus_crates_per_day": 1
	}
}
```

Create `game/core/ad_limits.gd`:

```gdscript
class_name AdLimits
## Per-calendar-day caps for rewarded-ad placements (spec 6: fuel refills are
## "limited per day"; the bonus crate is daily). Counts live in save.ads and
## reset lazily when DailyCrate.day_of rolls over; no midnight process exists.


static func _ads(data: Dictionary, now: int) -> Dictionary:
	if not data.has("ads"):
		data["ads"] = {}
	var ads: Dictionary = data["ads"]
	var today := DailyCrate.day_of(now)
	if int(ads.get("day", -1)) != today:
		ads["day"] = today
		ads["counts"] = {}
	if not ads.has("counts"):
		ads["counts"] = {}
	return ads


static func used(data: Dictionary, placement: String, now: int) -> int:
	return int((_ads(data, now)["counts"] as Dictionary).get(placement, 0))


static func can_use(data: Dictionary, placement: String, limit: int, now: int) -> bool:
	return used(data, placement, now) < limit


static func use(data: Dictionary, placement: String, limit: int, now: int) -> bool:
	# Call this at GRANT time, not request time: a dismissed rewarded ad must
	# never burn the daily limit.
	if not can_use(data, placement, limit, now):
		return false
	var counts: Dictionary = _ads(data, now)["counts"]
	counts[placement] = int(counts.get(placement, 0)) + 1
	return true
```

- [ ] **Step 5: Import and verify sidecars, run tests**

Run: `$GODOT --headless --import`
Run: `git status --porcelain` and confirm `game/core/ad_limits.gd.uid` and `tests/test_ad_limits.gd.uid` appear (they must be added in the commit).
Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0.

- [ ] **Step 6: Commit**

```bash
git add game/core/save_schema.gd game/core/ad_limits.gd game/core/ad_limits.gd.uid game/data/retention.json tests/test_save_schema.gd tests/test_ad_limits.gd tests/test_ad_limits.gd.uid
git commit -m "feat: save schema v5 with ad daily limits and notification flag, key backfill"
```

---

### Task 3: Quota tiers within runs

**Files:**
- Modify: `game/run/run_model.gd`
- Modify: `game/run/salvage_run.gd` (`_ready` config, `_compute_payout`, `_refresh_hud`)
- Modify: `game/data/skyfields/region_1.json`
- Test: `tests/test_run_model.gd` (append), `tests/test_salvage_run.gd` (append)

**Interfaces:**
- Consumes: `RunModel` internals, `salvage_run._compute_payout`.
- Produces: `RunModel.tiers: Array` from config key `"quota_tiers"` (array of `{"scrap_quota": int, "payout_multiplier": float}`, ascending), `RunModel.tier: int` (0 = base), signal `tier_reached(tier: int)`, `RunModel.payout_multiplier() -> float`; region JSON key `"quota_tiers"`; the HUD shows the current tier. T11 asserts tier lift on a scripted model.

- [ ] **Step 1: Append the failing RunModel tests**

Append to `tests/test_run_model.gd`:

```gdscript
func make_tiered(drops := 8) -> RunModel:
	return RunModel.new({
		"drops_per_run": drops,
		"max_active_pods": 4,
		"quota_tiers": [
			{"scrap_quota": 10, "payout_multiplier": 1.5},
			{"scrap_quota": 30, "payout_multiplier": 2.0},
		],
	})


func test_tier_starts_at_zero_with_no_multiplier() -> void:
	var model := make_tiered()
	assert_eq(model.tier, 0)
	assert_eq(model.payout_multiplier(), 1.0)

func test_reaching_scrap_quota_lifts_tier() -> void:
	var model := make_tiered()
	watch_signals(model)
	model.begin_drop()
	model.resolve_pod({"scrap": 10})
	assert_eq(model.tier, 1)
	assert_eq(model.payout_multiplier(), 1.5)
	assert_signal_emitted_with_parameters(model, "tier_reached", [1])

func test_one_catch_can_cross_multiple_tiers() -> void:
	var model := make_tiered()
	watch_signals(model)
	model.begin_drop()
	model.resolve_pod({"scrap": 45})
	assert_eq(model.tier, 2)
	assert_eq(model.payout_multiplier(), 2.0)
	assert_signal_emit_count(model, "tier_reached", 2)

func test_bonus_loot_counts_toward_quota() -> void:
	var model := make_tiered()
	model.add_bonus_loot({"scrap": 10})
	assert_eq(model.tier, 1, "Lightning Jar bonuses are salvage too")

func test_non_scrap_loot_ignores_quota() -> void:
	var model := make_tiered()
	model.begin_drop()
	model.resolve_pod({"cloudsilk": 50})
	assert_eq(model.tier, 0, "the quota is measured in scrap (spec 4.2 common currency)")

func test_no_tiers_config_never_lifts() -> void:
	var model := make_model()
	model.begin_drop()
	model.resolve_pod({"scrap": 999})
	assert_eq(model.tier, 0)
	assert_eq(model.payout_multiplier(), 1.0)
```

Append to `tests/test_salvage_run.gd`:

```gdscript
func test_tier_multiplier_applies_to_later_catches_only() -> void:
	scene.model = RunModel.new({
		"drops_per_run": 8, "max_active_pods": 4,
		"quota_tiers": [{"scrap_quota": 10, "payout_multiplier": 2.0}],
	})
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(pod, {"scrap": 10})
	assert_eq(scene.model.loot, {"scrap": 10}, "the crossing catch pays at the old tier")
	await wait_physics_frames(1)
	scene._on_drop_requested(300.0)
	var pod2: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(pod2, {"scrap": 10})
	assert_eq(int(scene.model.loot["scrap"]), 30, "tier 1 doubles the second catch")

func test_scene_reads_quota_tiers_from_region_data() -> void:
	assert_false(scene.model.tiers.is_empty(),
		"region_1 quota tiers must reach the run model")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: `tier`, `tiers`, `payout_multiplier` are unknown members of RunModel.

- [ ] **Step 3: Implement RunModel tiers**

In `game/run/run_model.gd`:

1. Add after the `run_over` signal: `signal tier_reached(tier: int)`.

2. Add after `var abandoned := false`:

```gdscript
var tiers: Array = []
var tier := 0
```

3. In `_init`, add after the `max_active_pods` line: `tiers = config.get("quota_tiers", [])`.

4. In `resolve_pod`, add `_check_tier()` between the loot loop and `loot_changed.emit(loot)`. The resulting function:

```gdscript
func resolve_pod(payout: Dictionary) -> void:
	pods_in_flight = maxi(0, pods_in_flight - 1)
	for currency in payout:
		loot[currency] = int(loot.get(currency, 0)) + int(payout[currency])
	_check_tier()
	loot_changed.emit(loot)
	_check_over()
```

5. In `add_bonus_loot`, add `_check_tier()` between the loot loop and `loot_changed.emit(loot)` the same way.

6. Add at the end of the file:

```gdscript
func payout_multiplier() -> float:
	# The multiplier of the highest tier reached; the base tier is 1.0.
	if tier <= 0:
		return 1.0
	return float((tiers[tier - 1] as Dictionary).get("payout_multiplier", 1.0))


func _check_tier() -> void:
	# Quota tiers (spec 3.2): the quota is measured in scrap collected this
	# run. One rich catch may cross several tiers; each lift is announced.
	while tier < tiers.size() and int(loot.get("scrap", 0)) >= int((tiers[tier] as Dictionary).get("scrap_quota", 0)):
		tier += 1
		tier_reached.emit(tier)
```

- [ ] **Step 4: Wire the scene and data**

In `game/data/skyfields/region_1.json`, add a top-level key after the `"board"` line:

```json
	"quota_tiers": [
		{"scrap_quota": 25, "payout_multiplier": 1.25},
		{"scrap_quota": 60, "payout_multiplier": 1.5}
	],
```

In `game/run/salvage_run.gd`:

1. In `_ready`, add after the `run_config["drops_per_run"]` line: `run_config["quota_tiers"] = region.get("quota_tiers", [])`.

2. Replace `_compute_payout` with:

```gdscript
func _compute_payout(pod: Node, base: Dictionary) -> Dictionary:
	# Central payout resolution: the run's quota-tier multiplier and the
	# pod-carried multipliers (Crystal Prism, Splitter Vane) apply here so
	# every catch path (barge, sea, watchdog) gets identical treatment.
	var mult := model.payout_multiplier()
	if is_instance_valid(pod) and pod.has_meta("value_mult"):
		mult *= float(pod.get_meta("value_mult"))
	if is_equal_approx(mult, 1.0):
		return base.duplicate()
	var out := {}
	for currency in base:
		var value := roundi(float(base[currency]) * mult)
		if value > 0:
			out[currency] = value
	return out
```

3. In `_refresh_hud`, replace the text assignment with:

```gdscript
	$UI/HudLabel.text = "Drops left: %d   Tier %d\n%s" % [model.drops_remaining(), model.tier, " ".join(parts)]
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0. Existing scene tests stay green: no existing test accumulates 25 scrap of loot in one scene, so region_1's first tier never triggers there.

- [ ] **Step 6: Commit**

```bash
git add game/run/run_model.gd game/run/salvage_run.gd game/data/skyfields/region_1.json tests/test_run_model.gd tests/test_salvage_run.gd
git commit -m "feat: quota tiers lift run payouts from region data"
```

---

### Task 4: Ad placements: fuel refill and payout double

**Files:**
- Modify: `game/main.gd`, `game/main.tscn`
- Modify: `game/run/salvage_run.gd`, `game/run/salvage_run.tscn`
- Test: `tests/test_main_boot.gd` (fixture hardening + append), `tests/test_salvage_run.gd` (append)

**Interfaces:**
- Consumes: `Ads.service` (`AdService.Placement.FUEL_REFILL`, `PAYOUT_DOUBLE`), `AdLimits` (T2), `FuelModel`, `DataDefs.retention["ads"]`.
- Produces: `main.gd` gains `_on_refill_pressed()`, `_grant_fuel_refill()`, `_refill_limit() -> int` and a `RefillButton` node; `salvage_run.gd` gains `_payout_doubled: bool`, `_on_double_pressed()`, `_grant_payout_double()` and a `UI/Results/VBox/DoubleButton` node. T5 follows the same request/grant split.

- [ ] **Step 1: Harden the main-boot fixture**

`test_main_boot.gd` currently leaves `GameState._io` pointing at the real save; the refill handler saves, so swap the IO like every other screen test. Replace the top of `tests/test_main_boot.gd` (through `after_all`) with:

```gdscript
extends GutTest

const MainScene := preload("res://game/main.tscn")
const TEST_SAVE := "user://test_main_boot.json"

var main


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy)
	GameState.data["created_at"] = 1000
	GameState.data["fuel"]["updated_at"] = 1000
	main = add_child_autofree(MainScene.instantiate())
	await wait_physics_frames(1)

func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_main_boot.json", "test_main_boot.json.tmp", "test_main_boot.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings)
```

- [ ] **Step 2: Append the failing tests**

Append to `tests/test_main_boot.gd`:

```gdscript
func test_refill_button_visible_with_grant_service() -> void:
	assert_true(main.get_node("RefillButton").visible,
		"GrantAdService makes every placement available")

func test_refill_button_disabled_at_full_tank() -> void:
	main._refresh()
	assert_true(main.get_node("RefillButton").disabled, "tank starts full")

func test_refill_grants_full_tank_and_counts_the_use() -> void:
	GameState.data["fuel"]["amount"] = 0
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	main._on_refill_pressed()
	assert_eq(FuelModel.current(GameState.data["fuel"], TimeUtil.now()), int(GameState.data["fuel"]["cap"]))
	assert_eq(AdLimits.used(GameState.data, "fuel_refill", TimeUtil.now()), 1)

func test_refill_stops_at_the_daily_limit() -> void:
	var limit := int((DataDefs.retention["ads"] as Dictionary)["fuel_refills_per_day"])
	for i in limit:
		GameState.data["fuel"]["amount"] = 0
		GameState.data["fuel"]["updated_at"] = TimeUtil.now()
		main._on_refill_pressed()
	GameState.data["fuel"]["amount"] = 0
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	main._on_refill_pressed()
	assert_eq(FuelModel.current(GameState.data["fuel"], TimeUtil.now()), 0,
		"spec 6: fuel refills are limited per day")
```

Append to `tests/test_salvage_run.gd`:

```gdscript
func test_double_payout_credits_loot_again_exactly_once() -> void:
	scene.model = RunModel.new({"drops_per_run": 1, "max_active_pods": 4})
	scene.model.run_over.connect(scene._on_run_over)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	var scrap_before := Economy.balance("scrap")
	scene._on_pod_caught(pod, {"scrap": 9})
	assert_eq(Economy.balance("scrap"), scrap_before + 9)
	assert_true(scene.get_node("UI/Results/VBox/DoubleButton").visible)
	scene._on_double_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 18, "double credits the run loot once more")
	scene._on_double_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 18, "double is once per run")
	assert_true(scene.get_node("UI/Results/VBox/DoubleButton").disabled)

func test_double_button_hidden_when_nothing_was_salvaged() -> void:
	scene.model = RunModel.new({"drops_per_run": 1, "max_active_pods": 4})
	scene.model.run_over.connect(scene._on_run_over)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	pod.set_meta("value_mult", 0.0)
	scene._on_pod_caught(pod, {"scrap": 1})
	assert_true(scene.get_node("UI/Results").visible)
	assert_false(scene.get_node("UI/Results/VBox/DoubleButton").visible,
		"nothing to double")
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: `RefillButton` and `DoubleButton` nodes do not exist; the handlers are undefined.

- [ ] **Step 4: Implement the scene nodes**

In `game/main.tscn`, add after the `GizmosButton` node block:

```
[node name="RefillButton" type="Button" parent="."]
offset_left = 160.0
offset_top = 800.0
offset_right = 560.0
offset_bottom = 860.0
text = "Refill fuel (ad)"
```

In `game/run/salvage_run.tscn`, add between the `Summary` node block and the `ReturnButton` node block (VBox order is declaration order):

```
[node name="DoubleButton" type="Button" parent="UI/Results/VBox"]
text = "Double payout (ad)"
```

- [ ] **Step 5: Implement the handlers**

In `game/main.gd`:

1. In `_ready`, add after the `$IslandButton` line: `$RefillButton.pressed.connect(_on_refill_pressed)`.

2. In `_refresh`, add before the `launch_button.disabled` line:

```gdscript
	$RefillButton.visible = Ads.service.is_available(AdService.Placement.FUEL_REFILL)
	$RefillButton.disabled = FuelModel.current(fuel, now) >= int(fuel["cap"]) \
		or not AdLimits.can_use(GameState.data, "fuel_refill", _refill_limit(), now)
```

3. Add at the end of the file:

```gdscript
func _on_refill_pressed() -> void:
	var now := TimeUtil.now()
	if not Ads.service.is_available(AdService.Placement.FUEL_REFILL):
		return
	if not AdLimits.can_use(GameState.data, "fuel_refill", _refill_limit(), now):
		return
	if FuelModel.current(GameState.data["fuel"], now) >= int(GameState.data["fuel"]["cap"]):
		return
	Ads.service.request_reward(AdService.Placement.FUEL_REFILL, _grant_fuel_refill)


func _grant_fuel_refill() -> void:
	# The limit is consumed at GRANT time so a dismissed real ad costs nothing.
	var now := TimeUtil.now()
	if not AdLimits.use(GameState.data, "fuel_refill", _refill_limit(), now):
		return
	var fuel: Dictionary = GameState.data["fuel"]
	FuelModel.materialize(fuel, now)
	fuel["amount"] = int(fuel["cap"])
	GameState.save_game()
	_refresh()


func _refill_limit() -> int:
	return int((DataDefs.retention.get("ads", {}) as Dictionary).get("fuel_refills_per_day", 2))
```

In `game/run/salvage_run.gd`:

1. Add after `var _next_barge_multiplier := 1.0`: `var _payout_doubled := false`.

2. In `_ready`, add after the ReturnButton connect line: `$UI/Results/VBox/DoubleButton.pressed.connect(_on_double_pressed)`.

3. In `_on_run_over`, add before `$UI/Results.visible = true`:

```gdscript
	$UI/Results/VBox/DoubleButton.visible = Ads.service.is_available(AdService.Placement.PAYOUT_DOUBLE) \
		and not model.loot.is_empty()
	$UI/Results/VBox/DoubleButton.disabled = false
```

4. Add at the end of the file:

```gdscript
func _on_double_pressed() -> void:
	if _payout_doubled or not Ads.service.is_available(AdService.Placement.PAYOUT_DOUBLE):
		return
	Ads.service.request_reward(AdService.Placement.PAYOUT_DOUBLE, _grant_payout_double)


func _grant_payout_double() -> void:
	# Once per run (spec 6 placement 3), credited straight to the economy;
	# model.loot stays the true single-run tally.
	if _payout_doubled:
		return
	_payout_doubled = true
	for currency in model.loot:
		Economy.add(currency, int(model.loot[currency]))
	GameState.save_game()
	$UI/Results/VBox/Summary.text = _summary_text() + "\nPayout doubled!"
	$UI/Results/VBox/DoubleButton.disabled = true
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0.

- [ ] **Step 7: Commit**

```bash
git add game/main.gd game/main.tscn game/run/salvage_run.gd game/run/salvage_run.tscn tests/test_main_boot.gd tests/test_salvage_run.gd
git commit -m "feat: wire fuel-refill and payout-double rewarded-ad placements"
```

---

### Task 5: Ad placements: timer skips and the bonus crate

**Files:**
- Modify: `game/base/island_screen.gd`, `game/base/island_screen.tscn`
- Modify: `game/base/workshop_screen.gd`
- Test: `tests/test_island_screen.gd` (append), `tests/test_workshop_screen.gd` (append)

**Interfaces:**
- Consumes: `Ads.service` (`TIMER_SKIP`, `BONUS_CRATE`), `AdLimits`, `TimerService.skip`, `DataDefs.retention`.
- Produces: both screens gain `_on_skip_pressed(timer_id: String)` and `_grant_skip(timer_id: String)`; island gains `_on_bonus_crate_pressed()`, `_grant_bonus_crate()`, `_bonus_crate_limit() -> int` and a `BonusCrateButton` node. T7/T8 rewrite these screens and must keep these exact handler names.

- [ ] **Step 1: Append the failing tests**

Append to `tests/test_island_screen.gd`:

```gdscript
func test_skip_completes_a_construction_timer() -> void:
	screen._on_select_pressed("plot_0")
	screen._on_build_pressed("plot_0")
	assert_true(TimerService.active_timers().has("build_plot_0"))
	screen._on_skip_pressed("build_plot_0")
	assert_true(TimerService.is_done("build_plot_0", TimeUtil.now()),
		"spec 6 placement 1: an ad skips the timer; the player still collects")

func test_bonus_crate_pays_and_respects_the_daily_limit() -> void:
	var scrap_before := Economy.balance("scrap")
	screen._on_bonus_crate_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 40)
	screen._on_bonus_crate_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 40, "bonus crate is once per day")

func test_bonus_crate_is_independent_of_the_free_crate() -> void:
	GameState.data["daily_crate"]["last_claim_day"] = 0
	var scrap_before := Economy.balance("scrap")
	screen._on_crate_pressed()
	screen._on_bonus_crate_pressed()
	assert_eq(Economy.balance("scrap"), scrap_before + 80,
		"the free crate and the ad crate are separate faucets (spec 6 placement 4)")
```

Append to `tests/test_workshop_screen.gd`:

```gdscript
func test_skip_completes_a_craft_timer_then_collect_merges() -> void:
	screen._on_craft_pressed("wind_fan")
	screen._on_skip_pressed("craft_wind_fan")
	assert_true(TimerService.is_done("craft_wind_fan", TimeUtil.now()))
	screen._on_collect_pressed("wind_fan")
	assert_eq(int(GameState.data["gizmos"]["owned"]["wind_fan"]), 2,
		"skip then collect merges the level like any finished craft")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: `_on_skip_pressed` and `_on_bonus_crate_pressed` are undefined.

- [ ] **Step 3: Implement**

In `game/base/island_screen.tscn`, add after the `SlotButton` node block:

```
[node name="BonusCrateButton" type="Button" parent="."]
offset_left = 20.0
offset_top = 930.0
offset_right = 700.0
offset_bottom = 980.0
text = "Bonus crate (ad)"
```

In `game/base/island_screen.gd`:

1. In `_ready`, add after the `$SlotButton` connect line: `$BonusCrateButton.pressed.connect(_on_bonus_crate_pressed)`.

2. In `_rebuild`, inside the `if TimerService.active_timers().has(timer_id):` branch, extend the `if TimerService.is_done(...)` with an `elif`, so the block reads:

```gdscript
		if TimerService.active_timers().has(timer_id):
			if TimerService.is_done(timer_id, now):
				var collect := Button.new()
				collect.text = "Complete!"
				collect.pressed.connect(_on_collect_pressed.bind(plot))
				row.add_child(collect)
			elif Ads.service.is_available(AdService.Placement.TIMER_SKIP):
				var skip := Button.new()
				skip.text = "Skip (ad)"
				skip.pressed.connect(_on_skip_pressed.bind(timer_id))
				row.add_child(skip)
```

3. In `_rebuild`, add at the end (after the `$SlotButton.text` line):

```gdscript
	$BonusCrateButton.visible = Ads.service.is_available(AdService.Placement.BONUS_CRATE)
	$BonusCrateButton.disabled = not AdLimits.can_use(GameState.data, "bonus_crate", _bonus_crate_limit(), now)
```

4. Add at the end of the file:

```gdscript
func _on_skip_pressed(timer_id: String) -> void:
	if not Ads.service.is_available(AdService.Placement.TIMER_SKIP):
		return
	Ads.service.request_reward(AdService.Placement.TIMER_SKIP, _grant_skip.bind(timer_id))


func _grant_skip(timer_id: String) -> void:
	# skip() emits no signal; the rebuild surfaces Complete! and the player
	# collects through the normal button.
	TimerService.skip(timer_id)
	GameState.save_game()
	_rebuild()


func _on_bonus_crate_pressed() -> void:
	var now := TimeUtil.now()
	if not Ads.service.is_available(AdService.Placement.BONUS_CRATE):
		return
	if not AdLimits.can_use(GameState.data, "bonus_crate", _bonus_crate_limit(), now):
		return
	Ads.service.request_reward(AdService.Placement.BONUS_CRATE, _grant_bonus_crate)


func _grant_bonus_crate() -> void:
	var now := TimeUtil.now()
	if not AdLimits.use(GameState.data, "bonus_crate", _bonus_crate_limit(), now):
		return
	var payout: Dictionary = DataDefs.retention.get("daily_crate", {})
	for currency in payout:
		Economy.add(currency, int(payout[currency]))
	GameState.save_game()
	_rebuild()


func _bonus_crate_limit() -> int:
	return int((DataDefs.retention.get("ads", {}) as Dictionary).get("bonus_crates_per_day", 1))
```

In `game/base/workshop_screen.gd`:

1. In `_rebuild`, the running-craft branch currently appends the countdown to the label. Replace the inner `if/else` of the timer branch so it reads:

```gdscript
		if TimerService.active_timers().has(timer_id):
			if TimerService.is_done(timer_id, now):
				var collect := Button.new()
				collect.text = "Collect!"
				collect.pressed.connect(_on_collect_pressed.bind(String(gizmo_id)))
				row.add_child(collect)
			else:
				label.text += "  (%ds)" % TimerService.remaining(timer_id, now)
				if Ads.service.is_available(AdService.Placement.TIMER_SKIP):
					var skip := Button.new()
					skip.text = "Skip (ad)"
					skip.pressed.connect(_on_skip_pressed.bind(timer_id))
					row.add_child(skip)
```

2. Add at the end of the file:

```gdscript
func _on_skip_pressed(timer_id: String) -> void:
	if not Ads.service.is_available(AdService.Placement.TIMER_SKIP):
		return
	Ads.service.request_reward(AdService.Placement.TIMER_SKIP, _grant_skip.bind(timer_id))


func _grant_skip(timer_id: String) -> void:
	TimerService.skip(timer_id)
	GameState.save_game()
	_rebuild()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/base/island_screen.gd game/base/island_screen.tscn game/base/workshop_screen.gd tests/test_island_screen.gd tests/test_workshop_screen.gd
git commit -m "feat: wire timer-skip and bonus-crate rewarded-ad placements"
```

---

### Task 6: Local notifications: planner, seam, service, permission

**Files:**
- Create: `game/core/notification_scheduler.gd`, `game/core/notification_planner.gd`, `game/autoload/notification_svc.gd`
- Modify: `project.godot` (autoload), `game/base/island_screen.gd` (permission hook)
- Test: `tests/test_notifications.gd` (new), `tests/test_island_screen.gd` (append)

**Interfaces:**
- Consumes: `GameState.data` (`timers`, `fuel`, `daily_crate`, `notifications` sections), `FuelModel.seconds_until_full`, `DailyCrate.can_claim/day_of/SECONDS_PER_DAY`, `DataDefs.buildings/gizmos`.
- Produces: `NotificationScheduler` (RefCounted, no-op `schedule(id: String, title: String, body: String, fire_at: int)`, `cancel_all()`, `request_permission()`); `NotificationPlanner.plan(data: Dictionary, building_defs: Dictionary, gizmo_defs: Dictionary, now: int) -> Array` of `{"id", "title", "body", "fire_at"}`; autoload `NotificationSvc` with `scheduler: NotificationScheduler` (injectable), `schedule_all(now: int)`, `request_permission_once()`, and pause/resume `_notification` handling. T11 exercises the planner end to end.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_notifications.gd`:

```gdscript
extends GutTest

const NOW := 1_800_000_000


class RecordingScheduler:
	extends NotificationScheduler
	var scheduled: Array = []
	var cancel_calls := 0
	var permission_calls := 0

	func schedule(id: String, title: String, body: String, fire_at: int) -> void:
		scheduled.append({"id": id, "title": title, "body": body, "fire_at": fire_at})

	func cancel_all() -> void:
		cancel_calls += 1

	func request_permission() -> void:
		permission_calls += 1


func make_data() -> Dictionary:
	var data := SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	data["created_at"] = NOW
	data["fuel"]["updated_at"] = NOW
	return data


func after_all() -> void:
	NotificationSvc.scheduler = NotificationScheduler.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings)


func test_planner_covers_all_four_return_hooks() -> void:
	var data := make_data()
	data["timers"]["build_plot_0"] = {"kind": "construction", "ends_at": NOW + 600, "payload": {"plot": "plot_0", "building": "wind_still", "to_level": 1}}
	data["timers"]["craft_wind_fan"] = {"kind": "craft", "ends_at": NOW + 120, "payload": {"gizmo": "wind_fan"}}
	data["fuel"]["amount"] = 0
	data["daily_crate"]["last_claim_day"] = DailyCrate.day_of(NOW)
	var plan := NotificationPlanner.plan(data, DataDefs.buildings, DataDefs.gizmos, NOW)
	var ids := []
	for entry in plan:
		ids.append(String(entry["id"]))
	ids.sort()
	assert_eq(ids, ["build_plot_0", "craft_wind_fan", "daily_crate", "fuel_full"],
		"spec 5: construction, craft, fuel full, daily crate")

func test_construction_entry_names_the_building_and_fires_at_ends_at() -> void:
	var data := make_data()
	data["timers"]["build_plot_0"] = {"kind": "construction", "ends_at": NOW + 600, "payload": {"plot": "plot_0", "building": "wind_still", "to_level": 1}}
	var plan := NotificationPlanner.plan(data, DataDefs.buildings, DataDefs.gizmos, NOW)
	assert_eq(plan.size(), 1, "full tank and claimable crate add nothing")
	assert_string_contains(String(plan[0]["body"]), "Wind Still")
	assert_eq(int(plan[0]["fire_at"]), NOW + 600)

func test_fuel_entry_fire_time_matches_the_model() -> void:
	var data := make_data()
	data["fuel"]["amount"] = 3
	var plan := NotificationPlanner.plan(data, DataDefs.buildings, DataDefs.gizmos, NOW)
	assert_eq(plan.size(), 1)
	assert_eq(String(plan[0]["id"]), "fuel_full")
	assert_eq(int(plan[0]["fire_at"]), NOW + FuelModel.seconds_until_full(data["fuel"], NOW))

func test_crate_entry_fires_at_next_day_boundary() -> void:
	var data := make_data()
	data["daily_crate"]["last_claim_day"] = DailyCrate.day_of(NOW)
	var plan := NotificationPlanner.plan(data, DataDefs.buildings, DataDefs.gizmos, NOW)
	assert_eq(plan.size(), 1)
	assert_eq(String(plan[0]["id"]), "daily_crate")
	assert_eq(int(plan[0]["fire_at"]), (DailyCrate.day_of(NOW) + 1) * DailyCrate.SECONDS_PER_DAY)

func test_fresh_state_plans_nothing() -> void:
	var plan := NotificationPlanner.plan(make_data(), DataDefs.buildings, DataDefs.gizmos, NOW)
	assert_eq(plan, [], "full tank, claimable crate, no timers: nothing to say")

func test_already_elapsed_timers_are_skipped() -> void:
	var data := make_data()
	data["timers"]["build_plot_0"] = {"kind": "construction", "ends_at": NOW - 5, "payload": {"plot": "plot_0", "building": "dock", "to_level": 1}}
	var plan := NotificationPlanner.plan(data, DataDefs.buildings, DataDefs.gizmos, NOW)
	assert_eq(plan, [], "a done timer is collected in-app, never notified")

func test_svc_reschedules_from_scratch_and_cancels_on_resume() -> void:
	var rec := RecordingScheduler.new()
	NotificationSvc.scheduler = rec
	var data := make_data()
	data["timers"]["build_plot_0"] = {"kind": "construction", "ends_at": NOW + 600, "payload": {"plot": "plot_0", "building": "dock", "to_level": 1}}
	data["fuel"]["amount"] = 0
	GameState.data = data
	NotificationSvc.schedule_all(NOW)
	assert_eq(rec.cancel_calls, 1, "always cancel before scheduling")
	assert_eq(rec.scheduled.size(), 2)
	NotificationSvc.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert_eq(rec.cancel_calls, 2, "resume clears pending notifications (spec 5)")

func test_svc_schedules_on_application_pause() -> void:
	var rec := RecordingScheduler.new()
	NotificationSvc.scheduler = rec
	var data := make_data()
	data["fuel"]["amount"] = 0
	GameState.data = data
	NotificationSvc.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(rec.scheduled.size(), 1, "fuel-full is the only pending hook")

func test_permission_requested_only_once() -> void:
	var rec := RecordingScheduler.new()
	NotificationSvc.scheduler = rec
	GameState.data = make_data()
	NotificationSvc.request_permission_once()
	NotificationSvc.request_permission_once()
	assert_eq(rec.permission_calls, 1)
	assert_true(bool(GameState.data["notifications"]["permission_requested"]))
```

Append to `tests/test_island_screen.gd`:

```gdscript
func test_first_construction_completion_requests_notification_permission() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 0}
	TimerService.start("build_plot_0", "construction", 10, 1000, {"plot": "plot_0", "building": "workshop", "to_level": 1})
	TimerService._state.data["timers"]["build_plot_0"]["ends_at"] = 0
	screen._on_collect_pressed("plot_0")
	assert_true(bool(GameState.data["notifications"]["permission_requested"]),
		"spec 5: permission asked at the first construction completion, not at launch")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: `NotificationScheduler`, `NotificationPlanner`, `NotificationSvc` are all unknown.

- [ ] **Step 3: Implement**

Create `game/core/notification_scheduler.gd`:

```gdscript
class_name NotificationScheduler
extends RefCounted
## Seam for the Android notification-scheduler plugin (spec 7.1). This base
## class is the desktop/headless no-op; the plugin-backed implementation is
## vendored at Android-build time and selected at boot, mirroring Ads.service.


func schedule(_id: String, _title: String, _body: String, _fire_at: int) -> void:
	pass


func cancel_all() -> void:
	pass


func request_permission() -> void:
	# Android 13+ POST_NOTIFICATIONS runtime permission (spec 5).
	pass
```

Create `game/core/notification_planner.gd`:

```gdscript
class_name NotificationPlanner
## Pure computation of the local notifications to schedule at background time
## (spec 5): construction complete, craft complete, fuel full, daily crate
## ready. Reads the persisted timers dict READ-ONLY; nothing here mutates
## state, which is what makes the plan testable and idempotent.


static func plan(data: Dictionary, building_defs: Dictionary, gizmo_defs: Dictionary, now: int) -> Array:
	var out: Array = []
	var timers: Dictionary = data.get("timers", {})
	for id in timers:
		var timer: Dictionary = timers[id]
		var fire_at := int(timer.get("ends_at", 0))
		if fire_at <= now:
			continue
		var kind := String(timer.get("kind", ""))
		var payload: Dictionary = timer.get("payload", {})
		if kind == "construction":
			var def: Dictionary = (building_defs.get("defs", {}) as Dictionary).get(String(payload.get("building", "")), {})
			out.append({
				"id": String(id),
				"title": "Construction complete",
				"body": "%s is ready." % String(def.get("name", payload.get("building", "A building"))),
				"fire_at": fire_at,
			})
		elif kind == "craft":
			var def: Dictionary = (gizmo_defs.get("defs", {}) as Dictionary).get(String(payload.get("gizmo", "")), {})
			out.append({
				"id": String(id),
				"title": "Craft complete",
				"body": "%s is ready to collect." % String(def.get("name", payload.get("gizmo", "A gizmo"))),
				"fire_at": fire_at,
			})
	var fuel: Dictionary = data.get("fuel", {})
	if not fuel.is_empty():
		var until_full := FuelModel.seconds_until_full(fuel, now)
		if until_full > 0:
			out.append({
				"id": "fuel_full",
				"title": "Fuel tank full",
				"body": "Your airship is fueled for new expeditions.",
				"fire_at": now + until_full,
			})
	if not DailyCrate.can_claim(data, now):
		out.append({
			"id": "daily_crate",
			"title": "Daily crate ready",
			"body": "A fresh salvage crate is waiting on the island.",
			"fire_at": (DailyCrate.day_of(now) + 1) * DailyCrate.SECONDS_PER_DAY,
		})
	return out
```

Create `game/autoload/notification_svc.gd`:

```gdscript
extends Node
## Schedules local notifications when the app backgrounds and cancels them on
## resume (spec 5). The pending set is recomputed from save state every time,
## never stored, so it can never drift from the truth.

var scheduler: NotificationScheduler = NotificationScheduler.new()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		schedule_all(TimeUtil.now())
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		scheduler.cancel_all()


func schedule_all(now: int) -> void:
	scheduler.cancel_all()
	for entry in NotificationPlanner.plan(GameState.data, DataDefs.buildings, DataDefs.gizmos, now):
		scheduler.schedule(String(entry["id"]), String(entry["title"]), String(entry["body"]), int(entry["fire_at"]))


func request_permission_once() -> void:
	# Spec 5: ask at the first construction completion, not at first launch.
	var flags: Dictionary = GameState.data.get("notifications", {})
	if bool(flags.get("permission_requested", false)):
		return
	flags["permission_requested"] = true
	scheduler.request_permission()
```

In `project.godot`, add to the `[autoload]` section after the `Ads` line:

```
NotificationSvc="*res://game/autoload/notification_svc.gd"
```

In `game/base/island_screen.gd`, in `_on_collect_pressed`, add `NotificationSvc.request_permission_once()` immediately after the `IslandModel.complete_build(...)` line.

- [ ] **Step 4: Import, verify sidecars, run tests**

Run: `$GODOT --headless --import`
Run: `git status --porcelain` and confirm the three new `.gd.uid` sidecars appear.
Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/core/notification_scheduler.gd game/core/notification_scheduler.gd.uid game/core/notification_planner.gd game/core/notification_planner.gd.uid game/autoload/notification_svc.gd game/autoload/notification_svc.gd.uid project.godot game/base/island_screen.gd tests/test_notifications.gd tests/test_notifications.gd.uid tests/test_island_screen.gd
git commit -m "feat: local notification planner, scheduler seam, and permission-once flow"
```

---

### Task 7: Island screen polish: signature-gated refresh, feedback, unconditional fuel heal

**Files:**
- Modify: `game/base/island_screen.gd` (full rewrite below), `game/base/island_screen.tscn` (StatusLabel)
- Modify: `game/base/island_model.gd` (`build_rejection`)
- Test: `tests/test_island_screen.gd` (append), `tests/test_island_model.gd` (append)

**Interfaces:**
- Consumes: everything T5/T6 added to this screen (handler names preserved exactly).
- Produces: `IslandModel.build_rejection(island, defs, economy, timers, plot, building_id, now) -> String` ("" when buildable, otherwise a player-facing reason; `can_start_build` delegates to it); island screen gains `_refresh_tick()`, `_signature(now) -> String`, `_refresh_labels(now)`, `_refresh_static_controls(now)`, `_last_signature: String`, `_plot_labels: Dictionary`, and a `StatusLabel` node. The RefreshTimer connects to `_refresh_tick`, never `_rebuild`.

- [ ] **Step 1: Append the failing tests**

Append to `tests/test_island_model.gd`:

```gdscript
func test_build_rejection_empty_when_buildable() -> void:
	assert_eq(IslandModel.build_rejection(island, defs, econ, timers, "plot_0", "workshop", 1000), "")

func test_build_rejection_names_busy_slots() -> void:
	IslandModel.start_build(island, defs, econ, timers, "plot_0", "workshop", 1000)
	assert_string_contains(
		IslandModel.build_rejection(island, defs, econ, timers, "plot_1", "gardens", 1000),
		"slots are busy")

func test_build_rejection_names_the_cost_shortfall() -> void:
	state.data["currencies"]["scrap"] = 0
	assert_string_contains(
		IslandModel.build_rejection(island, defs, econ, timers, "plot_0", "workshop", 1000),
		"Not enough")

func test_build_rejection_rejects_an_occupied_timer_plot() -> void:
	IslandModel.start_build(island, defs, econ, timers, "plot_0", "workshop", 1000)
	assert_string_contains(
		IslandModel.build_rejection(island, defs, econ, timers, "plot_0", "workshop", 1000),
		"under construction")

func test_build_rejection_rejects_an_impossible_target() -> void:
	island["plots"]["plot_0"] = {"building": "workshop", "level": 3}
	assert_string_contains(
		IslandModel.build_rejection(island, defs, econ, timers, "plot_0", "workshop", 1000),
		"cannot be built")
```

Append to `tests/test_island_screen.gd`:

```gdscript
func test_tick_without_state_change_keeps_row_nodes_alive() -> void:
	var row_before: Node = screen.get_node("Rows").get_child(0)
	screen._refresh_tick()
	assert_true(is_instance_valid(row_before) and not row_before.is_queued_for_deletion(),
		"per-second ticks must not free a button under the player's finger")

func test_tick_rebuilds_when_a_timer_finishes() -> void:
	screen._on_select_pressed("plot_0")
	screen._on_build_pressed("plot_0")
	screen._refresh_tick()
	var running_signature: String = screen._last_signature
	TimerService._state.data["timers"]["build_plot_0"]["ends_at"] = 0
	screen._refresh_tick()
	assert_ne(screen._last_signature, running_signature,
		"done is structural: the Complete! button must appear")

func test_slot_button_disabled_when_crystals_are_short() -> void:
	GameState.data["currencies"]["crystals"] = 0
	screen._rebuild()
	assert_true(screen.get_node("SlotButton").disabled)

func test_rejected_build_explains_itself() -> void:
	GameState.data["currencies"]["scrap"] = 0
	screen._on_select_pressed("plot_0")
	screen._on_build_pressed("plot_0")
	assert_string_contains(screen.get_node("StatusLabel").text, "Not enough")

func test_successful_build_clears_the_status() -> void:
	GameState.data["currencies"]["scrap"] = 0
	screen._on_select_pressed("plot_0")
	screen._on_build_pressed("plot_0")
	GameState.data["currencies"]["scrap"] = 2000
	screen._on_build_pressed("plot_0")
	assert_eq(screen.get_node("StatusLabel").text, "")

func test_any_completion_reapplies_fuel_effects() -> void:
	GameState.data["fuel"]["cap"] = 99
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 0}
	TimerService.start("build_plot_0", "construction", 10, 1000, {"plot": "plot_0", "building": "workshop", "to_level": 1})
	TimerService._state.data["timers"]["build_plot_0"]["ends_at"] = 0
	screen._on_collect_pressed("plot_0")
	assert_eq(int(GameState.data["fuel"]["cap"]), 5,
		"apply_fuel is unconditional and idempotent; a mangled cap heals at any collect")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: `build_rejection`, `_refresh_tick`, `_last_signature`, `StatusLabel` all missing.

- [ ] **Step 3: Implement IslandModel.build_rejection**

In `game/base/island_model.gd`, replace `can_start_build` with:

```gdscript
static func build_rejection(island: Dictionary, defs: Dictionary, economy: Node, timers: Node, plot: String, building_id: String, now: int) -> String:
	# "" means buildable; anything else is a short player-facing reason
	# (Plan 5 polish: a rejected Build tap must say why).
	if timers.active_timers().has("build_" + plot):
		return "This plot is already under construction."
	if active_constructions(timers, now) >= int(island.get("build_slots", 1)):
		return "All build slots are busy."
	var row := _next_level_row(defs, island, plot, building_id)
	if row.is_empty():
		return "%s cannot be built here." % building_id
	if not economy.can_afford(row.get("cost", {})):
		return "Not enough resources."
	return ""


static func can_start_build(island: Dictionary, defs: Dictionary, economy: Node, timers: Node, plot: String, building_id: String, now: int) -> bool:
	return build_rejection(island, defs, economy, timers, plot, building_id, now) == ""
```

- [ ] **Step 4: Add the StatusLabel and rewrite the screen script**

In `game/base/island_screen.tscn`, add after the `BonusCrateButton` node block:

```
[node name="StatusLabel" type="Label" parent="."]
offset_left = 20.0
offset_top = 1190.0
offset_right = 700.0
offset_bottom = 1245.0
```

Replace the whole of `game/base/island_screen.gd` with:

```gdscript
extends Control
## The home island (spec 4.1): plots, timed construction, upgrades, and the
## retention controls (trickle, crates, build slot, rewarded-ad accelerators).
## Dumb UI: every rule lives in IslandModel; this screen renders state and
## forwards taps.
##
## Refresh discipline: RefreshTimer ticks call _refresh_tick, which rebuilds
## the row tree ONLY when the structural signature changes (a timer starting,
## finishing, or disappearing); otherwise labels update in place so a button
## mid-tap is never freed under the player's finger.

var _selection: Dictionary = {}
var _last_signature := ""
var _plot_labels: Dictionary = {}

@onready var rows: VBoxContainer = $Rows


func _ready() -> void:
	$WorkshopButton.pressed.connect(_on_workshop_pressed)
	$BackButton.pressed.connect(_on_back_pressed)
	$RefreshTimer.timeout.connect(_refresh_tick)
	$GardensButton.pressed.connect(_on_gardens_pressed)
	$CrateButton.pressed.connect(_on_crate_pressed)
	$SlotButton.pressed.connect(_on_slot_pressed)
	$BonusCrateButton.pressed.connect(_on_bonus_crate_pressed)
	_rebuild()


func _plot_ids() -> Array[String]:
	var ids: Array[String] = []
	for i in int(DataDefs.buildings.get("plot_count", 6)):
		ids.append("plot_%d" % i)
	return ids


func _unbuilt_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in DataDefs.buildings.get("defs", {}):
		if IslandModel.building_level(GameState.data["island"], String(id)) == 0 \
				and IslandModel.plot_of(GameState.data["island"], String(id)) == "":
			ids.append(String(id))
	return ids


func _signature(now: int) -> String:
	var parts := PackedStringArray()
	for plot in _plot_ids():
		var timer_id := "build_" + plot
		if TimerService.active_timers().has(timer_id):
			parts.append("d" if TimerService.is_done(timer_id, now) else "r")
		else:
			parts.append("i")
	return ",".join(parts)


func _refresh_tick() -> void:
	var now := TimeUtil.now()
	if _signature(now) != _last_signature:
		_rebuild()
		return
	_refresh_labels(now)


func _refresh_labels(now: int) -> void:
	var island: Dictionary = GameState.data["island"]
	for plot in _plot_labels:
		var label: Label = _plot_labels[plot]
		if is_instance_valid(label):
			label.text = _row_text(String(plot), island, now)
	_refresh_static_controls(now)


func _rebuild() -> void:
	for child in rows.get_children():
		child.queue_free()
	_plot_labels.clear()
	var now := TimeUtil.now()
	_last_signature = _signature(now)
	var island: Dictionary = GameState.data["island"]
	for plot in _plot_ids():
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 64)
		var label := Label.new()
		label.custom_minimum_size = Vector2(320, 0)
		label.text = _row_text(plot, island, now)
		row.add_child(label)
		_plot_labels[plot] = label
		var timer_id := "build_" + plot
		if TimerService.active_timers().has(timer_id):
			if TimerService.is_done(timer_id, now):
				var collect := Button.new()
				collect.text = "Complete!"
				collect.pressed.connect(_on_collect_pressed.bind(plot))
				row.add_child(collect)
			elif Ads.service.is_available(AdService.Placement.TIMER_SKIP):
				var skip := Button.new()
				skip.text = "Skip (ad)"
				skip.pressed.connect(_on_skip_pressed.bind(timer_id))
				row.add_child(skip)
		else:
			var select := Button.new()
			select.text = _selection_text(plot, island)
			select.pressed.connect(_on_select_pressed.bind(plot))
			row.add_child(select)
			var build := Button.new()
			build.text = "Build"
			build.pressed.connect(_on_build_pressed.bind(plot))
			row.add_child(build)
		rows.add_child(row)
	_refresh_static_controls(now)


func _refresh_static_controls(now: int) -> void:
	var pending := TrickleModel.pending(GameState.data, DataDefs.buildings, now)
	$GardensButton.text = "Collect trickle (%d scrap)" % pending
	$GardensButton.disabled = pending <= 0
	$CrateButton.disabled = not DailyCrate.can_claim(GameState.data, now)
	$CrateButton.text = "Open daily crate" if not $CrateButton.disabled else "Crate opened today"
	var slots_cfg: Dictionary = DataDefs.buildings.get("build_slots", {})
	var slot_cost := int(slots_cfg.get("second_slot_crystal_cost", 20))
	$SlotButton.visible = int(GameState.data["island"].get("build_slots", 1)) < int(slots_cfg.get("max", 2))
	$SlotButton.text = "Unlock 2nd build slot (%d crystals)" % slot_cost
	$SlotButton.disabled = not Economy.can_afford({"crystals": slot_cost})
	$BonusCrateButton.visible = Ads.service.is_available(AdService.Placement.BONUS_CRATE)
	$BonusCrateButton.disabled = not AdLimits.can_use(GameState.data, "bonus_crate", _bonus_crate_limit(), now)


func _row_text(plot: String, island: Dictionary, now: int) -> String:
	var timer_id := "build_" + plot
	var plots: Dictionary = island.get("plots", {})
	if TimerService.active_timers().has(timer_id):
		var payload: Dictionary = TimerService.active_timers()[timer_id].get("payload", {})
		var remaining := TimerService.remaining(timer_id, now)
		return "%s: building %s (%ds)" % [plot, String(payload.get("building", "?")), remaining]
	if plots.has(plot):
		var entry: Dictionary = plots[plot]
		var def: Dictionary = (DataDefs.buildings["defs"] as Dictionary).get(String(entry["building"]), {})
		var text := "%s: %s Lv %d" % [plot, String(def.get("name", entry["building"])), int(entry["level"])]
		if String(entry["building"]) == "observatory" and int(entry["level"]) >= 1:
			text += "\n    %s" % String(def.get("teaser", ""))
		return text
	return "%s: (empty)" % plot


func _selection_text(plot: String, island: Dictionary) -> String:
	var plots: Dictionary = island.get("plots", {})
	if plots.has(plot):
		return "Upgrade"
	var chosen := String(_selection.get(plot, ""))
	return chosen if chosen != "" else "Choose..."


func _on_select_pressed(plot: String) -> void:
	var plots: Dictionary = GameState.data["island"]["plots"]
	if plots.has(plot):
		return
	var options := _unbuilt_ids()
	if options.is_empty():
		return
	var current := String(_selection.get(plot, ""))
	var index := options.find(current)
	_selection[plot] = options[(index + 1) % options.size()]
	_rebuild()


func _on_build_pressed(plot: String) -> void:
	var island: Dictionary = GameState.data["island"]
	var building_id: String
	if island["plots"].has(plot):
		building_id = String(island["plots"][plot]["building"])
	else:
		building_id = String(_selection.get(plot, ""))
	if building_id == "":
		$StatusLabel.text = "Pick a building for %s first." % plot
		return
	var now := TimeUtil.now()
	var reason := IslandModel.build_rejection(island, DataDefs.buildings, Economy, TimerService, plot, building_id, now)
	if reason != "":
		$StatusLabel.text = reason
		return
	if IslandModel.start_build(island, DataDefs.buildings, Economy, TimerService, plot, building_id, now):
		$StatusLabel.text = ""
		GameState.save_game()
	_rebuild()


func _on_collect_pressed(plot: String) -> void:
	var now := TimeUtil.now()
	var payload := TimerService.collect("build_" + plot, now)
	if payload.is_empty():
		return
	IslandModel.complete_build(GameState.data["island"], payload, GameState.data, now, DataDefs.buildings)
	NotificationSvc.request_permission_once()
	# Idempotent re-application self-heals fuel cap/regen after ANY completion,
	# not just the Wind Still: a mangled save heals at the next collect too.
	IslandEffects.apply_fuel(GameState.data, DataDefs.economy, DataDefs.buildings)
	GameState.save_game()
	_rebuild()


func _on_workshop_pressed() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/base/workshop_screen.tscn")


func _on_back_pressed() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/main.tscn")


func _on_gardens_pressed() -> void:
	var amount := TrickleModel.collect(GameState.data, DataDefs.buildings, TimeUtil.now())
	if amount > 0:
		Economy.add("scrap", amount)
		GameState.save_game()
	_rebuild()


func _on_crate_pressed() -> void:
	var payout := DailyCrate.claim(GameState.data, DataDefs.retention, TimeUtil.now())
	if payout.is_empty():
		return
	for currency in payout:
		Economy.add(currency, int(payout[currency]))
	GameState.save_game()
	_rebuild()


func _on_slot_pressed() -> void:
	if IslandModel.unlock_second_slot(GameState.data["island"], DataDefs.buildings, Economy):
		GameState.save_game()
	_rebuild()


func _on_skip_pressed(timer_id: String) -> void:
	if not Ads.service.is_available(AdService.Placement.TIMER_SKIP):
		return
	Ads.service.request_reward(AdService.Placement.TIMER_SKIP, _grant_skip.bind(timer_id))


func _grant_skip(timer_id: String) -> void:
	# skip() emits no signal; the rebuild surfaces Complete! and the player
	# collects through the normal button.
	TimerService.skip(timer_id)
	GameState.save_game()
	_rebuild()


func _on_bonus_crate_pressed() -> void:
	var now := TimeUtil.now()
	if not Ads.service.is_available(AdService.Placement.BONUS_CRATE):
		return
	if not AdLimits.can_use(GameState.data, "bonus_crate", _bonus_crate_limit(), now):
		return
	Ads.service.request_reward(AdService.Placement.BONUS_CRATE, _grant_bonus_crate)


func _grant_bonus_crate() -> void:
	var now := TimeUtil.now()
	if not AdLimits.use(GameState.data, "bonus_crate", _bonus_crate_limit(), now):
		return
	var payout: Dictionary = DataDefs.retention.get("daily_crate", {})
	for currency in payout:
		Economy.add(currency, int(payout[currency]))
	GameState.save_game()
	_rebuild()


func _bonus_crate_limit() -> int:
	return int((DataDefs.retention.get("ads", {}) as Dictionary).get("bonus_crates_per_day", 1))
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0. Existing island tests (T5/T6 additions included) stay green because every handler kept its name and behavior.

- [ ] **Step 6: Commit**

```bash
git add game/base/island_screen.gd game/base/island_screen.tscn game/base/island_model.gd tests/test_island_screen.gd tests/test_island_model.gd
git commit -m "feat: island screen polish with signature-gated refresh and build feedback"
```

---

### Task 8: Workshop signature refresh and loadout per-tap save

**Files:**
- Modify: `game/base/workshop_screen.gd` (full rewrite below)
- Modify: `game/ui/loadout_screen.gd` (`_on_slot_pressed`)
- Test: `tests/test_workshop_screen.gd` (append), `tests/test_loadout_screen.gd` (append)

**Interfaces:**
- Consumes: T5's workshop skip handlers (names preserved), `GizmoLoadout.set_slot`.
- Produces: workshop gains `_refresh_tick()`, `_signature(now)`, `_refresh_labels(now)`, `_slots_text()`, `_gizmo_label_text(gizmo_id, now)`, `_last_signature`, `_gizmo_labels: Dictionary`; loadout slot edits persist immediately (an OS kill after a tap loses nothing).

- [ ] **Step 1: Append the failing tests**

Append to `tests/test_workshop_screen.gd`:

```gdscript
func test_tick_without_state_change_keeps_row_nodes_alive() -> void:
	var row_before: Node = screen.get_node("Rows").get_child(0)
	screen._refresh_tick()
	assert_true(is_instance_valid(row_before) and not row_before.is_queued_for_deletion(),
		"per-second ticks must not free a button under the player's finger")

func test_tick_updates_the_countdown_in_place() -> void:
	screen._on_craft_pressed("wind_fan")
	var label: Label = screen._gizmo_labels["wind_fan"]
	var text_before: String = label.text
	TimerService._state.data["timers"]["craft_wind_fan"]["ends_at"] = \
		int(TimerService._state.data["timers"]["craft_wind_fan"]["ends_at"]) - 5
	screen._refresh_tick()
	assert_true(is_instance_valid(label), "the label survives the tick")
	assert_ne(label.text, text_before, "the countdown advanced without a rebuild")

func test_tick_rebuilds_when_a_craft_finishes() -> void:
	screen._on_craft_pressed("wind_fan")
	screen._refresh_tick()
	var running_signature: String = screen._last_signature
	TimerService._state.data["timers"]["craft_wind_fan"]["ends_at"] = 0
	screen._refresh_tick()
	assert_ne(screen._last_signature, running_signature,
		"done is structural: the Collect! button must appear")
```

Append to `tests/test_loadout_screen.gd`:

```gdscript
func test_slot_edit_persists_without_pressing_back() -> void:
	screen._on_slot_pressed("slot_0")
	var saved := SaveIO.new(TEST_SAVE).read()
	var loadout: Dictionary = ((saved["gizmos"] as Dictionary)["loadout"] as Dictionary).get("region_1", {})
	assert_true(loadout.has("slot_0"),
		"an OS kill right after a tap must not lose the edit (save-anywhere)")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: `_refresh_tick` and `_gizmo_labels` unknown on workshop; the loadout save file has no slot entry (only Back saved before).

- [ ] **Step 3: Implement**

Replace the whole of `game/base/workshop_screen.gd` with:

```gdscript
extends Control
## Workshop crafting (spec 4.1): craft duplicates of owned gizmos; a finished
## craft merges into a level (spec 3.3). Dumb UI over CraftModel.
##
## Refresh discipline mirrors island_screen: ticks rebuild only on structural
## change; countdown labels update in place.

var _last_signature := ""
var _gizmo_labels: Dictionary = {}

@onready var rows: VBoxContainer = $Rows
@onready var slots_label: Label = $SlotsLabel


func _ready() -> void:
	$BackButton.pressed.connect(_on_back_pressed)
	$RefreshTimer.timeout.connect(_refresh_tick)
	_rebuild()


func _signature(now: int) -> String:
	var parts := PackedStringArray()
	for gizmo_id in GameState.data["gizmos"]["owned"]:
		var timer_id := "craft_" + String(gizmo_id)
		if TimerService.active_timers().has(timer_id):
			parts.append("d" if TimerService.is_done(timer_id, now) else "r")
		else:
			parts.append("i")
	return ",".join(parts)


func _refresh_tick() -> void:
	var now := TimeUtil.now()
	if _signature(now) != _last_signature:
		_rebuild()
		return
	_refresh_labels(now)


func _refresh_labels(now: int) -> void:
	slots_label.text = _slots_text()
	for gizmo_id in _gizmo_labels:
		var label: Label = _gizmo_labels[gizmo_id]
		if is_instance_valid(label):
			label.text = _gizmo_label_text(String(gizmo_id), now)


func _slots_text() -> String:
	var slots := CraftModel.craft_slots(GameState.data["island"])
	return "Workshop Lv %d: crafting %d/%d" % [slots, CraftModel.active_crafts(TimerService), maxi(slots, 0)] \
		if slots > 0 else "Build a Workshop on the island to craft"


func _gizmo_label_text(gizmo_id: String, now: int) -> String:
	var owned: Dictionary = GameState.data["gizmos"]["owned"]
	var def: Dictionary = (DataDefs.gizmos["defs"] as Dictionary).get(gizmo_id, {})
	var text := "%s Lv %d" % [String(def.get("name", gizmo_id)), int(owned.get(gizmo_id, 1))]
	var timer_id := "craft_" + gizmo_id
	if TimerService.active_timers().has(timer_id) and not TimerService.is_done(timer_id, now):
		text += "  (%ds)" % TimerService.remaining(timer_id, now)
	return text


func _rebuild() -> void:
	for child in rows.get_children():
		child.queue_free()
	_gizmo_labels.clear()
	var now := TimeUtil.now()
	_last_signature = _signature(now)
	slots_label.text = _slots_text()
	var owned: Dictionary = GameState.data["gizmos"]["owned"]
	for gizmo_id in owned:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 56)
		var label := Label.new()
		label.custom_minimum_size = Vector2(360, 0)
		label.text = _gizmo_label_text(String(gizmo_id), now)
		row.add_child(label)
		_gizmo_labels[String(gizmo_id)] = label
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
		else:
			var craft := Button.new()
			craft.text = "Craft"
			craft.pressed.connect(_on_craft_pressed.bind(String(gizmo_id)))
			row.add_child(craft)
		rows.add_child(row)


func _on_craft_pressed(gizmo_id: String) -> void:
	if CraftModel.start_craft(GameState.data, DataDefs.gizmos, Economy, TimerService, gizmo_id, TimeUtil.now()):
		GameState.save_game()
	_rebuild()


func _on_collect_pressed(gizmo_id: String) -> void:
	var payload := TimerService.collect("craft_" + gizmo_id, TimeUtil.now())
	if payload.is_empty():
		return
	CraftModel.complete_craft(GameState.data, payload)
	GameState.save_game()
	_rebuild()


func _on_back_pressed() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/base/island_screen.tscn")


func _on_skip_pressed(timer_id: String) -> void:
	if not Ads.service.is_available(AdService.Placement.TIMER_SKIP):
		return
	Ads.service.request_reward(AdService.Placement.TIMER_SKIP, _grant_skip.bind(timer_id))


func _grant_skip(timer_id: String) -> void:
	TimerService.skip(timer_id)
	GameState.save_game()
	_rebuild()
```

Note the one behavior change from T5's version: the running-craft countdown moved from an inline `label.text +=` into `_gizmo_label_text`, so ticks can refresh it in place. The skip button still appears next to a running craft.

In `game/ui/loadout_screen.gd`, replace `_on_slot_pressed` with:

```gdscript
func _on_slot_pressed(slot: String) -> void:
	var gizmos_state: Dictionary = GameState.data["gizmos"]
	var loadout := GizmoLoadout.loadout_for(gizmos_state, region_id)
	var used: Array = []
	for other_slot in loadout:
		if other_slot != slot:
			used.append(loadout[other_slot])
	var next := GizmoLoadout.next_choice(String(loadout.get(slot, "")), GizmoLoadout.owned(gizmos_state).keys(), used)
	GizmoLoadout.set_slot(gizmos_state, region_id, slot, next)
	# Persist per tap: Android may kill the app at any moment and the pause
	# notification is not guaranteed on every death path (save-anywhere).
	GameState.save_game()
	_rebuild()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/base/workshop_screen.gd game/ui/loadout_screen.gd tests/test_workshop_screen.gd tests/test_loadout_screen.gd
git commit -m "feat: workshop signature refresh and immediate loadout persistence"
```

---

### Task 9: Skyfield geometry from board data and barge-id validation

**Files:**
- Modify: `game/run/skyfield.gd`
- Test: `tests/test_skyfield.gd` (append)

**Interfaces:**
- Consumes: `Skyfield.build/_build_walls/_build_sea/_build_barges`, region JSON `board` dict.
- Produces: `_build_sea(board: Dictionary)` and `_build_walls(board: Dictionary)` derive all geometry from `board` (region-1 values are numerically identical to the old constants, so physics tests stay green); `Skyfield.duplicate_barge_ids(barges: Array) -> Array` (static, pure) with `_build_barges` warning on each duplicate. Region 2 authoring gets both for free.

- [ ] **Step 1: Append the failing tests**

Append to `tests/test_skyfield.gd`:

```gdscript
const TALL_REGION := {
	"name": "Tall Test",
	"board": {"left": 40, "right": 500, "top": 140, "bottom": 2000},
	"pegs": [], "gizmo_slots": [], "barges": [],
}


func test_sea_geometry_derives_from_board_data() -> void:
	var board := build_board(TALL_REGION)
	var sea: Area2D = board.get_node("Sea")
	assert_eq(sea.position, Vector2(270, 2160), "sea centers under the board, below bottom")
	var shape: RectangleShape2D = (sea.get_child(0) as CollisionShape2D).shape
	assert_eq(shape.size, Vector2(540, 80), "sea spans the board width plus margin")

func test_wall_geometry_derives_from_board_data() -> void:
	var board := build_board(TALL_REGION)
	var wall: StaticBody2D = board.get_node("Walls").get_child(0)
	assert_eq(wall.position, Vector2(30, 1130), "left wall hugs the board and spans past the sea")
	var shape: RectangleShape2D = (wall.get_child(0) as CollisionShape2D).shape
	assert_eq(shape.size, Vector2(20, 2380))

func test_region_1_geometry_is_unchanged_by_the_derivation() -> void:
	var board := build_board(DataDefs.skyfield("region_1"))
	assert_eq((board.get_node("Sea") as Area2D).position, Vector2(360, 1180))
	var wall: StaticBody2D = board.get_node("Walls").get_child(0)
	assert_eq(wall.position, Vector2(10, 640))

func test_duplicate_barge_ids_are_flagged() -> void:
	var dupes := Skyfield.duplicate_barge_ids([
		{"id": "left"}, {"id": "center"}, {"id": "left"}, {"id": "left"},
	])
	assert_eq(dupes, ["left"])

func test_region_1_has_no_duplicate_barge_ids() -> void:
	var region := DataDefs.skyfield("region_1")
	assert_eq(Skyfield.duplicate_barge_ids(region.get("barges", [])), [])
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: `duplicate_barge_ids` unknown; the TALL_REGION sea sits at the hardcoded (360, 1180) instead of (270, 2160).

- [ ] **Step 3: Implement**

In `game/run/skyfield.gd`:

1. In `build`, change `_build_sea()` to `_build_sea(board)`.

2. Replace `_build_walls` with:

```gdscript
func _build_walls(board: Dictionary) -> void:
	# Walls span from above the drop line to below the sea, all derived from
	# board data so taller region-2+ boards keep pods contained (for region 1
	# this reproduces the original constants exactly).
	var bottom := float(board.get("bottom", 1020))
	var top_edge := -60.0
	var bottom_edge := bottom + 320.0
	for x in [float(board.get("left", 20)) - 10.0, float(board.get("right", 700)) + 10.0]:
		var wall := StaticBody2D.new()
		wall.position = Vector2(x, (top_edge + bottom_edge) / 2.0)
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(20, bottom_edge - top_edge)
		collider.shape = shape
		wall.add_child(collider)
		$Walls.add_child(wall)
```

3. Replace `_build_sea` with:

```gdscript
func _build_sea(board: Dictionary) -> void:
	var left := float(board.get("left", 20))
	var right := float(board.get("right", 700))
	var bottom := float(board.get("bottom", 1020))
	var sea := Area2D.new()
	sea.name = "Sea"
	sea.position = Vector2((left + right) / 2.0, bottom + 160.0)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(right - left + 80.0, 80.0)
	collider.shape = shape
	sea.add_child(collider)
	sea.body_entered.connect(_on_catcher_body.bind(sea_payout.duplicate(), "sea"))
	add_child(sea)
```

4. Add above `_build_barges`:

```gdscript
static func duplicate_barge_ids(barges: Array) -> Array:
	# Region-authoring validation: duplicate ids make payout attribution
	# ambiguous and Godot silently renames the second Area2D.
	var seen := {}
	var dupes: Array = []
	for barge in barges:
		var id := String((barge as Dictionary).get("id", "barge"))
		if seen.has(id) and not dupes.has(id):
			dupes.append(id)
		seen[id] = true
	return dupes
```

5. At the top of `_build_barges`, add:

```gdscript
	for id in duplicate_barge_ids(barges):
		push_warning("Region JSON has duplicate barge id '%s'" % id)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0, including the physics catch tests (region-1 geometry is bit-identical).

- [ ] **Step 5: Commit**

```bash
git add game/run/skyfield.gd tests/test_skyfield.gd
git commit -m "feat: derive sea and wall geometry from board data, validate barge ids"
```

---

### Task 10: Android export preset, icon, and project config

**Files:**
- Create: `export_presets.cfg`, `icon.svg` (plus generated `icon.svg.import`)
- Modify: `project.godot` (`config/icon`), `.gitignore` (`build/`)
- Test: `tests/test_export_config.gd` (new)

**Interfaces:**
- Consumes: nothing in-game.
- Produces: an Android AAB preset that excludes `addons/gut/*` and `tests/*` from the export, arm64-v8a only, gradle AAB format, POST_NOTIFICATIONS declared; `application/config/icon` pointing at a committed placeholder icon. Producing an actual AAB (Android SDK + export templates) is out of repo scope; the test pins the config so it cannot rot.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_export_config.gd`:

```gdscript
extends GutTest
## Pins the Android export scaffolding (spec 7.1 export row, spec 8 MVP line).
## The preset is config only: building the AAB needs the Android SDK, which
## lives outside this repo's test loop.


func _load_presets() -> ConfigFile:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK, "export_presets.cfg must exist and parse")
	return cfg


func test_android_preset_is_a_gradle_aab_for_arm64() -> void:
	var cfg := _load_presets()
	assert_eq(String(cfg.get_value("preset.0", "platform", "")), "Android")
	assert_true(bool(cfg.get_value("preset.0.options", "gradle_build/use_gradle_build", false)))
	assert_eq(int(cfg.get_value("preset.0.options", "gradle_build/export_format", -1)), 1, "1 = AAB")
	assert_true(bool(cfg.get_value("preset.0.options", "architectures/arm64-v8a", false)))
	assert_false(bool(cfg.get_value("preset.0.options", "architectures/armeabi-v7a", true)))

func test_export_excludes_dev_only_directories() -> void:
	var cfg := _load_presets()
	var exclude := String(cfg.get_value("preset.0", "exclude_filter", ""))
	assert_string_contains(exclude, "addons/gut/*")
	assert_string_contains(exclude, "tests/*")

func test_post_notifications_permission_is_declared() -> void:
	var cfg := _load_presets()
	assert_true(bool(cfg.get_value("preset.0.options", "permissions/post_notifications", false)),
		"spec 5: Android 13+ runtime permission needs the manifest entry")

func test_project_icon_is_configured_and_present() -> void:
	assert_eq(String(ProjectSettings.get_setting("application/config/icon", "")), "res://icon.svg")
	assert_true(FileAccess.file_exists("res://icon.svg"))

func test_project_is_locked_to_portrait() -> void:
	assert_eq(int(ProjectSettings.get_setting("display/window/handheld/orientation", 0)), 1,
		"spec: portrait only")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: `export_presets.cfg` missing, `config/icon` unset.

- [ ] **Step 3: Implement**

Create `icon.svg` (placeholder pending the image-agent art pass, see docs/art/placeholder-graphics-audit.md section 3.3: pod over cloud band on sky blue):

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
	<rect width="128" height="128" rx="24" fill="#6fa8dc"/>
	<circle cx="64" cy="52" r="22" fill="#f9d94c" stroke="#b8860b" stroke-width="3"/>
	<path d="M0 96 Q 16 84 32 96 Q 48 108 64 96 Q 80 84 96 96 Q 112 108 128 96 L 128 128 L 0 128 Z" fill="#f3f6fb"/>
</svg>
```

Create `export_presets.cfg`:

```
[preset.0]

name="Android"
platform="Android"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="addons/gut/*, tests/*"
export_path="build/windfall-isles.aab"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
gradle_build/use_gradle_build=true
gradle_build/gradle_build_directory=""
gradle_build/android_source_template=""
gradle_build/compress_native_libraries=false
gradle_build/export_format=1
gradle_build/min_sdk=""
gradle_build/target_sdk=""
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
version/code=1
version/name="0.1.0"
package/unique_name="com.graydyn.windfallisles"
package/name="Windfall Isles"
package/signed=true
package/app_category=2
screen/immersive_mode=true
screen/support_small=true
screen/support_normal=true
screen/support_large=true
screen/support_xlarge=true
permissions/post_notifications=true
```

(If the Godot editor later rewrites this file into its canonical form, accept the normalization, same ruling as the project.godot normalization commit. `package/unique_name` is a tunable pre-release choice.)

In `project.godot`, add to the `[application]` section after the `config/features` line:

```
config/icon="res://icon.svg"
```

Append to `.gitignore`:

```
build/
```

- [ ] **Step 4: Import, verify sidecars, run tests**

Run: `$GODOT --headless --import`
Run: `git status --porcelain` and confirm `icon.svg.import` and `tests/test_export_config.gd.uid` appear; both must be committed.
Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0.

- [ ] **Step 5: Commit**

```bash
git add export_presets.cfg icon.svg icon.svg.import project.godot .gitignore tests/test_export_config.gd tests/test_export_config.gd.uid
git commit -m "feat: android export preset, placeholder icon, and export config guard"
```

---

### Task 11: Retention integration proof (fake clock end to end)

**Files:**
- Test: `tests/test_retention_integration.gd` (new)

**Interfaces:**
- Consumes: everything this plan produced, driven together on a fake clock through the pure models (no scene changes, no wall clock except the documented boundaries).

This is an integration-proof task: RED is not required (established per-plan ruling for fake-clock e2e tasks); write the test, make it pass, investigate any failure as a real integration bug.

- [ ] **Step 1: Write the integration test**

Create `tests/test_retention_integration.gd`:

```gdscript
extends GutTest
## End-to-end retention glue on a fake clock (spec 5, 6, 3.2): build, ad-skip,
## craft, notification planning at background time, daily ad limits rolling
## over midnight, quota tiers lifting payouts, and a future-version save
## surviving the downgrade roundtrip.

const TimerServiceScript := preload("res://game/autoload/timer_service.gd")
const EconomyScript := preload("res://game/autoload/economy.gd")
const GameStateScript := preload("res://game/autoload/game_state.gd")
const TEST_PATH := "user://test_retention.json"
const DAY := 86400
const T0 := 20834 * DAY + 3600  # 01:00 on a clean day boundary, far future

var state: Node
var econ: Node
var timers: Node


func before_each() -> void:
	_delete_test_files()
	state = autofree(GameStateScript.new())
	state._io = SaveIO.new(TEST_PATH)
	state.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	state.data["created_at"] = T0
	state.data["fuel"]["updated_at"] = T0
	state.data["currencies"]["scrap"] = 5000
	econ = autofree(EconomyScript.new())
	econ.setup(state)
	timers = autofree(TimerServiceScript.new())
	timers.setup(state)

func after_all() -> void:
	_delete_test_files()

func _delete_test_files() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_retention.json", "test_retention.json.tmp", "test_retention.json.bak", "test_retention.json.incompatible"]:
		if dir.file_exists(f):
			dir.remove(f)


func test_build_skip_craft_and_notification_flywheel() -> void:
	# Build the Workshop, ad-skip the construction, collect.
	assert_true(IslandModel.start_build(state.data["island"], DataDefs.buildings, econ, timers, "plot_0", "workshop", T0))
	Ads.service.request_reward(AdService.Placement.TIMER_SKIP, func() -> void: timers.skip("build_plot_0"))
	assert_true(timers.is_done("build_plot_0", T0 + 1))
	IslandModel.complete_build(state.data["island"], timers.collect("build_plot_0", T0 + 1), state.data, T0 + 1, DataDefs.buildings)
	assert_eq(IslandModel.building_level(state.data["island"], "workshop"), 1)
	# Start a craft, drain the tank, claim the crate, then background the app:
	# the plan must cover craft, fuel, and crate.
	assert_true(CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan", T0 + 2))
	state.data["fuel"]["amount"] = 0
	state.data["fuel"]["updated_at"] = T0 + 2
	state.data["daily_crate"]["last_claim_day"] = DailyCrate.day_of(T0)
	var plan := NotificationPlanner.plan(state.data, DataDefs.buildings, DataDefs.gizmos, T0 + 2)
	var ids := []
	for entry in plan:
		ids.append(String(entry["id"]))
	ids.sort()
	assert_eq(ids, ["craft_wind_fan", "daily_crate", "fuel_full"])
	# Ad-skip the craft and merge the level.
	Ads.service.request_reward(AdService.Placement.TIMER_SKIP, func() -> void: timers.skip("craft_wind_fan"))
	CraftModel.complete_craft(state.data, timers.collect("craft_wind_fan", T0 + 3))
	assert_eq(int(state.data["gizmos"]["owned"]["wind_fan"]), 2)
	# The save roundtrips through v5 untouched.
	assert_eq(state.save_game(), OK)
	var reloaded := SaveIO.new(TEST_PATH).read()
	assert_eq(int(reloaded["version"]), SaveSchema.CURRENT_VERSION)
	assert_eq(int(reloaded["gizmos"]["owned"]["wind_fan"]), 2)

func test_ad_daily_limits_roll_over_at_midnight() -> void:
	var limit := int((DataDefs.retention["ads"] as Dictionary)["fuel_refills_per_day"])
	for i in limit:
		assert_true(AdLimits.use(state.data, "fuel_refill", limit, T0 + i))
	assert_false(AdLimits.can_use(state.data, "fuel_refill", limit, T0 + 100))
	assert_true(AdLimits.can_use(state.data, "fuel_refill", limit, T0 + DAY),
		"the next calendar day resets the counter")

func test_quota_tier_lifts_payouts_mid_run() -> void:
	var model := RunModel.new({
		"drops_per_run": 3, "max_active_pods": 4,
		"quota_tiers": [{"scrap_quota": 12, "payout_multiplier": 2.0}],
	})
	watch_signals(model)
	model.begin_drop()
	model.resolve_pod({"scrap": 12})
	assert_signal_emitted_with_parameters(model, "tier_reached", [1])
	assert_eq(model.payout_multiplier(), 2.0, "later catches pay double")

func test_future_save_survives_the_downgrade_roundtrip() -> void:
	var io := SaveIO.new(TEST_PATH)
	io.write({"version": SaveSchema.CURRENT_VERSION + 1, "precious": true})
	state.load_game(DataDefs.economy, T0, DataDefs.gizmos, DataDefs.buildings)
	assert_eq(int(state.data["version"]), SaveSchema.CURRENT_VERSION, "playable defaults")
	var parked: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH + ".incompatible"))
	assert_true(bool((parked as Dictionary)["precious"]),
		"the newer save is parked, not destroyed (spec 7.3)")
```

- [ ] **Step 2: Run the suite**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0. Any failure here is an integration bug: debug it, do not weaken the test.

- [ ] **Step 3: Verify sidecar and commit**

Run: `$GODOT --headless --import` then `git status --porcelain` (the test's `.gd.uid` must be staged).

```bash
git add tests/test_retention_integration.gd tests/test_retention_integration.gd.uid
git commit -m "test: prove the retention and ad-accelerator glue end to end with fake clocks"
```

---

## Post-plan checklist (for the executing session, not a task)

- Final whole-branch review runs the canonical suite once as the gate.
- Windowed smoke steps are waived in this non-interactive environment (headless substitutes), noted in the report.
- Collect every ledger "Ruling:" line for the finishing menu.
- Known deliberate deferrals OUT of MVP after this plan: regions 2+, boons and boon-reroll placement, real AdMob (`AdmobAdService` + `OS.has_feature("admob")` pick in `ads.gd`), notification plugin vendoring, island expansion/story, gizmo rarities, Play Pass submission, final art pass (image-agent pipeline, see docs/art/placeholder-graphics-audit.md), sound.
