# Windfall Isles Plan 9: Drag-and-Drop Gizmo Setup

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gizmo placement moves into a drag-and-drop setup phase inside the run scene, over the real board; fuel is spent on Start; the old loadout screen is retired.

**Architecture:** `salvage_run` gains a SETUP/RUNNING/OVER phase machine. Gizmo installation and the fuel debit move from launch time into the Start handler. Two small Control scripts (`GizmoChip` drag source, `SlotTarget` drop target, with an empty slot id meaning "the removal tray") ride Godot's built-in Control drag-and-drop; all loadout mutations flow through one salvage_run callback into a new pure `GizmoLoadout.place`. The loadout screen, main's Gizmos button, and `GizmoLoadout.next_choice` are deleted.

**Tech Stack:** Godot 4.6.3 (GDScript), GUT 9.6.1.

**Spec:** docs/superpowers/specs/2026-08-23-drag-drop-gizmo-setup-design.md

## Global Constraints

- Godot binary: `GODOT=/Applications/Godot-4.6.app/Contents/MacOS/Godot` (4.6.3; NEVER `/Applications/Godot.app`, which is 4.7 and breaks GUT 9.6.1).
- Full suite (must exit 0): `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- Single file: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit`
- After creating any new .gd file, run `$GODOT --headless --import` and commit the generated `.gd.uid` sidecars; `git status --porcelain` must show no untracked `.gd.uid` (test files included).
- Indentation: tabs. No em dashes anywhere, including comments and player-facing strings.
- Raw JSON floats: cast with `int()` / `float()` at use and assert sites; never normalize in DataDefs. Dictionary `==` does not coerce.
- Pure models (GizmoLoadout) never read autoloads, clocks, or RNG.
- GUT 9.6 auto-fails on pushed/engine errors; error-path tests declare `assert_push_error_count` / `assert_engine_error_count` AFTER the trigger. GUT strict warnings reject `:=` inference from untyped Array/Dictionary chains; declare explicit types on anything read from JSON-sourced containers.
- UI tests call handlers directly and NEVER press or invoke scene-changing buttons/handlers (`_on_return_pressed`, `_on_setup_back_pressed`, `_on_launch_pressed` change scenes: never call them in tests).
- Screen rebuild discipline: detach-then-free (`remove_child` before `queue_free`) when a rebuild can be followed synchronously by reads, matching island/loadout precedent.
- Never `add_child` a physics body inside a `body_entered` chain; `add_child.call_deferred` instead (standing rule; not expected to arise here).
- Do not state cumulative suite totals anywhere; per-task new-test lists only.
- Commit after every task; every commit leaves the full suite green.
- Deletion order matters: `GizmoLoadout.next_choice` is still called by `game/ui/loadout_screen.gd`, so it is deleted only in Task 5 together with that screen, never earlier.

---

### Task 1: GizmoLoadout.place

**Files:**
- Modify: `game/run/gizmo_loadout.gd`
- Test: `tests/test_gizmo_loadout.gd` (modify)

**Interfaces:**
- Consumes: existing `owned`, `loadout_for`, `set_slot` (unchanged).
- Produces: `GizmoLoadout.place(gizmos_state: Dictionary, region_id: String, slot: String, gizmo_id: String) -> bool`. Move-aware seat: clears `gizmo_id` from any other slot, overwrites whatever held `slot`. Returns false for empty or unowned `gizmo_id`. Removal remains `set_slot(state, region, slot, "")`. `next_choice` is NOT touched in this task.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_gizmo_loadout.gd`:

```gdscript
func test_place_seats_into_an_empty_slot() -> void:
	var state := fresh_state()
	assert_true(GizmoLoadout.place(state, "region_1", "slot_0", "wind_fan"))
	assert_eq(GizmoLoadout.loadout_for(state, "region_1"), {"slot_0": "wind_fan"})

func test_place_moves_between_slots_clearing_the_old_one() -> void:
	var state := fresh_state()
	GizmoLoadout.place(state, "region_1", "slot_0", "wind_fan")
	assert_true(GizmoLoadout.place(state, "region_1", "slot_1", "wind_fan"))
	assert_eq(GizmoLoadout.loadout_for(state, "region_1"), {"slot_1": "wind_fan"},
		"a move never leaves the gizmo doubled")

func test_place_overwrites_an_occupied_slot() -> void:
	var state := fresh_state()
	GizmoLoadout.place(state, "region_1", "slot_0", "wind_fan")
	assert_true(GizmoLoadout.place(state, "region_1", "slot_0", "balloon_cluster"))
	assert_eq(GizmoLoadout.loadout_for(state, "region_1"), {"slot_0": "balloon_cluster"},
		"the displaced gizmo simply stops being slotted")

func test_place_rejects_unowned_and_empty_ids() -> void:
	var state := fresh_state()
	assert_false(GizmoLoadout.place(state, "region_1", "slot_0", "chime_bell"))
	assert_false(GizmoLoadout.place(state, "region_1", "slot_0", ""),
		"removal goes through set_slot, never place")
	assert_eq(GizmoLoadout.loadout_for(state, "region_1"), {})

func test_place_move_and_overwrite_compose() -> void:
	var state := fresh_state()
	GizmoLoadout.place(state, "region_1", "slot_0", "wind_fan")
	GizmoLoadout.place(state, "region_1", "slot_1", "balloon_cluster")
	assert_true(GizmoLoadout.place(state, "region_1", "slot_1", "wind_fan"),
		"dragging wind_fan onto the occupied slot_1 seats it there")
	assert_eq(GizmoLoadout.loadout_for(state, "region_1"), {"slot_1": "wind_fan"},
		"balloon_cluster was un-seated and slot_0 emptied in one drop")
```

- [ ] **Step 2: Run to verify failure**

Run: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_gizmo_loadout.gd -gexit`
Expected: FAIL (`place` does not exist).

- [ ] **Step 3: Implement**

In `game/run/gizmo_loadout.gd`, add after `set_slot` (before `next_choice`):

```gdscript
static func place(gizmos_state: Dictionary, region_id: String, slot: String, gizmo_id: String) -> bool:
	# Drag placement (spec: drag-drop setup): seats the gizmo in `slot`,
	# clearing it from any other slot first (a move) and silently un-seating
	# whatever held `slot` (the displaced gizmo returns to the tray).
	# Removal stays set_slot(state, region, slot, "").
	if gizmo_id == "" or not owned(gizmos_state).has(gizmo_id):
		return false
	var region := loadout_for(gizmos_state, region_id)
	for other_slot in region.keys():
		if other_slot != slot and String(region[other_slot]) == gizmo_id:
			region.erase(other_slot)
	return set_slot(gizmos_state, region_id, slot, gizmo_id)
```

- [ ] **Step 4: Run the file, then the full suite**

Both must pass.

- [ ] **Step 5: Commit**

```bash
git add game/run/gizmo_loadout.gd tests/test_gizmo_loadout.gd
git commit -m "feat: move-aware GizmoLoadout.place for drag placement"
```

---

### Task 2: GizmoChip and SlotTarget controls

**Files:**
- Create: `game/run/gizmo_chip.gd`
- Create: `game/run/slot_target.gd`
- Test: `tests/test_setup_controls.gd` (create)

**Interfaces:**
- Consumes: nothing project-specific (pure Controls).
- Produces (Task 4 relies on these exact signatures):
  - `GizmoChip` (class_name, extends Label): `setup(id: String, display: String, source_slot: String)`, `set_dimmed(dimmed: bool)`, `_get_drag_data` returning `{"gizmo": id, "from_slot": source_slot}` or null when dimmed. Members `gizmo_id`, `from_slot`, `draggable`.
  - `SlotTarget` (class_name, extends Control): `setup(id: String, on_drop: Callable)`; member `slot_id`; `_can_drop_data` accepts Dictionaries with a non-empty "gizmo" (and, when `slot_id == ""`, only payloads with a non-empty "from_slot": the removal tray takes placed gizmos only); `_drop_data` calls `on_drop.call(payload, slot_id)`. Draws an outline when `slot_id != ""`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_setup_controls.gd`:

```gdscript
extends GutTest


func make_chip(id: String, source_slot: String) -> GizmoChip:
	var chip: GizmoChip = autofree(GizmoChip.new())
	chip.setup(id, "%s display" % id, source_slot)
	return chip


func test_chip_drag_payload_carries_id_and_source() -> void:
	var chip := make_chip("wind_fan", "")
	assert_eq(chip._get_drag_data(Vector2.ZERO), {"gizmo": "wind_fan", "from_slot": ""})
	var token := make_chip("wind_fan", "slot_2")
	assert_eq(token._get_drag_data(Vector2.ZERO), {"gizmo": "wind_fan", "from_slot": "slot_2"})

func test_dimmed_chip_does_not_drag() -> void:
	var chip := make_chip("wind_fan", "")
	chip.set_dimmed(true)
	assert_eq(chip._get_drag_data(Vector2.ZERO), null, "a placed gizmo's tray chip is inert")
	chip.set_dimmed(false)
	assert_eq(chip._get_drag_data(Vector2.ZERO), {"gizmo": "wind_fan", "from_slot": ""})

func test_chip_receives_mouse() -> void:
	var chip := make_chip("wind_fan", "")
	assert_eq(chip.mouse_filter, Control.MOUSE_FILTER_STOP,
		"Labels default to IGNORE; a chip must receive the drag press")

func test_slot_target_accepts_gizmo_payloads_only() -> void:
	var target: SlotTarget = autofree(SlotTarget.new())
	target.setup("slot_0", Callable())
	assert_true(target._can_drop_data(Vector2.ZERO, {"gizmo": "wind_fan", "from_slot": ""}))
	assert_true(target._can_drop_data(Vector2.ZERO, {"gizmo": "wind_fan", "from_slot": "slot_1"}))
	assert_false(target._can_drop_data(Vector2.ZERO, {"gizmo": ""}))
	assert_false(target._can_drop_data(Vector2.ZERO, "wind_fan"))
	assert_false(target._can_drop_data(Vector2.ZERO, 7))

func test_tray_target_accepts_only_placed_gizmos() -> void:
	var tray: SlotTarget = autofree(SlotTarget.new())
	tray.setup("", Callable())
	assert_false(tray._can_drop_data(Vector2.ZERO, {"gizmo": "wind_fan", "from_slot": ""}),
		"dropping a tray chip back onto the tray is a no-op")
	assert_true(tray._can_drop_data(Vector2.ZERO, {"gizmo": "wind_fan", "from_slot": "slot_0"}),
		"a placed gizmo dragged to the tray is a removal")

func test_drop_delegates_payload_and_slot() -> void:
	var seen: Array = []
	var target: SlotTarget = autofree(SlotTarget.new())
	target.setup("slot_3", func(payload: Dictionary, slot: String) -> void: seen.append([payload, slot]))
	target._drop_data(Vector2.ZERO, {"gizmo": "wind_fan", "from_slot": ""})
	assert_eq(seen, [[{"gizmo": "wind_fan", "from_slot": ""}, "slot_3"]])
```

- [ ] **Step 2: Run to verify failure**

Run: `$GODOT --headless --import` then the single file.
Expected: FAIL (classes do not exist; the script may fail to parse, which is the RED state).

- [ ] **Step 3: Implement**

Create `game/run/gizmo_chip.gd`:

```gdscript
class_name GizmoChip
extends Label
## One draggable gizmo in the setup phase: a tray chip (from_slot == "") or a
## slot token (from_slot == its slot). Dimmed chips are inert; the placed
## gizmo is dragged from its slot token instead.

var gizmo_id := ""
var from_slot := ""
var draggable := true


func setup(id: String, display: String, source_slot: String) -> void:
	gizmo_id = id
	from_slot = source_slot
	text = display
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_dimmed(dimmed: bool) -> void:
	draggable = not dimmed
	modulate.a = 0.4 if dimmed else 1.0


func _get_drag_data(_at: Vector2) -> Variant:
	if not draggable:
		return null
	# set_drag_preview is only legal while the viewport's drag is active
	# (true when the engine calls this hook; false when tests call it
	# directly, where an unguarded call pushes an engine error).
	if is_inside_tree() and get_viewport().gui_is_dragging():
		var preview := Label.new()
		preview.text = text
		set_drag_preview(preview)
	return {"gizmo": gizmo_id, "from_slot": from_slot}
```

Create `game/run/slot_target.gd`:

```gdscript
class_name SlotTarget
extends Control
## Drop target for gizmo drags. A real slot (slot_id "slot_N") accepts any
## gizmo payload and draws its outline; the removal tray (slot_id "") accepts
## only placed gizmos (payloads with a from_slot). All drops delegate to one
## salvage_run callback so every mutation flows through a single function.

var slot_id := ""
var _on_drop: Callable = Callable()


func setup(id: String, on_drop: Callable) -> void:
	slot_id = id
	_on_drop = on_drop
	mouse_filter = Control.MOUSE_FILTER_STOP


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var payload := data as Dictionary
	if String(payload.get("gizmo", "")) == "":
		return false
	if slot_id == "":
		return String(payload.get("from_slot", "")) != ""
	return true


func _drop_data(_at: Vector2, data: Variant) -> void:
	if _on_drop.is_valid():
		_on_drop.call(data as Dictionary, slot_id)


func _draw() -> void:
	if slot_id != "":
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5), false, 2.0)
```

- [ ] **Step 4: Run the file, then the full suite**

Run `$GODOT --headless --import` first; `git status --porcelain` must show no untracked `.gd.uid`. Both runs must pass.

- [ ] **Step 5: Commit**

```bash
git add game/run/gizmo_chip.gd game/run/gizmo_chip.gd.uid game/run/slot_target.gd game/run/slot_target.gd.uid tests/test_setup_controls.gd tests/test_setup_controls.gd.uid
git commit -m "feat: GizmoChip drag source and SlotTarget drop target"
```

---

### Task 3: Run phase machine and fuel-on-Start

**Files:**
- Modify: `game/run/salvage_run.gd`
- Modify: `game/run/salvage_run.tscn`
- Modify: `game/main.gd`
- Test: `tests/test_run_setup.gd` (create), `tests/test_salvage_run.gd` (modify), `tests/test_boon_integration.gd` (modify), `tests/test_gizmo_integration.gd` (modify)

**Interfaces:**
- Consumes: `FuelModel.spend(fuel, amount, now)`, `RegionModel.fuel_cost/entry`, existing `board.install_gizmos`.
- Produces: `salvage_run` phase enum `Phase { SETUP, RUNNING, OVER }` with member `_phase`; member `_region_id: String`; handler `_on_start_pressed()` (spends fuel, installs gizmos, enters RUNNING); handler `_on_setup_back_pressed()` (scene change, NEVER called in tests); `_setup_tick()`; `_on_drop_requested` ignores drops unless RUNNING; `_close_offer` re-enables the controller only in RUNNING; `_on_run_over` sets OVER. tscn nodes `UI/SetupUI` (with `TrayPanel/TrayFlow`, `SlotTargets`, `StartButton`, `BackButton`, `SetupStatus`, `SetupRefreshTimer`). main.gd launch no longer spends fuel. Task 4 fills SlotTargets/TrayFlow; this task leaves them empty but present.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_run_setup.gd`:

```gdscript
extends GutTest
## The setup phase (spec: drag-drop gizmo setup): the scene opens over the
## built board with nothing installed and no fuel spent; Start is the single
## commit point. Scene-changing handlers (Back) are never invoked here.

const RunScene := preload("res://game/run/salvage_run.tscn")
const TEST_SAVE := "user://test_run_setup.json"

var scene


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	GameState.data["created_at"] = 1000
	GameState.data["fuel"]["updated_at"] = 1000
	scene = add_child_autofree(RunScene.instantiate())


func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_run_setup.json", "test_run_setup.json.tmp", "test_run_setup.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings)


func test_scene_opens_in_setup() -> void:
	assert_false(scene.get_node("DropController").enabled, "no aiming during setup")
	assert_true(scene.get_node("UI/SetupUI").visible)
	assert_false(scene.get_node("UI/AbandonButton").visible)
	assert_eq(scene.get_node("Skyfield/Gizmos").get_child_count(), 0,
		"gizmos install at Start, not at boot")
	assert_eq(FuelModel.current(GameState.data["fuel"], TimeUtil.now()), 5,
		"no fuel is spent by entering the scene")
	assert_string_contains(String(scene.get_node("UI/HudLabel").text), "Place your gizmos")

func test_drops_are_ignored_during_setup() -> void:
	var drops_before: int = scene.model.drops_remaining()
	scene._on_drop_requested(360.0)
	assert_eq(scene.model.drops_remaining(), drops_before, "a drop before Start must not consume")
	assert_eq(get_tree().get_nodes_in_group("pods").size(), 0)

func test_start_spends_the_region_cost_once_and_installs() -> void:
	GizmoLoadout.set_slot(GameState.data["gizmos"], "region_1", "slot_0", "wind_fan")
	scene._on_start_pressed()
	assert_eq(FuelModel.current(GameState.data["fuel"], TimeUtil.now()), 4, "region 1 costs 1 fuel")
	assert_eq(scene.get_node("Skyfield/Gizmos").get_child_count(), 1, "the saved loadout installs at Start")
	assert_true(scene.get_node("DropController").enabled)
	assert_false(scene.get_node("UI/SetupUI").visible)
	assert_true(scene.get_node("UI/AbandonButton").visible)
	scene._on_start_pressed()
	assert_eq(FuelModel.current(GameState.data["fuel"], TimeUtil.now()), 4,
		"Start is a one-way gate; a second press spends nothing")

func test_start_persists_the_debit() -> void:
	scene._on_start_pressed()
	var saved := SaveIO.new(TEST_SAVE).read()
	assert_eq(FuelModel.current(saved["fuel"], TimeUtil.now()), 4,
		"an OS kill right after Start must not refund the fuel")

func test_start_without_fuel_stays_in_setup_and_explains() -> void:
	GameState.data["fuel"]["amount"] = 0
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	scene._on_start_pressed()
	assert_false(scene.get_node("DropController").enabled)
	assert_true(scene.get_node("UI/SetupUI").visible)
	assert_eq(scene.get_node("Skyfield/Gizmos").get_child_count(), 0)
	assert_string_contains(String(scene.get_node("UI/SetupUI/SetupStatus").text), "Not enough fuel")

func test_setup_tick_reflects_affordability() -> void:
	scene._setup_tick()
	assert_false(scene.get_node("UI/SetupUI/StartButton").disabled)
	assert_string_contains(String(scene.get_node("UI/SetupUI/StartButton").text), "1 fuel")
	GameState.data["fuel"]["amount"] = 0
	GameState.data["fuel"]["updated_at"] = TimeUtil.now()
	scene._setup_tick()
	assert_true(scene.get_node("UI/SetupUI/StartButton").disabled)

func test_boon_close_never_enables_drops_during_setup() -> void:
	# Unreachable in play (offers need catches), but the phase guard must hold:
	# _close_offer re-enables the controller only while RUNNING.
	scene._close_offer()
	assert_false(scene.get_node("DropController").enabled)

func test_back_button_exists_and_hud_returns_to_normal_after_start() -> void:
	assert_not_null(scene.get_node_or_null("UI/SetupUI/BackButton"))
	scene._on_start_pressed()
	assert_string_contains(String(scene.get_node("UI/HudLabel").text), "Drops left:")
```

Apply these edits to existing tests:

1. `tests/test_salvage_run.gd`, in `before_each`, add after `scene = add_child_autofree(RunScene.instantiate())`:

```gdscript
	scene._on_start_pressed()
```

2. `tests/test_salvage_run.gd`: replace the whole `test_ready_installs_loadout_gizmos` function with:

```gdscript
func test_start_installs_loadout_gizmos() -> void:
	GameState.data["gizmos"]["owned"]["test_gizmo"] = 1
	DataDefs.gizmos["defs"]["test_gizmo"] = {"name": "Test Gizmo", "scene": "res://tests/fixtures/test_gizmo.tscn"}
	GizmoLoadout.set_slot(GameState.data["gizmos"], "region_1", "slot_0", "test_gizmo")
	var second = add_child_autofree(RunScene.instantiate())
	assert_eq(second.get_node("Skyfield/Gizmos").get_child_count(), 0,
		"nothing installs at boot; placement is still editable")
	second._on_start_pressed()
	assert_eq(second.get_node("Skyfield/Gizmos").get_child_count(), 1,
		"the run scene installs the persisted loadout at Start")
	DataDefs.gizmos["defs"].erase("test_gizmo")
```

3. `tests/test_boon_integration.gd`, in `before_each`, add after `scene = add_child_autofree(RunScene.instantiate())` (before the rng seed line):

```gdscript
	scene._on_start_pressed()
```

4. `tests/test_gizmo_integration.gd`: in `test_splitter_through_the_real_scene_credits_two_half_pods` and `test_splitter_splits_on_real_contact_without_errors`, add directly after each `var scene = add_child_autofree(preload("res://game/run/salvage_run.tscn").instantiate())` line:

```gdscript
	scene._on_start_pressed()
```

(In the second test, keep the vane creation lines after the start call, exactly where they are relative to `_on_drop_requested`.)

- [ ] **Step 2: Run to verify failure**

Run: `$GODOT --headless --import` then `-gtest=res://tests/test_run_setup.gd`.
Expected: FAIL (no SetupUI node, no `_on_start_pressed`).

- [ ] **Step 3: Add the tscn nodes**

In `game/run/salvage_run.tscn`, append at the end:

```
[node name="SetupUI" type="Control" parent="UI"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2

[node name="SlotTargets" type="Control" parent="UI/SetupUI"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2

[node name="TrayPanel" type="PanelContainer" parent="UI/SetupUI"]
offset_left = 10.0
offset_top = 930.0
offset_right = 710.0
offset_bottom = 1120.0

[node name="TrayFlow" type="HFlowContainer" parent="UI/SetupUI/TrayPanel"]

[node name="StartButton" type="Button" parent="UI/SetupUI"]
offset_left = 380.0
offset_top = 1140.0
offset_right = 700.0
offset_bottom = 1210.0
text = "Start"

[node name="BackButton" type="Button" parent="UI/SetupUI"]
offset_left = 20.0
offset_top = 1140.0
offset_right = 340.0
offset_bottom = 1210.0
text = "Back"

[node name="SetupStatus" type="Label" parent="UI/SetupUI"]
offset_left = 20.0
offset_top = 1220.0
offset_right = 700.0
offset_bottom = 1260.0

[node name="SetupRefreshTimer" type="Timer" parent="UI/SetupUI"]
wait_time = 1.0
autostart = true
```

- [ ] **Step 4: Implement the phase machine**

In `game/run/salvage_run.gd`:

1. Replace the file's doc comment (lines 2-5) with:

```gdscript
## Glue for one expedition: a SETUP phase over the built board (drag gizmos
## into slots, fuel unspent), then Start spends fuel, installs gizmos, and
## runs the drops. Loot is credited per catch, so abandoning or being killed
## by the OS never loses anything (spec 3.2; fuel-on-Start amended by the
## 2026-08-23 drag-drop setup spec).
```

2. Add after `var _island_mult := 1.0`:

```gdscript
enum Phase { SETUP, RUNNING, OVER }
var _phase := Phase.SETUP
var _region_id := ""
```

3. In `_ready()`:
   - Replace `var region_id := RegionModel.selected_id(...)` and the two lines using `region_id` so the id persists on the member. The lines

```gdscript
	var region_id := RegionModel.selected_id(GameState.data, run_defs, GameState.data["island"])
	var region: Dictionary = DataDefs.skyfield(region_id)
```

   become:

```gdscript
	_region_id = RegionModel.selected_id(GameState.data, run_defs, GameState.data["island"])
	var region: Dictionary = DataDefs.skyfield(_region_id)
```

   - DELETE the entire `board.install_gizmos(...)` call and the `var gizmos_state: Dictionary = GameState.data["gizmos"]` line above it (installation moves to Start).
   - Add before the final `_refresh_hud()` line:

```gdscript
	controller.enabled = false
	$UI/AbandonButton.visible = false
	$UI/SetupUI/StartButton.pressed.connect(_on_start_pressed)
	$UI/SetupUI/BackButton.pressed.connect(_on_setup_back_pressed)
	$UI/SetupUI/SetupRefreshTimer.timeout.connect(_setup_tick)
	_setup_tick()
```

4. Add the phase guard as the first lines of `_on_drop_requested`:

```gdscript
	if _phase != Phase.RUNNING:
		return
```

5. Add after `_on_return_pressed`:

```gdscript
func _on_start_pressed() -> void:
	# The single commit point (spec: fuel-on-Start). Back before this is free.
	if _phase != Phase.SETUP:
		return
	var cost := RegionModel.fuel_cost(RegionModel.entry(DataDefs.run, _region_id), GameState.data["island"])
	if not FuelModel.spend(GameState.data["fuel"], cost, TimeUtil.now()):
		$UI/SetupUI/SetupStatus.text = "Not enough fuel."
		return
	GameState.save_game()
	var gizmos_state: Dictionary = GameState.data["gizmos"]
	board.install_gizmos(
		GizmoLoadout.loadout_for(gizmos_state, _region_id),
		DataDefs.gizmos,
		GizmoLoadout.owned(gizmos_state),
		self)
	_phase = Phase.RUNNING
	$UI/SetupUI.visible = false
	$UI/AbandonButton.visible = true
	controller.enabled = true
	_refresh_hud()


func _on_setup_back_pressed() -> void:
	# Free exit: nothing was spent, placements already saved per drop.
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/main.tscn")


func _setup_tick() -> void:
	if _phase != Phase.SETUP:
		return
	var cost := RegionModel.fuel_cost(RegionModel.entry(DataDefs.run, _region_id), GameState.data["island"])
	$UI/SetupUI/StartButton.text = "Start (%d fuel)" % cost
	$UI/SetupUI/StartButton.disabled = FuelModel.current(GameState.data["fuel"], TimeUtil.now()) < cost
```

6. In `_on_run_over`, add as the first line:

```gdscript
	_phase = Phase.OVER
```

7. In `_close_offer`, change the final block

```gdscript
	if not model.is_over():
		controller.enabled = true
```

   to:

```gdscript
	if not model.is_over() and _phase == Phase.RUNNING:
		controller.enabled = true
```

8. In `_refresh_hud`, add as the first lines:

```gdscript
	if _phase == Phase.SETUP:
		$UI/HudLabel.text = "Place your gizmos, then press Start."
		return
```

9. In `game/main.gd`, replace `_on_launch_pressed` with:

```gdscript
func _on_launch_pressed() -> void:
	# Fuel is spent by the run scene's Start button now (drag-drop setup
	# spec); this button only gates on affordability via _refresh.
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/run/salvage_run.tscn")
```

(Do NOT touch the Gizmos button here; that is Task 5.)

- [ ] **Step 5: Run the affected files, then the full suite**

Run `-gtest=` for: test_run_setup.gd, test_salvage_run.gd, test_boon_integration.gd, test_gizmo_integration.gd, test_islet_integration.gd (unchanged file, but its scene use must still pass), test_main_boot.gd. Then the full suite; must exit 0.

- [ ] **Step 6: Commit**

```bash
git add game/run/salvage_run.gd game/run/salvage_run.tscn game/main.gd tests/test_run_setup.gd tests/test_run_setup.gd.uid tests/test_salvage_run.gd tests/test_boon_integration.gd tests/test_gizmo_integration.gd
git commit -m "feat: run setup phase with fuel spent on Start"
```

---

### Task 4: Drag placement UI

**Files:**
- Modify: `game/run/salvage_run.gd`
- Test: `tests/test_run_setup.gd` (modify)

**Interfaces:**
- Consumes: `GizmoChip`/`SlotTarget` (Task 2), `GizmoLoadout.place` (Task 1), tscn nodes (Task 3).
- Produces: `_build_setup_ui(region)` called from `_ready`; `_refresh_setup_ui()`; `_on_gizmo_dropped(payload: Dictionary, slot: String)` (the single mutation callback; `slot == ""` removes `payload.from_slot`); `_chip_text(gizmo_id)`. The tray panel becomes a `SlotTarget` via `set_script` at build time.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_run_setup.gd`:

```gdscript
func slot_target(index: int) -> SlotTarget:
	return scene.get_node("UI/SetupUI/SlotTargets").get_child(index) as SlotTarget


func tray_chips() -> Array:
	return scene.get_node("UI/SetupUI/TrayPanel/TrayFlow").get_children()


func chip_for(gizmo_id: String) -> GizmoChip:
	for chip in tray_chips():
		if (chip as GizmoChip).gizmo_id == gizmo_id:
			return chip as GizmoChip
	return null


func test_setup_builds_a_target_per_slot_and_a_chip_per_owned() -> void:
	var region: Dictionary = DataDefs.skyfield("region_1")
	assert_eq(scene.get_node("UI/SetupUI/SlotTargets").get_child_count(),
		(region.get("gizmo_slots", []) as Array).size())
	assert_eq(tray_chips().size(), (GameState.data["gizmos"]["owned"] as Dictionary).size(),
		"every owned gizmo shows in the tray")
	assert_eq(slot_target(0).slot_id, "slot_0")

func test_slot_targets_sit_on_the_slot_coordinates() -> void:
	var slots: Array = DataDefs.skyfield("region_1").get("gizmo_slots", [])
	var first := slot_target(0)
	assert_almost_eq(first.position.x + first.size.x / 2.0, float((slots[0] as Dictionary)["x"]), 0.5)
	assert_almost_eq(first.position.y + first.size.y / 2.0, float((slots[0] as Dictionary)["y"]), 0.5)

func test_drop_from_tray_places_saves_and_dims() -> void:
	scene._on_gizmo_dropped({"gizmo": "wind_fan", "from_slot": ""}, "slot_0")
	assert_eq(GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1"), {"slot_0": "wind_fan"})
	assert_false(chip_for("wind_fan").draggable, "the placed gizmo's tray chip dims")
	assert_eq(slot_target(0).get_child_count(), 1, "the slot shows a token")
	var saved := SaveIO.new(TEST_SAVE).read()
	assert_eq((saved["gizmos"]["loadout"] as Dictionary).get("region_1"), {"slot_0": "wind_fan"},
		"every drop persists immediately")

func test_drop_onto_occupied_slot_returns_the_displaced_to_the_tray() -> void:
	scene._on_gizmo_dropped({"gizmo": "wind_fan", "from_slot": ""}, "slot_0")
	scene._on_gizmo_dropped({"gizmo": "balloon_cluster", "from_slot": ""}, "slot_0")
	assert_eq(GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1"), {"slot_0": "balloon_cluster"})
	assert_true(chip_for("wind_fan").draggable, "the displaced gizmo un-dims")

func test_slot_to_slot_move_via_token_payload() -> void:
	scene._on_gizmo_dropped({"gizmo": "wind_fan", "from_slot": ""}, "slot_0")
	scene._on_gizmo_dropped({"gizmo": "wind_fan", "from_slot": "slot_0"}, "slot_1")
	assert_eq(GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1"), {"slot_1": "wind_fan"})
	assert_eq(slot_target(0).get_child_count(), 0)
	assert_eq(slot_target(1).get_child_count(), 1)

func test_drop_on_tray_removes() -> void:
	scene._on_gizmo_dropped({"gizmo": "wind_fan", "from_slot": ""}, "slot_0")
	scene._on_gizmo_dropped({"gizmo": "wind_fan", "from_slot": "slot_0"}, "")
	assert_eq(GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1"), {})
	assert_true(chip_for("wind_fan").draggable)

func test_unowned_drop_is_rejected() -> void:
	scene._on_gizmo_dropped({"gizmo": "not_owned_gizmo", "from_slot": ""}, "slot_0")
	assert_eq(GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1"), {})

func test_drops_after_start_are_ignored() -> void:
	scene._on_start_pressed()
	scene._on_gizmo_dropped({"gizmo": "wind_fan", "from_slot": ""}, "slot_0")
	assert_eq(GizmoLoadout.loadout_for(GameState.data["gizmos"], "region_1"), {},
		"placement is frozen once the run begins")

func test_tray_panel_is_the_removal_target() -> void:
	var tray: SlotTarget = scene.get_node("UI/SetupUI/TrayPanel") as SlotTarget
	assert_not_null(tray, "the tray panel carries the SlotTarget script")
	assert_eq(tray.slot_id, "")

func test_slot_token_carries_its_source_slot() -> void:
	scene._on_gizmo_dropped({"gizmo": "wind_fan", "from_slot": ""}, "slot_2")
	var token := slot_target(2).get_child(0) as GizmoChip
	assert_eq(token._get_drag_data(Vector2.ZERO), {"gizmo": "wind_fan", "from_slot": "slot_2"})

func test_saved_loadout_prefills_the_board() -> void:
	GizmoLoadout.set_slot(GameState.data["gizmos"], "region_1", "slot_3", "chime_bell")
	var second = add_child_autofree(RunScene.instantiate())
	var target := second.get_node("UI/SetupUI/SlotTargets").get_child(3) as SlotTarget
	assert_eq(target.get_child_count(), 1, "setup opens pre-filled with the region's last placement")
```

- [ ] **Step 2: Run to verify failure**

Run: `-gtest=res://tests/test_run_setup.gd`. Expected: FAIL (no `_on_gizmo_dropped`, empty SlotTargets).

- [ ] **Step 3: Implement**

In `game/run/salvage_run.gd`:

1. Add a preload with the other const at the top:

```gdscript
const SlotTargetScript := preload("res://game/run/slot_target.gd")
```

2. In `_ready()`, add directly after the `_setup_tick()` line added in Task 3:

```gdscript
	_build_setup_ui(region)
```

3. Add after `_setup_tick`:

```gdscript
func _build_setup_ui(region: Dictionary) -> void:
	var slots: Array = region.get("gizmo_slots", [])
	for i in slots.size():
		var target := SlotTarget.new()
		var center := Vector2(float((slots[i] as Dictionary)["x"]), float((slots[i] as Dictionary)["y"]))
		target.position = center - Vector2(48.0, 48.0)
		target.size = Vector2(96.0, 96.0)
		target.setup("slot_%d" % i, _on_gizmo_dropped)
		$UI/SetupUI/SlotTargets.add_child(target)
	# The tray panel doubles as the removal target: same script, empty slot id,
	# so a token dragged home falls through Godot's ancestor walk onto it.
	$UI/SetupUI/TrayPanel.set_script(SlotTargetScript)
	($UI/SetupUI/TrayPanel as SlotTarget).setup("", _on_gizmo_dropped)
	_refresh_setup_ui()


func _on_gizmo_dropped(payload: Dictionary, slot: String) -> void:
	# The single mutation path for every drag (spec: one callback). slot ""
	# is the tray: remove the gizmo from the slot it came from.
	if _phase != Phase.SETUP:
		return
	var gizmos_state: Dictionary = GameState.data["gizmos"]
	if slot == "":
		var from_slot := String(payload.get("from_slot", ""))
		if from_slot == "":
			return
		GizmoLoadout.set_slot(gizmos_state, _region_id, from_slot, "")
	elif not GizmoLoadout.place(gizmos_state, _region_id, slot, String(payload.get("gizmo", ""))):
		return
	# Persist per drop: Android may kill the app at any moment (save-anywhere).
	GameState.save_game()
	_refresh_setup_ui()


func _refresh_setup_ui() -> void:
	var gizmos_state: Dictionary = GameState.data["gizmos"]
	var loadout := GizmoLoadout.loadout_for(gizmos_state, _region_id)
	var placed: Array = loadout.values()
	for target_node in $UI/SetupUI/SlotTargets.get_children():
		var target := target_node as SlotTarget
		for child in target.get_children():
			target.remove_child(child)
			child.queue_free()
		var held := String(loadout.get(target.slot_id, ""))
		if held != "":
			var token := GizmoChip.new()
			token.setup(held, _chip_text(held), target.slot_id)
			token.set_anchors_preset(Control.PRESET_FULL_RECT)
			target.add_child(token)
	var flow: HFlowContainer = $UI/SetupUI/TrayPanel/TrayFlow
	for child in flow.get_children():
		flow.remove_child(child)
		child.queue_free()
	for id in GizmoLoadout.owned(gizmos_state):
		var chip := GizmoChip.new()
		chip.setup(String(id), _chip_text(String(id)), "")
		chip.custom_minimum_size = Vector2(164.0, 56.0)
		chip.set_dimmed(placed.has(id))
		flow.add_child(chip)


func _chip_text(gizmo_id: String) -> String:
	var def: Dictionary = (DataDefs.gizmos.get("defs", {}) as Dictionary).get(gizmo_id, {})
	var level := int(GizmoLoadout.owned(GameState.data["gizmos"]).get(gizmo_id, 1))
	return "%s\nLv %d" % [String(def.get("name", gizmo_id)), level]
```

Note on `set_script`: attaching a script to a live node resets its `script`-declared members but not its node properties; `setup("", ...)` is called immediately after, which restores the contract. The alternative (a scripted tscn node) needs an ext_resource edit; this keeps all SlotTarget knowledge in one function.

- [ ] **Step 4: Run the file, then the full suite**

`-gtest=res://tests/test_run_setup.gd`, then the full suite; both must pass.

- [ ] **Step 5: Commit**

```bash
git add game/run/salvage_run.gd tests/test_run_setup.gd
git commit -m "feat: drag-and-drop gizmo placement in the setup phase"
```

---

### Task 5: Retire the loadout screen

**Files:**
- Delete: `game/ui/loadout_screen.gd`, `game/ui/loadout_screen.gd.uid`, `game/ui/loadout_screen.tscn`, `tests/test_loadout_screen.gd`, `tests/test_loadout_screen.gd.uid`
- Modify: `game/main.gd`, `game/main.tscn`, `game/run/gizmo_loadout.gd`, `tests/test_gizmo_loadout.gd`, `tests/test_main_boot.gd`, `docs/design/2026-08-15-windfall-isles-design.md`

**Interfaces:**
- Consumes: Tasks 3-4 (the replacement flow must already work).
- Produces: no references to `loadout_screen`, `GizmosButton`, or `next_choice` anywhere; a design-doc errata line.

- [ ] **Step 1: Write the failing test**

In `tests/test_main_boot.gd`, replace the whole `test_gizmos_button_exists` function with:

```gdscript
func test_gizmos_button_is_gone() -> void:
	assert_null(main.get_node_or_null("GizmosButton"),
		"placement lives in the run scene's setup phase now")
```

- [ ] **Step 2: Run to verify failure**

Run: `-gtest=res://tests/test_main_boot.gd`. Expected: FAIL (the button still exists).

- [ ] **Step 3: Delete and detach**

1. `git rm game/ui/loadout_screen.gd game/ui/loadout_screen.gd.uid game/ui/loadout_screen.tscn tests/test_loadout_screen.gd tests/test_loadout_screen.gd.uid` (run as separate `git rm` commands if the sandbox rejects the multi-path form; `game/ui/` disappears with its last file).
2. In `game/main.gd`: delete the line `$GizmosButton.pressed.connect(_on_gizmos_pressed)` and the whole `_on_gizmos_pressed` function.
3. In `game/main.tscn`: delete the `GizmosButton` node block (the `[node name="GizmosButton" ...]` header and its offset/text lines, up to the next `[node` header).
4. In `game/run/gizmo_loadout.gd`: delete the whole `next_choice` function (its only caller died with the screen; the cycling rule was the old UI's logic).
5. In `tests/test_gizmo_loadout.gd`: delete the whole `test_next_choice_cycles_and_skips_used` function.
6. In `docs/design/2026-08-15-windfall-isles-design.md`, find the spec 3.2 step-1 sentence stating fuel is spent before the run scene loads and append this sentence directly after it, same paragraph:

```
(Amended 2026-08-24 by the drag-drop gizmo setup spec: fuel is now spent by the Start button inside the run scene's setup phase; the launcher still gates on affordability, and backing out of setup costs nothing.)
```

If the exact sentence is worded differently than expected, place the parenthetical after whichever sentence in section 3.2 states the launch-time fuel spend, and report the actual anchor in your report.

- [ ] **Step 4: Verify no dangling references, run the suite**

Run: `grep -rn "loadout_screen" game tests project.godot export_presets.cfg` and `grep -rn "GizmosButton\|next_choice" game tests`. Both must return nothing. Run `$GODOT --headless --import`, confirm `git status --porcelain` shows only the intended deletions/modifications, then run the full suite; must exit 0.

- [ ] **Step 5: Commit**

```bash
git add -A game/ui game/main.gd game/main.tscn game/run/gizmo_loadout.gd tests/test_gizmo_loadout.gd tests/test_main_boot.gd tests/test_loadout_screen.gd tests/test_loadout_screen.gd.uid docs/design/2026-08-15-windfall-isles-design.md
git commit -m "feat: retire the loadout screen; placement lives in run setup"
```

---

## Manual smoke steps (waived in the non-interactive environment, listed for the on-device pass)

1. Launch an expedition: the board appears with outlined slots, the tray shows every owned gizmo, no fuel was deducted.
2. Drag a gizmo onto a slot, another onto an occupied slot (displaced returns to tray), one between slots, one back to the tray. Each feels responsive under touch; the drag preview is legible.
3. Back out to main: fuel untouched. Relaunch: placements exactly as left.
4. Start: fuel drops by the region cost, gizmos appear at their slots, drops work, boon offers still pause and resume drops.
5. Region 2: slot outlines remain visible against the gear rings and drift haze.
