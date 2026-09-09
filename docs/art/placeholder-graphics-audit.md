# Placeholder Graphics Audit

**Date:** 2026-08-16
**Purpose:** Complete inventory of every placeholder visual in the game, written as a brief for the image-generation agent. Each entry lists the asset name, where the placeholder lives in code, what it looks like today, its exact on-screen size, its gameplay role, and any states or variants the final art must support.

## Global art direction (from the design doc)

- **Tone:** cozy, optimistic, Ghibli-adjacent sky-fantasy. Fantasy without elves, sci-fi without robots. No combat, no violence.
- **Style:** painterly / stylized 2D. Explicitly NOT pixel art.
- **Setting:** a salvager rebuilds a shattered floating island above an endless cloud sea littered with debris from a lost sky-civilization.
- **Platform:** Android only, portrait only. Design resolution is **720 x 1280** (canvas_items stretch, expand aspect). All pixel sizes below are at this resolution; deliver at 2x (or vector-clean) so art survives stretch scaling on high-DPI phones.
- **Transparency:** every sprite below needs a transparent background (PNG with alpha) unless noted as a full-screen background.

Currently the game contains **zero image files**. Every visual is a flat-color `Polygon2D` built in code, a `_draw()` call, or default gray Godot UI theme. This audit covers all of them plus the visuals that are logically present but currently invisible.

---

## 1. Salvage run entities (the pachinko board)

The skyfield board occupies x 20..700, y 140..1020 of the portrait screen. Board layout comes from [region_1.json](game/data/skyfields/region_1.json) ("Home Skies", the only region so far).

### 1.1 Salvage pod

- **Placeholder:** warm-yellow 12-segment circle polygon, color `(0.98, 0.85, 0.3)`, radius 12 px (24 px diameter). [pod.tscn](game/run/pod.tscn), [pod.gd](game/run/pod.gd).
- **Role:** the "ball". A physics body dropped from the airship at the top; bounces down through pegs and gizmos into barges or the cloud sea. Up to 4 on screen at once; the Splitter Vane can clone one mid-fall.
- **Art needed:** a small salvage pod / canister that reads clearly at 24 px against a sky background. Round silhouette (collision is a circle). Think a rivet-seamed cargo sphere, tiny barrel, or bundled crate with a scrap of balloon silk. It rotates freely under physics, so the design should look acceptable at any rotation (avoid a strong "this way up" face).
- **States/variants:** one base sprite is enough for MVP. A half-value "split" pod variant (from Splitter Vane) is a nice-to-have (same size, visibly lighter or cracked).

### 1.2 Natural pegs

- **Placeholder:** blue-gray 12-segment circle, color `(0.55, 0.6, 0.7)`, radius 14 px (28 px diameter). Built in `_build_pegs()` in [skyfield.gd](game/run/skyfield.gd).
- **Role:** fixed bounce obstacles. Region 1 has 32 of them in a staggered grid. The design doc describes natural pegs as "rock chunks, cloud puffs, ruin fragments".
- **Art needed:** round peg sprites, 28 px, in 2-4 interchangeable variants so the grid does not look stamped: e.g. a floating rock chunk, a puff of dense cloud, a fragment of carved sky-ruin masonry. Circular silhouette is required (collision is a circle).
- **States/variants:** static for now. Future regions add storm pegs and ice pegs, but do not generate those yet.

### 1.3 Collection barges

- **Placeholder:** flat green rectangle, color `(0.35, 0.55, 0.4)`, 100 x 50 px. Built in `_build_barges()` in [skyfield.gd](game/run/skyfield.gd).
- **Role:** the payout catchers along the bottom of the board (5 in region 1, at y 1060). Different barges pay different amounts; the far-left pays best in scrap, the far-right drops cloudsilk.
- **Art needed:** a small open-topped sky barge (wooden hull hung from balloons or propellers) about 100 x 50 px, with an obvious open mouth on top where pods land. Ideally 2-3 tint/decoration variants so high-value barges can look richer than the center one. The catch area is the full rectangle, so the open top should span most of the width.

### 1.4 Cloud sea

- **Placeholder:** none, currently invisible. It is an Area2D catcher at the very bottom of the screen (760 x 80 px at y 1180), built in `_build_sea()` in [skyfield.gd](game/run/skyfield.gd).
- **Role:** the miss-catcher. Pods that miss every barge sink into the cloud sea for a minimum 1-scrap payout.
- **Art needed:** a horizontal band of soft rolling clouds spanning the full 720 px screen width, roughly 100-160 px tall, that sits along the bottom edge under the barges. Should read as "soft, endless cloud ocean", not as ground.

### 1.5 Board background

- **Placeholder:** none. The run scene renders on the default dark gray Godot clear color.
- **Role:** the backdrop for the whole salvage run: open sky between the player's airship (top) and the cloud sea (bottom).
- **Art needed:** a full-screen 720 x 1280 portrait sky background. Soft daytime sky, distant floating islets and drifting clouds, kept low-contrast and uncluttered in the central play area (x 20..700, y 140..1020) so pegs and pods stay readable on top of it.

### 1.6 Drop aim indicator

- **Placeholder:** a `draw_circle()` white dot at 50% alpha, radius 8 px, shown at the top of the board while the player aims. [drop_controller.gd](game/run/drop_controller.gd) `_draw()`.
- **Role:** shows where the next pod will release as the player drags along the top edge.
- **Art needed:** a small aim marker, about 16-24 px: a soft glowing reticle, a winch hook, or a hatch-open pod silhouette. Semi-transparent or glowing so it reads as a preview rather than a live object. (An airship hull peeking from the top edge that the marker slides along would be a strong future addition; not currently a node.)

### 1.7 Gizmo slot markers

- **Placeholder:** none, invisible `Marker2D` anchors (6 in region 1).
- **Role:** the fixed anchor points where crafted gizmos are installed. Currently the player never sees empty slots in-run, but a loadout/placement UI will eventually need them.
- **Art needed (low priority):** a subtle empty-socket marker, about 30 px: a faint ring, docking clamp, or dashed circle.

---

## 2. Gizmos (8 total)

Gizmos are player-crafted machines installed at slot markers on the board. Each is its own scene under [game/run/gizmos/](game/run/gizmos/) with a flat-color `Polygon2D` placeholder set in its `.gd` script. Names and stats come from [gizmos.json](game/data/gizmos.json). Shared needs:

- Each sprite is centered on its anchor point and must read at the sizes given below.
- Several gizmos have a **spent state** (out of uses for the run), currently shown by dropping sprite alpha. Final art can either rely on the same alpha trick (one sprite is enough) or provide a dimmed/closed variant. Noted per gizmo.
- Style: handmade salvager contraptions: wood, brass, rope, canvas, glass. Cozy, not industrial.

| Asset | Placeholder today | Size (px) | What it is / does | States |
|---|---|---|---|---|
| **Wind Fan** | light-blue rectangle `(0.6, 0.8, 0.95)` | 44 x 24 | A fan that blows a steady horizontal wind through a tall column above it (column is 90 x 420, invisible). Pushes pods sideways. Faces left or right per `direction`. | Always active. Design so it can be mirrored horizontally. A subtle wind-column effect (streaks/leaves) is a nice-to-have second asset. |
| **Balloon Cluster** | pink-red circle `(0.95, 0.5, 0.55)` | 52 dia (r 26) | A bundle of small balloons that punts the pod sharply upward on contact. Pops after 3 hits per run. | Spent state (alpha 0.25 today): deflated/popped variant welcome. |
| **Crystal Prism** | translucent violet triangle `(0.75, 0.6, 0.95, 0.85)` | ~60 w x 54 h | A mounted aether crystal that multiplies the value of everything the pod collects after passing through it. | Always active. Should look glassy/glowing; some transparency in the art fits the current look. |
| **Lightning Jar** | yellow hexagon `(0.95, 0.9, 0.4)` | 48 dia (r 24) | A jar of captured lightning; when a pod touches it, it zaps up to 3 nearby pegs into bonus scrap. 2 charges per run. | Spent state (alpha 0.25 today): dark/empty jar variant welcome. A zap/spark effect sprite is a nice-to-have. |
| **Chime Bell** | brass-gold trapezoid (wider at bottom) `(0.9, 0.75, 0.35)` | 40 w x 38 h | A hanging bell; when rung by a pod, the next barge catch pays double. 2 rings per run. | Spent state (alpha 0.25 today). |
| **Magnet Buoy** | slate-blue octagon `(0.55, 0.65, 0.9)` | 32 dia (visual r 16; its pull field reaches r 160) | A floating buoy that curves pod trajectories toward itself. | Always active. A faint field-radius glow ring (~320 px dia, very subtle) is a nice-to-have second asset. |
| **Cargo Net** | brown trapezoid `(0.7, 0.55, 0.4)` | 60 w x 28 h | A net that catches a falling pod, holds it ~0.8 s, then flings it back toward board center. 1 use per run. | Spent state (alpha 0.4 today): torn/hanging-loose net variant welcome. |
| **Splitter Vane** | mint-green triangle `(0.6, 0.9, 0.7)` | 40 w x 40 h | A bladed vane that splits a pod into two half-value pods (once per pod). | Always active. |

Gizmos also have upgrade levels 1-5 (stats scale +25% per level). Art does NOT need per-level variants for MVP, but small attachable level markers (stars/pips) may be requested later for the UI.

---

## 3. UI screens (default Godot theme, no art at all)

All four screens use the stock gray Godot theme: gray buttons, plain labels, no backgrounds, no icons. Functional placeholders, listed here so the image agent knows the full surface area. Screen-level art (backgrounds, panel frames, button skins) is a theming pass rather than single sprites, but the **icons** below are concrete assets.

### 3.1 Screens

| Screen | File | Contents today |
|---|---|---|
| Main / home | [main.tscn](game/main.tscn) | Multi-line debug text of balances plus three gray buttons (Island, Gizmos, Launch Expedition). Will eventually become the island vista. |
| Island | [island_screen.tscn](game/base/island_screen.tscn) | Text rows listing the 6 buildings (Workshop, Wind Still, Dock, Balloonworks, Observatory, Gardens & Cisterns) with build/upgrade buttons; trickle-collect, daily-crate, and slot-unlock buttons. No building illustrations exist. |
| Workshop | [workshop_screen.tscn](game/base/workshop_screen.tscn) | Text rows for the 8 gizmo recipes with craft buttons and timers. No gizmo icons exist. |
| Gizmo loadout | [loadout_screen.tscn](game/ui/loadout_screen.tscn) | Text rows assigning gizmos to the 6 board slots. |
| Run HUD | inside [salvage_run.tscn](game/run/salvage_run.tscn) | Plain text HUD label (drops left, loot), Abandon button, and a gray results panel. |

### 3.2 Icon assets needed for UI (concrete, high value)

| Asset | Role | Suggested size |
|---|---|---|
| **Scrap icon** | common currency, shown everywhere | 48 px |
| **Cloudsilk icon** | region-1 material (shimmering woven cloud fiber) | 48 px |
| **Aether Crystal icon** | premium currency | 48 px |
| **Fuel icon** | expedition energy (wind-fuel from the Wind Still) | 48 px |
| **Gizmo icons x8** | workshop/loadout rows; can be cropped renders of the section-2 sprites | 64 px each |
| **Building icons x6** | Workshop, Wind Still, Dock, Balloonworks, Observatory, Gardens & Cisterns | 96 px each |
| **Daily crate** | the once-per-day reward crate (closed; an open variant is a nice-to-have) | 96 px |

### 3.3 App icon

There is **no icon file in the repo at all** (Godot's default icon.svg was never added). Android export will need a proper app icon: 512 px master, foreground/background layers for adaptive icons. Suggested subject: the home island floating above the cloud sea, or a salvage pod with balloon.

---

## 4. Suggested priority order for the image agent

1. **Board entities** (pod, pegs, barges, cloud sea, sky background): this is where the player spends the session loop, biggest visual win.
2. **The 8 gizmo sprites** with spent-state variants.
3. **Currency and fuel icons**: they appear on every screen.
4. **Gizmo and building icons** for the workshop/island rows.
5. **App icon** and aim indicator.
6. UI theming (buttons, panels) and nice-to-haves (wind column, zap effect, magnet glow, split-pod variant, empty-slot marker).

## 5. Technical delivery notes

- PNG with alpha, delivered at 2x the listed sizes (design resolution is 720 x 1280 and the game stretches up on device).
- Circular-collision entities (pod, pegs, balloon cluster, lightning jar, magnet buoy, chime bell zone) should keep silhouettes close to their collision circles so physics matches what the player sees.
- The board background must stay low-contrast in the play area; every entity above renders on top of it.
- No text baked into any sprite (localization).
- Wiring the art into scenes (swapping `Polygon2D` for `Sprite2D`, adding the background layers) is a separate code task tracked outside this audit.
