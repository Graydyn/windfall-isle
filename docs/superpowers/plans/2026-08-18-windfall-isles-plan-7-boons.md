# Windfall Isles Plan 7: Boons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Quota tiers get their payoff: crossing a tier offers a skippable pick-1-of-3 run-scoped boon from a data-driven pool of six, with a once-per-offer rewarded-ad reroll, plus the Plan 6 backlog fixes.

**Architecture:** The boon pool is data (`boons.json`); draws are a pure `BoonModel.offer` over an injected `RandomNumberGenerator` (the scene seeds from the clock at its boundary, tests pass fixed seeds). Taken-boon state and payout magnitudes live on `RunModel` (captured at pick time, so the model stays defs-free afterward); scene-side effects (Featherfall's pod defs, Second Wind's `recharge()`) apply in `salvage_run.gd`. The offer panel gates new drops only; physics never pauses. Nothing persists: no save schema change.

**Tech Stack:** Godot 4.6.3 GDScript, GUT 9.6.1 headless, JSON data files.

**Spec:** [docs/superpowers/specs/2026-08-18-boons-design.md](../specs/2026-08-18-boons-design.md) (approved; its parent docs/design/2026-08-15-windfall-isles-design.md binds where it is silent). Plans 1-6 are merged on main (333 tests green, plus the boons spec commit).

## Global Constraints

- Engine: Godot 4.6.x pinned; `$GODOT` = `/Applications/Godot-4.6.app/Contents/MacOS/Godot` (4.6.3). Never plain `godot` or `/Applications/Godot.app` (4.7).
- GDScript only; tabs. Every tunable in `game/data/*.json`. No em dashes in any file. Boons are strictly run-scoped: no save schema change, nothing persists.
- Randomness is injected: `BoonModel.offer` takes a `RandomNumberGenerator`; only the scene boundary seeds from `TimeUtil.now()`; tests use fixed seeds or force `_current_offer` directly. Never an unseeded global RNG in logic or tests.
- All ad interactions go through `Ads.service`; `AdService.Placement` gains `BOON_REROLL` appended LAST (existing member order unchanged; enum values are persisted nowhere but order discipline stands). One reroll per offer, granted at reward time; no daily limit (spec 6, placement 5). Unavailable placements hide their UI.
- Offer flow rules (spec sections 5-6): offers queue when one catch crosses two tiers; Skip forfeits (no banking); run end closes an open offer unpicked; pods in flight keep falling while the panel is up (only new drops are gated); reroll exclusions are the current trio plus taken boons, per-reroll only.
- Payout discipline: multiplied payouts use `roundi` and drop zero-value entries, identical for every catch source; Heavy Loot adds flat scrap only to non-empty payouts; the Chime Bell composes multiplicatively with Barge Bounty and is consumed only on barge catches, exactly as today.
- Canonical test command (must exit 0): `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- Binding repo lessons (Plans 1-6): `.gd.uid` sidecars committed for EVERY new script including tests, verified via `git status --porcelain` after `--import`; `int()`/`float()` wrap all JSON reads and int-cast scalar assertions against JSON-sourced dicts (raw dict equality against JSON is forbidden; DataDefs.load_json stays raw); UI tests never press buttons that change scenes (direct handler calls); GameState `_io` swap + four-arg `load_game` restore; error/warning-count assertions AFTER the trigger (`assert_push_warning_count` exists in this GUT); no cumulative suite totals; physics-affecting handlers need one real-contact proof where behavior changed (this plan's recharge restores counters and visuals only: direct handler tests suffice, and each consumable already has real-contact coverage of its original behavior); `add_child.call_deferred` inside physics-flush paths; loadout `_rebuild` uses detach-then-free (leave it; other screens' rebuilds unchanged).
- One pre-existing GUT warning (`tests/fixtures/test_gizmo.gd`) plus intentional push_warnings from tier-validation and duplicate-barge tests are known; new warnings are findings.
- The sandbox rejects compound bash commands; run commands one at a time.
- Commit after every task, conventional-commit messages.

## Interfaces consumed from Plans 1-6 (merged, exact)

- `RunModel` (game/run/run_model.gd, current): `_init(config)`, `drops_total`, `drops_used`, `drops_remaining()`, `begin_drop()`, `resolve_pod(payout)`, `add_bonus_loot(payout)`, `add_split_pod()`, `abandon()`, `is_over()`, `loot`, `tiers`, `tier`, `payout_multiplier()`, `_check_tier()`, `_valid_tiers(rows)` (static; drops malformed rows with one warning each), signals `loot_changed`, `run_over`, `tier_reached(tier)`.
- `salvage_run.gd` (current): `model`, `pod_defs` (member Dictionary used by `_on_drop_requested` and `request_split` for `pod.setup`), `board`, `controller` (`enabled` flag gates `drop_requested`), `_on_pod_caught(pod, payout, source="barge")` (computes `_compute_payout`, applies `_next_barge_multiplier` on barge, credits Economy, `model.resolve_pod`), `_on_run_over()` (disables controller, frees pods, saves, shows Results + DoubleButton), `_compute_payout(pod, base)` (tier multiplier x pod `value_mult`, `roundi`, drops zero entries), `_refresh_hud()`, `add_bonus`, `set_next_barge_multiplier`, `request_split`, `_on_double_pressed/_grant_payout_double`. Scene tree: `UI` CanvasLayer with `HudLabel`, `AbandonButton`, `Results/VBox/{Summary,DoubleButton,ReturnButton}`.
- `GizmoBase`: `setup/defs/level/context`, `scaled(base)`. Consumable internals: BalloonCluster `_hits_left`/`zone.set_deferred("monitoring", false)`/alpha 0.25 when spent; LightningJar `_charges`/alpha 0.25; ChimeBell `_uses_left`/alpha 0.25; CargoNet `_uses_left`/alpha 0.4. Skyfield holds installed gizmos under the `Gizmos` child; `install_gizmos` adds children then calls `setup`.
- `AdService.Placement` currently `{ TIMER_SKIP, FUEL_REFILL, PAYOUT_DOUBLE, BONUS_CRATE }`; `Ads.service` is `GrantAdService` (always available, synchronous grant).
- `RegionModel` (game/core/region_model.gd, current): `FALLBACK_ID`, `unlocked`, `fuel_cost`, `unlocked_entries`, `entry`, `selected_id(data, run_defs, island)` (currently casts `data.get("expedition", {})` as Dictionary unguarded), `_entries`.
- `main.gd._on_region_pressed` and `loadout_screen.gd._on_region_pressed` currently duplicate the cycle loop (entries lookup, index scan, modulo step) before their persistence lines.
- `DataDefs`: `economy/run/gizmos/buildings/retention` + `load_json`; adding `boons` follows the same pattern. `TimeUtil.now()`.
- Test fixtures: `tests/test_salvage_run.gd` (GameState `_io` swap to `user://test_run_scene.json`, scene instantiated per test via `add_child_autofree(RunScene.instantiate())`); `tests/test_region_model.gd` (`RUN_DEFS` const, `island_with_dock(level)` helper); gizmo tests use `add_child_autofree(<Scene>.instantiate())` + `setup(defs, level, self)` with `context_stub`-style inner classes where needed.

## File Structure

```
game/core/region_model.gd            # T1 modify (type guard + next_region_id)
game/main.gd                         # T1 modify (cycle via next_region_id)
game/ui/loadout_screen.gd            # T1 modify (cycle via next_region_id)
game/run/run_model.gd                # T1 modify (ascending warning), T3 modify (boon state)
tests/test_region_model.gd           # T1 append
tests/test_run_model.gd              # T1 append, T3 append
game/data/boons.json                 # T2
game/autoload/data_defs.gd           # T2 modify (boons)
game/core/boon_model.gd              # T2
tests/test_boon_model.gd             # T2
game/core/ad_service.gd              # T4 modify (BOON_REROLL)
game/run/gizmos/gizmo_base.gd        # T4 modify (recharge no-op)
game/run/salvage_run.gd              # T4 modify (offer flow), T5 modify (payout effects)
game/run/salvage_run.tscn            # T4 modify (BoonOffer panel)
tests/test_ad_service.gd             # T4 append
tests/test_salvage_run.gd            # T4 append, T5 append
game/run/gizmos/balloon_cluster.gd   # T6 modify (recharge)
game/run/gizmos/lightning_jar.gd     # T6 modify (recharge)
game/run/gizmos/chime_bell.gd        # T6 modify (recharge)
game/run/gizmos/cargo_net.gd         # T6 modify (recharge)
tests/test_balloon_cluster.gd        # T6 append
tests/test_lightning_jar.gd          # T6 append
tests/test_chime_bell.gd             # T6 append
tests/test_cargo_net.gd              # T6 append
tests/test_boon_integration.gd       # T7 e2e
```

---

### Task 1: Plan 6 backlog fixes

**Files:**
- Modify: `game/core/region_model.gd`, `game/main.gd`, `game/ui/loadout_screen.gd`, `game/run/run_model.gd`
- Test: `tests/test_region_model.gd` (append), `tests/test_run_model.gd` (append)

**Interfaces:**
- Consumes: current `selected_id`, the two duplicated `_on_region_pressed` bodies, `_valid_tiers`.
- Produces: `selected_id` tolerates a wrong-typed expedition section (falls back, never crashes); `RegionModel.next_region_id(run_defs: Dictionary, island: Dictionary, current_id: String) -> String` (next unlocked id in declared order; `current_id` unchanged when there is nothing to cycle to); both screens cycle through it (behavior identical, existing screen tests stay green untouched); `_valid_tiers` warns once per non-ascending `scrap_quota` pair (rows still load).

- [ ] **Step 1: Append the failing tests**

Append to `tests/test_region_model.gd`:

```gdscript
func test_selected_id_tolerates_a_wrong_typed_expedition_section() -> void:
	assert_eq(RegionModel.selected_id({"expedition": "region_2"}, RUN_DEFS, island_with_dock(2)), "region_1",
		"a hand-edited save must fall back, never crash")

func test_next_region_id_cycles_unlocked_regions_in_order() -> void:
	assert_eq(RegionModel.next_region_id(RUN_DEFS, island_with_dock(0), "region_1"), "region_1",
		"nothing to cycle to without a Dock")
	assert_eq(RegionModel.next_region_id(RUN_DEFS, island_with_dock(1), "region_1"), "region_2")
	assert_eq(RegionModel.next_region_id(RUN_DEFS, island_with_dock(1), "region_2"), "region_1", "wraps")

func test_next_region_id_recovers_an_unknown_current() -> void:
	assert_eq(RegionModel.next_region_id(RUN_DEFS, island_with_dock(1), "region_9"), "region_2",
		"an unknown current id scans as index 0 and steps to the next entry")
```

Append to `tests/test_run_model.gd`:

```gdscript
func test_non_ascending_quota_tiers_warn_but_load() -> void:
	var model := RunModel.new({
		"drops_per_run": 3, "max_active_pods": 4,
		"quota_tiers": [
			{"scrap_quota": 80, "payout_multiplier": 2.0},
			{"scrap_quota": 35, "payout_multiplier": 1.5},
		],
	})
	assert_push_warning_count(1, "one warning per out-of-order pair")
	assert_eq(model.tiers.size(), 2, "authoring warning only; rows still load")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: the wrong-typed test crashes or errors inside `selected_id`'s unguarded cast, `next_region_id` is unknown, the ascending test counts 0 warnings.

- [ ] **Step 3: Implement**

In `game/core/region_model.gd`:

1. Replace `selected_id` with:

```gdscript
static func selected_id(data: Dictionary, run_defs: Dictionary, island: Dictionary) -> String:
	# A persisted id that is unknown (defs changed), no longer unlocked
	# (hand-edited save), or held in a wrong-typed section falls back
	# silently; nothing rewrites the save.
	var expedition: Variant = data.get("expedition", {})
	if not (expedition is Dictionary):
		return FALLBACK_ID
	var wanted := String((expedition as Dictionary).get("region", FALLBACK_ID))
	var region_entry := entry(run_defs, wanted)
	if not region_entry.is_empty() and unlocked(region_entry, island):
		return wanted
	return FALLBACK_ID
```

2. Add after `selected_id`:

```gdscript
static func next_region_id(run_defs: Dictionary, island: Dictionary, current_id: String) -> String:
	# Cycle helper shared by the launcher and loadout screens: the next
	# unlocked id in declared order, or current_id when there is no cycle.
	var entries := unlocked_entries(run_defs, island)
	if entries.size() <= 1:
		return current_id
	var index := 0
	for i in entries.size():
		if String((entries[i] as Dictionary).get("id", "")) == current_id:
			index = i
			break
	return String((entries[(index + 1) % entries.size()] as Dictionary).get("id", FALLBACK_ID))
```

In `game/main.gd`, replace `_on_region_pressed` with:

```gdscript
func _on_region_pressed() -> void:
	var next := RegionModel.next_region_id(DataDefs.run, GameState.data["island"], _selected_region())
	if next == _selected_region():
		return
	if not GameState.data.has("expedition"):
		GameState.data["expedition"] = {"region": RegionModel.FALLBACK_ID}
	(GameState.data["expedition"] as Dictionary)["region"] = next
	GameState.save_game()
	_refresh()
```

In `game/ui/loadout_screen.gd`, replace `_on_region_pressed` with:

```gdscript
func _on_region_pressed() -> void:
	var next := RegionModel.next_region_id(DataDefs.run, GameState.data["island"], region_id)
	if next == region_id:
		return
	region_id = next
	if not GameState.data.has("expedition"):
		GameState.data["expedition"] = {"region": RegionModel.FALLBACK_ID}
	(GameState.data["expedition"] as Dictionary)["region"] = region_id
	GameState.save_game()
	_load_region()
```

In `game/run/run_model.gd`, in `_valid_tiers`, add before the final `return out`:

```gdscript
	for i in range(1, out.size()):
		if int((out[i] as Dictionary)["scrap_quota"]) <= int((out[i - 1] as Dictionary)["scrap_quota"]):
			push_warning("Quota tiers are not strictly ascending at index %d" % i)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0. The existing screen cycle tests (main_boot, loadout) stay green: the refactor preserves behavior exactly. The existing malformed-tier test still counts exactly 3 warnings (its one surviving row makes no pair).

- [ ] **Step 5: Commit**

```bash
git add game/core/region_model.gd game/main.gd game/ui/loadout_screen.gd game/run/run_model.gd tests/test_region_model.gd tests/test_run_model.gd
git commit -m "fix: plan 6 backlog: expedition type guard, shared region cycle, tier order warning"
```

---

### Task 2: The boon pool and BoonModel

**Files:**
- Create: `game/data/boons.json`, `game/core/boon_model.gd`
- Modify: `game/autoload/data_defs.gd`
- Test: `tests/test_boon_model.gd` (new)

**Interfaces:**
- Consumes: `DataDefs.load_json` pattern.
- Produces: `DataDefs.boons: Dictionary` (loaded at `_ready`); `BoonModel.offer(pool_ids: Array, taken: Array, rng: RandomNumberGenerator) -> Array` (up to 3 distinct ids, uniform without replacement, excluding `taken`; remainder when fewer than 3 candidates; `[]` when none). The six boon ids: `barge_bounty`, `rich_seas`, `spare_pods`, `heavy_loot`, `featherfall`, `second_wind`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_boon_model.gd`:

```gdscript
extends GutTest

const POOL := ["barge_bounty", "rich_seas", "spare_pods", "heavy_loot", "featherfall", "second_wind"]


func seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_offer_draws_three_distinct_pool_members() -> void:
	var offer := BoonModel.offer(POOL, [], seeded(42))
	assert_eq(offer.size(), 3)
	for id in offer:
		assert_has(POOL, id)
	assert_ne(offer[0], offer[1])
	assert_ne(offer[1], offer[2])
	assert_ne(offer[0], offer[2])

func test_offer_is_deterministic_for_a_fixed_seed() -> void:
	assert_eq(BoonModel.offer(POOL, [], seeded(42)), BoonModel.offer(POOL, [], seeded(42)),
		"same seed, same draw: the no-wall-clock discipline applied to randomness")

func test_offer_excludes_taken_boons() -> void:
	var taken := ["barge_bounty", "rich_seas", "spare_pods"]
	for seed_value in [1, 2, 3, 4, 5]:
		var offer := BoonModel.offer(POOL, taken, seeded(seed_value))
		for id in taken:
			assert_false(offer.has(id), "taken boons never reappear")

func test_short_pool_returns_the_remainder() -> void:
	var offer := BoonModel.offer(POOL, ["barge_bounty", "rich_seas", "spare_pods", "heavy_loot"], seeded(7))
	offer.sort()
	assert_eq(offer, ["featherfall", "second_wind"])

func test_exhausted_pool_returns_empty() -> void:
	assert_eq(BoonModel.offer(POOL, POOL, seeded(7)), [])

func test_boon_defs_load_with_names_and_descriptions() -> void:
	var defs: Dictionary = DataDefs.boons.get("defs", {})
	assert_eq(defs.size(), 6)
	for id in POOL:
		assert_has(defs, id)
		assert_true(String((defs[id] as Dictionary).get("name", "")) != "")
		assert_true(String((defs[id] as Dictionary).get("description", "")) != "")

func test_boon_magnitudes_are_data() -> void:
	var defs: Dictionary = DataDefs.boons.get("defs", {})
	assert_almost_eq(float((defs["barge_bounty"] as Dictionary)["barge_multiplier"]), 1.5, 0.001)
	assert_almost_eq(float((defs["rich_seas"] as Dictionary)["sea_multiplier"]), 3.0, 0.001)
	assert_eq(int((defs["spare_pods"] as Dictionary)["extra_drops"]), 2)
	assert_eq(int((defs["heavy_loot"] as Dictionary)["bonus_scrap_per_catch"]), 2)
	assert_almost_eq(float((defs["featherfall"] as Dictionary)["bounce_bonus"]), 0.2, 0.001)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: `BoonModel` unknown; `DataDefs.boons` does not exist.

- [ ] **Step 3: Implement**

Create `game/data/boons.json`:

```json
{
	"defs": {
		"barge_bounty": {"name": "Barge Bounty", "description": "Barge payouts +50% this run.", "barge_multiplier": 1.5},
		"rich_seas": {"name": "Rich Seas", "description": "Cloud-sea payouts tripled this run.", "sea_multiplier": 3.0},
		"spare_pods": {"name": "Spare Pods", "description": "+2 pod drops this run.", "extra_drops": 2},
		"heavy_loot": {"name": "Heavy Loot", "description": "+2 scrap on every catch this run.", "bonus_scrap_per_catch": 2},
		"featherfall": {"name": "Featherfall", "description": "Pods dropped from now on bounce higher.", "bounce_bonus": 0.2},
		"second_wind": {"name": "Second Wind", "description": "Consumable gizmos regain their uses."}
	}
}
```

In `game/autoload/data_defs.gd`:

1. Add after the `RETENTION_PATH` const: `const BOONS_PATH := "res://game/data/boons.json"`
2. Add after `var retention: Dictionary = {}`: `var boons: Dictionary = {}`
3. In `_ready`, add after the `retention = ...` line: `boons = load_json(BOONS_PATH)`

Create `game/core/boon_model.gd`:

```gdscript
class_name BoonModel
## Pure boon-offer draws (spec 3.2 step 4): pick-1-of-3 run-scoped modifiers.
## The RandomNumberGenerator is injected: the scene seeds from the clock at
## its boundary, tests pass fixed seeds. This is the repo's no-wall-clock
## discipline applied to randomness.


static func offer(pool_ids: Array, taken: Array, rng: RandomNumberGenerator) -> Array:
	var candidates: Array = []
	for id in pool_ids:
		if not taken.has(id):
			candidates.append(id)
	var out: Array = []
	while out.size() < 3 and not candidates.is_empty():
		out.append(candidates.pop_at(rng.randi_range(0, candidates.size() - 1)))
	return out
```

- [ ] **Step 4: Import, verify sidecars, run tests**

Run: `$GODOT --headless --import`
Run: `git status --porcelain` and confirm `game/core/boon_model.gd.uid` and `tests/test_boon_model.gd.uid` appear; both go in the commit.
Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/data/boons.json game/core/boon_model.gd game/core/boon_model.gd.uid game/autoload/data_defs.gd tests/test_boon_model.gd tests/test_boon_model.gd.uid
git commit -m "feat: boon pool data and seeded boon offer draws"
```

---

### Task 3: RunModel boon state and accessors

**Files:**
- Modify: `game/run/run_model.gd`
- Test: `tests/test_run_model.gd` (append)

**Interfaces:**
- Consumes: current RunModel members.
- Produces (read by T4/T5/T7): `boons: Array` (taken ids, pick order); `add_boon(boon_id: String, boon_defs: Dictionary) -> void` (records the id, captures magnitudes, applies `spare_pods` drops immediately; duplicate ids are no-ops); `add_drops(count: int) -> void` (negative-safe); `has_boon(boon_id: String) -> bool`; `barge_boon_multiplier() -> float` (1.0 neutral); `sea_boon_multiplier() -> float` (1.0 neutral); `bonus_scrap_per_catch() -> int` (0 neutral).

- [ ] **Step 1: Append the failing tests**

Append to `tests/test_run_model.gd`:

```gdscript
const BOON_DEFS := {
	"defs": {
		"barge_bounty": {"name": "Barge Bounty", "barge_multiplier": 1.5},
		"rich_seas": {"name": "Rich Seas", "sea_multiplier": 3.0},
		"spare_pods": {"name": "Spare Pods", "extra_drops": 2},
		"heavy_loot": {"name": "Heavy Loot", "bonus_scrap_per_catch": 2},
		"featherfall": {"name": "Featherfall", "bounce_bonus": 0.2},
		"second_wind": {"name": "Second Wind"},
	},
}


func test_boon_accessors_default_neutral() -> void:
	var model := make_model()
	assert_eq(model.barge_boon_multiplier(), 1.0)
	assert_eq(model.sea_boon_multiplier(), 1.0)
	assert_eq(model.bonus_scrap_per_catch(), 0)
	assert_false(model.has_boon("barge_bounty"))

func test_add_boon_captures_magnitudes() -> void:
	var model := make_model()
	model.add_boon("barge_bounty", BOON_DEFS)
	model.add_boon("rich_seas", BOON_DEFS)
	model.add_boon("heavy_loot", BOON_DEFS)
	assert_true(model.has_boon("barge_bounty"))
	assert_almost_eq(model.barge_boon_multiplier(), 1.5, 0.001)
	assert_almost_eq(model.sea_boon_multiplier(), 3.0, 0.001)
	assert_eq(model.bonus_scrap_per_catch(), 2)
	assert_eq(model.boons, ["barge_bounty", "rich_seas", "heavy_loot"], "pick order preserved")

func test_spare_pods_extends_the_run_immediately() -> void:
	var model := make_model(3)
	model.add_boon("spare_pods", BOON_DEFS)
	assert_eq(model.drops_remaining(), 5)

func test_duplicate_boon_is_a_no_op() -> void:
	var model := make_model()
	model.add_boon("heavy_loot", BOON_DEFS)
	model.add_boon("heavy_loot", BOON_DEFS)
	assert_eq(model.bonus_scrap_per_catch(), 2, "magnitudes never stack")
	assert_eq(model.boons.size(), 1)

func test_add_drops_is_negative_safe() -> void:
	var model := make_model(3)
	model.add_drops(-5)
	assert_eq(model.drops_remaining(), 3)

func test_scene_only_boons_record_without_magnitudes() -> void:
	var model := make_model()
	model.add_boon("featherfall", BOON_DEFS)
	model.add_boon("second_wind", BOON_DEFS)
	assert_true(model.has_boon("featherfall"))
	assert_true(model.has_boon("second_wind"))
	assert_eq(model.barge_boon_multiplier(), 1.0, "no payout magnitudes on scene-side boons")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: `add_boon`, `boons`, and the accessors are unknown.

- [ ] **Step 3: Implement**

In `game/run/run_model.gd`:

1. Add after `var tier := 0`:

```gdscript
var boons: Array = []

var _barge_boon_multiplier := 1.0
var _sea_boon_multiplier := 1.0
var _bonus_scrap_per_catch := 0
```

2. Add after `add_split_pod`:

```gdscript
func add_boon(boon_id: String, boon_defs: Dictionary) -> void:
	# Run-scoped modifiers (spec 3.2 step 4). Magnitudes are captured at pick
	# time so the model stays defs-free afterward; the offer already excludes
	# taken ids, so the duplicate guard is belt and braces.
	if boons.has(boon_id):
		return
	boons.append(boon_id)
	var def: Dictionary = (boon_defs.get("defs", {}) as Dictionary).get(boon_id, {})
	_barge_boon_multiplier = maxf(_barge_boon_multiplier, float(def.get("barge_multiplier", 1.0)))
	_sea_boon_multiplier = maxf(_sea_boon_multiplier, float(def.get("sea_multiplier", 1.0)))
	_bonus_scrap_per_catch += int(def.get("bonus_scrap_per_catch", 0))
	if def.has("extra_drops"):
		add_drops(int(def["extra_drops"]))


func add_drops(count: int) -> void:
	drops_total += maxi(0, count)


func has_boon(boon_id: String) -> bool:
	return boons.has(boon_id)


func barge_boon_multiplier() -> float:
	return _barge_boon_multiplier


func sea_boon_multiplier() -> float:
	return _sea_boon_multiplier


func bonus_scrap_per_catch() -> int:
	return _bonus_scrap_per_catch
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/run/run_model.gd tests/test_run_model.gd
git commit -m "feat: run model records boons and exposes payout magnitudes"
```

---

### Task 4: The boon offer flow and the reroll placement

**Files:**
- Modify: `game/core/ad_service.gd` (enum), `game/run/gizmos/gizmo_base.gd` (recharge no-op), `game/run/salvage_run.gd`, `game/run/salvage_run.tscn`
- Test: `tests/test_ad_service.gd` (append), `tests/test_salvage_run.gd` (append)

**Interfaces:**
- Consumes: `BoonModel.offer` (T2), `RunModel.add_boon/boons/is_over` (T3), `Ads.service`, `controller.enabled`.
- Produces: `AdService.Placement.BOON_REROLL` (appended last); `GizmoBase.recharge() -> void` (default no-op; T6 overrides it); scene members `_rng: RandomNumberGenerator` (seeded from `TimeUtil.now()` in `_ready`), `_current_offer: Array`, `_offer_rerolled: bool`, `_pending_offers: int`; handlers `_on_tier_reached(tier)`, `_show_next_offer()`, `_render_offer()`, `_on_boon_picked(index)`, `_apply_scene_boon(boon_id)`, `_on_boon_skipped()`, `_close_offer()`, `_on_reroll_pressed()`, `_grant_reroll()`; the `UI/BoonOffer` panel. Offer rules per Global Constraints (queueing, skip forfeits, run-over closes, one reroll per offer excluding the current trio).

- [ ] **Step 1: Append the failing tests**

Append to `tests/test_ad_service.gd`:

```gdscript
func test_boon_reroll_placement_exists_and_grants() -> void:
	var svc := GrantAdService.new()
	assert_true(svc.is_available(AdService.Placement.BOON_REROLL))
	var granted := [false]
	svc.request_reward(AdService.Placement.BOON_REROLL, func() -> void: granted[0] = true)
	assert_true(granted[0])
```

Append to `tests/test_salvage_run.gd`:

```gdscript
func test_tier_reached_shows_an_offer_and_pauses_drops() -> void:
	scene._rng.seed = 42
	scene._on_tier_reached(1)
	assert_true(scene.get_node("UI/BoonOffer").visible)
	assert_false(scene.get_node("DropController").enabled, "new drops gate while the offer is up")
	assert_eq((scene._current_offer as Array).size(), 3)

func test_picking_a_boon_applies_and_resumes() -> void:
	scene._rng.seed = 42
	scene._on_tier_reached(1)
	var picked := String(scene._current_offer[0])
	scene._on_boon_picked(0)
	assert_true(scene.model.has_boon(picked))
	assert_false(scene.get_node("UI/BoonOffer").visible)
	assert_true(scene.get_node("DropController").enabled)

func test_skip_forfeits_without_applying() -> void:
	scene._rng.seed = 42
	scene._on_tier_reached(1)
	scene._on_boon_skipped()
	assert_eq((scene.model.boons as Array).size(), 0, "spec: skip forfeits, no banking")
	assert_false(scene.get_node("UI/BoonOffer").visible)
	assert_true(scene.get_node("DropController").enabled)

func test_reroll_redraws_disjoint_and_is_once_per_offer() -> void:
	scene._rng.seed = 42
	scene._on_tier_reached(1)
	var before: Array = (scene._current_offer as Array).duplicate()
	scene._on_reroll_pressed()
	var after: Array = scene._current_offer
	for id in after:
		assert_false(before.has(id), "the reroll never returns the same trio")
	assert_false(scene.get_node("UI/BoonOffer/VBox/RerollButton").visible, "one reroll per offer")
	scene._on_reroll_pressed()
	assert_eq(scene._current_offer, after, "a second reroll is a no-op")

func test_crossing_two_tiers_queues_two_offers() -> void:
	scene._rng.seed = 42
	scene._on_tier_reached(1)
	scene._on_tier_reached(2)
	scene._on_boon_picked(0)
	assert_true(scene.get_node("UI/BoonOffer").visible, "the queued second offer serves immediately")
	assert_false(scene.get_node("DropController").enabled)
	scene._on_boon_skipped()
	assert_true(scene.get_node("DropController").enabled)
	assert_eq((scene.model.boons as Array).size(), 1)

func test_run_over_closes_an_open_offer_unpicked() -> void:
	scene.model = RunModel.new({"drops_per_run": 1, "max_active_pods": 4})
	scene.model.run_over.connect(scene._on_run_over)
	scene._rng.seed = 42
	scene._on_tier_reached(1)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(pod, {"scrap": 3})
	assert_false(scene.get_node("UI/BoonOffer").visible, "run end closes the offer, nothing lost")
	assert_true(scene.get_node("UI/Results").visible)
	assert_eq((scene.model.boons as Array).size(), 0)

func test_featherfall_bumps_only_subsequent_pod_defs() -> void:
	var bounce_before := float(scene.pod_defs.get("bounce", 0.55))
	scene._current_offer = ["featherfall", "rich_seas", "heavy_loot"]
	scene._on_boon_picked(0)
	assert_almost_eq(float(scene.pod_defs["bounce"]), bounce_before + 0.2, 0.001)
	assert_almost_eq(float((DataDefs.run["pod"] as Dictionary)["bounce"]), bounce_before, 0.001,
		"the shared defs are never mutated; the scene copies before bumping")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: `BOON_REROLL` unknown, `_on_tier_reached` and the BoonOffer node missing.

- [ ] **Step 3: Implement the enum, the virtual, and the panel**

In `game/core/ad_service.gd`, replace the enum line with:

```gdscript
enum Placement { TIMER_SKIP, FUEL_REFILL, PAYOUT_DOUBLE, BONUS_CRATE, BOON_REROLL }
```

In `game/run/gizmos/gizmo_base.gd`, add after `scaled`:

```gdscript
func recharge() -> void:
	# Second Wind boon (Plan 7): consumable gizmos restore their uses.
	# Default no-op for always-active gizmos.
	pass
```

In `game/run/salvage_run.tscn`, add after the `Results/VBox/ReturnButton` node block:

```
[node name="BoonOffer" type="PanelContainer" parent="UI"]
visible = false
offset_left = 60.0
offset_top = 360.0
offset_right = 660.0
offset_bottom = 780.0

[node name="VBox" type="VBoxContainer" parent="UI/BoonOffer"]

[node name="Title" type="Label" parent="UI/BoonOffer/VBox"]
text = "The winds favor you. Choose a boon:"

[node name="Pick0" type="Button" parent="UI/BoonOffer/VBox"]

[node name="Pick1" type="Button" parent="UI/BoonOffer/VBox"]

[node name="Pick2" type="Button" parent="UI/BoonOffer/VBox"]

[node name="RerollButton" type="Button" parent="UI/BoonOffer/VBox"]
text = "Reroll (ad)"

[node name="SkipButton" type="Button" parent="UI/BoonOffer/VBox"]
text = "Skip"
```

- [ ] **Step 4: Implement the offer flow**

In `game/run/salvage_run.gd`:

1. Add after `var _payout_doubled := false`:

```gdscript
var _rng := RandomNumberGenerator.new()
var _current_offer: Array = []
var _offer_rerolled := false
var _pending_offers := 0
```

2. In `_ready`, add after the `model.run_over.connect(...)` line:

```gdscript
	model.tier_reached.connect(_on_tier_reached)
	_rng.seed = TimeUtil.now()
	for i in 3:
		($UI/BoonOffer/VBox.get_node("Pick%d" % i) as Button).pressed.connect(_on_boon_picked.bind(i))
	$UI/BoonOffer/VBox/RerollButton.pressed.connect(_on_reroll_pressed)
	$UI/BoonOffer/VBox/SkipButton.pressed.connect(_on_boon_skipped)
```

3. In `_on_run_over`, add after `controller.enabled = false`:

```gdscript
	$UI/BoonOffer.visible = false
	_pending_offers = 0
	_current_offer = []
```

4. Add at the end of the file:

```gdscript
func _on_tier_reached(_tier: int) -> void:
	# Spec 3.2 step 4: each tier crossing offers a boon. One rich catch can
	# cross two tiers; the offers queue and serve one at a time.
	_pending_offers += 1
	if not $UI/BoonOffer.visible:
		_show_next_offer()


func _show_next_offer() -> void:
	if _pending_offers <= 0 or model.is_over():
		return
	_pending_offers -= 1
	_current_offer = BoonModel.offer((DataDefs.boons.get("defs", {}) as Dictionary).keys(), model.boons, _rng)
	if _current_offer.is_empty():
		return
	_offer_rerolled = false
	controller.enabled = false
	_render_offer()
	$UI/BoonOffer.visible = true


func _render_offer() -> void:
	var defs: Dictionary = DataDefs.boons.get("defs", {})
	for i in 3:
		var button: Button = $UI/BoonOffer/VBox.get_node("Pick%d" % i)
		if i < _current_offer.size():
			var def: Dictionary = defs.get(String(_current_offer[i]), {})
			button.text = "%s\n%s" % [String(def.get("name", _current_offer[i])), String(def.get("description", ""))]
			button.visible = true
		else:
			button.visible = false
	$UI/BoonOffer/VBox/RerollButton.visible = Ads.service.is_available(AdService.Placement.BOON_REROLL) \
		and not _offer_rerolled


func _on_boon_picked(index: int) -> void:
	if index >= _current_offer.size():
		return
	var boon_id := String(_current_offer[index])
	model.add_boon(boon_id, DataDefs.boons)
	_apply_scene_boon(boon_id)
	_close_offer()


func _apply_scene_boon(boon_id: String) -> void:
	# Scene-side effects: the model handles payout magnitudes; the scene owns
	# pod construction (Featherfall) and the live gizmo nodes (Second Wind).
	var def: Dictionary = (DataDefs.boons.get("defs", {}) as Dictionary).get(boon_id, {})
	if boon_id == "featherfall":
		pod_defs = pod_defs.duplicate()
		pod_defs["bounce"] = minf(1.0, float(pod_defs.get("bounce", 0.55)) + float(def.get("bounce_bonus", 0.2)))
	elif boon_id == "second_wind":
		for gizmo in board.get_node("Gizmos").get_children():
			(gizmo as GizmoBase).recharge()


func _on_boon_skipped() -> void:
	# Spec: skip forfeits the offer; there is no banking.
	_close_offer()


func _close_offer() -> void:
	$UI/BoonOffer.visible = false
	_current_offer = []
	_refresh_hud()
	if _pending_offers > 0:
		_show_next_offer()
		return
	if not model.is_over():
		controller.enabled = true


func _on_reroll_pressed() -> void:
	if _offer_rerolled or not Ads.service.is_available(AdService.Placement.BOON_REROLL):
		return
	Ads.service.request_reward(AdService.Placement.BOON_REROLL, _grant_reroll)


func _grant_reroll() -> void:
	# One reroll per offer (spec 6 placement 5), granted at reward time. The
	# current trio joins the exclusions so the redraw is always disjoint;
	# the exclusion is per-reroll only, never permanent.
	if _offer_rerolled:
		return
	_offer_rerolled = true
	var exclusions: Array = (model.boons as Array).duplicate()
	exclusions.append_array(_current_offer)
	var redraw := BoonModel.offer((DataDefs.boons.get("defs", {}) as Dictionary).keys(), exclusions, _rng)
	if not redraw.is_empty():
		_current_offer = redraw
	_render_offer()
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0. Existing scene tests stay green: no boon is ever offered unless `tier_reached` fires, and existing tests never cross region_1's 25-scrap quota.

- [ ] **Step 6: Commit**

```bash
git add game/core/ad_service.gd game/run/gizmos/gizmo_base.gd game/run/salvage_run.gd game/run/salvage_run.tscn tests/test_ad_service.gd tests/test_salvage_run.gd
git commit -m "feat: boon offers on tier lifts with a rewarded-ad reroll"
```

---

### Task 5: Payout effects: Barge Bounty, Rich Seas, Heavy Loot

**Files:**
- Modify: `game/run/salvage_run.gd` (`_on_pod_caught`)
- Test: `tests/test_salvage_run.gd` (append)

**Interfaces:**
- Consumes: `RunModel.barge_boon_multiplier/sea_boon_multiplier/bonus_scrap_per_catch` (T3), the offer flow (T4).
- Produces: barge-source payouts multiply by the barge boon (composing multiplicatively with the Chime Bell's one-shot `_next_barge_multiplier`, which is still consumed only on barge catches); sea-source payouts (watchdog included, it passes `"sea"`) multiply by the sea boon; non-empty payouts gain the flat scrap bonus after all multipliers. Neutral boons leave every existing payout bit-identical.

- [ ] **Step 1: Append the failing tests**

Append to `tests/test_salvage_run.gd`:

```gdscript
func test_barge_bounty_boosts_barge_catches() -> void:
	scene._current_offer = ["barge_bounty", "rich_seas", "heavy_loot"]
	scene._on_boon_picked(0)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	var scrap_before := Economy.balance("scrap")
	scene._on_pod_caught(pod, {"scrap": 10}, "barge")
	assert_eq(Economy.balance("scrap"), scrap_before + 15, "10 x 1.5 barge bounty")

func test_barge_bounty_composes_with_the_chime_bell() -> void:
	scene._current_offer = ["barge_bounty", "rich_seas", "heavy_loot"]
	scene._on_boon_picked(0)
	scene.set_next_barge_multiplier(2.0)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	var scrap_before := Economy.balance("scrap")
	scene._on_pod_caught(pod, {"scrap": 10}, "barge")
	assert_eq(Economy.balance("scrap"), scrap_before + 30, "10 x 1.5 boon x 2.0 bell")

func test_rich_seas_boosts_sea_catches_only() -> void:
	scene._current_offer = ["rich_seas", "barge_bounty", "heavy_loot"]
	scene._on_boon_picked(0)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	var scrap_before := Economy.balance("scrap")
	scene._on_pod_caught(pod, {"scrap": 2}, "sea")
	assert_eq(Economy.balance("scrap"), scrap_before + 6, "2 x 3.0 rich seas")
	scene._on_drop_requested(300.0)
	var pod2: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(pod2, {"scrap": 10}, "barge")
	assert_eq(Economy.balance("scrap"), scrap_before + 6 + 10, "barge catches are untouched by rich seas")

func test_heavy_loot_adds_flat_scrap_after_multipliers() -> void:
	scene._current_offer = ["heavy_loot", "rich_seas", "barge_bounty"]
	scene._on_boon_picked(0)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	var scrap_before := Economy.balance("scrap")
	scene._on_pod_caught(pod, {"cloudsilk": 1}, "barge")
	assert_eq(Economy.balance("scrap"), scrap_before + 2, "the bonus lands even on non-scrap catches")
	assert_eq(int(scene.model.loot.get("cloudsilk", 0)), 1)

func test_heavy_loot_skips_empty_payouts() -> void:
	scene._current_offer = ["heavy_loot", "rich_seas", "barge_bounty"]
	scene._on_boon_picked(0)
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	pod.set_meta("value_mult", 0.0)
	var scrap_before := Economy.balance("scrap")
	scene._on_pod_caught(pod, {"scrap": 1}, "barge")
	assert_eq(Economy.balance("scrap"), scrap_before, "a zero-value catch stays worth nothing")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: the boons apply nothing yet (payouts unchanged).

- [ ] **Step 3: Implement**

In `game/run/salvage_run.gd`, replace `_on_pod_caught` with:

```gdscript
func _on_pod_caught(pod: Node, payout: Dictionary, source: String = "barge") -> void:
	payout = _compute_payout(pod, payout)
	var source_mult := 1.0
	if source == "barge":
		source_mult = model.barge_boon_multiplier()
		if _next_barge_multiplier > 1.0:
			# Chime Bell: one-shot, consumed only by a barge catch, composing
			# multiplicatively with the run-long Barge Bounty boon.
			source_mult *= _next_barge_multiplier
			_next_barge_multiplier = 1.0
	elif source == "sea":
		source_mult = model.sea_boon_multiplier()
	if not is_equal_approx(source_mult, 1.0):
		var boosted := {}
		for currency in payout:
			var value := roundi(float(payout[currency]) * source_mult)
			if value > 0:
				boosted[currency] = value
		payout = boosted
	var bonus := model.bonus_scrap_per_catch()
	if bonus > 0 and not payout.is_empty():
		# Heavy Loot: flat scrap after all multipliers; empty payouts stay
		# empty so "nothing salvaged" remains truthful.
		payout = payout.duplicate()
		payout["scrap"] = int(payout.get("scrap", 0)) + bonus
	if is_instance_valid(pod):
		pod.queue_free()
	for currency in payout:
		Economy.add(currency, int(payout[currency]))
	model.resolve_pod(payout)
	_refresh_hud()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0. Every existing payout test stays green: with no boon taken, `source_mult` reduces to exactly the old bell-only path (1.0 or the bell value) and the bonus branch never fires.

- [ ] **Step 5: Commit**

```bash
git add game/run/salvage_run.gd tests/test_salvage_run.gd
git commit -m "feat: barge bounty, rich seas, and heavy loot payout effects"
```

---

### Task 6: Second Wind: recharge overrides on the four consumables

**Files:**
- Modify: `game/run/gizmos/balloon_cluster.gd`, `game/run/gizmos/lightning_jar.gd`, `game/run/gizmos/chime_bell.gd`, `game/run/gizmos/cargo_net.gd`
- Test: `tests/test_balloon_cluster.gd`, `tests/test_lightning_jar.gd`, `tests/test_chime_bell.gd`, `tests/test_cargo_net.gd` (append one test each)

**Interfaces:**
- Consumes: `GizmoBase.recharge()` no-op (T4), each consumable's internals (see Interfaces section above).
- Produces: each override restores its uses counter from `defs`, restores `$Visual.modulate.a = 1.0`, and (Balloon Cluster only) re-enables `zone` monitoring via `set_deferred`. Always-active gizmos keep the inherited no-op. The Piston Kicker's `"piston_kicked"` pod meta is deliberately NOT recharged (it is pod state, not gizmo state).

- [ ] **Step 1: Append the failing tests**

Each test drives the gizmo to spent through its existing test file's established fixture style, then recharges. Append to `tests/test_balloon_cluster.gd` (match its existing fixture names; it instantiates the scene and calls `setup(defs, level, self)` with defs from `DataDefs.gizmos`):

```gdscript
func test_recharge_restores_hits_and_visual() -> void:
	var balloon = add_child_autofree(preload("res://game/run/gizmos/balloon_cluster.tscn").instantiate())
	balloon.setup((DataDefs.gizmos["defs"]["balloon_cluster"] as Dictionary).duplicate(), 1, self)
	balloon._hits_left = 0
	balloon.get_node("Visual").modulate.a = 0.25
	balloon.recharge()
	assert_eq(balloon._hits_left, int(DataDefs.gizmos["defs"]["balloon_cluster"]["max_hits"]))
	assert_almost_eq(balloon.get_node("Visual").modulate.a, 1.0, 0.001)
```

Append to `tests/test_lightning_jar.gd` (its fixture builds the jar in `before_each` as `jar`):

```gdscript
func test_recharge_restores_charges_and_visual() -> void:
	jar._charges = 0
	jar.get_node("Visual").modulate.a = 0.25
	jar.recharge()
	assert_eq(jar._charges, int(DataDefs.gizmos["defs"]["lightning_jar"]["charges"]))
	assert_almost_eq(jar.get_node("Visual").modulate.a, 1.0, 0.001)
```

Append to `tests/test_chime_bell.gd` (match its fixture; if it builds the bell per test, instantiate as in the balloon test):

```gdscript
func test_recharge_restores_rings_and_visual() -> void:
	var bell = add_child_autofree(preload("res://game/run/gizmos/chime_bell.tscn").instantiate())
	bell.setup((DataDefs.gizmos["defs"]["chime_bell"] as Dictionary).duplicate(), 1, self)
	bell._uses_left = 0
	bell.get_node("Visual").modulate.a = 0.25
	bell.recharge()
	assert_eq(bell._uses_left, int(DataDefs.gizmos["defs"]["chime_bell"]["uses_per_run"]))
	assert_almost_eq(bell.get_node("Visual").modulate.a, 1.0, 0.001)
```

Append to `tests/test_cargo_net.gd`:

```gdscript
func test_recharge_restores_the_net() -> void:
	var net = add_child_autofree(preload("res://game/run/gizmos/cargo_net.tscn").instantiate())
	net.setup((DataDefs.gizmos["defs"]["cargo_net"] as Dictionary).duplicate(), 1, self)
	net._uses_left = 0
	net.get_node("Visual").modulate.a = 0.4
	net.recharge()
	assert_eq(net._uses_left, int(DataDefs.gizmos["defs"]["cargo_net"]["uses"]))
	assert_almost_eq(net.get_node("Visual").modulate.a, 1.0, 0.001)
```

(If a fixture in these files already constructs the gizmo under a different variable name, reuse that fixture instead of instantiating inline; the assertions stay the same. Also verify: the balloon's spent path disables `zone.monitoring` via `set_deferred`, so its recharge must re-enable it; extend the balloon test with `await wait_physics_frames(1)` then `assert_true(balloon.get_node("Zone").monitoring)` after `recharge()`.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: `recharge()` exists (T4's no-op) but restores nothing, so the counters stay 0.

- [ ] **Step 3: Implement**

Add to `game/run/gizmos/balloon_cluster.gd`:

```gdscript
func recharge() -> void:
	_hits_left = int(defs.get("max_hits", 3))
	$Visual.modulate.a = 1.0
	zone.set_deferred("monitoring", true)
```

Add to `game/run/gizmos/lightning_jar.gd`:

```gdscript
func recharge() -> void:
	_charges = int(defs.get("charges", 2))
	$Visual.modulate.a = 1.0
```

Add to `game/run/gizmos/chime_bell.gd`:

```gdscript
func recharge() -> void:
	_uses_left = int(defs.get("uses_per_run", 2))
	$Visual.modulate.a = 1.0
```

Add to `game/run/gizmos/cargo_net.gd`:

```gdscript
func recharge() -> void:
	_uses_left = int(defs.get("uses", 1))
	$Visual.modulate.a = 1.0
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0.

- [ ] **Step 5: Commit**

```bash
git add game/run/gizmos/balloon_cluster.gd game/run/gizmos/lightning_jar.gd game/run/gizmos/chime_bell.gd game/run/gizmos/cargo_net.gd tests/test_balloon_cluster.gd tests/test_lightning_jar.gd tests/test_chime_bell.gd tests/test_cargo_net.gd
git commit -m "feat: second wind recharges the four consumable gizmos"
```

---

### Task 7: Boon flywheel integration proof

**Files:**
- Test: `tests/test_boon_integration.gd` (new)

**Interfaces:**
- Consumes: everything this plan produced, driven through the real scene with a forced offer for determinism (fixed seeds where the rng is used; forced `_current_offer` where the specific boon matters).

This is an integration-proof task: RED is not required (standing ruling for fake-clock/fixed-seed e2e tasks). Write the test, make it pass; a failing assertion is a real integration bug, never a test to weaken.

- [ ] **Step 1: Write the integration test**

Create `tests/test_boon_integration.gd`:

```gdscript
extends GutTest
## End-to-end boon flywheel through the real run scene (spec sections 3-7):
## a catch crosses region 1's first quota tier, the offer appears and gates
## drops, a picked Barge Bounty boosts the next barge catch on top of the
## tier multiplier, Spare Pods extends the run, and the run finishes with
## everything banked. Determinism: fixed rng seed for the organic offer,
## forced offers where a specific boon is required.

const RunScene := preload("res://game/run/salvage_run.tscn")
const TEST_SAVE := "user://test_boon_integration.json"

var scene


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	GameState.data["created_at"] = 1000
	GameState.data["fuel"]["updated_at"] = 1000
	scene = add_child_autofree(RunScene.instantiate())
	scene._rng.seed = 20260818

func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_boon_integration.json", "test_boon_integration.json.tmp", "test_boon_integration.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings)


func test_boon_flywheel_end_to_end() -> void:
	var scrap_before := Economy.balance("scrap")
	# Catch 25 scrap: exactly region 1's first quota. The crossing catch pays
	# at the old tier and the offer opens.
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(pod, {"scrap": 25}, "barge")
	assert_eq(Economy.balance("scrap"), scrap_before + 25, "the crossing catch pays at tier 0")
	assert_eq(scene.model.tier, 1)
	assert_true(scene.get_node("UI/BoonOffer").visible)
	assert_false(scene.get_node("DropController").enabled)
	# Force a known trio so the pick is deterministic, then take Barge Bounty.
	scene._current_offer = ["barge_bounty", "rich_seas", "second_wind"]
	scene._render_offer()
	scene._on_boon_picked(0)
	assert_true(scene.model.has_boon("barge_bounty"))
	assert_true(scene.get_node("DropController").enabled)
	# The next barge catch pays tier 1 (x1.25) then Barge Bounty (x1.5):
	# 8 -> 10 -> 15.
	scene._on_drop_requested(300.0)
	await wait_physics_frames(1)
	var pod2: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(pod2, {"scrap": 8}, "barge")
	assert_eq(Economy.balance("scrap"), scrap_before + 25 + 15)
	assert_eq(int(scene.model.loot["scrap"]), 40)
	# A second forced offer grants Spare Pods; the run extends immediately.
	var drops_before: int = scene.model.drops_remaining()
	scene._current_offer = ["spare_pods", "heavy_loot", "featherfall"]
	scene._render_offer()
	scene._on_boon_picked(0)
	assert_eq(scene.model.drops_remaining(), drops_before + 2)
	assert_eq(scene.model.boons, ["barge_bounty", "spare_pods"], "pick order preserved")

func test_organic_offer_is_seed_deterministic() -> void:
	scene._on_tier_reached(1)
	var first: Array = (scene._current_offer as Array).duplicate()
	assert_eq(first.size(), 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260818
	var expected := BoonModel.offer((DataDefs.boons.get("defs", {}) as Dictionary).keys(), [], rng)
	assert_eq(first, expected, "the scene's draw is exactly the seeded model draw")
```

- [ ] **Step 2: Run the suite**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS, exit 0. Any failure is an integration bug: debug it, never weaken the test.

- [ ] **Step 3: Import, verify sidecar, commit**

Run: `$GODOT --headless --import` then `git status --porcelain` (stage `tests/test_boon_integration.gd.uid`).

```bash
git add tests/test_boon_integration.gd tests/test_boon_integration.gd.uid
git commit -m "test: prove the boon flywheel end to end with fixed seeds"
```

---

## Post-plan checklist (for the executing session, not a task)

- Final whole-branch review runs the canonical suite once as the gate.
- Windowed smoke steps are waived in this non-interactive environment (headless substitutes), noted in the report.
- Collect every ledger "Ruling:" line for the finishing menu.
- Deliberate deferrals after this plan: boon persistence trees (parent spec open question 1), AdMob and async-grant hardening (the reroll knowingly inherits the synchronous-grant assumption), island expansion/story, rarities, sound, art (boon icons join the audit at the art pass), regions 3+.
