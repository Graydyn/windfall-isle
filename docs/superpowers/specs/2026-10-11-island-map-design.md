# Island Map Design (Plan 15)

**Date:** 2026-10-11
**Status:** Approved for planning (autonomous session; owner asked "build this out" directly)
**Depends on:** Plans 1-14 merged, art wiring pass 1, build-browser modal

## 0. Goal

The island screen today is a vertical text menu. It should feel like a game:
a scrollable island space the player looks at, where buildings stand on the
island at real positions, islets hang below behind broken bridges, and crew
wander the shore. The player places buildings by tapping an empty plot pad
on the map and choosing from the existing build browser.

Non-goals (explicitly out):
- Free-form building placement. Plots remain fixed, authored pads; the player
  chooses WHICH pad gets WHICH building, exactly as the model works today.
  (Ruling: free placement would force a save-schema change and drag placement
  for zero mechanical gain; pads are the genre norm.)
- Any change to IslandModel, IsletModel, CrewModel, ConvertModel, TimerService,
  or the save schema. This is a presentation rework; every rule stays put.
- The main-screen vista (audit 4.6 "future"). This plan designs the island
  screen only, but its layout file and background become the vista's basis.

## 1. The map

### 1.1 Geometry

Design resolution is 720 x 1280 portrait. The map is a Control of
**720 x 2000** inside a vertical ScrollContainer. No horizontal scroll.
All coordinates live in a new data file, never in scripts (spec 7.2):

**`game/data/island_layout.json`** (loaded as `DataDefs.island_layout`):

```json
{
	"map_size": [720, 2000],
	"plot_size": 128,
	"plots": {
		"plot_0": [180, 330],
		"plot_1": [470, 300],
		"plot_2": [130, 560],
		"plot_3": [360, 480],
		"plot_4": [590, 540],
		"plot_5": [250, 760],
		"plot_6": [520, 750],
		"islet_lantern_0": [300, 1360],
		"islet_foundry_0": [520, 1740]
	},
	"islets": {
		"lantern_shoal": {"pos": [170, 1230], "bridge": [[240, 1040], [180, 1160]]},
		"foundry_rock": {"pos": [540, 1570], "bridge": [[330, 1400], [480, 1510]]}
	},
	"crew_band": {"y": 940, "start_x": 64, "spacing": 82}
}
```

Positions are node centers. The home plateau occupies roughly y 200..1050,
Lantern Shoal y 1150..1450, Foundry Rock y 1500..1800, and a cloud-sea band
closes the bottom (y 1850..2000). The crew band sits on the home island's
shore at y 940 (on the plateau, below the plots, above the first bridge).

A def-validation test pins: every home plot id (`plot_0..plot_<count-1>`
from `buildings.json plot_count`) and every islet plot id from `islets.json`
appears in `plots` exactly once; every position sits inside `map_size` with a
half-plot margin; no two plot centers are closer than 150 px.

### 1.2 Scene structure

`island_screen.tscn` is rebuilt around:

```
IslandScreen (Control, full rect)
├── MapScroll (ScrollContainer, y 90..1100, horizontal scroll disabled)
│   └── Map (Control, custom_minimum_size 720x2000)
│       ├── Backdrop (Control; code-drawn fallback, see 4)
│       ├── Bridges (Node2D-free: plain Control children per islet)
│       ├── Plots (Control; PlotNode children, built by _rebuild)
│       ├── Islets (Control; IsletNode children)
│       └── CrewBand (Control; CrewToken children)
├── Title, RefreshTimer, StatusLabel          (kept, same names)
├── HudBar (HBoxContainer, fixed at the bottom, y 1110..1270)
│   ├── GardensButton, CrateButton, BonusCrateButton, SlotButton,
│   │   WorkshopButton, BackButton            (kept, SAME node names,
│   │                                          reparented under HudBar)
├── BuildModal (unchanged, all child paths identical)
├── LetterPanel (unchanged)
└── PlotSheet (new overlay, see 2.3)
```

The `Rows` VBoxContainer is DELETED. Tests that counted `Rows` children are
rewritten against `Map/Plots`, `Map/Islets`, `Map/CrewBand` child counts.
Handler-level tests (the large majority) are untouched because every handler
keeps its name and signature. Scripts that `get_node` the six HUD buttons
switch to their new `HudBar/...` paths; tests use `find_child` or the new
paths explicitly.

### 1.3 Refresh discipline (carried over verbatim)

The signature mechanism stays: `_signature(now)` is unchanged, `_refresh_tick`
rebuilds map children only on structural change, and per-second updates write
label text in place (`_plot_labels` becomes per-PlotNode status labels;
`_islet_labels` per-IsletNode). The liveness test ("a tick must not free a
button under the player's finger") is rewritten to hold a PlotNode reference.

## 2. Map elements

### 2.1 PlotNode (`game/base/plot_node.gd` + scene, 128 x 128 Button)

One per plot id, positioned from the layout file. `flat = true`; a plot is
one big tap target. Children: Art (TextureRect), Overlay (TextureRect for the
construction scaffold), NameLabel (bottom, building name + "Lv N" or
"(empty)"), StatusLabel (countdown / "Tap to collect!" / batch state),
WorkerBadge (32 px TextureRect, crew portrait of the assigned worker),
ReadyBadge (modulated glow ring/label when a timer is done). All children
`MOUSE_FILTER_IGNORE` (repo DnD lesson: never block the tap walk).

States rendered from existing model reads (no new model code):
- **Empty:** pad art (fallback: dashed 50%-alpha rect in `_draw`), name
  "(empty)", status "Tap to build".
- **Constructing:** building art at 50% modulate + `construction_overlay.png`
  (delivered art, wired here at last) + countdown in StatusLabel.
- **Construction done:** ReadyBadge visible, StatusLabel "Tap to collect!".
- **Built:** building art full, name + level, WorkerBadge when crewed,
  StatusLabel shows batch state ("batch 312s" / "Batch ready!") or "".

Signal: `plot_tapped(plot_id)`. The screen routes it:
- construction timer done → `_on_collect_pressed(plot)` directly (one-tap
  collect, no intermediate sheet);
- batch timer done (and no construction pending) → `_on_batch_collect_pressed`
  directly;
- empty plot → `_open_build_modal(plot)` (build browser, unchanged);
- otherwise (built or constructing) → open the PlotSheet (2.3).

### 2.2 IsletNode (128 x 160 Button, one per islet)

Art = existing `islet_<id>_ruined/restored.png`, name label, status label
(same strings `_islet_row_text` produces today; that helper is kept).
A bridge Control per islet draws between the layout's bridge endpoints:
fallback is a 3-px dashed line (broken), solid line (restored), solid +
"restoring (Ns)" label while the timer runs; art replaces these later (see 5).
Locked islets dim to 40% (fixes the parked Plan 8 polish note).

Tap routing by `_islet_state`:
- "o" (offered) → `_on_restore_pressed(islet_id)`; the model already
  rejects unaffordable/out-of-order restores and StatusLabel explains why;
- "d" (done) → `_on_restore_collect_pressed(islet_id)` (opens the letter);
- "R" (restored) → `_on_read_letter_pressed(islet_id)`;
- "r"/"L" → no-op.

A restored islet's plot id joins `_plot_ids()` exactly as today, so its
PlotNode appears at the authored position on the islet.

### 2.3 PlotSheet (new bottom-sheet overlay panel)

Opened by tapping a built or constructing plot. A PanelContainer anchored to
the bottom third, with: title ("Workshop Lv 2"), worker line, and a VBox of
contextual buttons wired to EXISTING handlers:
- **Upgrade...** → closes the sheet, `_open_build_modal(plot)` (locked
  upgrade card, unchanged);
- one button per recipe → `_on_batch_start_pressed(building, recipe)`
  (text/disabled state via the kept `_batch_button_text` / `can_start`);
- **Skip (ad)** while constructing and the placement is available →
  `_on_skip_pressed("build_" + plot)`;
- **Close.**

The sheet re-renders on every tick while open (workshop CraftModal
precedent) and closes itself if its plot's structural state changes.

### 2.4 CrewToken (64 x 96 Button per crew def)

Portrait from `game/art/crew/<id>.png`; unrescued = 40% alpha (silhouette),
label "???" and not pressable. Rescued: name label + assignment line
("idle" / building name). Tap → `_on_assign_pressed(crew_id)` (the existing
cycle). The assigned building's PlotNode shows the WorkerBadge, so the
assignment is visible in both places.

## 3. HUD bar

The six existing buttons keep their names and handlers, arranged in a fixed
HudBar under the scroll view in two rows (Gardens/Crate/BonusCrate on top,
Slot/Workshop/Back below). StatusLabel sits just above it. No behavior
change; `_refresh_static_controls` is untouched except for node paths.

## 4. Backdrop fallback

Until the vista art lands, Backdrop draws in code (no PNG): a vertical sky
gradient, a flat plateau silhouette polygon behind the plots, two smaller
rock silhouettes behind the islets, and a pale cloud band at the bottom.
When `res://game/art/regions/island_vista.png` exists it is drawn instead
(TextureRect full-map). This keeps the screen shippable art-less and gives
the art a single drop-in target.

## 5. Graphics this design needs (tracked in the audit doc)

The plan's final task rewrites audit section 4.6 into a concrete "Island
map" brief:

| Asset | Size (design px, deliver 2x) | Notes |
|---|---|---|
| Island vista map background | 720 x 2000 | Sky top, home plateau (plots at the layout coordinates), two islet rocks, cloud-sea bottom band. Painted around the authored pad positions in `island_layout.json`. |
| Empty plot pad | 128 x 128 | Cleared foundation: stone circle / timber deck. Reads as "build here". |
| Bridge, broken | ~200 x 80 | Snapped rope bridge stub pair. One generic set reused for both islets. |
| Bridge, scaffold (restoring) | ~200 x 80 | Half-built planks + rigging. |
| Bridge, restored | ~200 x 80 | Whole rope bridge. |
| Ready glow badge | 96 x 96 | Soft gold burst behind "Tap to collect!" (nice-to-have; modulate fallback ships first). |
| Shore/crew band dressing | 720 x 160 | Optional: dock planks the crew stand on. |

Already delivered and newly wired by this plan: `construction_overlay.png`
(constructing plots), building illustrations (plot art), islet
ruined/restored art (IsletNodes), crew portraits (tokens + worker badges).

## 6. Testing

- Layout def validation (1.1) in a new `tests/test_island_layout_defs.gd`.
- `tests/test_island_screen.gd`: rewrite only the structural tests (Rows
  counts, row liveness, restored-islet row) against Map child counts and
  PlotNode liveness; add tap-routing tests (empty → modal, done → collect,
  built → sheet), PlotSheet button wiring, islet tap routing per state, crew
  token cycling, construction overlay visibility, locked-islet dimming.
- All handler/modal/batch/crate/slot tests pass unchanged apart from HUD
  button node paths.
- Headless limits acknowledged: ScrollContainer touch-drag feel is an
  on-device smoke item, waived headless per standing ruling.
