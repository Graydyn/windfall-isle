# Windfall Isles: Pending Work

**As of:** 2026-08-18, main at 143cf42, 369/369 GUT tests green.
**State:** MVP complete (Plans 1-5) plus Region 2 "Brasswork Reach" (Plan 6) and Boons (Plan 7). Both loops work and cross-feed: two regions, ten gizmos, six boons, four retention hooks with local-notification logic, five rewarded-ad placements behind the AdService seam, Android export scaffolding.

The binding design doc is [docs/design/2026-08-15-windfall-isles-design.md](design/2026-08-15-windfall-isles-design.md). Post-MVP feature specs live in [docs/superpowers/specs/](superpowers/specs/), implementation plans in [docs/superpowers/plans/](superpowers/plans/). The established cadence per feature: brainstorm scope with the owner, write a spec, write a plan, execute subagent-driven in a worktree, merge on a clean final review.

---

## 1. Major pending features (spec section 8 "Out" items, in rough value order)

### Real AdMob integration (explicitly deferred by owner: do not start without their go-ahead)
- Vendor the cengiz-pz AdMob plugin (free build only) and implement `AdmobAdService`.
- Switch selection in `game/autoload/ads.gd`: `AdmobAdService.new() if OS.has_feature("admob") else GrantAdService.new()`; add the `admob` custom feature tag to a free-build export preset (the Play Pass preset keeps GrantAdService and compiles no ad SDK).
- **Accumulated hardening list that MUST ride along** (parked across Plans 5-7 because GrantAdService grants synchronously):
  - Grant callbacks assume synchronous grants: with real async ads, a scene change between request and grant leaves dangling callables (fuel refill on main, payout double and boon reroll on salvage_run, skips/bonus crate on island/workshop). The AdMob seam implementation must survive or cancel grants across scene changes.
  - Skip-button availability sits outside the island/workshop refresh signature: if `is_available` flips mid-session, row skip buttons will not appear/disappear until the next structural rebuild (the standalone buttons already refresh per tick).
  - The boon reroll can consume a grant with no effect when taken boons + the current trio cover the whole pool; hide the reroll when no disjoint candidate exists.

### Notification plugin vendoring (Android build step)
- Vendor cengiz-pz notification-scheduler and implement a plugin-backed `NotificationScheduler`; the seam (`schedule/cancel_all/request_permission`), the pure planner, and the permission-once flow are done and tested. Selection at boot mirrors Ads.
- Small pre-existing gap worth closing then: `NotificationSvc.request_permission_once` and `AdLimits._ads` heal a MISSING save section but not a wrong-typed one.

### Island expansion + story vignettes (spec 4.4): SHIPPED (Plan 8)
- Two data-driven islets (islets.json), IsletModel restoration lane, Lens Array and Foundry Annex, letter panel, schema v7. Spec: docs/superpowers/specs/2026-08-22-island-expansion-vignettes-design.md. Islet 3+ is JSON authoring plus one new building effect if desired. Restoration timers are deliberately not ad-skippable yet (revisit after playtest).

### Gizmo rarities (spec 3.3)
- Rarity tiers beyond the current flat set; interacts with Workshop levels ("higher levels unlock higher rarities") and the craft-to-acquire flow from Plan 6.

### Regions 3+
- Now data-driven: a new `game/data/skyfields/region_N.json` plus a `regions` entry, and at most one new hazard implementation (storm pegs and ice pegs from spec 3.4 are unbuilt; drift currents exist). Dock max_level currently 2; a third region needs a Dock level or another unlock.
- **Tripwire before any region ships 3+ quota tiers or the boon pool grows past six** (latent bugs, unreachable with shipped data, found by Plan 7's final review):
  - `salvage_run._show_next_offer`'s empty-draw return leaves `controller.enabled` false when a queued offer finds the pool exhausted; re-enable when not over.
  - `RunModel.add_boon`'s `maxf` composition of same-type multipliers is untested (only one barge and one sea booster exist today).
- Region-authoring guards already in place: barge-id uniqueness validation, quota-tier row validation, ascending-quota warning.

### Sound design
- Nothing researched (design doc open question 2). Needs direction before any implementation.

### Art pass (external image-agent pipeline)
- The complete image-agent brief is `docs/art/placeholder-graphics-audit.md` (NOTE: currently untracked in git; commit it or keep it wherever the art pipeline lives). Written against the MVP; before running the pipeline, extend it with: region 2 visuals (gear-ring pegs, drift-zone haze, brass barges), the Gyro Damper and Piston Kicker sprites, boon offer icons, and the BoonOffer panel theming.
- Wiring delivered art into scenes (Polygon2D to Sprite2D swaps, backgrounds, UI theme) is a separate code plan once assets exist.

### Play Pass submission
- Blocked on the free/ads build existing (AdMob) and the final art pass; the GrantAdService binary is already the Play Pass behavior.

### Design-doc open questions (decide when relevant)
- Boon persistence as a late-game "expedition perks" tree (open question 1).
- Second build slot: permanent unlock vs per-use (open question 3; currently permanent).

## 2. Verification debt

- **On-device / windowed smoke testing has never run.** Every plan's manual smoke steps were waived in the non-interactive environment; all 369 tests are headless. Before any release work: run the game in the editor and on an Android device, feel the physics (pod bounce, drift zones, piston kick), check the per-second UI refresh on real hardware, and exercise the notification permission flow on Android 13+.
- **Flywheel tuning playtest** (spec 8's MVP success question): after the first hour, does the player return unprompted to check a timer and immediately spend the result on another run? All balance numbers are designer-tunable JSON (`game/data/*.json`), tuned so far by reasoning only, never by play.
- The two wall-clock ad-limit tests retain a milliseconds-wide UTC-midnight flake window (accepted residual, documented in the Plan 6 spec).

## 3. Environment and process (for whoever picks this up)

- Godot binary: `/Applications/Godot-4.6.app/Contents/MacOS/Godot` (4.6.3; brew ships 4.7 which GUT 9.6.1 does not support; never use `/Applications/Godot.app`).
- Test command (must exit 0): `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- Run `$GODOT --headless --import` after adding files; commit `.gd.uid` sidecars (and `.import` files for assets).
- Repo disciplines that repeatedly mattered: raw JSON floats with `int()`/`float()` casts at use and assert sites (never normalize in DataDefs); injected clocks (`now: int`) and injected RNG (seeded `RandomNumberGenerator`); mass-respecting forces only; `has_meta("caught")` early returns in contact gizmos; `add_child.call_deferred` inside physics flushes; UI tests call handlers directly and never press scene-changing buttons.
- Session memory for the AI-assisted workflow lives outside the repo (auto-memory); this file is the repo-resident source of truth for pending work.
