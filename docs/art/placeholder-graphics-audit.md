# Placeholder Graphics Audit

**Date:** 2026-10-07 (replaces the 2026-08-16 MVP audit)
**Wiring status (2026-10-11):** first wiring pass done for the delivered `game/art/` batch. Wired: run board (pod + split pod, drop marker, airship strip, slot sockets + hover, survivor raft, region peg variants, ice/storm pegs, storm-swallow puff, material barge pennants), all 12 gizmo sprites with spent variants and direction flips, building modal illustrations, islet thumbnails, letter panel + seals, crew portraits, region emblem on the region button, boon offer icons, crate/build-slot button icons, sprite drag previews. Delivered but NOT yet wired: currency/material/kit icons (text rows need an icon layout), rarity frames, zap arc / gale puff / piston-extended effect frames, region locked overlay, boon_card.png (theme pass; panel.png and button.png gained their first wiring on the island PlotSheet, 2026-10-15), construction overlay. Not yet delivered: region backgrounds, cloud sea band, field/column overlays, app icon, island vista. The island screen is now a scrollable map (see 4.6); the construction overlay, islet art and crew portraits gained their map wiring there. The bottom HUD row is gone (2026-10-17): crates float top right as icons, the 2nd slot sells inside the build modal, the trickle collects on the Gardens pad, the Workshop sheet carries the enter button, and the new Crew Quarters opens the crew sheet.
**Codebase state:** main at f6f5e0b, Plans 1-14 merged: 4 regions, 12 gizmos, 9 buildings, 2 islets, 8 crew, 6 boons, 3 run-kit consumables, 11 balances + fuel.
**Purpose:** Complete inventory of every visual the game needs, written as a brief for the image-generation agent. Each entry lists the asset, where its placeholder lives in code, what it looks like today, its exact on-screen size, its gameplay role, and any states or variants the final art must support. Entries marked **NEW** did not exist in the August audit; **CHANGED** means the requirement moved since then.

## Global art direction (from the design doc)

- **Tone:** cozy, optimistic, Ghibli-adjacent sky-fantasy. Fantasy without elves, sci-fi without robots. No combat, no violence.
- **Style:** painterly / stylized 2D. Explicitly NOT pixel art.
- **Setting:** a salvager rebuilds a shattered floating island above an endless cloud sea littered with debris from a lost sky-civilization.
- **Platform:** Android only, portrait only. Design resolution is **720 x 1280** (canvas_items stretch, expand aspect). All pixel sizes below are at this resolution; deliver at **2x** so art survives stretch scaling on high-DPI phones.
- **Transparency:** every sprite needs a transparent background (PNG with alpha) unless noted as a full-screen background.
- **No text baked into any sprite** (localization). Labels, numbers and level pips are drawn by the UI.

## 0. What exists today

| File | What it is | Status |
|---|---|---|
| `barge.png`, `barge_fancier.png`, `barge_fanciest.png` (repo root) | Three tiers of a wooden sky barge with two balloons and an open hull, 100 x 100 px RGBA | **Delivered but not wired in.** Sitting at the repo root with no `.import` sidecars; nothing references them. Delivered at 1x (100 px), not 2x. See 1.3 for fit notes. |
| `icon.svg` | Simple vector placeholder: blue rounded square, yellow sun, white cloud wave | Wired as `config/icon`. Fine for dev; not the final app icon (see 6). |

Everything else is still a flat-color `Polygon2D`, a `_draw()` call, a `ColorRect`, or the default gray Godot theme.

---

## 1. Salvage run: shared board entities

The skyfield board occupies x 20..700, y 140..1020 in every region. Barges sit at y 1060; the cloud-sea catcher sits below them. Layouts live in [game/data/skyfields/](../../game/data/skyfields/).

### 1.1 Salvage pod
- **Placeholder:** warm-yellow circle `(0.98, 0.85, 0.3)`, radius 12 (24 px). [pod.tscn](../../game/run/pod.tscn).
- **Role:** the "ball". Dropped from the top, bounces through pegs and gizmos into barges or the cloud sea. Up to 4 on screen; the Splitter Vane clones pods.
- **Art needed:** small salvage pod / canister readable at 24 px on all four region backgrounds. Round silhouette (circle collision), acceptable at any rotation.
- **Variants:** base sprite. Nice-to-have: half-value "split" pod (Splitter Vane) and a "multiplied" glow overlay (Crystal Prism) so value changes are visible.

### 1.2 Drop marker and airship — CHANGED
- **Placeholder:** `draw_circle()` white dot, 50% alpha, radius 8, at y 100. [drop_controller.gd](../../game/run/drop_controller.gd).
- **Role (changed in Plan 9/1065778):** aiming is now **timed release**. The marker sweeps left-right automatically along the top edge at 400 px/s (x 44..676); a tap drops the pod wherever the marker is.
- **Art needed:** a 24-32 px marker that reads as "release point" while moving: a winch hook, an open cargo hatch, or a hanging pod in a clamp. Now that the marker is always moving, an **airship hull strip** along the top edge (720 x ~100 px, y 0..120) that the marker slides beneath is strongly recommended; it anchors the fiction of dropping from your ship.

### 1.3 Collection barges — CHANGED (partly delivered)
- **Placeholder:** green rectangle `(0.35, 0.55, 0.4)`, 100 x 50. `_build_barges()` in [skyfield.gd](../../game/run/skyfield.gd).
- **Role:** 5 payout catchers at x 90 / 225 / 360 / 495 / 630, y 1060. Every region uses the same pattern: **far_left** pays the most scrap, **left/right** mid, **center** least, and **right / far_right** also pay the region's material.
- **Delivered:** three tiers (plain / fancier / fanciest) at 100 x 100. Natural mapping: center = plain, left & right = fancier, far_left & far_right = fanciest.
- **Fit notes for the delivered files:**
  - The catch rectangle is 100 x 50 (y 1035..1085). The delivered art is square, with balloons above the hull. Placed hull-aligned, the balloons rise to ~y 985, overlapping the bottom 35 px of the board. Pods will visually pass through the balloons; that's acceptable, but the hull's open mouth should line up with the top of the catch rect.
  - Re-export at 200 x 200 (2x) if the source allows.
  - Move into an art folder (e.g. `game/art/run/`) and run the Godot import before wiring.
- **Still wanted:** a way to tell material barges apart from scrap-only ones in each region (a cargo crate or tinted pennant in cloudsilk / brass / rimeglass / stormglass colors), as a separate overlay or 4 tinted variants of the fanciest barge.

### 1.4 Cloud sea
- **Placeholder:** none, invisible Area2D at the bottom (`_build_sea()` in [skyfield.gd](../../game/run/skyfield.gd)).
- **Role:** miss catcher. Pays a small scrap consolation (1 in region 1, 2-3 in later regions).
- **Art needed:** 720 x 120-160 px band of rolling clouds along the bottom edge, below the barges. Reads as soft endless cloud ocean, not ground. Optionally one tint per region (see 2).

### 1.5 Gizmo slot outlines — CHANGED (now visible)
- **Placeholder:** 96 x 96 white rectangle outline at 50% alpha, 2 px stroke, drawn by `SlotTarget._draw()` in [slot_target.gd](../../game/run/slot_target.gd), centered on each slot. Shown only during the setup phase.
- **Role:** drop targets for dragging gizmos onto the board before a run (6 / 8 / 9 / 10 slots in regions 1-4).
- **Art needed:** a 96 px empty-socket marker: docking clamp ring, brass mounting plate, or dashed rope circle. Must read over all four region backgrounds and not get lost against region 2's gear-ring pegs. Nice-to-have: a highlighted "drop here" state for while a drag hovers.

### 1.6 Stranded survivor raft — NEW
- **Placeholder:** gold trapezoid `(0.9, 0.75, 0.3)`, 48 x 18 px; collision circle radius 26. [survivor.gd](../../game/run/survivor.gd).
- **Role:** 25% chance per run: a raft carrying a stranded crewmember drifts horizontally across the board at y 480 (from either side). Any pod touching it rescues them; they join the island crew (see 4.4).
- **Art needed:** ~56 px small raft or lifeboat with a single waving figure (a generic silhouette is fine, since the crewmember is random). Must read as "rescue me" and be mirrorable (drifts both directions). Nice-to-have: a little flag or flare to draw the eye.

---

## 2. Salvage run: per-region visuals — NEW (regions 2-4 did not exist in August)

Each region needs its own backdrop and a peg set. Natural pegs are all radius 14 (28 px), circle collision, so silhouettes must stay round. Hazard pegs share that size.

| Region | Theme | Natural pegs | Hazard | Material (barge cargo / icon) |
|---|---|---|---|---|
| **1. Home Skies** | Soft daytime sky near home | 32: rock chunks, cloud puffs, carved ruin fragments | none | cloudsilk |
| **2. Brasswork Reach** | Derelict brass industry of the old sky-civilization | 39: brass gears, rivets, pipe joints; two "gear cluster" rings of 8 pegs around an open hub | **drift currents** | brasswork |
| **3. Rimefall Shallows** | Frozen shallows, frost and rime | 40 natural in loose shelf rows: frosted rock, icicled ruin | **8 ice pegs** | rimeglass |
| **4. Stormglass Verge** | Edge of a perpetual storm, glassy lightning-struck debris | 38 in staggered columns: dark slate, fused glass | **6 storm pegs** | stormglass |

### 2.1 Region backgrounds (x4)
- **Placeholder:** none; default dark gray clear color.
- **Art needed:** four 720 x 1280 portrait backgrounds, one per region above. Keep the play area (x 20..700, y 140..1020) low-contrast and uncluttered. Detail belongs at the edges and in the far distance.

### 2.2 Natural peg sets (4 sets x 2-4 variants)
- **Placeholder:** blue-gray circle `(0.55, 0.6, 0.7)`, 28 px. `_build_pegs()` in [skyfield.gd](../../game/run/skyfield.gd).
- **Art needed:** 2-4 interchangeable 28 px variants per region (themes in the table) so grids don't look stamped. Region 2 pegs should make the gear-ring formations read as gears.

### 2.3 Ice peg (region 3 hazard)
- **Placeholder:** pale-blue circle `(0.7, 0.85, 0.95)`, 28 px.
- **Role:** kills the pod's bounce on contact; the pod drops nearly dead. Guards the rich right side of the board.
- **Art needed:** 28 px, clearly distinct from region 3's natural frosty pegs (which share the palette): slick clear ice ball or frozen-solid lump that looks "sticky / dead". Readability against natural pegs matters more than beauty here.

### 2.4 Storm peg (region 4 hazard)
- **Placeholder:** orange-red circle `(0.85, 0.45, 0.25)`, 28 px. [storm_peg.gd](../../game/run/storm_peg.gd).
- **Role:** **consumes** any pod that touches it; that drop earns nothing. Seeded along high-value lanes; routing around them is the region's skill test.
- **Art needed:** 28 px crackling storm knot / miniature thundercloud with a lightning core. Must read instantly as "avoid" while staying non-violent. Nice-to-have: 2-3 frame idle crackle, and a "swallowed pod" puff effect.

### 2.5 Drift current zones (region 2 hazard)
- **Placeholder:** translucent tan rectangle `(0.8, 0.7, 0.5, 0.22)`, 440 x 160 px (two of them at y 400 and y 800, pushing right and left respectively). [drift_zone.gd](../../game/run/drift_zone.gd).
- **Role:** hostile wind bands that push pods sideways every frame. The Gyro Damper cancels them inside its field.
- **Art needed:** a 440 x 160 tileable / stretchable band of streaming haze or soot-laden wind with a clear **direction** (streaks, drifting motes). Must be mirrorable. Very translucent: pegs inside it must stay readable. Nice-to-have: scrolling-texture friendly (seamless horizontally).

---

## 3. Gizmos (12) — CHANGED (4 new, rarity tiers added)

Each gizmo is a scene under [game/run/gizmos/](../../game/run/gizmos/) with a `Polygon2D` named `Visual`, centered on its slot. Style: handmade salvager contraptions (wood, brass, rope, canvas, glass), cozy rather than industrial. Gizmos now have a **rarity** (common / uncommon / rare) gated by Workshop level. Levels 1-5 still need no per-level art.

**Spent state:** consumable gizmos drop `Visual.modulate.a` when out of uses, and the "Second Wind" boon recharges them back to full. One sprite works with the alpha trick; a dedicated spent variant is welcome where noted.

| Asset | Rarity | Placeholder today | Size (px) | What it does | States / notes |
|---|---|---|---|---|---|
| **Wind Fan** | common | light-blue rect `(0.6, 0.8, 0.95)` | 44 x 24 | Blows pods sideways through an invisible 90 x 420 column above it. | Mirrorable. Nice-to-have: wind-column streak overlay (90 x 420). |
| **Balloon Cluster** | common | pink circle `(0.95, 0.5, 0.55)` | 52 dia | Punts pods sharply upward. 3 hits per run. | Spent (alpha 0.25): deflated variant welcome. |
| **Magnet Buoy** | common | slate-blue octagon `(0.55, 0.65, 0.9)` | 32 dia (field r 160) | Curves pod paths toward itself. | Always on. Nice-to-have: ~320 px faint field ring. |
| **Cargo Net** — CHANGED | common | brown trapezoid `(0.7, 0.55, 0.4)` | 60 x 28 | Catches a pod, holds 0.8 s, flings it back toward center. **Uses now = level** (1-5 per run). | Spent (alpha 0.4): torn / slack net variant welcome. |
| **Crystal Prism** | uncommon | violet triangle, 85% alpha `(0.75, 0.6, 0.95)` | 60 x 54 | Multiplies the value of everything the pod later collects. | Glassy / glowing, some transparency. |
| **Lightning Jar** | uncommon | yellow hexagon `(0.95, 0.9, 0.4)` | 48 dia | On touch, zaps up to 3 nearby pegs into bonus scrap. 2 charges. | Spent (alpha 0.25): dark empty jar. Nice-to-have: zap arc effect. |
| **Chime Bell** | uncommon | gold trapezoid `(0.9, 0.75, 0.35)` | 40 x 38 | When rung, the next barge catch pays double. 2 rings. | Spent (alpha 0.25). |
| **Splitter Vane** | rare | mint triangle `(0.6, 0.9, 0.7)` | 40 x 40 | Splits a pod into two half-value pods. | Always on. |
| **Gyro Damper** — NEW | rare (brasswork) | gold octagon `(0.85, 0.7, 0.35)` r 20 + translucent field disc r 140 at 12% alpha | 40 dia core; **280 px dia field** | Passive stabilizer: drift currents can't push pods inside its field. Field radius grows with level. | Always on. Needs **two assets**: the core (spinning gyroscope in a brass cage) and a very faint, scalable field-ring/disc (art should scale cleanly since radius changes with level). |
| **Piston Kicker** — NEW | rare (brasswork) | orange arrow-pentagon `(0.8, 0.55, 0.3)` pointing right | 48 x 20 | Fires the pod sideways with a sharp impulse, once per pod. Faces left or right per `direction`. | Mirrorable; strong directional read. Nice-to-have: extended-piston frame. |
| **Sleet Sail** — NEW | rare (rimeglass) | ice-blue rect `(0.75, 0.9, 1.0)` | 40 x 28 | Pods in the 80 x 420 column above it fall at half gravity (floaty drift). Column width grows with level. | Needs a sail/kite-like base sprite plus a nice-to-have slow-falling-snow column overlay (80 x 420, stretchable horizontally). |
| **Gale Vent** — NEW | rare (stormglass) | sage triangle pointing up `(0.55, 0.75, 0.6)` | 44 x 32 | One sharp upward kick per pod per vent: re-lofts pods away from storm pegs. | Upward-facing vent / bellows grate; nice-to-have updraft puff. |

### 3.1 Rarity treatment — NEW
- The gizmo rarities spec explicitly left "rarity coloring" to the art pass.
- **Art needed:** three frame/border treatments (common / uncommon / rare) usable behind gizmo icons in the workshop and on setup-phase chips. A color + subtle ornament ramp (e.g. wood, brass, crystal-inlaid) works well. Locked-by-rarity rows in the workshop are dimmed in code; no separate locked art needed.

---

## 4. Home island and meta screens

All screens still use the stock gray Godot theme. Screen chrome (panels, buttons) is a theming pass; the icons and illustrations below are concrete assets.

### 4.1 Screens inventory — CHANGED

| Screen | File | Contents today |
|---|---|---|
| Main / home | [main.tscn](../../game/main.tscn) | Debug text block listing balances and fuel; buttons: Launch, Island, **Region selector** (cycles regions and shows fuel cost), **Refill fuel (ad)**. Will eventually become the island vista. |
| Island | [island_screen.tscn](../../game/base/island_screen.tscn) | Scrollable 720 x 2000 island map: building pads at authored positions, islet markers with code-drawn bridges, crew tokens on the shore band; PlotSheet bottom sheet for upgrade/batch/skip; BuildModal browser; LetterPanel; HUD bar (trickle, crates, slot unlock, workshop, back). |
| Workshop | [workshop_screen.tscn](../../game/base/workshop_screen.tscn) | Text rows for the 12 gizmo recipes with craft timers; rarity-locked rows dimmed. |
| Run setup phase — NEW (replaces the loadout screen) | inside [salvage_run.tscn](../../game/run/salvage_run.tscn) | Gizmo **tray** (164 x 56 chips, name + level), slot outlines over the live board, **kit panel** (190 x 38 toggle chips for consumables), Start (fuel cost) and Back buttons, status label. Drag preview is a plain text label. |
| Run HUD | inside [salvage_run.tscn](../../game/run/salvage_run.tscn) | Text HUD (drops, loot, quota tier), Abandon button, **BoonOffer panel** (title, 3 picks, reroll, skip), **RescueBanner**, results panel (summary, double-payout ad, return). |

The old loadout screen (`game/ui/loadout_screen.tscn`) no longer exists.

### 4.2 Building illustrations (9) — CHANGED (was 6)
- **Placeholder:** the BuildModal shows a **96 x 96 `ColorRect`** with a hashed hue and the building's first letter (`ModalPicture` in [island_screen.tscn](../../game/base/island_screen.tscn), set in `island_screen.gd` around line 294). Island rows are text only.
- **Art needed:** one illustration per building, delivered square at 192 px (96 @2x) for the modal; the same art can be cropped for row icons. Flavor text from [buildings.json](../../game/data/buildings.json) as a style hook:

| Building | Flavor / function |
|---|---|
| Workshop | "Sawdust, solder, and second chances." Crafts gizmos. |
| Wind Still | "It drinks the wind and pays you back in weather." Fuel cap and regen. |
| Dock | "Every horizon needs somewhere to leave from." Unlocks regions (4 levels). |
| Balloonworks | "Silk, rope, and stubborn optimism." Extra drops; crafts run consumables. |
| Observatory | "The clouds keep their secrets badly." Charts the winds. |
| Gardens & Cisterns | "Green things, growing where nothing should." Scrap trickle; provisions. |
| **Smeltery** — NEW | "The furnace remembers what the sky forgot." Scrap to parts. |
| **Lens Array** — NEW (Lantern Shoal islet only) | "Light, bent until it pays." Payout multiplier. |
| **Foundry Annex** — NEW (Foundry Rock islet only) | "Halvard banked these coals on purpose." Brass smelting. |

- **Nice-to-have:** an "under construction" overlay (scaffolding) shared by all buildings, since every build and upgrade runs on a timer.

### 4.3 Islets and letters — NEW
- **Islet art (x2):** Lantern Shoal (a small rock strung with salvage-barge guide lanterns) and Foundry Rock (cold furnace stacks of the old brass foundry). Each needs a **ruined / unrestored** state and a **restored** state (restoring opens the bridge or balloon line). ~192 px square each for now; they become vista pieces in 4.6.
- **Letter panel:** [LetterPanel](../../game/base/island_screen.tscn) shows a found letter (Lantern Shoal: "A letter, wax-sealed against the wind"; Foundry Rock: "A foreman's log, brass-bound"). Art: a parchment / logbook-page panel background (~600 x 700, 9-slice friendly so long text can scroll) and optionally a small wax-seal or brass-clasp ornament per letter.

### 4.4 Crew portraits (8) — NEW
- **Placeholder:** names in text rows only. The crew spec ruled portraits out of scope *for that plan*, not for the art pass.
- **Role:** survivors rescued mid-run who staff buildings for a 1.5x bonus at their specialty. They appear on the island crew rows and in the run's RescueBanner.
- **Art needed:** 8 head-and-shoulders portraits, 96 px (192 @2x), circular or soft-square crop, one consistent style:

| Crew | Specialty | Personality line |
|---|---|---|
| Maren | Workshop | "You found my tools on the shoal? Then let's put them to work." (the lens grinder from the Lantern Shoal letter) |
| Halvard | Foundry Annex | "Day 417. The coals were banked on purpose." (the foreman from the Foundry Rock log) |
| Odo | Gardens | "Soil remembers. So do I." |
| Brisa | Wind Still | "That still of yours whistles flat. I can fix that." |
| Petch | Balloonworks | "Silk holds if you tie it like you mean it." |
| Suno | Gardens | "Rain is just sky-sea. I speak both." |
| Immel | Workshop | "Half these gizmos were mine once, you know. The good halves." |
| Reya | Smeltery | "Ditched at sea twice already. The third time buys the drinks." |

### 4.5 Region emblems (4) — NEW
- **Placeholder:** the main-screen RegionButton is text ("Region: Home Skies (1 fuel)").
- **Art needed:** four 96 px emblems or postcard thumbnails (Home Skies, Brasswork Reach, Rimefall Shallows, Stormglass Verge) for region selection, plus a **locked** treatment (shared padlock / fog overlay) for regions still gated behind Dock level.

### 4.6 Island map screen (art DONE 2026-10-14, layered; layout shipped 2026-10-11)
The island screen is a vertically scrollable 720 x 2000 map ([island_screen.tscn](../../game/base/island_screen.tscn)); every coordinate lives in [island_layout.json](../../game/data/island_layout.json), so art is painted AROUND those authored positions. The 2026-10-14 jig batch (manifest section 8) delivered the map as LAYERS instead of one vista piece, because `jig generate` caps at 1024 px and the CLI's `background` command is unavailable: the sky gradient and cloud sea stay code-drawn in [island_backdrop.gd](../../game/base/island_backdrop.gd), with `island_home.png` (720x880, plateau-dominant framing) stretched over the plateau zone, the islets rendering their own art large in IslandIsletNode (the generic `islet_rock.png` underlay and the rotated bridge sprites were retired 2026-10-15). A full hand-painted `game/art/regions/island_vista.png` still overrides everything if ever produced.

| Asset | Size (design px, deliver 2x) | Notes |
|---|---|---|
| Island vista map background | 720 x 1750 | DONE as layers (2026-10-14): `island_home.png` + `islet_rock.png` over the code sky. A single hand-painted `game/art/regions/island_vista.png` remains an optional future upgrade. |
| Empty plot pad | 128 x 128 | DONE (2026-10-14): `game/art/buildings/plot_pad.png`, a turquoise ring pad with gold stakes. |
| Bridge, broken | ~200 x 80 | RETIRED (2026-10-15): drawn bridges never read well rotated on the map; the sprite stays in `game/art/buildings/` unused. Restoration state lives in the islet art and sheet. |
| Bridge, scaffold | ~200 x 80 | RETIRED (2026-10-15), sprite kept unused. |
| Bridge, restored | ~200 x 80 | RETIRED (2026-10-15), sprite kept unused. |
| Ready glow badge | 96 x 96 | DONE (2026-10-14): `game/art/ui/ready_glow.png`, a solid starburst badge (a soft glow hit the known binary-alpha limit, job 39b1b7d8); it replaces the "!" label on pads. |
| Shore band dressing | 720 x 160 | Still optional and undelivered; the crew now stand on island_home's painted rocky rim, which carries the band fine. |
| Crew Quarters illustration | 256 x 256 | Bunkhouse with a kettle chimney, matching the other home-building illustrations. File: `game/art/buildings/crew_quarters.png`; a lettered pad fallback draws until it exists. DONE (2026-10-17, jig 478ddf65). |
| Speech bubble | ~128 x 48 | Rounded comic bubble for the gardens/workshop pending counters. A drawn StyleBoxFlat panel carries it until delivered. DONE (2026-10-17, jig c42e7877, `game/art/ui/speech_bubble.png` wired as a region-sliced StyleBoxTexture; a white fill got chroma-eaten on the first try, cream fill survived). |

Wired by the map rework (previously delivered): `construction_overlay.png` now scaffolds constructing pads; building illustrations double as pad sprites; islet ruined/restored art marks the islets; crew portraits became shore tokens and worker badges on pads.

2026-10-15 polish: pads lost their text labels (the sheet carries the words); the PlotSheet wears `ui/panel.png` and its buttons wear `ui/button.png`; an upgrade-affordable badge marks pads (`game/art/icons/upgrade_ready.png`, DONE 2026-10-17 jig b5bf5804; the code-drawn mint arrow remains only as the missing-file fallback).

---

## 5. Icons

### 5.1 Currencies and materials — CHANGED (was 4)
All 48 px (96 @2x), shown in HUD, rows, costs and payouts.

| Icon | Meaning |
|---|---|
| **Scrap** | common currency |
| **Cloudsilk** | region 1 material, shimmering woven cloud fiber |
| **Brasswork** — NEW | region 2 material, salvaged brass fittings |
| **Rimeglass** — NEW | region 3 material, frosted glass shard |
| **Stormglass** — NEW | region 4 material, dark glass with trapped lightning |
| **Aether Crystals** | premium currency |
| **Parts** — NEW | worked parts smelted from scrap; spent on gizmo crafts |
| **Provisions** — NEW | Gardens output; spent on provisioned runs |
| **Fuel** | expedition energy from the Wind Still |

### 5.2 Run-kit consumables — NEW
48 px (for kit chips and island recipe rows). Crafted at the Balloonworks or Gardens, elected in the setup kit panel.

| Icon | Effect |
|---|---|
| **Charged Ballast** | +2 pod drops this run |
| **Wind Charm** | one free boon reroll |
| **Storm Oil** | pods bounce higher (+0.15) |
| **Provision run** | spend 3 provisions for a 1.15x payout run (can reuse the Provisions icon with a badge) |

### 5.3 Boons (6) — NEW
- **Placeholder:** three text buttons in the BoonOffer panel. Offered mid-run when a quota tier is crossed.
- **Art needed:** six 64 px (128 @2x) icons plus a **boon card frame** (~180 x 240) so offers read as a choice of three cards.

| Boon | Effect |
|---|---|
| Barge Bounty | barge payouts +50% |
| Rich Seas | cloud-sea payouts x3 |
| Spare Pods | +2 drops |
| Heavy Loot | +2 scrap per catch |
| Featherfall | pods bounce higher |
| Second Wind | consumable gizmos recharge |

### 5.4 Gizmo icons (12) — CHANGED (was 8)
64 px (128 @2x), for workshop rows, setup-phase tray chips, and the drag preview. Can be cropped renders of the section-3 sprites, sitting in the rarity frames from 3.1.

### 5.5 Misc UI icons
| Icon | Size | Notes |
|---|---|---|
| Daily crate (closed; open variant nice-to-have) | 96 px | carried over |
| Bonus crate — NEW | 96 px | ad-gated second crate; a visibly fancier crate than the daily one |
| "Watch ad" badge — NEW | 32 px | small film-reel or spyglass badge to overlay on ad-backed buttons (fuel refill, double payout, boon reroll, timer skip, bonus crate) |
| Timer / hourglass — NEW | 32 px | used on every build, craft, conversion and restoration row |
| Build slot — NEW | 48 px | for the second build slot unlock (crystal cost) |
| Level pip / star | 16 px | gizmo and building levels (1-5); drawn as repeated pips |

---

## 6. App icon
- `icon.svg` exists but is a simple dev placeholder.
- **Art needed:** 512 px master plus adaptive-icon foreground and background layers. Subject suggestion: the home island floating above the cloud sea, or a salvage pod under a balloon. Should still read at 48 px.

---

## 7. UI theming (one Godot Theme resource)
- 9-slice **panel** (parchment / canvas over light wood), **button** in normal / pressed / disabled / hover, **toggle chip** for kit selection (on/off states), **modal backdrop** dim.
- Panels in use: BuildModal, LetterPanel (parchment variant), BoonOffer, Results, KitPanel, TrayPanel.
- A rounded storybook display font plus a clean UI body font (fonts are out of the image agent's scope but belong in the same pass).

---

## 8. Suggested priority order

1. **Wire the 3 delivered barges** (code task) to validate the pipeline end to end before generating more.
2. **Region 1 board:** pod, region-1 pegs, sky background, cloud sea, drop marker + airship strip, slot outline.
3. **The 12 gizmo sprites** with spent variants, then the 4 field/column overlays (gyro field, magnet ring, wind column, sleet column).
4. **Currency, material and consumable icons** (13): they appear on every screen.
5. **Regions 2-4:** backgrounds, peg sets, ice/storm pegs, drift band.
6. **Building illustrations (9), crew portraits (8), boon icons + card (6+1), gizmo icons + rarity frames (12+3).**
7. **Islets + letter panel, region emblems, survivor raft, misc UI icons, app icon.**
8. **UI theme**, then the island vista once its layout exists.

### Rough count
| Group | Required | Nice-to-have |
|---|---|---|
| Run board shared (pod, marker, airship, barges delivered, sea, slot, raft) | 6 | ~5 |
| Per-region (4 backgrounds, ~12 peg variants, ice, storm, drift band) | ~19 | ~3 |
| Gizmos (12 sprites + gyro field) | 13 | ~10 |
| Icons (9 currency, 4 kit, 6 boon, 12 gizmo, 3 rarity frames, misc 6) | ~40 | — |
| Buildings, islets (x2 states), crew, region emblems | 9 + 4 + 8 + 5 | ~4 |
| App icon, UI theme, letter panel, boon card | ~4 sets | — |

## 9. Technical delivery notes

- PNG with alpha at **2x** the listed sizes. Put files under a `game/art/` tree (e.g. `run/`, `regions/`, `gizmos/`, `icons/`, `buildings/`, `crew/`, `ui/`) rather than the repo root, and commit the `.import` sidecars after running `godot --headless --import`.
- Circle-collision entities (pod, pegs, ice/storm pegs, balloon cluster, lightning jar, magnet buoy, chime bell, splitter vane, prism, piston kicker, gale vent zones, survivor raft) should keep silhouettes close to their collision circles.
- Directional gizmos (Wind Fan, Piston Kicker) and the drift band and survivor raft are flipped in code. Draw them facing **right**.
- Field and column overlays (gyro field, magnet ring, wind column, sleet column) scale with gizmo level in code: deliver them so they stretch cleanly (soft radial gradient or 9-slice / tileable).
- Backgrounds must stay low-contrast in the play area.
- Wiring the art into scenes (Polygon2D to Sprite2D swaps, backgrounds, Theme resource, icon TextureRects in rows) is a separate code plan, per the roadmap.
