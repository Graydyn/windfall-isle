# Drag-and-Drop Gizmo Setup: Design Spec

**Date:** 2026-08-23
**Status:** Approved scope, pre-plan
**Parent design:** docs/design/2026-08-15-windfall-isles-design.md section 3.3 (placement is the player's skill expression)
**Baseline:** main at da1829c, 417/417 GUT tests green, save schema v7

## 1. Summary

Gizmo placement moves out of the abstract slot-list screen and into the run scene itself. Launching an expedition opens a setup phase over the real board: pegs, barges, and hazards visible, slot positions outlined, and a tray of every owned gizmo. The player drags gizmos onto slots, then presses Start to spend fuel and begin the drops. "Slot 1" stops being a label and becomes a place you can see between the pegs.

Owner decisions locked during brainstorming:

1. Placement happens in a setup phase inside `salvage_run`, over the real board. Not a home-screen preview, not a revamped separate screen.
2. Fuel is spent on Start, not on Launch. Back during setup returns home free. This deliberately amends the design-doc rule that the run scene never touches fuel; main still shows the cost and disables Launch when unaffordable.
3. The loadout screen and main's Gizmos button are retired. The per-region saved loadout (`gizmos.loadout`) survives: setup opens pre-filled with the region's last placement, and every placement change saves immediately. Region switching lives on main only.
4. Drag mechanics use Godot's built-in Control drag-and-drop (`_get_drag_data` / `_can_drop_data` / `_drop_data`), which works with touch via mouse emulation and lets tests call the drop handlers directly.

Out of scope: any change to gizmo behavior, loadout schema, or region data; art beyond placeholder shapes; tutorialization of the drag gesture.

## 2. Run phases

`salvage_run` gains an explicit phase enum: `SETUP`, `RUNNING`, `OVER`.

- **SETUP** (new, initial): board fully built and visible (`board.build` stays in `_ready`), gizmos NOT installed, `controller.enabled` false, HUD shows a setup hint ("Place your gizmos, then press Start."), AbandonButton hidden, SetupUI visible. No fuel has been spent.
- **RUNNING**: entered by Start. Fuel spent, gizmos installed from the saved loadout, SetupUI hidden, AbandonButton shown, controller enabled, HUD switches to the normal drops/tier readout. Identical to today's post-`_ready` state from here on (boon offers, watchdogs, results).
- **OVER**: unchanged (run_over / abandon handling).

`_island_mult`, `RunModel` construction, RNG seeding, and signal wiring all stay in `_ready` unchanged. `board.install_gizmos(...)` moves from `_ready` into the Start handler.

### 2.1 Start

The Start handler:

1. Computes `cost = RegionModel.fuel_cost(RegionModel.entry(DataDefs.run, region_id), GameState.data["island"])` for the region the scene was built with.
2. Calls `FuelModel.spend(GameState.data["fuel"], cost, TimeUtil.now())`. On failure (regen dipped below cost while experimenting): a setup status label explains ("Not enough fuel."), phase stays SETUP.
3. On success: saves, installs gizmos, transitions to RUNNING.

The Start button also reflects affordability per refresh tick (disabled with the cost in its label when short), so the failure path in step 2 is a race guard, not the primary UX.

### 2.2 Back

A Back button during SETUP saves and returns to `res://game/main.tscn`. Nothing is spent; placements made during setup are already persisted. Process death during setup loses nothing for the same reason.

### 2.3 main.gd changes

`_on_launch_pressed` no longer spends fuel: it saves and changes scene. The affordability gate on the Launch button stays exactly as today (disabled when current fuel < cost) so players rarely meet the disabled Start. The Gizmos button and `_on_gizmos_pressed` are deleted.

## 3. Setup UI

New nodes under the existing `UI` CanvasLayer in `salvage_run.tscn`, grouped under a `SetupUI` Control (full-rect, visible only during SETUP):

- **SlotTargets**: one drop-target Control per region slot, centered on the slot's board coordinates (region JSON `gizmo_slots` x/y are board pixels; the board renders at identity transform, so UI coordinates match board coordinates). Each target is 96x96, drawn as a visible outline during setup. When the slot holds a gizmo, the target displays the gizmo's name and level as a token.
- **Tray**: a bottom panel with one chip per owned gizmo (name + level), laid out in a flow container. A chip whose gizmo is currently placed renders dimmed with a "placed" marker and is not draggable; placed gizmos are dragged from their slot token instead.
- **StartButton**, **BackButton**, **SetupStatus** label (for the fuel-race message and drop rejections, mirroring the island screen's StatusLabel pattern).

### 3.1 Drag semantics

Drag payload is a Dictionary `{"gizmo": <id>, "from_slot": <slot id or "">}`.

- **Tray chip drag onto an empty slot**: place. Onto an occupied slot: replace; the displaced gizmo returns to the tray (its chip un-dims).
- **Slot token drag onto another slot**: move; if the destination is occupied, the two swap is NOT attempted: the destination's occupant returns to the tray and the dragged gizmo takes the slot (single consistent rule: a drop always seats the dragged gizmo and un-seats whatever was there).
- **Slot token drag onto the tray**: remove (slot empties, chip un-dims).
- **A drag released over nothing** (Godot drops it on no target): no-op, per engine behavior.

Every successful drop writes through the loadout model and saves immediately (save-anywhere, same as the retired screen's per-tap save).

### 3.2 New Control scripts

Two small scripts (one responsibility each), colocated with the run code:

- `game/run/gizmo_chip.gd` (`class_name GizmoChip`, extends a Control): renders one gizmo (name, level, dimmed state); implements `_get_drag_data` returning the payload plus a drag preview; a flag disables dragging when dimmed or when used as a slot token whose drag source is the slot.
- `game/run/slot_target.gd` (`class_name SlotTarget`, extends a Control): knows its slot id; implements `_can_drop_data` (payload is a Dictionary with a "gizmo" key) and `_drop_data` (delegates to a `salvage_run` callback); draws the outline and hosts the token chip when occupied.

The tray container also accepts drops (`_can_drop_data` true for payloads with a non-empty `from_slot`; `_drop_data` removes). `salvage_run` owns the single drop callback so all mutations flow through one function.

## 4. Loadout model addition

`GizmoLoadout.set_slot` already enforces owned-only and one-slot-per-gizmo (it rejects a set when the gizmo sits in another slot). Drag placement needs a move-aware wrapper, added to the pure model:

- `GizmoLoadout.place(gizmos_state: Dictionary, region_id: String, slot: String, gizmo_id: String) -> bool`: clears `gizmo_id` from any other slot in the region, then `set_slot(gizmos_state, region_id, slot, gizmo_id)`. Placing over an occupied slot overwrites it (the displaced gizmo simply stops being slotted). Returns false only when the gizmo is unowned or `gizmo_id` is empty (removal stays `set_slot(state, region, slot, "")`).

`set_slot`, `loadout_for`, `owned` are unchanged. `next_choice` loses its only caller when the loadout screen dies and is deleted along with its tests (the pure cycling rule is the old UI's logic, not a placement rule).

## 5. Retirement

Deleted: `game/ui/loadout_screen.tscn`, `game/ui/loadout_screen.gd` (and `.uid`), `tests/test_loadout_screen.gd` (and `.uid`), main's `GizmosButton` node and handler. The `game/ui/` directory goes away if empty. `RegionModel.next_region_id` keeps its remaining caller (main) and stays.

No schema change: `gizmos.loadout` keeps its shape and meaning.

## 6. Testing

All headless GUT, repo conventions (handlers called directly, no scene-changing button presses, injected clocks where models are involved, int casts at JSON assert sites).

- **GizmoLoadout.place unit tests**: place into empty, move between slots (old slot cleared), overwrite occupied, unowned rejected, empty id rejected, removal via set_slot unchanged.
- **Phase tests on the run scene**: scene opens in SETUP with controller disabled, gizmos not installed, no fuel spent; Start spends exactly the region cost once, installs the saved loadout, enables the controller; Start with insufficient fuel stays in SETUP with a status message and spends nothing; drops requested during SETUP are ignored.
- **Drop-callback tests**: call the salvage_run drop callback directly for each semantic (tray-to-empty, tray-to-occupied, slot-to-slot, slot-to-tray removal), asserting both the loadout dict and the tray/token dim states; assert each successful drop persisted (re-read via SaveIO).
- **Existing run-scene tests** (`test_salvage_run`, `test_gizmo_integration`, `test_boon_integration`, `test_islet_integration`, and any gizmo test that instantiates the run scene, verified by grep in the plan): gain a shared fast-forward: grant fuel, call the Start handler directly, then proceed as before. The gizmo integration tests must assert install still happens (now at Start).
- **main.gd test**: launch no longer debits fuel (moved-debit proof), Gizmos button gone.

Manual smoke steps (waived headless, listed for the on-device pass): drag feel on touch, drag preview legibility, slot outlines against region 2's gear rings, back-out and relaunch keeping placements.

## 7. Risks and interactions

- **Fuel-spend relocation** is the one design-doc amendment (spec 3.2 step 1 said fuel is spent before the run scene loads). The launcher still gates; the run scene spends. The design doc gets a one-line errata note in the plan.
- **Existing tests assume gizmos install at `_ready`**: every run-scene test file needs the fast-forward helper in the same task that flips the phase, or the suite breaks mid-plan.
- **Board/UI coordinate identity**: slot targets assume board pixels equal UI pixels (true today: the board draws at identity under a plain CanvasLayer). If a camera or scaling transform ever lands on the board, targets must map through the canvas transform; the plan should note this at the target-positioning site.
- **Touch emulation**: Godot's Control DnD rides on mouse emulation from touch (project default). If real multi-touch drag issues surface on device, that is the manual smoke pass's job to catch; DropController already guards multi-touch for the drop gesture itself.
- **BoonOffer overlap**: boon offers can only fire in RUNNING (tier lifts require catches), so SetupUI and BoonOffer are never visible together.
- **Region switching stays on main**: the setup phase is per-launch; switching regions mid-setup is deliberately not offered (Back, switch on main, relaunch).
