# Windfall Isles Plan 15: Island Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the island screen's text-row menu with a vertically scrollable island map where buildings, islets and crew live at authored positions and are tapped directly.

**Architecture:** Pure presentation rework: every rule stays in IslandModel/IsletModel/CrewModel/ConvertModel/TimerService and every existing handler keeps its name and signature. A new `island_layout.json` carries all map coordinates; new Button-derived map nodes (plot pad, islet, crew token) render state dictionaries the screen computes; a code-drawn backdrop stands in for the vista art; a bottom PlotSheet overlay carries the per-building actions the old rows held inline. The signature-gated refresh discipline carries over unchanged.

**Tech Stack:** Godot 4 GDScript (plain `godot`, 4.7.1, with the vendored GUT 9.6.1), JSON data files.

**Spec:** docs/superpowers/specs/2026-10-11-island-map-design.md

## Global Constraints

- Test command (run from the repo root, ONE plain command at a time; the sandbox rejects compound commands): first `godot --headless --import`, then `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.
- After any `--import`, run `git status --porcelain` and commit every new `.gd.uid` sidecar, including for TEST files (recurring pitfall, bitten twice).
- Tabs for indentation. Typed GDScript; warnings are errors: cast `Dictionary.get` results with `String(...)`/`int(...)`/`float(...)` before `:=` inference; never infer types from untyped Array chains.
- JSON numbers all parse as float; int-cast or float-cast every scalar read from JSON in both code and tests.
- All layout/balance numbers live in JSON data files, never in scripts (design spec 7.2).
- Detach-then-free when clearing rebuilt containers: `container.remove_child(child)` then `child.queue_free()` (Plans 8/9/13 precedent).
- Every child of a tappable Button sets `mouse_filter = Control.MOUSE_FILTER_IGNORE` (repo input-walk lesson from Plans 9/12).
- GUT 9.6: stubs use `context_stub`; `assert_signal_emitted_with_parameters` takes NO message argument; error-path tests declare `assert_push_error_count`/`assert_engine_error_count`.
- Never write cumulative suite totals anywhere; list only each task's new tests.
- No em dashes in any authored text (code comments, docs, commit messages).
- Keep these island_screen handler names and signatures untouched; tests pin them: `_open_build_modal(plot)`, `_modal_building()`, `_on_modal_prev_pressed()`, `_on_modal_next_pressed()`, `_on_modal_confirm_pressed()`, `_on_modal_cancel_pressed()`, `_on_collect_pressed(plot)`, `_on_skip_pressed(timer_id)`, `_grant_skip(timer_id)`, `_on_restore_pressed(islet_id)`, `_on_restore_collect_pressed(islet_id)`, `_on_read_letter_pressed(islet_id)`, `_on_letter_close_pressed()`, `_on_assign_pressed(crew_id)`, `_on_batch_start_pressed(building_id, recipe_id)`, `_on_batch_collect_pressed(building_id)`, `_on_gardens_pressed()`, `_on_crate_pressed()`, `_on_slot_pressed()`, `_on_bonus_crate_pressed()`, `_grant_bonus_crate()`, `_refresh_tick()`, `_rebuild()`, `_signature(now)`, `_islet_state(islet_id, now)`, `_stats_text(building_id, def)`, `_batch_button_text(building_id, recipe_id)`, `_unbuilt_ids(plot)`, `_plot_ids()`.
- The six HUD buttons and StatusLabel keep their node names as DIRECT children of IslandScreen (`$GardensButton`, `$CrateButton`, `$BonusCrateButton`, `$SlotButton`, `$WorkshopButton`, `$BackButton`, `$StatusLabel`); only their offsets change. BuildModal and LetterPanel subtrees keep every node path byte-identical.

## Review Focus

Failure modes the spec implies that need pinning tests (each is assigned to a task below):

1. A plot id with no entry in `island_layout.json` must render at a safe fallback position instead of crashing (Task 5: `test_unknown_plot_position_falls_back_to_origin_without_crashing`).
2. A plot with BOTH a done construction and a done batch must collect the construction on the first tap and keep the batch for the next (Task 5: `test_construction_done_outranks_batch_done_on_one_tap`).
3. Map taps must not leak through an open modal, letter, or sheet; a full-screen blocker shades and swallows them (Task 5: `test_modal_block_shades_the_map_behind_overlays`).
4. A sheet left open while its batch finishes must re-render to offer Collect on the next tick (Task 6: `test_sheet_rerenders_to_collect_when_the_batch_finishes`).
5. Tapping a locked islet must be a silent no-op, never a spend and never a StatusLabel complaint (Task 5: `test_islet_tap_is_a_noop_while_locked`).

---

### Task 1: island_layout.json and DataDefs loading

**Files:**
- Create: `game/data/island_layout.json`
- Modify: `game/autoload/data_defs.gd`
- Test: `tests/test_island_layout_defs.gd` (create)

**Interfaces:**
- Consumes: `DataDefs.buildings["plot_count"]`, `IsletModel.islets(defs) -> Array` of Dictionaries with `id` and `plots` keys.
- Produces: `DataDefs.island_layout: Dictionary` with keys `map_size: [w, h]`, `plot_size: float`, `plots: {plot_id: [x, y]}` (node centers), `islets: {islet_id: {pos: [x, y], bridge: [[x, y], [x, y]]}}`, `crew_band: {y, start_x, spacing}`. Tasks 5 reads all of these.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_island_layout_defs.gd`:

```gdscript
extends GutTest
## island_layout.json authoring guards: every plot the game can open must
## have a map position, positions must fit the map, and pads must not crowd.


func layout() -> Dictionary:
	return DataDefs.island_layout


func test_layout_file_loads() -> void:
	assert_false(layout().is_empty(), "island_layout.json exists and parses")


func test_every_plot_id_has_a_position() -> void:
	var positions: Dictionary = layout()["plots"]
	for i in int(DataDefs.buildings["plot_count"]):
		assert_true(positions.has("plot_%d" % i), "home plot_%d has a map position" % i)
	for islet_v in IsletModel.islets(DataDefs.islets):
		for plot in (islet_v as Dictionary).get("plots", []):
			assert_true(positions.has(String(plot)), "islet plot %s has a map position" % String(plot))


func test_positions_fit_the_map_with_a_half_pad_margin() -> void:
	var map_size: Array = layout()["map_size"]
	var half := float(layout()["plot_size"]) / 2.0
	for plot in layout()["plots"]:
		var pos: Array = (layout()["plots"] as Dictionary)[plot]
		assert_between(float(pos[0]), half, float(map_size[0]) - half, "%s x inside the map" % String(plot))
		assert_between(float(pos[1]), half, float(map_size[1]) - half, "%s y inside the map" % String(plot))


func test_no_two_pads_crowd_each_other() -> void:
	var positions: Dictionary = layout()["plots"]
	var ids: Array = positions.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: Array = positions[ids[i]]
			var b: Array = positions[ids[j]]
			var dist := Vector2(float(a[0]), float(a[1])).distance_to(Vector2(float(b[0]), float(b[1])))
			assert_true(dist >= 150.0, "%s and %s are %d px apart (need 150)" % [String(ids[i]), String(ids[j]), int(dist)])


func test_every_islet_has_a_pos_and_a_two_point_bridge() -> void:
	var islets_layout: Dictionary = layout()["islets"]
	for islet_v in IsletModel.islets(DataDefs.islets):
		var islet_id := String((islet_v as Dictionary).get("id", ""))
		assert_true(islets_layout.has(islet_id), "%s has a layout entry" % islet_id)
		var entry: Dictionary = islets_layout[islet_id]
		assert_eq((entry.get("pos", []) as Array).size(), 2, "%s pos is [x, y]" % islet_id)
		var bridge: Array = entry.get("bridge", [])
		assert_eq(bridge.size(), 2, "%s bridge has two endpoints" % islet_id)
		for point_v in bridge:
			assert_eq((point_v as Array).size(), 2, "%s bridge point is [x, y]" % islet_id)


func test_crew_band_fits_the_whole_cast_on_screen() -> void:
	var band: Dictionary = layout()["crew_band"]
	var count := CrewModel.members(DataDefs.crew).size()
	var last_center := float(band["start_x"]) + float(band["spacing"]) * float(count - 1)
	assert_true(last_center + 36.0 <= float((layout()["map_size"] as Array)[0]),
		"the last crew token stays inside the map width")
```

- [ ] **Step 2: Run the new file to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_island_layout_defs.gd -gexit`
Expected: FAIL (DataDefs has no `island_layout` property).

- [ ] **Step 3: Create the data file**

Create `game/data/island_layout.json`:

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

- [ ] **Step 4: Load it in DataDefs**

In `game/autoload/data_defs.gd`, add below `const CREW_PATH := "res://game/data/crew.json"`:

```gdscript
const ISLAND_LAYOUT_PATH := "res://game/data/island_layout.json"
```

Add below `var crew: Dictionary = {}`:

```gdscript
var island_layout: Dictionary = {}
```

Add at the end of `_ready()`:

```gdscript
	island_layout = load_json(ISLAND_LAYOUT_PATH)
```

- [ ] **Step 5: Run the new file to verify it passes**

Run: `godot --headless --import`
Then: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_island_layout_defs.gd -gexit`
Expected: PASS (6 tests).

- [ ] **Step 6: Check for new .gd.uid sidecars and commit**

Run: `git status --porcelain`
Stage any new `tests/test_island_layout_defs.gd.uid` alongside the sources.

```bash
git add game/data/island_layout.json game/autoload/data_defs.gd tests/test_island_layout_defs.gd tests/test_island_layout_defs.gd.uid
git commit -m "feat: island map layout data and authoring guards (plan 15 task 1)"
```

---

### Task 2: IslandPlotNode

**Files:**
- Create: `game/base/plot_node.gd`
- Test: `tests/test_plot_node.gd` (create)

**Interfaces:**
- Consumes: nothing from other tasks (delivered art paths only).
- Produces: `IslandPlotNode` (extends Button), `IslandPlotNode.new(plot_id: String)`, signal `plot_tapped(plot_id: String)`, method `render(state: Dictionary)` where state keys are `kind` ("empty"/"constructing"/"built"), `art` (String path), `name` (String), `status` (String), `ready` (bool), `worker_portrait` (String path, optional). Internal children `_art`, `_overlay`, `_name_label`, `_status_label`, `_worker_badge`, `_ready_badge` are poked by tests. `custom_minimum_size` is `Vector2(128, 172)`. Task 5 positions nodes by `center - node.custom_minimum_size / 2.0`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_plot_node.gd`:

```gdscript
extends GutTest
## IslandPlotNode is pure presentation: feed it a state dictionary, check
## what it shows. Every rule lives in the models, none in here.


func make_node(id := "plot_0") -> IslandPlotNode:
	var node := IslandPlotNode.new(id)
	add_child_autofree(node)
	return node


func test_empty_state_invites_building() -> void:
	var node := make_node()
	node.render({"kind": "empty", "name": "(empty)", "status": "Tap to build", "ready": false})
	assert_eq(node._name_label.text, "(empty)")
	assert_eq(node._status_label.text, "Tap to build")
	assert_false(node._overlay.visible)
	assert_false(node._worker_badge.visible)
	assert_false(node._ready_badge.visible)


func test_constructing_state_dims_art_and_shows_the_scaffold() -> void:
	var node := make_node()
	node.render({"kind": "constructing", "art": "res://game/art/buildings/workshop.png",
		"name": "Workshop", "status": "42s", "ready": false})
	assert_not_null(node._art.texture, "the building art shows while it builds")
	assert_almost_eq(node._art.modulate.a, 0.5, 0.01, "constructing art dims")
	assert_true(node._overlay.visible, "construction_overlay.png is wired at last (audit 4.2)")


func test_ready_state_shows_the_badge() -> void:
	var node := make_node()
	node.render({"kind": "constructing", "art": "res://game/art/buildings/workshop.png",
		"name": "Workshop", "status": "Tap to collect!", "ready": true})
	assert_true(node._ready_badge.visible)


func test_built_state_shows_the_worker_badge() -> void:
	var node := make_node()
	node.render({"kind": "built", "art": "res://game/art/buildings/gardens.png",
		"name": "Gardens Lv 1", "status": "", "ready": false,
		"worker_portrait": "res://game/art/crew/odo.png"})
	assert_true(node._worker_badge.visible)
	assert_not_null(node._worker_badge.texture)
	assert_almost_eq(node._art.modulate.a, 1.0, 0.01, "built art shows at full strength")


func test_missing_art_keeps_the_node_alive() -> void:
	var node := make_node()
	node.render({"kind": "built", "art": "res://game/art/buildings/not_a_building.png",
		"name": "Mystery", "status": "", "ready": false})
	assert_null(node._art.texture, "missing art falls back to no texture, no crash")


func test_tap_emits_the_plot_id() -> void:
	var node := make_node("plot_3")
	watch_signals(node)
	node.pressed.emit()
	assert_signal_emitted_with_parameters(node, "plot_tapped", ["plot_3"])


func test_children_never_block_the_tap() -> void:
	var node := make_node()
	for child in node.get_children():
		assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"repo lesson: children of a tappable Button must ignore the mouse")
```

- [ ] **Step 2: Run the new file to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_plot_node.gd -gexit`
Expected: FAIL (IslandPlotNode does not exist; script parse errors count).

- [ ] **Step 3: Implement the node**

Create `game/base/plot_node.gd`:

```gdscript
extends Button
class_name IslandPlotNode
## One tappable building pad on the island map. Pure presentation: the
## island screen computes a state dictionary from the models and this node
## only renders it. Children all ignore the mouse so the Button receives
## every tap (repo lesson: never block the input walk with child filters).

signal plot_tapped(plot_id: String)

const PAD_ART := "res://game/art/buildings/plot_pad.png"
const OVERLAY_ART := "res://game/art/buildings/construction_overlay.png"
const PLOT_SIZE := 128.0

var plot_id := ""
var _empty := true

var _art: TextureRect
var _overlay: TextureRect
var _name_label: Label
var _status_label: Label
var _worker_badge: TextureRect
var _ready_badge: Label


func _init(id: String) -> void:
	plot_id = id
	flat = true
	custom_minimum_size = Vector2(PLOT_SIZE, PLOT_SIZE + 44.0)
	size = custom_minimum_size
	pressed.connect(func() -> void: plot_tapped.emit(plot_id))
	_art = _child_texture_rect(Rect2(16, 4, 96, 96))
	_overlay = _child_texture_rect(Rect2(16, 4, 96, 96))
	if ResourceLoader.exists(OVERLAY_ART):
		_overlay.texture = load(OVERLAY_ART)
	_overlay.visible = false
	_worker_badge = _child_texture_rect(Rect2(92, 68, 32, 32))
	_worker_badge.visible = false
	_name_label = _child_label(Rect2(0, 100, 128, 22), 13)
	_status_label = _child_label(Rect2(0, 122, 128, 20), 12)
	_status_label.modulate.a = 0.85
	_ready_badge = _child_label(Rect2(96, 0, 28, 28), 26)
	_ready_badge.text = "!"
	_ready_badge.modulate = Color(1.0, 0.85, 0.2)
	_ready_badge.visible = false


func render(state: Dictionary) -> void:
	var kind := String(state.get("kind", "empty"))
	_empty = kind == "empty"
	var art_path := String(state.get("art", ""))
	if _empty:
		art_path = PAD_ART
	if art_path != "" and ResourceLoader.exists(art_path):
		_art.texture = load(art_path)
	else:
		_art.texture = null
	_art.modulate.a = 0.5 if kind == "constructing" else 1.0
	_overlay.visible = kind == "constructing" and _overlay.texture != null
	_name_label.text = String(state.get("name", ""))
	_status_label.text = String(state.get("status", ""))
	var worker_path := String(state.get("worker_portrait", ""))
	if worker_path != "" and ResourceLoader.exists(worker_path):
		_worker_badge.texture = load(worker_path)
		_worker_badge.visible = true
	else:
		_worker_badge.texture = null
		_worker_badge.visible = false
	_ready_badge.visible = bool(state.get("ready", false))
	queue_redraw()


func _draw() -> void:
	# Pad-art fallback: an empty plot with no delivered pad sprite still
	# reads as a build site.
	if _empty and _art.texture == null:
		draw_rect(Rect2(18, 6, 92, 92), Color(1, 1, 1, 0.5), false, 2.0)


func _child_texture_rect(rect: Rect2) -> TextureRect:
	var tr := TextureRect.new()
	tr.position = rect.position
	tr.size = rect.size
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	return tr


func _child_label(rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
```

- [ ] **Step 4: Run the new file to verify it passes**

Run: `godot --headless --import`
Then: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_plot_node.gd -gexit`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit (including .gd.uid sidecars)**

Run: `git status --porcelain` and stage every new sidecar.

```bash
git add game/base/plot_node.gd game/base/plot_node.gd.uid tests/test_plot_node.gd tests/test_plot_node.gd.uid
git commit -m "feat: tappable plot pad node for the island map (plan 15 task 2)"
```

---

### Task 3: IslandIsletNode and IslandCrewToken

**Files:**
- Create: `game/base/islet_node.gd`
- Create: `game/base/crew_token.gd`
- Test: `tests/test_island_map_nodes.gd` (create)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `IslandIsletNode` (extends Button), `IslandIsletNode.new(islet_id: String)`, signal `islet_tapped(islet_id: String)`, `render(state)` with keys `art`, `name`, `status`, `dim` (bool); `custom_minimum_size Vector2(160, 164)`. `IslandCrewToken` (extends Button), `IslandCrewToken.new(crew_id: String)`, signal `crew_tapped(crew_id: String)`, `render(state)` with keys `portrait`, `name`, `line`, `rescued` (bool); `custom_minimum_size Vector2(72, 104)`; unrescued tokens are `disabled`. Internal children `_art`, `_name_label`, `_status_label` (islet) and `_portrait`, `_name_label`, `_line_label` (crew) are poked by tests.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_island_map_nodes.gd`:

```gdscript
extends GutTest
## Islet markers and crew tokens on the island map: pure presentation nodes.


func make_islet(id := "lantern_shoal") -> IslandIsletNode:
	var node := IslandIsletNode.new(id)
	add_child_autofree(node)
	return node


func make_token(id := "odo") -> IslandCrewToken:
	var token := IslandCrewToken.new(id)
	add_child_autofree(token)
	return token


func test_islet_renders_art_name_and_status() -> void:
	var node := make_islet()
	node.render({"art": "res://game/art/buildings/islet_lantern_shoal_ruined.png",
		"name": "Lantern Shoal", "status": "600 scrap, 4 cloudsilk", "dim": false})
	assert_not_null(node._art.texture)
	assert_eq(node._name_label.text, "Lantern Shoal")
	assert_eq(node._status_label.text, "600 scrap, 4 cloudsilk")
	assert_almost_eq(node.modulate.a, 1.0, 0.01)


func test_locked_islet_dims() -> void:
	var node := make_islet("foundry_rock")
	node.render({"art": "res://game/art/buildings/islet_foundry_rock_ruined.png",
		"name": "Foundry Rock", "status": "beyond a broken bridge", "dim": true})
	assert_almost_eq(node.modulate.a, 0.4, 0.01, "Plan 8 polish: locked islets dim at last")


func test_islet_tap_emits_the_id() -> void:
	var node := make_islet("foundry_rock")
	watch_signals(node)
	node.pressed.emit()
	assert_signal_emitted_with_parameters(node, "islet_tapped", ["foundry_rock"])


func test_islet_children_never_block_the_tap() -> void:
	var node := make_islet()
	for child in node.get_children():
		assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_unrescued_token_is_a_disabled_silhouette() -> void:
	var token := make_token()
	token.render({"portrait": "res://game/art/crew/odo.png", "name": "???", "line": "", "rescued": false})
	assert_true(token.disabled, "an unrescued crewmember cannot be assigned")
	assert_almost_eq(token._portrait.modulate.a, 0.5, 0.01, "silhouette treatment")
	assert_eq(token._name_label.text, "???")


func test_rescued_token_enables_and_shows_the_line() -> void:
	var token := make_token()
	token.render({"portrait": "res://game/art/crew/odo.png", "name": "Odo",
		"line": "knows the Gardens", "rescued": true})
	assert_false(token.disabled)
	assert_almost_eq(token._portrait.modulate.a, 1.0, 0.01)
	assert_eq(token._name_label.text, "Odo")
	assert_eq(token._line_label.text, "knows the Gardens")


func test_token_tap_emits_the_crew_id() -> void:
	var token := make_token("brisa")
	token.render({"portrait": "res://game/art/crew/brisa.png", "name": "Brisa", "line": "idle", "rescued": true})
	watch_signals(token)
	token.pressed.emit()
	assert_signal_emitted_with_parameters(token, "crew_tapped", ["brisa"])


func test_token_children_never_block_the_tap() -> void:
	var token := make_token()
	for child in token.get_children():
		assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)
```

- [ ] **Step 2: Run the new file to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_island_map_nodes.gd -gexit`
Expected: FAIL (classes do not exist).

- [ ] **Step 3: Implement the islet node**

Create `game/base/islet_node.gd`:

```gdscript
extends Button
class_name IslandIsletNode
## One tappable islet marker on the island map. Pure presentation; the
## screen computes the state and routes the tap by islet state.

signal islet_tapped(islet_id: String)

var islet_id := ""

var _art: TextureRect
var _name_label: Label
var _status_label: Label


func _init(id: String) -> void:
	islet_id = id
	flat = true
	custom_minimum_size = Vector2(160.0, 164.0)
	size = custom_minimum_size
	pressed.connect(func() -> void: islet_tapped.emit(islet_id))
	_art = TextureRect.new()
	_art.position = Vector2(24, 0)
	_art.size = Vector2(112, 112)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_name_label = _make_label(Rect2(0, 112, 160, 24), 14)
	_status_label = _make_label(Rect2(0, 136, 160, 26), 12)
	_status_label.modulate.a = 0.85


func render(state: Dictionary) -> void:
	var art_path := String(state.get("art", ""))
	if art_path != "" and ResourceLoader.exists(art_path):
		_art.texture = load(art_path)
	else:
		_art.texture = null
	_name_label.text = String(state.get("name", ""))
	_status_label.text = String(state.get("status", ""))
	modulate.a = 0.4 if bool(state.get("dim", false)) else 1.0


func _make_label(rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
```

- [ ] **Step 4: Implement the crew token**

Create `game/base/crew_token.gd`:

```gdscript
extends Button
class_name IslandCrewToken
## One crewmember standing on the island shore. Unrescued crew are disabled
## silhouettes; rescued crew tap to cycle their assignment.

signal crew_tapped(crew_id: String)

var crew_id := ""

var _portrait: TextureRect
var _name_label: Label
var _line_label: Label


func _init(id: String) -> void:
	crew_id = id
	flat = true
	custom_minimum_size = Vector2(72.0, 104.0)
	size = custom_minimum_size
	pressed.connect(func() -> void: crew_tapped.emit(crew_id))
	_portrait = TextureRect.new()
	_portrait.position = Vector2(4, 0)
	_portrait.size = Vector2(64, 64)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait)
	_name_label = _make_label(Rect2(0, 64, 72, 20), 12)
	_line_label = _make_label(Rect2(0, 84, 72, 20), 10)
	_line_label.modulate.a = 0.8


func render(state: Dictionary) -> void:
	var portrait_path := String(state.get("portrait", ""))
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		_portrait.texture = load(portrait_path)
	else:
		_portrait.texture = null
	var rescued := bool(state.get("rescued", false))
	disabled = not rescued
	_portrait.modulate.a = 1.0 if rescued else 0.5
	_name_label.text = String(state.get("name", ""))
	_line_label.text = String(state.get("line", ""))


func _make_label(rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
```

- [ ] **Step 5: Run the new file to verify it passes**

Run: `godot --headless --import`
Then: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_island_map_nodes.gd -gexit`
Expected: PASS (8 tests).

- [ ] **Step 6: Commit (including .gd.uid sidecars)**

Run: `git status --porcelain` and stage every new sidecar.

```bash
git add game/base/islet_node.gd game/base/islet_node.gd.uid game/base/crew_token.gd game/base/crew_token.gd.uid tests/test_island_map_nodes.gd tests/test_island_map_nodes.gd.uid
git commit -m "feat: islet markers and crew tokens for the island map (plan 15 task 3)"
```

---

### Task 4: IslandBackdrop

**Files:**
- Create: `game/base/island_backdrop.gd`
- Test: `tests/test_island_backdrop.gd` (create)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `IslandBackdrop` (extends Control) used as the script of `MapScroll/Map/Backdrop` in Task 5; `set_bridges(bridges: Array)` where each entry is `{"from": Vector2, "to": Vector2, "state": String}` with state one of "broken"/"scaffold"/"restored"; `VISTA_PATH` constant `res://game/art/regions/island_vista.png` (drawn full-map when it exists, code fallback otherwise).

- [ ] **Step 1: Write the failing tests**

Create `tests/test_island_backdrop.gd`:

```gdscript
extends GutTest
## The map backdrop: vista art when delivered, code-drawn fallback until
## then, and the bridges that span between the home island and the islets.


func make_backdrop() -> IslandBackdrop:
	var node := IslandBackdrop.new()
	node.size = Vector2(720, 2000)
	add_child_autofree(node)
	return node


func test_backdrop_ignores_the_mouse() -> void:
	var node := make_backdrop()
	assert_eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the backdrop must never eat taps meant for pads")


func test_vista_art_is_not_delivered_yet_so_fallback_draws() -> void:
	var node := make_backdrop()
	assert_null(node._vista, "no island_vista.png in the repo yet; code fallback carries the screen")


func test_set_bridges_stores_and_requests_a_redraw() -> void:
	var node := make_backdrop()
	node.set_bridges([
		{"from": Vector2(240, 1040), "to": Vector2(180, 1160), "state": "broken"},
		{"from": Vector2(330, 1400), "to": Vector2(480, 1510), "state": "restored"},
	])
	assert_eq(node._bridges.size(), 2)
```

- [ ] **Step 2: Run the new file to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_island_backdrop.gd -gexit`
Expected: FAIL (class does not exist).

- [ ] **Step 3: Implement the backdrop**

Create `game/base/island_backdrop.gd`:

```gdscript
extends Control
class_name IslandBackdrop
## The island map's painted background. Until the vista art is delivered it
## draws a code fallback (sky, plateau, islet rocks, cloud sea) so the map
## reads as a place, never a gray void. Bridges render here because they
## span between map nodes rather than belonging to any one of them.

const VISTA_PATH := "res://game/art/regions/island_vista.png"

var _bridges: Array = []
var _vista: Texture2D = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(VISTA_PATH):
		_vista = load(VISTA_PATH)


func set_bridges(bridges: Array) -> void:
	_bridges = bridges
	queue_redraw()


func _draw() -> void:
	if _vista != null:
		draw_texture_rect(_vista, Rect2(Vector2.ZERO, size), false)
	else:
		_draw_fallback()
	for bridge_v in _bridges:
		_draw_bridge(bridge_v as Dictionary)


func _draw_fallback() -> void:
	# Sky: a vertical gradient from deep day blue to a warm horizon.
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
		PackedColorArray([Color(0.45, 0.65, 0.9), Color(0.45, 0.65, 0.9),
			Color(0.85, 0.8, 0.75), Color(0.85, 0.8, 0.75)]))
	# The home plateau behind the plots.
	draw_polygon(_island_points(Vector2(360, 580), 335.0, 430.0),
		PackedColorArray([Color(0.45, 0.58, 0.38)]))
	# Islet rocks.
	draw_polygon(_island_points(Vector2(190, 1300), 120.0, 170.0),
		PackedColorArray([Color(0.5, 0.52, 0.45)]))
	draw_polygon(_island_points(Vector2(540, 1650), 130.0, 180.0),
		PackedColorArray([Color(0.48, 0.46, 0.44)]))
	# The cloud sea closes the bottom of the map.
	draw_rect(Rect2(0, size.y - 160, size.x, 160), Color(0.92, 0.93, 0.96, 0.9))


func _island_points(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 20:
		var angle := TAU * float(i) / 20.0
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points


func _draw_bridge(bridge: Dictionary) -> void:
	var from_point: Vector2 = bridge.get("from", Vector2.ZERO)
	var to_point: Vector2 = bridge.get("to", Vector2.ZERO)
	match String(bridge.get("state", "broken")):
		"restored":
			draw_line(from_point, to_point, Color(0.55, 0.4, 0.25), 6.0)
			draw_line(from_point, to_point, Color(0.75, 0.6, 0.4), 2.0)
		"scaffold":
			draw_dashed_line(from_point, to_point, Color(0.7, 0.65, 0.5), 4.0, 12.0)
		_:
			# Broken: two stubs reaching toward each other across the gap.
			var dir := (to_point - from_point).normalized()
			draw_line(from_point, from_point + dir * 36.0, Color(0.5, 0.38, 0.28), 5.0)
			draw_line(to_point, to_point - dir * 36.0, Color(0.5, 0.38, 0.28), 5.0)
```

- [ ] **Step 4: Run the new file to verify it passes**

Run: `godot --headless --import`
Then: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_island_backdrop.gd -gexit`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit (including .gd.uid sidecars)**

```bash
git add game/base/island_backdrop.gd game/base/island_backdrop.gd.uid tests/test_island_backdrop.gd tests/test_island_backdrop.gd.uid
git commit -m "feat: code-drawn island map backdrop with bridge states (plan 15 task 4)"
```

---

### Task 5: Island screen map rework

**Files:**
- Modify: `game/base/island_screen.tscn` (full replacement below)
- Modify: `game/base/island_screen.gd` (full replacement below)
- Test: `tests/test_island_screen.gd` (targeted edits below)

**Interfaces:**
- Consumes: `DataDefs.island_layout` (Task 1); `IslandPlotNode` (Task 2); `IslandIsletNode`, `IslandCrewToken` (Task 3); `IslandBackdrop.set_bridges` (Task 4); all existing model statics.
- Produces: tap routing `_on_plot_tapped(plot: String)`, `_on_islet_tapped(islet_id: String)`; state builders `_plot_state(plot, now) -> Dictionary`, `_islet_visual_state(islet, now) -> Dictionary`, `_crew_visual_state(member) -> Dictionary`; `_layout_pos(value) -> Vector2`; node registries `_plot_nodes`, `_islet_nodes`, `_crew_tokens`; sheet entry points `_open_plot_sheet(plot)`, `_render_sheet()` (stub; Task 6 replaces it), `_close_sheet()`, `_on_sheet_close_pressed()`; `_update_modal_block()`. Scene gains `MapScroll/Map/{Backdrop,Islets,CrewBand,Plots}`, `ModalBlock`, `PlotSheet/VBox/{SheetTitle,SheetInfo,SheetActions,SheetClose}`.

- [ ] **Step 1: Rewrite the structural tests and add the routing tests (failing first)**

Apply these edits to `tests/test_island_screen.gd`:

Replace `test_builds_one_row_per_plot_plus_islets_plus_crew` entirely with:

```gdscript
func test_builds_map_nodes_for_plots_islets_and_crew() -> void:
	assert_eq(screen.get_node("MapScroll/Map/Plots").get_child_count(),
		int(DataDefs.buildings["plot_count"]), "fresh save: one pad per home plot")
	assert_eq(screen.get_node("MapScroll/Map/Islets").get_child_count(),
		IsletModel.islets(DataDefs.islets).size(), "one marker per islet")
	assert_eq(screen.get_node("MapScroll/Map/CrewBand").get_child_count(),
		CrewModel.members(DataDefs.crew).size(), "one token per crew def, rescued or not")
```

Replace `test_built_observatory_shows_its_teaser` entirely with:

```gdscript
func test_built_observatory_shows_its_teaser_in_the_sheet() -> void:
	GameState.data["island"]["plots"]["plot_3"] = {"building": "observatory", "level": 1}
	screen._rebuild()
	screen._on_plot_tapped("plot_3")
	assert_string_contains(String(screen.get_node("PlotSheet/VBox/SheetInfo").text), "Brasswork Reach",
		"spec 4.1: the Observatory reveals upcoming regions")
```

Replace `test_tick_without_state_change_keeps_row_nodes_alive` entirely with:

```gdscript
func test_tick_without_state_change_keeps_map_nodes_alive() -> void:
	var node_before: Node = screen.get_node("MapScroll/Map/Plots").get_child(0)
	screen._refresh_tick()
	assert_true(is_instance_valid(node_before) and not node_before.is_queued_for_deletion(),
		"per-second ticks must not free a pad under the player's finger")
```

Replace `test_restored_islet_contributes_its_plot_row` entirely with:

```gdscript
func test_restored_islet_contributes_its_plot_pad() -> void:
	restore_lantern()
	assert_eq(screen.get_node("MapScroll/Map/Plots").get_child_count(),
		int(DataDefs.buildings["plot_count"]) + 1,
		"the restored islet's plot joins the map")
```

Replace the `crew_row_count` helper and `test_crew_rows_exist_for_the_whole_cast` entirely with:

```gdscript
func crew_token_count() -> int:
	return screen.get_node("MapScroll/Map/CrewBand").get_child_count()


func test_crew_tokens_exist_for_the_whole_cast() -> void:
	assert_eq(crew_token_count(), CrewModel.members(DataDefs.crew).size(),
		"every crew def gets a token, rescued or not")
```

Replace `test_unrescued_crew_show_as_silhouettes` and `test_rescued_crew_show_name_and_specialty` entirely with:

```gdscript
func test_unrescued_crew_show_as_disabled_silhouettes() -> void:
	var state: Dictionary = screen._crew_visual_state(CrewModel.entry(DataDefs.crew, "odo"))
	assert_eq(String(state["name"]), "???")
	assert_false(bool(state["rescued"]))
	var token: Button = screen._crew_tokens["odo"]
	assert_true(token.disabled)


func test_rescued_crew_show_name_and_specialty() -> void:
	rescue_and_rebuild(["odo"])
	var state: Dictionary = screen._crew_visual_state(CrewModel.entry(DataDefs.crew, "odo"))
	assert_eq(String(state["name"]), "Odo")
	assert_string_contains(String(state["line"]), "Gardens")
	var token: Button = screen._crew_tokens["odo"]
	assert_false(token.disabled)
```

Replace `test_worker_suffix_on_building_rows` entirely with:

```gdscript
func test_worker_badge_rides_the_building_pad() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	rescue_and_rebuild(["odo"])
	screen._on_assign_pressed("odo")
	var state: Dictionary = screen._plot_state("plot_2", TimeUtil.now())
	assert_string_contains(String(state.get("worker_portrait", "")), "odo",
		"the assigned worker's portrait badges the pad")
```

In `test_running_batch_joins_the_signature_and_row_text`, replace the one `_row_text` assertion line (`assert_string_contains(screen._row_text(...), "batch", ...)`) with:

```gdscript
	assert_string_contains(String(screen._plot_state("plot_1", TimeUtil.now()).get("status", "")), "batch",
		"the countdown rides the pad's status label")
```

Then APPEND these new tests at the end of the file:

```gdscript
func test_empty_plot_tap_opens_the_build_browser() -> void:
	screen._on_plot_tapped("plot_0")
	assert_true(screen.get_node("BuildModal").visible)
	assert_eq(screen._modal_building(), "workshop")


func test_done_construction_tap_collects_directly() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 0}
	TimerService.start("build_plot_0", "construction", 10, 1000, {"plot": "plot_0", "building": "workshop", "to_level": 1})
	TimerService._state.data["timers"]["build_plot_0"]["ends_at"] = 0
	screen._rebuild()
	screen._on_plot_tapped("plot_0")
	assert_eq(IslandModel.building_level(GameState.data["island"], "workshop"), 1)
	assert_false(screen.get_node("PlotSheet").visible, "a done build collects on the tap itself")


func test_built_plot_tap_opens_the_sheet() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	screen._rebuild()
	screen._on_plot_tapped("plot_0")
	assert_true(screen.get_node("PlotSheet").visible)
	assert_string_contains(String(screen.get_node("PlotSheet/VBox/SheetTitle").text), "Workshop Lv 1")


func test_constructing_plot_tap_opens_the_sheet_with_countdown() -> void:
	screen._open_build_modal("plot_0")
	screen._on_modal_confirm_pressed()
	screen._on_plot_tapped("plot_0")
	assert_true(screen.get_node("PlotSheet").visible)
	assert_string_contains(String(screen.get_node("PlotSheet/VBox/SheetTitle").text), "Building Workshop")


func test_done_batch_tap_collects_directly() -> void:
	with_smeltery(1)
	screen._on_batch_start_pressed("smeltery", "smelt")
	TimerService._state.data["timers"]["convert_smeltery"]["ends_at"] = 0
	screen._rebuild()
	screen._on_plot_tapped("plot_1")
	assert_eq(Economy.balance("parts"), 1)
	assert_false(screen.get_node("PlotSheet").visible)


func test_construction_done_outranks_batch_done_on_one_tap() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	screen._rebuild()
	screen._on_batch_start_pressed("gardens", "put_up_provisions")
	TimerService.start("build_plot_2", "construction", 10, 1000, {"plot": "plot_2", "building": "gardens", "to_level": 2})
	TimerService._state.data["timers"]["build_plot_2"]["ends_at"] = 0
	TimerService._state.data["timers"]["convert_gardens"]["ends_at"] = 0
	screen._on_plot_tapped("plot_2")
	assert_eq(int((GameState.data["island"]["plots"]["plot_2"] as Dictionary)["level"]), 2,
		"the construction collects first")
	assert_true(TimerService.active_timers().has("convert_gardens"), "the batch stays for the next tap")


func test_plot_pads_sit_at_their_authored_positions() -> void:
	var node: Control = screen._plot_nodes["plot_0"]
	var pos: Array = (DataDefs.island_layout["plots"] as Dictionary)["plot_0"]
	assert_eq(node.position + node.custom_minimum_size / 2.0, Vector2(float(pos[0]), float(pos[1])))


func test_constructing_plot_shows_the_scaffold_overlay() -> void:
	screen._open_build_modal("plot_0")
	screen._on_modal_confirm_pressed()
	var node: IslandPlotNode = screen._plot_nodes["plot_0"]
	assert_true(node._overlay.visible, "construction_overlay.png wired (audit 4.2)")


func test_unknown_plot_position_falls_back_to_origin_without_crashing() -> void:
	assert_eq(screen._layout_pos([]), Vector2.ZERO)
	assert_eq(screen._layout_pos(null), Vector2.ZERO)


func test_islet_tap_restores_when_offered() -> void:
	GameState.data["currencies"]["cloudsilk"] = 10
	screen._on_islet_tapped("lantern_shoal")
	assert_true(TimerService.active_timers().has("restore_lantern_shoal"))


func test_islet_tap_is_a_noop_while_locked() -> void:
	screen._on_islet_tapped("foundry_rock")
	assert_false(TimerService.active_timers().has("restore_foundry_rock"))
	assert_eq(screen.get_node("StatusLabel").text, "", "a locked islet tap does not even complain")


func test_islet_tap_collects_a_done_restoration_and_opens_the_letter() -> void:
	GameState.data["currencies"]["cloudsilk"] = 10
	screen._on_restore_pressed("lantern_shoal")
	TimerService._state.data["timers"]["restore_lantern_shoal"]["ends_at"] = 0
	screen._refresh_tick()
	screen._on_islet_tapped("lantern_shoal")
	assert_true(IsletModel.is_restored(GameState.data, "lantern_shoal"))
	assert_true(screen.get_node("LetterPanel").visible)


func test_islet_tap_rereads_the_letter_when_restored() -> void:
	restore_lantern()
	screen._on_islet_tapped("lantern_shoal")
	assert_true(screen.get_node("LetterPanel").visible)


func test_locked_islet_dims_on_the_map() -> void:
	var node: Control = screen._islet_nodes["foundry_rock"]
	assert_almost_eq(node.modulate.a, 0.4, 0.01, "Plan 8 polish: locked islets finally dim")


func test_modal_block_shades_the_map_behind_overlays() -> void:
	assert_false(screen.get_node("ModalBlock").visible)
	screen._open_build_modal("plot_0")
	assert_true(screen.get_node("ModalBlock").visible, "map taps cannot leak through the modal")
	screen._on_modal_cancel_pressed()
	assert_false(screen.get_node("ModalBlock").visible)


func test_sheet_close_hides_sheet_and_block() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	screen._rebuild()
	screen._on_plot_tapped("plot_0")
	screen._on_sheet_close_pressed()
	assert_false(screen.get_node("PlotSheet").visible)
	assert_false(screen.get_node("ModalBlock").visible)
```

- [ ] **Step 2: Run the island screen file to verify the new tests fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_island_screen.gd -gexit`
Expected: FAIL (no MapScroll node, no `_plot_state`).

- [ ] **Step 3: Replace the scene**

Replace the ENTIRE contents of `game/base/island_screen.tscn` with:

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://game/base/island_screen.gd" id="1_is"]
[ext_resource type="Script" path="res://game/base/island_backdrop.gd" id="2_bd"]
[ext_resource type="Texture2D" path="res://game/art/ui/letter_panel.png" id="3_letter"]

[sub_resource type="StyleBoxTexture" id="StyleBoxTexture_letter"]
texture = ExtResource("3_letter")
texture_margin_left = 48.0
texture_margin_top = 48.0
texture_margin_right = 48.0
texture_margin_bottom = 48.0
content_margin_left = 32.0
content_margin_top = 32.0
content_margin_right = 32.0
content_margin_bottom = 32.0

[node name="IslandScreen" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_is")

[node name="Title" type="Label" parent="."]
offset_left = 24.0
offset_top = 24.0
offset_right = 500.0
offset_bottom = 64.0
text = "Home Island"

[node name="MapScroll" type="ScrollContainer" parent="."]
offset_top = 90.0
offset_right = 720.0
offset_bottom = 1080.0
horizontal_scroll_mode = 0

[node name="Map" type="Control" parent="MapScroll"]
custom_minimum_size = Vector2(720, 2000)

[node name="Backdrop" type="Control" parent="MapScroll/Map"]
offset_right = 720.0
offset_bottom = 2000.0
mouse_filter = 2
script = ExtResource("2_bd")

[node name="Islets" type="Control" parent="MapScroll/Map"]
offset_right = 720.0
offset_bottom = 2000.0
mouse_filter = 2

[node name="CrewBand" type="Control" parent="MapScroll/Map"]
offset_right = 720.0
offset_bottom = 2000.0
mouse_filter = 2

[node name="Plots" type="Control" parent="MapScroll/Map"]
offset_right = 720.0
offset_bottom = 2000.0
mouse_filter = 2

[node name="RefreshTimer" type="Timer" parent="."]
wait_time = 1.0
autostart = true

[node name="GardensButton" type="Button" parent="."]
offset_left = 10.0
offset_top = 1096.0
offset_right = 245.0
offset_bottom = 1152.0
text = "Collect trickle"

[node name="CrateButton" type="Button" parent="."]
offset_left = 250.0
offset_top = 1096.0
offset_right = 475.0
offset_bottom = 1152.0
text = "Open daily crate"

[node name="BonusCrateButton" type="Button" parent="."]
offset_left = 480.0
offset_top = 1096.0
offset_right = 710.0
offset_bottom = 1152.0
text = "Bonus crate (ad)"

[node name="SlotButton" type="Button" parent="."]
offset_left = 10.0
offset_top = 1160.0
offset_right = 320.0
offset_bottom = 1216.0
text = "Unlock 2nd build slot"

[node name="WorkshopButton" type="Button" parent="."]
offset_left = 330.0
offset_top = 1160.0
offset_right = 520.0
offset_bottom = 1216.0
text = "Workshop"

[node name="BackButton" type="Button" parent="."]
offset_left = 530.0
offset_top = 1160.0
offset_right = 710.0
offset_bottom = 1216.0
text = "Back"

[node name="StatusLabel" type="Label" parent="."]
offset_left = 20.0
offset_top = 1222.0
offset_right = 700.0
offset_bottom = 1270.0

[node name="ModalBlock" type="ColorRect" parent="."]
visible = false
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0, 0, 0, 0.45)

[node name="LetterPanel" type="PanelContainer" parent="."]
visible = false
offset_left = 40.0
offset_top = 200.0
offset_right = 680.0
offset_bottom = 700.0
theme_override_styles/panel = SubResource("StyleBoxTexture_letter")

[node name="VBox" type="VBoxContainer" parent="LetterPanel"]

[node name="LetterTitle" type="Label" parent="LetterPanel/VBox"]
text = "A letter"

[node name="LetterSeal" type="TextureRect" parent="LetterPanel/VBox"]
custom_minimum_size = Vector2(48, 48)
expand_mode = 1
stretch_mode = 5

[node name="LetterBody" type="Label" parent="LetterPanel/VBox"]
custom_minimum_size = Vector2(600, 0)
autowrap_mode = 3

[node name="LetterClose" type="Button" parent="LetterPanel/VBox"]
text = "Close"

[node name="BuildModal" type="PanelContainer" parent="."]
visible = false
offset_left = 60.0
offset_top = 180.0
offset_right = 660.0
offset_bottom = 780.0

[node name="VBox" type="VBoxContainer" parent="BuildModal"]

[node name="ModalTitle" type="Label" parent="BuildModal/VBox"]

[node name="ModalPicture" type="TextureRect" parent="BuildModal/VBox"]
custom_minimum_size = Vector2(96, 96)
expand_mode = 1
stretch_mode = 5

[node name="PictureLetter" type="Label" parent="BuildModal/VBox/ModalPicture"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
horizontal_alignment = 1
vertical_alignment = 1

[node name="ModalFlavor" type="Label" parent="BuildModal/VBox"]
modulate = Color(1, 1, 1, 0.7)
custom_minimum_size = Vector2(560, 0)
autowrap_mode = 3

[node name="ModalDescription" type="Label" parent="BuildModal/VBox"]
custom_minimum_size = Vector2(560, 0)
autowrap_mode = 3

[node name="ModalStats" type="Label" parent="BuildModal/VBox"]
custom_minimum_size = Vector2(560, 0)
autowrap_mode = 3

[node name="ModalCost" type="Label" parent="BuildModal/VBox"]

[node name="ModalStatus" type="Label" parent="BuildModal/VBox"]

[node name="NavRow" type="HBoxContainer" parent="BuildModal/VBox"]

[node name="PrevButton" type="Button" parent="BuildModal/VBox/NavRow"]
text = "< Prev"

[node name="NextButton" type="Button" parent="BuildModal/VBox/NavRow"]
text = "Next >"

[node name="ActionRow" type="HBoxContainer" parent="BuildModal/VBox"]

[node name="ConfirmButton" type="Button" parent="BuildModal/VBox/ActionRow"]
text = "Build"

[node name="CancelButton" type="Button" parent="BuildModal/VBox/ActionRow"]
text = "Cancel"

[node name="PlotSheet" type="PanelContainer" parent="."]
visible = false
offset_left = 40.0
offset_top = 720.0
offset_right = 680.0
offset_bottom = 1140.0

[node name="VBox" type="VBoxContainer" parent="PlotSheet"]

[node name="SheetTitle" type="Label" parent="PlotSheet/VBox"]

[node name="SheetInfo" type="Label" parent="PlotSheet/VBox"]
custom_minimum_size = Vector2(560, 0)
autowrap_mode = 3

[node name="SheetActions" type="VBoxContainer" parent="PlotSheet/VBox"]

[node name="SheetClose" type="Button" parent="PlotSheet/VBox"]
text = "Close"
```

- [ ] **Step 4: Replace the script**

Replace the ENTIRE contents of `game/base/island_screen.gd` with:

```gdscript
extends Control
## The home island (spec 4.1) as a scrollable map (Plan 15): building pads,
## islets and crew live at authored positions from island_layout.json. Dumb
## UI: every rule lives in the models; this screen renders state and routes
## taps to the same handlers the old menu used.
##
## Refresh discipline: RefreshTimer ticks call _refresh_tick, which rebuilds
## the map ONLY when the structural signature changes (a timer starting,
## finishing, or disappearing); otherwise nodes re-render in place so a pad
## is never freed under the player's finger.

var _last_signature := ""
var _modal_plot := ""
var _modal_ids: Array[String] = []
var _modal_index := 0
var _plot_nodes: Dictionary = {}
var _islet_nodes: Dictionary = {}
var _crew_tokens: Dictionary = {}
var _letter_islet := ""
var _sheet_plot := ""


func _ready() -> void:
	$WorkshopButton.pressed.connect(_on_workshop_pressed)
	$BackButton.pressed.connect(_on_back_pressed)
	$RefreshTimer.timeout.connect(_refresh_tick)
	$GardensButton.pressed.connect(_on_gardens_pressed)
	$CrateButton.pressed.connect(_on_crate_pressed)
	$SlotButton.pressed.connect(_on_slot_pressed)
	$BonusCrateButton.pressed.connect(_on_bonus_crate_pressed)
	$LetterPanel/VBox/LetterClose.pressed.connect(_on_letter_close_pressed)
	$BuildModal/VBox/NavRow/PrevButton.pressed.connect(_on_modal_prev_pressed)
	$BuildModal/VBox/NavRow/NextButton.pressed.connect(_on_modal_next_pressed)
	$BuildModal/VBox/ActionRow/ConfirmButton.pressed.connect(_on_modal_confirm_pressed)
	$BuildModal/VBox/ActionRow/CancelButton.pressed.connect(_on_modal_cancel_pressed)
	$PlotSheet/VBox/SheetClose.pressed.connect(_on_sheet_close_pressed)
	$BuildModal.visibility_changed.connect(_update_modal_block)
	$LetterPanel.visibility_changed.connect(_update_modal_block)
	$PlotSheet.visibility_changed.connect(_update_modal_block)
	_rebuild()


func _plot_ids() -> Array[String]:
	var ids: Array[String] = []
	for i in int(DataDefs.buildings.get("plot_count", 6)):
		ids.append("plot_%d" % i)
	ids.append_array(IsletModel.open_plots(GameState.data, DataDefs.islets))
	return ids


func _unbuilt_ids(plot: String) -> Array[String]:
	# A home plot offers home buildings; an islet plot offers exactly its
	# islet's buildings (spec 4.4).
	var plot_islet := IsletModel.islet_of_plot(DataDefs.islets, plot)
	var ids: Array[String] = []
	for id in DataDefs.buildings.get("defs", {}):
		var def: Dictionary = (DataDefs.buildings["defs"] as Dictionary)[id]
		if String(def.get("islet", "")) != plot_islet:
			continue
		if IslandModel.building_level(GameState.data["island"], String(id)) == 0 \
				and IslandModel.plot_of(GameState.data["island"], String(id)) == "":
			ids.append(String(id))
	return ids


func _signature(now: int) -> String:
	var parts := PackedStringArray()
	for plot in _plot_ids():
		var timer_id := "build_" + plot
		if TimerService.active_timers().has(timer_id):
			parts.append("d" if TimerService.is_done(timer_id, now) else "r")
		else:
			parts.append("i")
	for row_v in IsletModel.islets(DataDefs.islets):
		parts.append(_islet_state(String((row_v as Dictionary).get("id", "")), now))
	for row_v in CrewModel.members(DataDefs.crew):
		var crew_id := String((row_v as Dictionary).get("id", ""))
		if not CrewModel.is_rescued(GameState.data, crew_id):
			parts.append("u")
		else:
			parts.append("@" + CrewModel.building_of(GameState.data, crew_id))
	for id in DataDefs.buildings.get("defs", {}):
		if not ((DataDefs.buildings["defs"] as Dictionary)[id] as Dictionary).has("recipes"):
			continue
		var convert_id := "convert_" + String(id)
		if TimerService.active_timers().has(convert_id):
			parts.append("cd" if TimerService.is_done(convert_id, now) else "cr")
		else:
			parts.append("ci")
	return ",".join(parts)


func _islet_state(islet_id: String, now: int) -> String:
	# One char per islet: R restored, r restoring, d done-uncollected,
	# o offered, L locked behind an earlier islet. All five are structural.
	if IsletModel.is_restored(GameState.data, islet_id):
		return "R"
	var timer_id := "restore_" + islet_id
	if TimerService.active_timers().has(timer_id):
		return "d" if TimerService.is_done(timer_id, now) else "r"
	return "o" if IsletModel.next_offered(GameState.data, DataDefs.islets) == islet_id else "L"


func _refresh_tick() -> void:
	var now := TimeUtil.now()
	if _signature(now) != _last_signature:
		_rebuild()
		return
	_refresh_labels(now)


func _refresh_labels(now: int) -> void:
	for plot in _plot_nodes:
		var node: IslandPlotNode = _plot_nodes[plot]
		if is_instance_valid(node):
			node.render(_plot_state(String(plot), now))
	for islet_id in _islet_nodes:
		var islet_node: IslandIsletNode = _islet_nodes[islet_id]
		if is_instance_valid(islet_node):
			islet_node.render(_islet_visual_state(IsletModel.entry(DataDefs.islets, String(islet_id)), now))
	if $PlotSheet.visible:
		_render_sheet()
	_refresh_static_controls(now)


func _rebuild() -> void:
	for container in [$MapScroll/Map/Plots, $MapScroll/Map/Islets, $MapScroll/Map/CrewBand]:
		for child in (container as Control).get_children():
			(container as Control).remove_child(child)
			child.queue_free()
	_plot_nodes.clear()
	_islet_nodes.clear()
	_crew_tokens.clear()
	var now := TimeUtil.now()
	_last_signature = _signature(now)
	var layout: Dictionary = DataDefs.island_layout
	var plot_positions: Dictionary = layout.get("plots", {})
	for plot in _plot_ids():
		var node := IslandPlotNode.new(plot)
		node.plot_tapped.connect(_on_plot_tapped)
		node.position = _layout_pos(plot_positions.get(plot)) - node.custom_minimum_size / 2.0
		$MapScroll/Map/Plots.add_child(node)
		node.render(_plot_state(plot, now))
		_plot_nodes[plot] = node
	var islet_layout: Dictionary = layout.get("islets", {})
	var bridges: Array = []
	for row_v in IsletModel.islets(DataDefs.islets):
		var islet := row_v as Dictionary
		var islet_id := String(islet.get("id", ""))
		var islet_node := IslandIsletNode.new(islet_id)
		islet_node.islet_tapped.connect(_on_islet_tapped)
		var entry: Dictionary = islet_layout.get(islet_id, {})
		islet_node.position = _layout_pos(entry.get("pos")) - islet_node.custom_minimum_size / 2.0
		$MapScroll/Map/Islets.add_child(islet_node)
		islet_node.render(_islet_visual_state(islet, now))
		_islet_nodes[islet_id] = islet_node
		var bridge_points: Array = entry.get("bridge", [])
		if bridge_points.size() == 2:
			bridges.append({
				"from": _layout_pos(bridge_points[0]),
				"to": _layout_pos(bridge_points[1]),
				"state": _bridge_state(islet_id, now),
			})
	$MapScroll/Map/Backdrop.set_bridges(bridges)
	var band: Dictionary = layout.get("crew_band", {})
	var index := 0
	for row_v in CrewModel.members(DataDefs.crew):
		var member := row_v as Dictionary
		var member_id := String(member.get("id", ""))
		var token := IslandCrewToken.new(member_id)
		token.crew_tapped.connect(_on_assign_pressed)
		token.position = Vector2(
			float(band.get("start_x", 64)) + float(band.get("spacing", 82)) * float(index),
			float(band.get("y", 940))) - token.custom_minimum_size / 2.0
		$MapScroll/Map/CrewBand.add_child(token)
		token.render(_crew_visual_state(member))
		_crew_tokens[member_id] = token
		index += 1
	if $PlotSheet.visible:
		_render_sheet()
	_refresh_static_controls(now)


func _layout_pos(value: Variant) -> Vector2:
	# A plot id missing from island_layout.json must degrade to a visible
	# misplacement, never a crash; the defs test catches the authoring hole.
	if not (value is Array) or (value as Array).size() < 2:
		return Vector2.ZERO
	var arr := value as Array
	return Vector2(float(arr[0]), float(arr[1]))


func _plot_state(plot: String, now: int) -> Dictionary:
	var island: Dictionary = GameState.data["island"]
	var plots: Dictionary = island.get("plots", {})
	var defs: Dictionary = DataDefs.buildings.get("defs", {})
	var timer_id := "build_" + plot
	if TimerService.active_timers().has(timer_id):
		var payload: Dictionary = (TimerService.active_timers()[timer_id] as Dictionary).get("payload", {})
		var building := String(payload.get("building", ""))
		var def: Dictionary = defs.get(building, {})
		var state := {
			"kind": "constructing",
			"art": "res://game/art/buildings/%s.png" % building,
			"name": String(def.get("name", building)),
			"status": "%ds" % TimerService.remaining(timer_id, now),
			"ready": false,
		}
		if TimerService.is_done(timer_id, now):
			state["status"] = "Tap to collect!"
			state["ready"] = true
		return state
	if plots.has(plot):
		var entry: Dictionary = plots[plot]
		var building := String(entry.get("building", ""))
		var def: Dictionary = defs.get(building, {})
		var state := {
			"kind": "built",
			"art": "res://game/art/buildings/%s.png" % building,
			"name": "%s Lv %d" % [String(def.get("name", building)), int(entry.get("level", 0))],
			"status": "",
			"ready": false,
		}
		var worker := CrewModel.crew_at(GameState.data, building)
		if worker != "":
			state["worker_portrait"] = "res://game/art/crew/%s.png" % worker
		var convert_id := "convert_" + building
		if TimerService.active_timers().has(convert_id):
			if TimerService.is_done(convert_id, now):
				state["status"] = "Batch ready!"
				state["ready"] = true
			else:
				state["status"] = "batch %ds" % TimerService.remaining(convert_id, now)
		return state
	return {"kind": "empty", "name": "(empty)", "status": "Tap to build", "ready": false}


func _islet_visual_state(islet: Dictionary, now: int) -> Dictionary:
	var islet_id := String(islet.get("id", ""))
	var restored := IsletModel.is_restored(GameState.data, islet_id)
	return {
		"art": "res://game/art/buildings/islet_%s_%s.png" % [islet_id, "restored" if restored else "ruined"],
		"name": String(islet.get("name", islet_id)),
		"status": _islet_status_text(islet, now),
		"dim": _islet_state(islet_id, now) == "L",
	}


func _islet_status_text(islet: Dictionary, now: int) -> String:
	var islet_id := String(islet.get("id", ""))
	match _islet_state(islet_id, now):
		"R":
			return "restored"
		"r":
			return "restoring (%ds)" % TimerService.remaining("restore_" + islet_id, now)
		"d":
			return "the bridge is ready"
		"o":
			return _cost_text(islet.get("cost", {}))
	return "beyond a broken bridge"


func _islet_row_text(islet: Dictionary, now: int) -> String:
	return "%s: %s" % [String(islet.get("name", String(islet.get("id", "")))), _islet_status_text(islet, now)]


func _crew_visual_state(member: Dictionary) -> Dictionary:
	var member_id := String(member.get("id", ""))
	var rescued := CrewModel.is_rescued(GameState.data, member_id)
	var line := ""
	if rescued:
		var building := CrewModel.building_of(GameState.data, member_id)
		if building == "":
			var specialty := String(member.get("specialty", ""))
			var spec_def: Dictionary = (DataDefs.buildings.get("defs", {}) as Dictionary).get(specialty, {})
			line = "knows the %s" % String(spec_def.get("name", specialty))
		else:
			line = String(((DataDefs.buildings.get("defs", {}) as Dictionary).get(building, {}) as Dictionary).get("name", building))
	return {
		"portrait": "res://game/art/crew/%s.png" % member_id,
		"name": String(member.get("name", member_id)) if rescued else "???",
		"line": line,
		"rescued": rescued,
	}


func _bridge_state(islet_id: String, now: int) -> String:
	match _islet_state(islet_id, now):
		"R":
			return "restored"
		"r", "d":
			return "scaffold"
	return "broken"


func _on_plot_tapped(plot: String) -> void:
	var now := TimeUtil.now()
	var timer_id := "build_" + plot
	if TimerService.active_timers().has(timer_id):
		if TimerService.is_done(timer_id, now):
			_on_collect_pressed(plot)
		else:
			_open_plot_sheet(plot)
		return
	var plots: Dictionary = (GameState.data["island"] as Dictionary).get("plots", {})
	if not plots.has(plot):
		_open_build_modal(plot)
		return
	var building := String((plots[plot] as Dictionary).get("building", ""))
	var convert_id := "convert_" + building
	if TimerService.active_timers().has(convert_id) and TimerService.is_done(convert_id, now):
		_on_batch_collect_pressed(building)
		return
	_open_plot_sheet(plot)


func _on_islet_tapped(islet_id: String) -> void:
	match _islet_state(islet_id, TimeUtil.now()):
		"o":
			_on_restore_pressed(islet_id)
		"d":
			_on_restore_collect_pressed(islet_id)
		"R":
			_on_read_letter_pressed(islet_id)


func _open_plot_sheet(plot: String) -> void:
	_sheet_plot = plot
	_render_sheet()
	if _sheet_plot != "":
		$PlotSheet.visible = true


func _render_sheet() -> void:
	# Task 6 fills in the action buttons; this stub renders title and info
	# so tap routing stands alone.
	var now := TimeUtil.now()
	var plots: Dictionary = (GameState.data["island"] as Dictionary).get("plots", {})
	var timer_id := "build_" + _sheet_plot
	var constructing := TimerService.active_timers().has(timer_id)
	if _sheet_plot == "" or (not plots.has(_sheet_plot) and not constructing):
		_close_sheet()
		return
	var building := ""
	var level := 0
	if plots.has(_sheet_plot):
		var entry: Dictionary = plots[_sheet_plot]
		building = String(entry.get("building", ""))
		level = int(entry.get("level", 0))
	if constructing:
		var payload: Dictionary = (TimerService.active_timers()[timer_id] as Dictionary).get("payload", {})
		building = String(payload.get("building", building))
	var def: Dictionary = (DataDefs.buildings.get("defs", {}) as Dictionary).get(building, {})
	var display := String(def.get("name", building))
	if constructing:
		if TimerService.is_done(timer_id, now):
			$PlotSheet/VBox/SheetTitle.text = "%s: ready!" % display
		else:
			$PlotSheet/VBox/SheetTitle.text = "Building %s (%ds)" % [display, TimerService.remaining(timer_id, now)]
	else:
		$PlotSheet/VBox/SheetTitle.text = "%s Lv %d" % [display, level]
	var info_lines := PackedStringArray()
	var worker := CrewModel.crew_at(GameState.data, building)
	if worker != "":
		info_lines.append("%s is working here" % String(CrewModel.entry(DataDefs.crew, worker).get("name", worker)))
	if level >= 1 and String(def.get("teaser", "")) != "":
		info_lines.append(String(def.get("teaser", "")))
	$PlotSheet/VBox/SheetInfo.text = "\n".join(info_lines)
	$PlotSheet/VBox/SheetInfo.visible = not info_lines.is_empty()


func _close_sheet() -> void:
	_sheet_plot = ""
	$PlotSheet.visible = false


func _on_sheet_close_pressed() -> void:
	_close_sheet()


func _update_modal_block() -> void:
	$ModalBlock.visible = $BuildModal.visible or $LetterPanel.visible or $PlotSheet.visible


func _refresh_static_controls(now: int) -> void:
	var pending := TrickleModel.pending(GameState.data, DataDefs.buildings, now, DataDefs.crew)
	$GardensButton.text = "Collect trickle (%d scrap)" % pending
	$GardensButton.disabled = pending <= 0
	$CrateButton.disabled = not DailyCrate.can_claim(GameState.data, now)
	$CrateButton.text = "Open daily crate" if not $CrateButton.disabled else "Crate opened today"
	$CrateButton.icon = load("res://game/art/icons/daily_crate_open.png" if $CrateButton.disabled else "res://game/art/icons/daily_crate.png")
	$CrateButton.add_theme_constant_override("icon_max_width", 40)
	var slots_cfg: Dictionary = DataDefs.buildings.get("build_slots", {})
	var slot_cost := int(slots_cfg.get("second_slot_crystal_cost", 20))
	$SlotButton.visible = int(GameState.data["island"].get("build_slots", 1)) < int(slots_cfg.get("max", 2))
	$SlotButton.text = "Unlock 2nd build slot (%d crystals)" % slot_cost
	$SlotButton.disabled = not Economy.can_afford({"crystals": slot_cost})
	$BonusCrateButton.visible = Ads.service.is_available(AdService.Placement.BONUS_CRATE)
	$BonusCrateButton.disabled = not AdLimits.can_use(GameState.data, "bonus_crate", _bonus_crate_limit(), now)
	$BonusCrateButton.icon = load("res://game/art/icons/bonus_crate.png")
	$BonusCrateButton.add_theme_constant_override("icon_max_width", 40)
	$SlotButton.icon = load("res://game/art/icons/build_slot.png")
	$SlotButton.add_theme_constant_override("icon_max_width", 32)


func _open_build_modal(plot: String) -> void:
	# The build browser (owner request, 2026-09-09): an empty plot browses its
	# candidates; an occupied plot opens locked on its own building for the
	# upgrade. Confirm routes through IslandModel like the old Build button.
	var plots: Dictionary = GameState.data["island"].get("plots", {})
	_modal_plot = plot
	if plots.has(plot):
		var held: Array[String] = [String((plots[plot] as Dictionary).get("building", ""))]
		_modal_ids = held
	else:
		_modal_ids = _unbuilt_ids(plot)
	if _modal_ids.is_empty():
		return
	_modal_index = 0
	$BuildModal/VBox/ModalStatus.text = ""
	_render_modal()
	$BuildModal.visible = true


func _modal_building() -> String:
	if _modal_ids.is_empty():
		return ""
	return String(_modal_ids[_modal_index])


func _render_modal() -> void:
	var building_id := _modal_building()
	var def: Dictionary = (DataDefs.buildings.get("defs", {}) as Dictionary).get(building_id, {})
	var display := String(def.get("name", building_id))
	$BuildModal/VBox/ModalTitle.text = display
	# Building illustration (audit 4.2); the lettered placeholder only remains
	# as the fallback for a building without delivered art.
	var art_path := "res://game/art/buildings/%s.png" % building_id
	if ResourceLoader.exists(art_path):
		$BuildModal/VBox/ModalPicture.texture = load(art_path)
		$BuildModal/VBox/ModalPicture/PictureLetter.text = ""
	else:
		$BuildModal/VBox/ModalPicture.texture = null
		$BuildModal/VBox/ModalPicture/PictureLetter.text = display.left(1)
	$BuildModal/VBox/ModalFlavor.text = String(def.get("flavor", ""))
	$BuildModal/VBox/ModalDescription.text = String(def.get("description", ""))
	var stats := _stats_text(building_id, def)
	$BuildModal/VBox/ModalStats.text = stats
	$BuildModal/VBox/ModalStats.visible = stats != ""
	$BuildModal/VBox/NavRow.visible = _modal_ids.size() > 1
	var level := IslandModel.building_level(GameState.data["island"], building_id)
	var level_rows: Array = def.get("levels", [])
	if level >= int(def.get("max_level", 1)) or level >= level_rows.size():
		$BuildModal/VBox/ModalCost.text = "Max level reached"
		$BuildModal/VBox/ActionRow/ConfirmButton.text = "Max level"
		$BuildModal/VBox/ActionRow/ConfirmButton.disabled = true
		return
	var next_row: Dictionary = level_rows[level]
	$BuildModal/VBox/ModalCost.text = "Cost: %s" % _cost_text(next_row.get("cost", {}))
	$BuildModal/VBox/ActionRow/ConfirmButton.text = ("Upgrade to Lv %d" % (level + 1)) if level > 0 else "Build"
	$BuildModal/VBox/ActionRow/ConfirmButton.disabled = false


func _stats_text(building_id: String, def: Dictionary) -> String:
	# Concrete numbers straight from the def (owner request, 2026-09-11): the
	# line can never drift from the data because it IS the data. Buildings
	# whose whole effect is narrative (observatory, dock) return "".
	var lines := PackedStringArray()
	if building_id == "workshop":
		lines.append("• 1 craft slot per level")
	if def.has("fuel_cap_bonus_per_level"):
		lines.append("• +%d fuel cap per level" % int(def["fuel_cap_bonus_per_level"]))
	if def.has("regen_delta_per_level"):
		lines.append("• %ds faster fuel regen per level" % absi(int(def["regen_delta_per_level"])))
	if def.has("drops_bonus_per_level"):
		lines.append("• +%d pod drop per run per level" % int(def["drops_bonus_per_level"]))
	if def.has("scrap_per_hour_per_level"):
		lines.append("• %d scrap per hour per level, banks up to %dh" % [
			int(def["scrap_per_hour_per_level"]), int(def.get("cap_hours", 8.0))])
	if def.has("payout_bonus_per_level"):
		lines.append("• +%d%% expedition payout per level" % roundi(float(def["payout_bonus_per_level"]) * 100.0))
	var recipe_rows: Array = def.get("recipes", [])
	for row_v in recipe_rows:
		var conversion := row_v as Dictionary
		var inputs: Dictionary = conversion.get("inputs", {})
		var input_text := _cost_text(inputs) if not inputs.is_empty() else "free"
		lines.append("• Makes: %s (%s -> %s, %dm)" % [
			String(conversion.get("name", conversion.get("id", ""))),
			input_text,
			_cost_text(conversion.get("outputs", {})),
			int(float(conversion.get("seconds", 600)) / 60.0),
		])
	if not recipe_rows.is_empty():
		lines.append("• Batch outputs scale with building level")
	return "\n".join(lines)


func _on_modal_prev_pressed() -> void:
	if _modal_ids.size() <= 1:
		return
	_modal_index = (_modal_index - 1 + _modal_ids.size()) % _modal_ids.size()
	$BuildModal/VBox/ModalStatus.text = ""
	_render_modal()


func _on_modal_next_pressed() -> void:
	if _modal_ids.size() <= 1:
		return
	_modal_index = (_modal_index + 1) % _modal_ids.size()
	$BuildModal/VBox/ModalStatus.text = ""
	_render_modal()


func _on_modal_confirm_pressed() -> void:
	var building_id := _modal_building()
	if building_id == "" or not $BuildModal.visible:
		return
	var island: Dictionary = GameState.data["island"]
	var now := TimeUtil.now()
	var reason := IslandModel.build_rejection(island, DataDefs.buildings, Economy, TimerService, _modal_plot, building_id, now, DataDefs.islets, GameState.data.get("islets", {}))
	if reason != "":
		# Rejections live in the modal so the player sees them beside the card.
		$BuildModal/VBox/ModalStatus.text = reason
		return
	if IslandModel.start_build(island, DataDefs.buildings, Economy, TimerService, _modal_plot, building_id, now, DataDefs.islets, GameState.data.get("islets", {})):
		GameState.save_game()
	$BuildModal.visible = false
	_rebuild()


func _on_modal_cancel_pressed() -> void:
	$BuildModal.visible = false


func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for currency in cost:
		parts.append("%d %s" % [int(cost[currency]), String(currency)])
	return ", ".join(parts)


func _batch_button_text(building_id: String, recipe_id: String) -> String:
	var conversion := ConvertModel.recipe_by_id(DataDefs.buildings, building_id, recipe_id)
	var inputs: Dictionary = conversion.get("inputs", {})
	var display := String(conversion.get("name", recipe_id))
	if inputs.is_empty():
		return display
	return "%s (%s)" % [display, _cost_text(inputs)]


func _on_batch_start_pressed(building_id: String, recipe_id: String) -> void:
	if ConvertModel.start_batch(GameState.data, DataDefs.buildings, Economy, TimerService, building_id, recipe_id, TimeUtil.now(), DataDefs.crew):
		GameState.save_game()
	_rebuild()


func _on_batch_collect_pressed(building_id: String) -> void:
	var payload := TimerService.collect("convert_" + building_id, TimeUtil.now())
	if payload.is_empty():
		return
	ConvertModel.complete_batch(GameState.data, DataDefs.buildings, Economy, payload)
	GameState.save_game()
	_rebuild()


func _on_assign_pressed(crew_id: String) -> void:
	var options: Array = CrewModel.workable(DataDefs.crew)
	var now := TimeUtil.now()
	var current := CrewModel.building_of(GameState.data, crew_id)
	var next_index := options.find(current) + 1
	# Bank fuel accrued at the old regen rate before the rate can change.
	FuelModel.materialize(GameState.data["fuel"], now)
	if next_index >= options.size():
		if current != "":
			CrewModel.unassign(GameState.data, DataDefs.crew, current, DataDefs.buildings, now)
	else:
		CrewModel.assign(GameState.data, DataDefs.crew, String(options[next_index]), crew_id, DataDefs.buildings, now)
	IslandEffects.apply_fuel(GameState.data, DataDefs.economy, DataDefs.buildings, DataDefs.crew)
	GameState.save_game()
	_rebuild()


func _on_collect_pressed(plot: String) -> void:
	var now := TimeUtil.now()
	var payload := TimerService.collect("build_" + plot, now)
	if payload.is_empty():
		return
	IslandModel.complete_build(GameState.data["island"], payload, GameState.data, now, DataDefs.buildings, DataDefs.crew)
	NotificationSvc.request_permission_once()
	# Idempotent re-application self-heals fuel cap/regen after ANY completion,
	# not just the Wind Still: a mangled save heals at the next collect too.
	IslandEffects.apply_fuel(GameState.data, DataDefs.economy, DataDefs.buildings, DataDefs.crew)
	GameState.save_game()
	_rebuild()


func _on_restore_pressed(islet_id: String) -> void:
	var reason := IsletModel.restore_rejection(GameState.data, DataDefs.islets, Economy, TimerService, islet_id)
	if reason != "":
		$StatusLabel.text = reason
		return
	if IsletModel.start_restore(GameState.data, DataDefs.islets, Economy, TimerService, islet_id, TimeUtil.now()):
		$StatusLabel.text = ""
		GameState.save_game()
	_rebuild()


func _on_restore_collect_pressed(islet_id: String) -> void:
	var payload := TimerService.collect("restore_" + islet_id, TimeUtil.now())
	if payload.is_empty():
		return
	IsletModel.complete_restore(GameState.data, payload)
	GameState.save_game()
	_open_letter(islet_id)
	_rebuild()


func _on_read_letter_pressed(islet_id: String) -> void:
	_open_letter(islet_id)


func _open_letter(islet_id: String) -> void:
	var islet := IsletModel.entry(DataDefs.islets, islet_id)
	var vignette: Dictionary = islet.get("vignette", {})
	_letter_islet = islet_id
	$LetterPanel/VBox/LetterTitle.text = String(vignette.get("title", String(islet.get("name", islet_id))))
	var lines := PackedStringArray()
	for line in vignette.get("lines", []):
		lines.append(String(line))
	$LetterPanel/VBox/LetterBody.text = "\n\n".join(lines)
	# Each letter carries its own ornament: a wax seal for the shoal's letter,
	# a brass clasp for the foundry log (audit 4.3).
	var seal_path := String({
		"lantern_shoal": "res://game/art/ui/seal_lantern.png",
		"foundry_rock": "res://game/art/ui/clasp_foundry.png",
	}.get(islet_id, ""))
	var seal: TextureRect = $LetterPanel/VBox/LetterSeal
	seal.texture = load(seal_path) if seal_path != "" and ResourceLoader.exists(seal_path) else null
	seal.visible = seal.texture != null
	$LetterPanel.visible = true


func _on_letter_close_pressed() -> void:
	if _letter_islet != "":
		# Write-back discipline: heal a mangled section before flagging.
		if not GameState.data.has("islets") or not (GameState.data["islets"] is Dictionary):
			GameState.data["islets"] = {"restored": {}, "letters_seen": {}}
		var section: Dictionary = GameState.data["islets"]
		if not section.has("letters_seen") or not (section["letters_seen"] is Dictionary):
			section["letters_seen"] = {}
		(section["letters_seen"] as Dictionary)[_letter_islet] = true
		GameState.save_game()
	_letter_islet = ""
	$LetterPanel.visible = false


func _on_workshop_pressed() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/base/workshop_screen.tscn")


func _on_back_pressed() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/main.tscn")


func _on_gardens_pressed() -> void:
	var amount := TrickleModel.collect(GameState.data, DataDefs.buildings, TimeUtil.now(), DataDefs.crew)
	if amount > 0:
		Economy.add("scrap", amount)
		GameState.save_game()
	_rebuild()


func _on_crate_pressed() -> void:
	var payout := DailyCrate.claim(GameState.data, DataDefs.retention, TimeUtil.now())
	if payout.is_empty():
		return
	for currency in payout:
		Economy.add(currency, int(payout[currency]))
	GameState.save_game()
	_rebuild()


func _on_slot_pressed() -> void:
	if IslandModel.unlock_second_slot(GameState.data["island"], DataDefs.buildings, Economy):
		GameState.save_game()
	_rebuild()


func _on_skip_pressed(timer_id: String) -> void:
	if not Ads.service.is_available(AdService.Placement.TIMER_SKIP):
		return
	Ads.service.request_reward(AdService.Placement.TIMER_SKIP, _grant_skip.bind(timer_id))


func _grant_skip(timer_id: String) -> void:
	# skip() emits no signal; the rebuild surfaces the ready state and the
	# player collects with a tap on the pad.
	TimerService.skip(timer_id)
	GameState.save_game()
	_rebuild()


func _on_bonus_crate_pressed() -> void:
	var now := TimeUtil.now()
	if not Ads.service.is_available(AdService.Placement.BONUS_CRATE):
		return
	if not AdLimits.can_use(GameState.data, "bonus_crate", _bonus_crate_limit(), now):
		return
	Ads.service.request_reward(AdService.Placement.BONUS_CRATE, _grant_bonus_crate)


func _grant_bonus_crate() -> void:
	var now := TimeUtil.now()
	if not AdLimits.use(GameState.data, "bonus_crate", _bonus_crate_limit(), now):
		return
	var payout: Dictionary = DataDefs.retention.get("daily_crate", {})
	for currency in payout:
		Economy.add(currency, int(payout[currency]))
	GameState.save_game()
	_rebuild()


func _bonus_crate_limit() -> int:
	return int((DataDefs.retention.get("ads", {}) as Dictionary).get("bonus_crates_per_day", 1))
```

Note what changed versus the old file: `Rows` handling, `_plot_labels`, `_islet_labels`, `_row_text`, `_crew_row_text`, and `_assign_text` are gone; `_rebuild`/`_refresh_labels` now build and re-render map nodes; everything from `_open_build_modal` through the ad handlers is byte-identical to the old file except the `_grant_skip` comment.

- [ ] **Step 5: Run the island suite files**

Run: `godot --headless --import`
Then: `git status --porcelain` (commit any new .gd.uid later with this task)
Then: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_island_screen.gd -gexit`
Expected: PASS for everything except the Task 6 sheet-action tests (which do not exist yet). The sheet stub satisfies the title/info tests added above.

- [ ] **Step 6: Run the FULL suite to catch cross-file breakage**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS. If `tests/test_smoke.gd` or others reference removed island nodes, fix the references against the new scene paths (`MapScroll/Map/...`).

- [ ] **Step 7: Commit**

```bash
git add game/base/island_screen.tscn game/base/island_screen.gd tests/test_island_screen.gd
git commit -m "feat: island screen becomes a scrollable island map (plan 15 task 5)"
```

---

### Task 6: PlotSheet actions

**Files:**
- Modify: `game/base/island_screen.gd` (replace `_render_sheet`, add four handlers)
- Test: `tests/test_island_screen.gd` (append tests)

**Interfaces:**
- Consumes: Task 5's sheet scaffolding (`_sheet_plot`, `_open_plot_sheet`, `_close_sheet`, `PlotSheet/VBox/SheetActions`), `ConvertModel.recipes/can_start/outputs_for`, `Ads.service`, `AdService.Placement.TIMER_SKIP`.
- Produces: `_on_sheet_upgrade_pressed()`, `_on_sheet_collect_pressed()`, `_on_sheet_batch_start_pressed(building_id, recipe_id)`, `_on_sheet_batch_collect_pressed(building_id)`; `_render_sheet` fills `SheetActions` with contextual buttons. SheetActions child order: while constructing, a single Complete!/Skip button; otherwise index 0 is always Upgrade, followed by batch buttons.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_island_screen.gd`:

```gdscript
func test_sheet_upgrade_opens_the_locked_modal() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	GameState.data["currencies"]["cloudsilk"] = 20
	screen._rebuild()
	screen._on_plot_tapped("plot_0")
	var upgrade: Button = screen.get_node("PlotSheet/VBox/SheetActions").get_child(0)
	assert_eq(upgrade.text, "Upgrade...")
	upgrade.pressed.emit()
	assert_false(screen.get_node("PlotSheet").visible, "the sheet yields to the modal")
	assert_true(screen.get_node("BuildModal").visible)
	assert_eq((screen._modal_ids as Array).size(), 1, "locked on the plot's own building")
	assert_string_contains(String(screen.get_node("BuildModal/VBox/ActionRow/ConfirmButton").text), "Upgrade to Lv 2")


func test_sheet_max_level_disables_upgrade() -> void:
	GameState.data["island"]["plots"]["plot_3"] = {"building": "observatory", "level": 1}
	screen._rebuild()
	screen._on_plot_tapped("plot_3")
	var upgrade: Button = screen.get_node("PlotSheet/VBox/SheetActions").get_child(0)
	assert_true(upgrade.disabled)
	assert_eq(upgrade.text, "Max level")


func test_sheet_lists_batch_buttons_and_starts_one() -> void:
	with_smeltery(1)
	screen._on_plot_tapped("plot_1")
	var actions: VBoxContainer = screen.get_node("PlotSheet/VBox/SheetActions")
	assert_eq(actions.get_child_count(), 2, "Upgrade plus the smelt recipe")
	var smelt: Button = actions.get_child(1)
	assert_string_contains(smelt.text, "Smelt (")
	smelt.pressed.emit()
	assert_true(TimerService.active_timers().has("convert_smeltery"))
	assert_eq(Economy.balance("scrap"), 2000 - 40)


func test_sheet_rerenders_to_collect_when_the_batch_finishes() -> void:
	with_smeltery(1)
	screen._on_batch_start_pressed("smeltery", "smelt")
	screen._on_plot_tapped("plot_1")
	assert_true(screen.get_node("PlotSheet").visible)
	TimerService._state.data["timers"]["convert_smeltery"]["ends_at"] = 0
	screen._refresh_tick()
	var actions: VBoxContainer = screen.get_node("PlotSheet/VBox/SheetActions")
	var collect: Button = actions.get_child(actions.get_child_count() - 1)
	assert_string_contains(collect.text, "Collect")
	collect.pressed.emit()
	assert_eq(Economy.balance("parts"), 1)


func test_sheet_skip_ad_completes_the_construction() -> void:
	screen._open_build_modal("plot_0")
	screen._on_modal_confirm_pressed()
	screen._on_plot_tapped("plot_0")
	var skip: Button = screen.get_node("PlotSheet/VBox/SheetActions").get_child(0)
	assert_eq(skip.text, "Skip (ad)")
	skip.pressed.emit()
	assert_true(TimerService.is_done("build_plot_0", TimeUtil.now()),
		"spec 6 placement 1: an ad skips the timer; the player still collects")
```

- [ ] **Step 2: Run the file to verify the new tests fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_island_screen.gd -gexit`
Expected: the five new tests FAIL (SheetActions stays empty); everything else passes.

- [ ] **Step 3: Implement the full sheet**

In `game/base/island_screen.gd`, replace the entire `_render_sheet` function with:

```gdscript
func _render_sheet() -> void:
	var now := TimeUtil.now()
	var island: Dictionary = GameState.data["island"]
	var plots: Dictionary = island.get("plots", {})
	var timer_id := "build_" + _sheet_plot
	var constructing := TimerService.active_timers().has(timer_id)
	if _sheet_plot == "" or (not plots.has(_sheet_plot) and not constructing):
		_close_sheet()
		return
	var actions: VBoxContainer = $PlotSheet/VBox/SheetActions
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	var building := ""
	var level := 0
	if plots.has(_sheet_plot):
		var entry: Dictionary = plots[_sheet_plot]
		building = String(entry.get("building", ""))
		level = int(entry.get("level", 0))
	if constructing:
		var payload: Dictionary = (TimerService.active_timers()[timer_id] as Dictionary).get("payload", {})
		building = String(payload.get("building", building))
	var def: Dictionary = (DataDefs.buildings.get("defs", {}) as Dictionary).get(building, {})
	var display := String(def.get("name", building))
	if constructing:
		if TimerService.is_done(timer_id, now):
			$PlotSheet/VBox/SheetTitle.text = "%s: ready!" % display
		else:
			$PlotSheet/VBox/SheetTitle.text = "Building %s (%ds)" % [display, TimerService.remaining(timer_id, now)]
	else:
		$PlotSheet/VBox/SheetTitle.text = "%s Lv %d" % [display, level]
	var info_lines := PackedStringArray()
	var worker := CrewModel.crew_at(GameState.data, building)
	if worker != "":
		info_lines.append("%s is working here" % String(CrewModel.entry(DataDefs.crew, worker).get("name", worker)))
	if level >= 1 and String(def.get("teaser", "")) != "":
		info_lines.append(String(def.get("teaser", "")))
	$PlotSheet/VBox/SheetInfo.text = "\n".join(info_lines)
	$PlotSheet/VBox/SheetInfo.visible = not info_lines.is_empty()
	if constructing:
		if TimerService.is_done(timer_id, now):
			var complete := Button.new()
			complete.text = "Complete!"
			complete.pressed.connect(_on_sheet_collect_pressed)
			actions.add_child(complete)
		elif Ads.service.is_available(AdService.Placement.TIMER_SKIP):
			var skip := Button.new()
			skip.text = "Skip (ad)"
			skip.pressed.connect(_on_skip_pressed.bind(timer_id))
			actions.add_child(skip)
		return
	var upgrade := Button.new()
	var max_level := int(def.get("max_level", 1))
	upgrade.text = "Upgrade..." if level < max_level else "Max level"
	upgrade.disabled = level >= max_level
	upgrade.pressed.connect(_on_sheet_upgrade_pressed)
	actions.add_child(upgrade)
	var convert_id := "convert_" + building
	if TimerService.active_timers().has(convert_id):
		if TimerService.is_done(convert_id, now):
			var payload: Dictionary = (TimerService.active_timers()[convert_id] as Dictionary).get("payload", {})
			var outputs := ConvertModel.outputs_for(DataDefs.buildings, island, building, String(payload.get("recipe", "")))
			var batch := Button.new()
			batch.text = "Collect (%s)" % _cost_text(outputs) if not outputs.is_empty() else "Collect"
			batch.pressed.connect(_on_sheet_batch_collect_pressed.bind(building))
			actions.add_child(batch)
	else:
		for recipe_v in ConvertModel.recipes(DataDefs.buildings, building):
			var recipe_id := String((recipe_v as Dictionary).get("id", ""))
			var start_batch := Button.new()
			start_batch.text = _batch_button_text(building, recipe_id)
			start_batch.disabled = not ConvertModel.can_start(GameState.data, DataDefs.buildings, Economy, TimerService, building, recipe_id)
			start_batch.pressed.connect(_on_sheet_batch_start_pressed.bind(building, recipe_id))
			actions.add_child(start_batch)
```

Then add these four handlers directly after `_close_sheet()`:

```gdscript
func _on_sheet_collect_pressed() -> void:
	var plot := _sheet_plot
	_close_sheet()
	_on_collect_pressed(plot)


func _on_sheet_upgrade_pressed() -> void:
	var plot := _sheet_plot
	_close_sheet()
	_open_build_modal(plot)


func _on_sheet_batch_start_pressed(building_id: String, recipe_id: String) -> void:
	_on_batch_start_pressed(building_id, recipe_id)


func _on_sheet_batch_collect_pressed(building_id: String) -> void:
	_on_batch_collect_pressed(building_id)
```

- [ ] **Step 4: Run the file to verify everything passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_island_screen.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Run the FULL suite**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add game/base/island_screen.gd tests/test_island_screen.gd
git commit -m "feat: plot sheet carries upgrade, batch and skip actions (plan 15 task 6)"
```

---

### Task 7: Graphics tracking and spec errata

**Files:**
- Modify: `docs/art/placeholder-graphics-audit.md`
- Modify: `docs/superpowers/specs/2026-10-11-island-map-design.md`

**Interfaces:**
- Consumes: the shipped layout from Tasks 1-6.
- Produces: the updated image-agent brief; no code.

- [ ] **Step 1: Rewrite audit section 4.6**

In `docs/art/placeholder-graphics-audit.md`, replace the whole `### 4.6 Island vista (future, large) — carried over` section (heading and its body) with:

```markdown
### 4.6 Island map screen (CHANGED: layout shipped 2026-10-11)
The island screen is now a vertically scrollable 720 x 2000 map ([island_screen.tscn](../../game/base/island_screen.tscn)); every coordinate lives in [island_layout.json](../../game/data/island_layout.json), so art is painted AROUND those authored positions. The backdrop is code-drawn (sky gradient, plateau and islet silhouettes, cloud band) until the vista lands; the fallback lives in [island_backdrop.gd](../../game/base/island_backdrop.gd) and swaps itself out the moment `game/art/regions/island_vista.png` exists.

| Asset | Size (design px, deliver 2x) | Notes |
|---|---|---|
| Island vista map background | 720 x 2000 | Sky top band (y 0..200), home plateau (plots centered per island_layout.json, y 200..1050), Lantern Shoal rock (~y 1150..1450 left), Foundry Rock (~y 1500..1800 right), cloud-sea bottom band (y 1850..2000). File: `game/art/regions/island_vista.png`. |
| Empty plot pad | 128 x 128 | Cleared foundation (stone circle / timber deck) that reads as "build here". File: `game/art/buildings/plot_pad.png`; the dashed-outline fallback draws until it exists. |
| Bridge, broken | ~200 x 80 | Snapped rope-bridge stub pair; one generic set serves both islets. Replaces the code-drawn stubs in island_backdrop.gd. |
| Bridge, scaffold | ~200 x 80 | Half-built planks and rigging (shown while a restoration timer runs). |
| Bridge, restored | ~200 x 80 | Whole rope bridge. |
| Ready glow badge | 96 x 96 | Soft gold burst behind "Tap to collect!"; nice-to-have, the gold "!" label ships first. |
| Shore band dressing | 720 x 160 | Optional dock planks under the crew tokens (band centered at y 940). |

Wired by the map rework (previously delivered): `construction_overlay.png` now scaffolds constructing pads; building illustrations double as pad sprites; islet ruined/restored art marks the islets; crew portraits became shore tokens and worker badges on pads.
```

- [ ] **Step 2: Stamp the header wiring paragraph**

In the same file's `**Wiring status (2026-10-08):**` header line, change the leading marker to `**Wiring status (2026-10-11):**` and within that paragraph move `construction overlay` out of the "Delivered but NOT yet wired" list and append this sentence at the end of the paragraph: `The island screen is now a scrollable map (see 4.6); the construction overlay, islet art and crew portraits gained their map wiring there.`

- [ ] **Step 3: Update audit 4.1 island row**

In the 4.1 screens table, replace the Island row's "Contents today" cell text with: `Scrollable 720 x 2000 island map: building pads at authored positions, islet markers with code-drawn bridges, crew tokens on the shore band; PlotSheet bottom sheet for upgrade/batch/skip; BuildModal browser; LetterPanel; HUD bar (trickle, crates, slot unlock, workshop, back).`

- [ ] **Step 4: Spec errata**

In `docs/superpowers/specs/2026-10-11-island-map-design.md` section 1.2, append this line at the end of the section:

```markdown
**Errata (execution):** the six HUD buttons and StatusLabel stayed DIRECT children of IslandScreen with their original node names (no HudBar container), eliminating all path churn in script and tests; inside the Map, Islets and CrewBand render before Plots so pads draw and pick above islet art where they overlap.
```

- [ ] **Step 5: Run the FULL suite one last time**

Run: `godot --headless --import`
Then: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS.
Then: `git status --porcelain` and stage any straggler `.gd.uid` sidecars.

- [ ] **Step 6: Commit**

```bash
git add docs/art/placeholder-graphics-audit.md docs/superpowers/specs/2026-10-11-island-map-design.md
git commit -m "docs: island map art brief and spec errata (plan 15 task 7)"
```
