# Windfall Isles: Pending Work

**As of:** 2026-09-15, main at 913e4af (Plan 14 merged), full suite green.
**State:** Plans 1-14 merged. MVP (Plans 1-5), Region 2 "Brasswork Reach" (Plan 6), Boons (Plan 7), Island Expansion + Vignettes (Plan 8, schema v7), and the drag-and-drop gizmo setup phase (Plan 9: placement happens over the real board inside the run scene, fuel is spent on Start, the loadout screen is gone). Four regions, twelve gizmos, six boons, two restorable islets with two islet-exclusive buildings, four retention hooks with local-notification logic, five rewarded-ad placements behind the AdService seam, Android export scaffolding.

The binding design doc is [docs/design/2026-08-15-windfall-isles-design.md](design/2026-08-15-windfall-isles-design.md) (section 3.2's launch-time fuel spend carries a Plan 9 errata). Post-MVP feature specs live in [docs/superpowers/specs/](superpowers/specs/), implementation plans in [docs/superpowers/plans/](superpowers/plans/). The established cadence per feature: brainstorm scope with the owner, write a spec, write a plan, execute subagent-driven in a worktree, merge on a clean final review.

**Sequencing decision (owner, 2026-09-07):** finish the actual game mechanics first (Phase A, in order below), then do all release work (Phase B: sound, art, AdMob, submission) at the very end.

---

## Phase A: game mechanics

### Island mechanic rework (owner priority): crew + chains + run kit
- Direction settled 2026-09-07 (spec: docs/superpowers/specs/2026-09-07-crew-system-design.md, section 0): a closed bidirectional economy in three plans. Plan 10 (crew: rescued survivors staff buildings, rate seam CrewModel.multiplier_for): SHIPPED. Plan 11 (production chains): SHIPPED (spec: docs/superpowers/specs/2026-09-08-production-chains-design.md; parts and provisions currencies, Smeltery + Annex + Gardens batch recipes on the "convert" timer kind, all gizmo crafts repriced to parts, Annex discount retired). Plan 12 (run kit): SHIPPED (spec: docs/superpowers/specs/2026-09-09-run-kit-design.md; recipes arrays, three Balloonworks consumables, setup-phase kit panel, provisioning at 1.15x). The island rework arc is COMPLETE: every run resource feeds the island and every island output feeds the runs.

### Gizmo rarities (spec 3.3)
- SHIPPED (Plan 13, spec: docs/superpowers/specs/2026-09-14-gizmo-rarities-design.md): static rarity per def (`rarity` + `rarity_unlocks` in gizmos.json), Workshop level gates crafting via CraftModel.rarity_unlocked (fail-closed on unknown rarities), starters shrunk to the four commons (existing saves grandfathered, still schema v8), workshop screen dims locked rows. Cargo Net rider landed: uses scale with level, relaunch speed no longer does. Future gizmos: add `rarity` to the def and extend the pinned tier table in tests/test_gizmo_rarity_defs.gd.

### Regions 3+
- Regions 3 and 4 SHIPPED (Plan 14, spec: docs/superpowers/specs/2026-09-14-regions-3-and-4-design.md): Rimefall Shallows (ice pegs, rimeglass, Dock Lv3, 3 quota tiers) and Stormglass Verge (storm pegs, stormglass, Dock Lv4, 3 tiers), plus the Plan 7 boon tripwire fixes (exhausted-pool offers close out and re-enable drops; pointless rerolls hide via BoonModel.reroll_candidates; maxf composition pinned). Peg hazards are data-driven ("type": "ice"/"storm" on peg rows; unknown types warn and build normal pegs). Two new rare gizmos: Sleet Sail (rimeglass) and Gale Vent (stormglass).
- Region 5+ is JSON authoring plus at most one new hazard; a fuel-reduction row for region 4 wants a Dock Lv5 first. The remaining boon latency: growing the pool past six composes fine now, but only one barge and one sea booster exist in data.

### Design-doc open questions (fold into the island rework brainstorm)
- Boon persistence as a late-game "expedition perks" tree (open question 1).
- Second build slot: permanent unlock vs per-use (open question 3; currently permanent).
- Islet 3+ authoring is pure JSON plus one building effect if desired; restoration timers are deliberately not ad-skippable yet (revisit after playtest).

## Phase B: release work (only after Phase A is done)

### Sound design
- Nothing researched (design doc open question 2). Needs direction before any implementation.

### Art pass (external image-agent pipeline)
- The complete image-agent brief is `docs/art/placeholder-graphics-audit.md` (NOTE: currently untracked in git; commit it or keep it wherever the art pipeline lives). Written against the MVP; before running the pipeline, extend it with: region 2 visuals (gear-ring pegs, drift-zone haze, brass barges), the Gyro Damper and Piston Kicker sprites, boon offer icons, BoonOffer panel theming, Plan 8's islet and letter-panel visuals, and Plan 9's setup-phase chrome (slot outlines, tray chips, drag preview). Whatever Phase A adds extends it further.
- Wiring delivered art into scenes (Polygon2D to Sprite2D swaps, backgrounds, UI theme) is a separate code plan once assets exist.
- Small UI polish parked for this pass (Plan 8 final review): LetterPanel body needs a ScrollContainer for long letters; locked islet rows should render dimmed; maxed gizmos still show a craft cost in the workshop.

### Real AdMob integration (explicitly deferred by owner: do not start without their go-ahead)
- Vendor the cengiz-pz AdMob plugin (free build only) and implement `AdmobAdService`.
- Switch selection in `game/autoload/ads.gd`: `AdmobAdService.new() if OS.has_feature("admob") else GrantAdService.new()`; add the `admob` custom feature tag to a free-build export preset (the Play Pass preset keeps GrantAdService and compiles no ad SDK).
- **Accumulated hardening list that MUST ride along** (parked across Plans 5-7 because GrantAdService grants synchronously):
  - Grant callbacks assume synchronous grants: with real async ads, a scene change between request and grant leaves dangling callables (fuel refill on main, payout double and boon reroll on salvage_run, skips/bonus crate on island/workshop). The AdMob seam implementation must survive or cancel grants across scene changes.
  - Skip-button availability sits outside the island/workshop refresh signature: if `is_available` flips mid-session, row skip buttons will not appear/disappear until the next structural rebuild (the standalone buttons already refresh per tick).
  - FIXED in Plan 14: the boon reroll now hides when no disjoint candidate exists and the grant path no-ops; the only residual window is an async ad watched while the pool becomes covered mid-request (the grant no-ops, the ad was still watched).

### Notification plugin vendoring (Android build step)
- Vendor cengiz-pz notification-scheduler and implement a plugin-backed `NotificationScheduler`; the seam (`schedule/cancel_all/request_permission`), the pure planner, and the permission-once flow are done and tested. Selection at boot mirrors Ads.
- Small pre-existing gap worth closing then: `NotificationSvc.request_permission_once` and `AdLimits._ads` heal a MISSING save section but not a wrong-typed one.

### Play Pass submission
- Blocked on the free/ads build existing (AdMob) and the final art pass; the GrantAdService binary is already the Play Pass behavior.

## Verification notes

- Smoke testing runs throughout development on the owner's side (windowed/on-device); it is an ongoing practice, not a parked debt. Remaining hardware-specific checks worth a deliberate pass before release: the Android 13+ notification permission flow, and drag feel for the Plan 9 setup phase on touch.
- **Flywheel tuning playtest** (spec 8's MVP success question): after the first hour, does the player return unprompted to check a timer and immediately spend the result on another run? All balance numbers are designer-tunable JSON (`game/data/*.json`), tuned so far by reasoning only, never by play. The island rework brainstorm should draw on how the current loop actually feels.
- The two wall-clock ad-limit tests retain a milliseconds-wide UTC-midnight flake window (accepted residual, documented in the Plan 6 spec).

## Environment and process (for whoever picks this up)

- Godot binary: `godot` on PATH (4.7.1) runs the suite fine with the vendored GUT 9.6.1; the old 4.6.3-only note is obsolete. `/Applications/Godot-4.6.app/Contents/MacOS/Godot` remains available if a regression ever appears.
- Test command (must exit 0): `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- Run `$GODOT --headless --import` after adding files; commit `.gd.uid` sidecars (and `.import` files for assets).
- Repo disciplines that repeatedly mattered: raw JSON floats with `int()`/`float()` casts at use and assert sites (never normalize in DataDefs); injected clocks (`now: int`) and injected RNG (seeded `RandomNumberGenerator`); mass-respecting forces only; `has_meta("caught")` early returns in contact gizmos; `add_child.call_deferred` inside physics flushes; UI tests call handlers directly and never press scene-changing buttons; Control drag-and-drop chips need `MOUSE_FILTER_PASS` (STOP blocks the drop-target ancestor walk, and headless direct-handler tests cannot see it).
- Session memory for the AI-assisted workflow lives outside the repo (auto-memory); this file is the repo-resident source of truth for pending work.
