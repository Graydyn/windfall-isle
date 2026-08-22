# Island Expansion and Story Vignettes: Design Spec

**Date:** 2026-08-22
**Status:** Approved scope, pre-plan
**Parent design:** docs/design/2026-08-15-windfall-isles-design.md section 4.4
**Baseline:** main at 2fe3a52, 369/369 GUT tests green, save schema v6

## 1. Summary

Restoring bridges and balloon lines to neighboring islets opens new building plots. Each restored islet carries a skippable found-letter vignette (ambient flavor of the old sky-civilization, no dialogue trees). This plan ships two data-driven islets, two islet-exclusive buildings, a restoration timer lane, a letter panel, and save schema v7.

Owner decisions locked during brainstorming:

1. New plots hold new islet-specific buildings (not duplicates of existing ones, not empty promise plots).
2. Restoration is cost plus a long timer in its own TimerService lane, kind "restoration"; it never consumes a build slot. One restoration active at a time.
3. Two islets ship: one mid-game (scrap and cloudsilk), one late-game gated on brasswork, giving Region 2's currency its first island sink. Data-driven so islet 3+ is JSON authoring.
4. Vignettes show in a panel at collect time and stay re-readable forever from the islet's row. Text lives in JSON; the save stores only flags.
5. Architecture: new `game/data/islets.json` plus a new pure `IsletModel`, mirroring the region data-driven pattern. Not folded into IslandModel.

Out of scope for this plan: ad-skippable restoration timers (revisit after playtest), a letters archive screen, islets beyond the two shipped, any art beyond placeholder shapes.

## 2. Data: islets.json

New file `game/data/islets.json`, loaded by DataDefs alongside the other def files. Raw JSON numbers stay raw (floats); all consumers cast with `int()` / `float()` at use, per repo convention.

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

The array is ordered: islet N+1 is offered only after islet N is restored. Islet plot ids must be globally unique and must never collide with `plot_0..plot_N` home plots; the plan should add a validation warning (duplicate islet plot id or islet id) mirroring the barge-id uniqueness guard.

All costs and durations are designer-tunable placeholders, tuned by reasoning, subject to the flywheel playtest like every other balance number.

## 3. IsletModel (new, pure)

`game/base/islet_model.gd`, `class_name IsletModel`, all-static like IslandModel. Timer ids are `restore_<islet_id>`, kind `"restoration"`, payload `{"islet": id}`.

- `entry(defs: Dictionary, islet_id: String) -> Dictionary`: the def row, `{}` if unknown.
- `is_restored(data: Dictionary, islet_id: String) -> bool`: reads `data.islets.restored`.
- `open_plots(data: Dictionary, defs: Dictionary) -> Array[String]`: plot ids contributed by all restored islets, in islet order.
- `active_restoration(timers: Node) -> String`: id of the running restoration timer, `""` if none.
- `next_offered(data: Dictionary, defs: Dictionary) -> String`: id of the first unrestored islet in array order (the only one that may be offered), `""` when all are restored.
- `restore_rejection(data: Dictionary, defs: Dictionary, economy: Node, timers: Node, islet_id: String) -> String`: `""` means startable, otherwise a short player-facing reason. Checks in order: unknown islet, already restored, not the next offered islet, a restoration already running (its own or any other), cannot afford.
- `start_restore(data, defs, economy, timers, islet_id, now) -> bool`: rejection check, `economy.pay(cost)`, `timers.start(...)` with `restore_seconds`.
- `complete_restore(data: Dictionary, payload: Dictionary) -> void`: sets `data.islets.restored[islet_id] = true`. Idempotent; empty or unknown payload is a no-op.

Rules the model must uphold, matching repo discipline: injected `now`, no reads of autoloads, no clocks, no RNG. Economy is passed as a Node exactly like IslandModel and CraftModel do.

## 4. New buildings (buildings.json)

Two new defs, each carrying an `"islet"` field naming the only islet whose plots accept it:

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

Placement rules, added to `IslandModel.build_rejection` (and therefore inherited by `can_start_build` / `start_build`):

- A def with an `"islet"` field only builds on a plot id listed in that islet's `plots`, and only when that islet is restored.
- An islet plot only accepts defs whose `"islet"` field names that islet. Home-island defs (no `"islet"` field) never build on islet plots.
- Rejection reasons stay short and player-facing ("That building belongs on Lantern Shoal.", "This plot awaits its own building.").

`build_rejection`'s signature grows to accept whatever it needs for the islet lookup (islet defs and the save's islets section); the plan settles the exact signature. Everything else about construction is unchanged: build slots, timer kind "construction", skip rules, `complete_build`.

### 4.1 Lens Array effect: run payout multiplier

New seam `IslandEffects.payout_multiplier(island: Dictionary, building_defs: Dictionary) -> float`, recomputed from defs and level like every IslandEffects function: `1.0 + level * float(def.get("payout_bonus_per_level", 0.0))`, so level 0 or absent def yields exactly 1.0.

Wiring: `salvage_run` reads it once in `_ready` into a member (island state cannot change mid-run) and multiplies it into `_compute_payout`'s `mult` alongside `model.payout_multiplier()` and the pod-carried multipliers. The existing `roundi` and drop-zero-values behavior applies unchanged. RunModel stays defs-free and untouched.

### 4.2 Foundry Annex effect: craft discount

New helper `CraftModel.effective_cost(def: Dictionary, island: Dictionary, building_defs: Dictionary) -> Dictionary`: each currency amount becomes `ceili(float(amount) * (1.0 - level * float(craft_discount_per_level)))` clamped to a minimum of 1, so no craft ever becomes free. Both `can_craft`'s `can_afford` and `start_craft`'s `pay` must use the same helper (paying a different price than was checked is the bug class to avoid). The workshop screen shows the discounted cost.

## 5. Save schema v7

```
"islets": {"restored": {}, "letters_seen": {}}
```

Both are maps of islet id to `true` (absent means false). `CURRENT_VERSION` becomes 7; `_migrate_6_to_7` adds the section; `_backfill_missing_keys` heals a missing `islets` section and its two subkeys. Wrong-typed sections follow the existing backfill behavior (heal missing, leave wrong-typed, matching the documented residual for other sections).

No changes to the `island` dict shape: islet plots appear as ordinary new keys in `island.plots` when built on, which IslandModel already iterates generically.

## 6. UI

### 6.1 Island screen islet rows

Below the existing plot and building rows, one row per islet in JSON order:

- **Locked** (a prior islet is unrestored): name only, dimmed, no button.
- **Offered** (`next_offered`): name, cost text, Restore button. A rejected tap routes the `restore_rejection` reason through the existing StatusLabel.
- **Restoring**: countdown label, updated in place per tick.
- **Done** (timer done, uncollected): Collect button. Collect completes the timer through the same collect path constructions use, calls `complete_restore`, saves, opens the letter panel.
- **Restored**: the islet's plot rows join the plot list (same row widget as home plots, offering only that islet's buildings), plus a persistent "Read letter" button.

The refresh signature extends with the restoration timer state (absent / running / done) and the restored set, so state transitions rebuild the tree and countdowns update labels in place, preserving the mid-tap safety discipline. UI tests call handlers directly and never press scene-changing buttons.

### 6.2 Letter panel

A hidden PanelContainer inside `island_screen.tscn`: title label, body label (wrapped, scrollable if needed), Close button. Opening sets nothing; Close sets `letters_seen[islet_id] = true` and saves. Skipping is just closing; nothing gates on having read a letter. "Read letter" reopens it with the same JSON text. `letters_seen` exists for future polish (an unread badge), not for gating.

## 7. Notifications

`NotificationPlanner.plan` gains an `islet_defs: Dictionary = {}` parameter and a `"restoration"` branch mirroring the construction branch: title "Bridge restored", body "The way to %s is open." with the islet name resolved from defs by the payload's islet id. `NotificationSvc` passes `DataDefs.islets` through. The planner stays pure and read-only.

## 8. Testing

All tests headless GUT, following repo conventions (injected clocks, `int()` casts at JSON assert sites, error-path tests declare expected push/engine error counts, `.gd.uid` sidecars committed).

- **IsletModel unit tests**: ordering gate (islet 2 rejected while islet 1 unrestored), single active restoration, affordability rejection, pay-then-timer on success, complete_restore idempotence and unknown-payload no-op, open_plots ordering.
- **Schema**: fresh v7 shape, v6 to v7 migration preserves everything and adds the section, backfill heals a missing islets section, full v1-to-7 chain still passes.
- **Placement rules**: islet building rejected on home plot, home building rejected on islet plot, islet building rejected on its own plot while unrestored, accepted once restored.
- **Effects**: payout_multiplier at levels 0/1/2 including the exact 1.0 identity at level 0; craft discount rounding at both levels, the 1-minimum clamp, and can_craft/start_craft price agreement.
- **Planner**: a restoration timer yields the notification with the defs-resolved name; past-deadline timers excluded (existing behavior).
- **Screen tests**: row state per islet lifecycle stage via direct handler calls; letter panel open on collect and reopen via Read letter; StatusLabel carries restore rejections.
- **Integration proof** (fixed seed, no-strict-RED per standing ruling): restore Lantern Shoal with a fake clock, build Lens Array to level 1, run a salvage run, assert the payout reflects the 1.05 multiplier end to end.

Manual windowed smoke steps are listed but waived in the non-interactive environment, per standing process.

## 9. Risks and interactions

- **Signature churn**: `build_rejection` and `NotificationPlanner.plan` both grow parameters; every caller must be updated in the same task that changes the signature.
- **Refresh signature**: forgetting the restoration timer or restored set in the signature makes islet rows go stale mid-session; this is the exact bug class the signature discipline exists for.
- **Craft price drift**: any future caller reading `def.craft_cost` directly instead of `effective_cost` reintroduces the check/pay mismatch; the plan should grep for `craft_cost` consumers.
- **Brasswork sink balance**: Foundry Rock plus Foundry Annex costs (18 brasswork to restore and reach Annex level 1) are the first island-side brasswork drain; numbers are tunable JSON and unvalidated by play, like all balance.
- **plot_count is untouched**: `_plot_ids` on the island screen keeps enumerating home plots from `plot_count`; islet plots come only from `IsletModel.open_plots`. The two id spaces must stay disjoint.
