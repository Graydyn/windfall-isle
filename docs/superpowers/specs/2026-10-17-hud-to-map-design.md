# The HUD dissolves into the map (Plan 16 design)

Date: 2026-10-17. Owner request: remove all of the buttons at the bottom of the
island screen and turn them into gameplay elements.

## 1. Goals

The island screen's bottom HUD row (Collect trickle, Open daily crate, Bonus
crate, 2nd slot, Crew, Workshop) disappears. Each function moves onto the map
or into the sheet or modal where the player already acts:

1. **Trickle** collects by tapping the Gardens building. A speech bubble above
   the Gardens shows the pending scrap.
2. **Crates** become crate icons floating at the top right of the screen, shown
   only while claimable. The bonus crate carries a small ad badge.
3. **2nd build slot** moves into the build modal: an offer button appears when
   every builder is busy and the second slot is still purchasable. (What it
   does: it raises `island.build_slots` from 1 to 2 so two constructions can
   run at once, for 20 crystals.)
4. **Crew Quarters** is a new, cheap home building (40 scrap, 45 s, max level
   1) on a new eighth plot. Survivors stop spawning on runs until it stands;
   tapping the built Crew Quarters opens the Crew sheet, replacing the Crew
   button.
5. **Workshop** navigation moves into the Workshop's own plot sheet as an
   "Enter the workshop" button. A speech bubble above the Workshop shows how
   many distinct gizmos the player has the resources to craft.

The Back button stays: it is navigation, not gameplay. It moves to the top
left; the map scroll extends to the bottom of the screen.

## 2. Components

- **buildings.json / island_layout.json**: `crew_quarters` def, `plot_count` 8,
  `plot_7` at (360, 810).
- **CraftModel.craftable_ids(data, gizmo_defs, economy)**: distinct gizmo ids
  whose rarity is unlocked, below craft max level, and affordable. Slot
  occupancy is deliberately ignored: the bubble advertises what the resources
  allow, not what the queue allows this minute.
- **salvage_run._maybe_schedule_survivor**: early return while
  `IslandModel.building_level(island, "crew_quarters") < 1`.
- **IslandPlotNode**: a speech-bubble child (rounded white panel + label,
  mouse-ignored) shown when the state dict carries a nonempty `bubble`; a
  lettered fallback label for a BUILT building whose art is missing (the Crew
  Quarters has no illustration yet), driven by a `letter` state key.
- **island_screen.tscn**: the six HUD buttons' nodes are deleted (BackButton
  survives, moved to the top left); `DailyCrateIcon` and `BonusCrateIcon`
  TextureButtons sit at the top right; `ModalSlotButton` joins the build
  modal's VBox; MapScroll extends to y 1270 and the mist band moves down.
- **island_screen.gd**: `_refresh_static_controls` drives crate icon
  visibility only; `_plot_state` computes `bubble` and `letter`;
  `_on_plot_tapped` routes a Gardens tap with pending trickle to
  `_collect_trickle` and a built Crew Quarters tap to the crew sheet; the
  Workshop sheet gains the Enter button; `_render_modal` shows the slot offer.

## 3. Tap routing on a built plot (priority order)

1. Construction timer done: collect the build (unchanged).
2. Construction running: open the sheet (unchanged).
3. Empty plot: open the build browser (unchanged).
4. Batch timer done: collect the batch (unchanged).
5. Gardens with pending trickle > 0: collect the trickle silently; the bubble
   vanishing is the feedback. The sheet is still reachable: pending resets to
   0 on collect, so the next tap opens the sheet.
6. Crew Quarters: open the Crew sheet.
7. Otherwise: open the plot sheet (unchanged).

## 4. Out of scope

- Crew Quarters illustration, speech-bubble art, crate-icon bobbing animation:
  the Phase B art pass owns those. The lettered pad fallback and drawn bubble
  carry until then.
- No change to crate payouts, trickle math, ad limits, or the reward modal.

## 5. Testing

Per-feature GUT tests ride each task: defs shape guards, craftable_ids rules,
survivor gating, bubble render rules on the plot node, crate icon visibility,
modal slot offer, tap routing (trickle collect, crew sheet, workshop enter
button), and updates to every test that referenced the removed HUD nodes.
