# Windfall Isles: Design Document

**Status:** Approved concept, pre-implementation
**Date:** 2026-08-15
**Title:** Windfall Isles (chosen 2026-08-15). "Windfall" carries the double meaning of a fortune that falls to you (the pachinko payout) and wind + fall (the drop through the sky); "Isles" anchors the base-builder half. Store-collision check found no existing game with this exact title; nearest neighbors are a niche Steam sailing sim named "Windfall" and Zelda's fictional Windfall Island (a location, not a product). Note: "Driftfall", the original placeholder, is unusable; an existing Android game "Driftfall: Pixel Action RPG" already features floating-fortress building.

---

## 1. Vision

A casual, portrait-mode, fully offline Android game with two interlocking loops:

1. **The home island** (base builder): restore a shattered floating island with timed construction, an energy system, and a three-tier currency economy.
2. **Salvage drops** (session loop): a pachinko/Peggle-descent arcade loop where the player drops salvage pods from an airship through a peg field they have engineered themselves, using gizmos crafted at the base.

The player is a salvager rebuilding a floating archipelago above an endless cloud sea littered with debris from a lost sky-civilization. Tone is cozy, optimistic, Ghibli-adjacent sky-fantasy: fantasy without elves, sci-fi without robots. No combat, no violence, no fail-state punishment.

### Pillars

- **Pick up and go.** Sessions of 2-4 minutes, one thumb, save-anywhere, no run ever loses collected loot.
- **Both loops feed each other.** Runs are the resource faucet for the base; the base is the power faucet for runs. Neither is optional.
- **Skill is engineering, not reflexes.** The player's mastery lives in which gizmos they craft and where they slot them, not in twitch aiming.
- **Honest offline.** No server, no accounts, no analytics. Ads are optional accelerators; no connectivity means no ads and a fully playable, merely slower, game.

### Hard constraints (from project owner)

- Android exclusive. No iOS, ever.
- 2D only, portrait only.
- Completely offline; no backend. APK tampering is explicitly accepted and out of scope.
- Native touch: taps and swipes only. No virtual joystick or rendered controller.
- Art is 100% AI-generated via an external pipeline (out of scope for this repo). Not pixel art; painterly/stylized 2D.
- Monetization is ads-only (rewarded video), designed so ads can be stripped cleanly for a Google Play Pass build.

---

## 2. Market rationale (research summary)

Research conducted 2026-08-15. Full citations in Appendix A.

**The two-loop architecture is proven at scale.** Ball X Pit (2M sales; breakout runs feed a city builder), Solitaire Grand Harvest ($1B+ lifetime; solitaire levels feed a farm), and Gardenscapes ($4.47B lifetime; match-3 feeds renovation) all pair a classic-game session loop with a builder meta.

**Why pachinko for Loop 2.** Peglin (400k+ sold, shipped on Android) and Ballionaire (well-reviewed 2024) prove the pachinko-roguelite session loop. A vertical peg board is inherently portrait; input is a single tap; turn-based pacing gives interruptible short sessions and trivial save-anywhere. Nobody has shipped the "Ballionaire-style board engine + base builder" combination on Android: a real novelty window. Runner-up formats considered: swipe-aim ball launcher (proven by Ballz/BBTAN but sits directly in Ball X Pit's fresh shadow), TriPeaks solitaire (most proven, least action, dominated by Playtika ad budgets), vertical digger (weak recent commercial proof), slots engine-builder (rejected: gambling aesthetics create Play policy and age-rating friction, bad for a Play Pass pitch).

**Why sky islands for the theme.** Chosen deliberately as a whitespace bet: almost no top-grossing casual title owns the cozy sky-archipelago fantasy. It composites proven elements: restoration meta (present in 70 of the top 100 US iOS grossers per GameRefinery), exploration/destination progression (Travel Town), and the cozy-nature aesthetic of the fast-growing cozy market (near gender-balanced audience). It avoids the saturated farm/renovation metas and all banned cliches (zombies, robots, pets). Known risk: no direct chart evidence for the theme at casual scale; the emotional anchor (rebuilding a beloved home island) is the mitigation, since "restore a beloved place" is the proven hook underneath.

---

## 3. Loop 2: Salvage drops

### 3.1 The skyfield

A **skyfield** is a single-screen portrait peg board representing a stretch of cloud sea below the player's airship.

- **Natural pegs:** fixed obstacles generated per region (rock chunks, cloud puffs, ruin fragments). These define the board's terrain and cannot be moved by the player.
- **Gizmo slots:** a sparse grid of anchor points where the player installs crafted gizmos before/between runs. Slot count grows with region and base progress (MVP: ~6 slots).
- **Collection barges:** 3-5 catchers along the bottom edge with different payout values and types. Pods that miss all barges fall into the cloud sea for a minimum scrap payout (never zero).

### 3.2 A run ("salvage expedition")

1. Player spends **fuel** (energy) to launch an expedition on a chosen skyfield. (Amended 2026-08-24 by the drag-drop gizmo setup spec: fuel is now spent by the Start button inside the run scene's setup phase; the launcher still gates on affordability, and backing out of setup costs nothing.)
2. The run grants a fixed number of **pod drops** (8-12, upgradeable).
3. Per drop: tap or drag along the top edge to set the drop point, release, watch the physics cascade, collect the payout. Pure tap/drag input.
4. **Quota tiers:** reaching the salvage quota mid-run lifts the airship to a richer tier of the same skyfield (denser loot, nastier hazards) and offers a **boon**: pick 1 of 3 temporary run-scoped modifiers (e.g., pods split once, barge payouts +50%, gizmo triggers fire twice). Light roguelite spice; post-MVP.
5. Run ends when drops are exhausted. Missing quota just ends the run at the current tier. **The player always keeps everything collected.** No fail state.
6. The run can be abandoned at any moment (or interrupted by the OS) with loot intact.

Target session length: 2-4 minutes.

### 3.3 Gizmos

Gizmos are the run-side expression of base progress. They are crafted at the Workshop (timed crafts, resource costs), owned permanently, and slotted into skyfields by the player. Placement and combination is the core skill expression.

Launch vocabulary (MVP set of ~8, names indicative):

| Gizmo | Effect on contact |
|---|---|
| Balloon Cluster | Bounces the pod sharply upward; pops after N hits per run |
| Lightning Jar | Chain-zaps nearby natural pegs into bonus scrap |
| Wind Fan | Applies steady lateral push in its column |
| Crystal Prism | Multiplies the value of everything the pod collects below it |
| Cargo Net | Catches a falling pod once and re-drops it at a chosen angle |
| Chime Bell | Rings: next barge payout is doubled |
| Magnet Buoy | Curves pod trajectories toward itself |
| Splitter Vane | Splits the pod into two half-value pods (once per drop) |

Gizmos have rarity tiers and upgrade levels (crafted duplicates merge into upgrades). New regions introduce new gizmo recipes gated on regional materials.

### 3.4 Regions

Regions are new skyfields unlocked via the Dock. Each brings: a new natural-peg terrain set, a new hazard (storm pegs that consume pods, ice pegs that deaden bounce, drift currents), a new regional material as its distinctive drop, and more gizmo slots. Regions are the primary content treadmill for Loop 2. MVP ships one region.

---

## 4. Loop 1: The home island

### 4.1 Buildings

Classic builder rules: each structure costs resources, takes real time to build/upgrade (minutes early game, hours later), and occupies a plot. One free build slot; a second is a rewarded-ad/crystal unlock.

| Building | Role |
|---|---|
| Workshop | Crafts gizmos (timed crafts); higher levels unlock higher rarities and parallel craft slots |
| Wind Still | Raises fuel cap and regeneration rate |
| Dock | Unlocks new skyfield regions; higher levels reduce expedition fuel costs |
| Balloonworks | Upgrades pods: drops per run, pod weight/bounce profile |
| Observatory | Reveals upcoming regions; issues quests/goals |
| Gardens & Cisterns | Trickle scrap while away (idle faucet, capped, must be collected) |

### 4.2 Currencies and resources

| Tier | Currency | Faucets | Sinks |
|---|---|---|---|
| Common | **Scrap** | Runs (primary), idle trickle, daily crate | Building costs, common gizmo crafts |
| Regional | **Materials** (cloudsilk, brasswork, stormglass, one per region) | Drops only in their region's skyfields | Region-specific buildings and gizmo recipes |
| Premium | **Aether Crystals** | Rare run drops, achievements, quests, rewarded ads | Timer skips, fuel refills, rare crafts, second build slot |

Crystals are the "monetized" currency in the ads-only model: rewarded video is their high-frequency faucet. All crystal sinks are accelerators or breadth, never exclusive progression.

### 4.3 Energy: fuel

- Expeditions cost fuel. Fuel regenerates on a wall-clock timer up to a cap.
- Cap and regen scale with the Wind Still. Refills: crystals or one rewarded ad.
- Tuning goal: a full tank at any progression stage supports roughly 3-5 expeditions, i.e., a satisfying 10-15 minute session, with shorter top-up visits between.

### 4.4 Island expansion and story

Restoring bridges and balloon lines to neighboring islets opens new building plots. Each restored islet carries a small story vignette (found letters and artifacts of the old sky-civilization). Story is ambient flavor, skippable, no dialogue trees. Post-MVP.

---

## 5. The flywheel and retention

```
runs drop scrap + materials + crystals
        v
base builds: Workshop crafts gizmos, Wind Still raises fuel,
             Dock opens regions, Balloonworks upgrades pods
        v
stronger boards and more drops per run
        v
bigger payouts, new regions demanding (and dropping) new materials
        ^________________________________________________|
```

Return hooks (all offline-safe, computed from Unix timestamps on app resume):

- Fuel regeneration
- Construction timers
- Gizmo craft timers
- Idle scrap trickle (capped, must collect)
- Daily salvage crate (calendar-day based, no punishing streaks)
- **Local notifications**: construction complete, craft complete, fuel full, daily crate ready. Scheduled at app-background time; canceled/rescheduled on resume. Android 13+ POST_NOTIFICATIONS permission requested at the first construction completion, not at first launch.

Deliberately excluded from v1: live events, streak penalties, PvP/social, anything requiring a clock authority beyond the device.

---

## 6. Monetization: ads-only, Play Pass ready

**Model:** rewarded video only. No interstitials, no banners. Every placement is optional acceleration; progression never requires watching an ad. When the device is offline, placements simply hide and the game remains fully playable.

Placements:

1. Skip/reduce a construction or craft timer
2. Refill fuel (limited per day)
3. Double one expedition's payout (offered on the results screen)
4. Open a bonus daily crate
5. Reroll a boon offer (post-MVP)

**Play Pass strategy:** the ideal outcome is a Play Pass version with zero ads. Play Pass is curated and pitch-based (Google must accept the title), so the ad-supported free build is the guaranteed baseline and Play Pass is the goal.

**Architecture rule:** all ad interactions go through a single `AdService` interface. Two implementations selected by build flag:

- `AdmobAdService` (free build): real rewarded video via the AdMob plugin.
- `GrantAdService` (Play Pass build): every placement either auto-grants its reward instantly or is hidden. No ad SDK is compiled into this binary at all.

Economy tuning must remain fair in the no-ads case (offline players get the same economy minus accelerators), which automatically keeps the Play Pass build balanced.

---

## 7. Technical design

### 7.1 Stack

| Concern | Choice |
|---|---|
| Engine | **Godot 4.6.x** (stability release with the 2025-26 Android fixes), minor version pinned; plugins pinned to match |
| Language | **GDScript** (C# Android export remains experimental; Android plugins are GDScript-first) |
| Physics | Godot built-in 2D physics: RigidBody2D pods, StaticBody2D pegs/gizmos; hard cap on simultaneous pods for low-end devices |
| Saves | Versioned JSON in `user://` via FileAccess; write-to-temp-then-rename; small ConfigFile for settings |
| Timers | Unix timestamps persisted in the save; elapsed time computed on resume; no background execution assumed |
| Notifications | godot-sdk-integrations / cengiz-pz notification-scheduler plugin (Android 13+ ready) |
| Ads | cengiz-pz AdMob plugin, free build only, behind `AdService` |
| Export | AAB, arm64-v8a primary, per-arch splits, portrait locked, latest Play-required target API |
| Testing | GUT (Godot Unit Test) for economy simulation and save migration; physics feel tuned by hand |

Rejected alternatives: Unity (heavier for pure 2D; license-trust history; its live-service strengths go unused offline), Defold (excellent mobile 2D engineering but much smaller community; revisit only if binary size becomes a requirement), LibGDX/Flutter+Flame/native Kotlin (framework-level effort for engine-level problems), Bevy (Android not ready).

### 7.2 High-level structure

```
game/
  autoload/            # singletons
    GameState.gd       #   save/load, versioned JSON, timestamp math
    Economy.gd         #   currencies, faucets/sinks, data-driven rates
    TimerService.gd    #   construction/craft/fuel timers
    NotificationSvc.gd #   schedule/cancel local notifications
    AdService.gd       #   interface + build-flag implementation pick
  base/                # island scene: plots, buildings, build UI
  run/                 # skyfield scene: board, physics, drop controller,
                       #   gizmo behaviors, payout resolution
  data/                # Resource/JSON defs: buildings, gizmos, regions,
                       #   economy curves (all tunable without code)
  ui/                  # shared HUD, currency bar, dialogs
```

Design rules: the two loops are separate scenes that communicate only through `GameState` and `Economy`; every number a designer would tune lives in `data/`, not in scripts; gizmo behaviors are self-contained scenes implementing a common trigger interface so new gizmos are additive.

### 7.3 Save integrity

Single local save, versioned schema with per-version migration functions, temp-file-then-rename writes, and a rolling backup of the previous good save. Cheating via save editing is accepted per constraints; corruption via crash is not.

---

## 8. MVP cut line

**In:** one region, one skyfield layout with ~6 gizmo slots, ~8 gizmo types, the 6 buildings listed, fuel + construction + craft timers, daily crate, idle trickle, local notifications, quota tiers within runs, `AdService` stubbed (GrantAdService behavior), save/load with versioning.

**Out (stacked after the flywheel proves fun):** regions 2+, boons, island expansion and story vignettes, gizmo rarities beyond two tiers, real AdMob integration, Play Pass submission, final art pass, sound design.

**MVP success question:** after the first hour, does the player return unprompted to check a timer and immediately spend the resulting gizmo/fuel on another run? If either loop is being skipped, the flywheel is broken and needs rebalancing before content expansion.

---

## 9. Open questions (deferred, not blocking)

1. Whether boons should persist as a permanent "expedition perks" tree in late game.
2. Sound/music direction (nothing researched yet).
3. Whether the second build slot should be permanent-unlock or per-use.

---

## Appendix A: Research sources

**Loop 2 / format:** PC Gamer and Push Square on Ball X Pit sales; Naavik's Solitaire Grand Harvest deconstruction; Sensor Tower on Gardenscapes; Peglin coverage (148Apps); PC Gamer's Ballionaire review; TouchArcade on Ballz; Luck Be a Landlord and Balatro (Wikipedia, GamesRadar, Pocket Tactics); Mobilegamer on Vampire Survivors mobile; WN Hub on Survivor.io and Archero.

**Theme:** GameRefinery market reviews (meta layers in 70 of top 100 US iOS grossers; Feb 2026 novelty-theme signals; match-3 theme splits by region), Sensor Tower theme-spending studies (Money/Treasure at $4.4B US), Udonis/Mobidictum/Naavik/Deconstructor of Fun on Gossip Harbor and the merge market, cozy-market sizing (IntelMarketResearch, Destructoid on 2025 Steam cozy output), cooking-game market sizing (Dataintelo), Liftoff 2025 Casual Gaming Apps Report.

**Tech:** Godot Mobile update (Apr 2026) and release archive; godot-sdk-integrations plugin repos (billing, notification scheduler) and docs; Ziva "Godot Mobile in 2026"; Unity Runtime Fee cancellation and 2025-26 pricing posts (Unity, CG Channel); Defold IAP/push extension docs; libGDX news; Bevy Android discussions; GameMaker pricing page.
