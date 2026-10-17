# Windfall Isles Plan 16: The HUD Dissolves Into the Map

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the island screen's bottom HUD buttons and move each function into the map itself: trickle collects on a Gardens tap (with a pending-scrap speech bubble), crates become top-right icons shown only while claimable, the 2nd build slot becomes a build-modal offer, a new cheap Crew Quarters building gates crew and opens the crew sheet, and the Workshop's sheet carries the enter-workshop button plus a craftable-count bubble.

**Architecture:** Dumb UI stays dumb: every rule lives in the models (TrickleModel, CraftModel, IslandModel, DailyCrate, AdLimits); island_screen.gd only computes state dictionaries and routes taps. IslandPlotNode grows two pure-presentation children (a speech bubble, a lettered art fallback) driven by new `bubble` and `letter` state keys. The survivor gate is one early return in salvage_run reading IslandModel.building_level.

**Tech Stack:** Godot 4.6 (GDScript, binary at `/Applications/Godot-4.6.app/Contents/MacOS/Godot`), vendored GUT 9.6.1.

**Spec:** `docs/superpowers/specs/2026-10-17-hud-to-map-design.md`

## Global Constraints

- Godot binary: `GODOT=/Applications/Godot-4.6.app/Contents/MacOS/Godot`. Run tests as two separate plain commands (the sandbox rejects compound bash commands: no `&&` chains, no for-loops): first `$GODOT --headless --import`, then `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.
- After creating any new .gd file, run `git status --porcelain` and stage its `.gd.uid` sidecar with the commit.
- GDScript uses TABS for indentation. Match the existing comment density and voice (short "why" comments, often citing the owner request date).
- NEVER use an em dash in any file, comment, test message, or commit message. Use a colon, comma, or two sentences.
- Never state cumulative suite totals in code, comments, or commit messages.
- Children of a tappable Button must be `MOUSE_FILTER_IGNORE` (repo lesson: never block the input walk). Map-level buttons use `MOUSE_FILTER_PASS` so drag-scroll works; do not change existing filters.
- Spends confirm via a sheet or modal, never on a bare map tap. (Trickle and crate collection are gains, not spends; they may collect on the tap.)
- GUT lessons: `assert_signal_emitted_with_parameters` takes no message argument; place GUT error-count assertions after the triggering call; use `context_stub` if a stub name collides.
- The island screen scene header `[gd_scene load_steps=9 format=3]` stays unchanged: no task adds or removes an ext_resource or sub_resource.
- Rules live in models; island_screen.gd computes state dicts and routes taps only.
- Keep `GameState.save_game()` after every state mutation a handler performs.

## Review Focus

Inputs the spec implies but could slip through, each pinned to a task's tests:

1. Trickle crossing 0 to positive between structural rebuilds: the bubble must appear from a plain `_refresh_tick` with no signature change (Task 6, `test_trickle_bubble_appears_on_a_plain_tick`).
2. A done Gardens batch AND pending trickle on one tap: the batch collects first and the trickle stays for the next tap (Task 6, `test_done_gardens_batch_outranks_the_trickle_on_one_tap`).
3. Crew Quarters tapped while still constructing: the plot sheet with the countdown opens, not the crew sheet (Task 6, `test_constructing_crew_quarters_tap_opens_the_plot_sheet`).
4. Build modal opened when both slots are already owned and busy: no slot offer appears even though every builder is busy (Task 5, `test_modal_never_offers_a_third_slot`).
5. A crafted-out or resource-poor Workshop: the bubble must vanish, not show "0 craftable" (Task 6, second half of `test_workshop_bubble_counts_distinct_craftable_gizmos`).

---

### Task 1: Crew Quarters def, eighth plot, layout position

**Files:**
- Modify: `game/data/buildings.json`
- Modify: `game/data/island_layout.json`
- Test: `tests/test_recipe_defs.gd`

**Interfaces:**
- Produces: building def id `crew_quarters` (name "Crew Quarters", max_level 1, one level row {cost {scrap: 40}, build_seconds: 45}, no "islet" key, no recipes); `plot_count` 8; layout key `plot_7` at [360, 810]. Tasks 3, 5 and 6 rely on the id `crew_quarters` and on plot_7 existing.

- [ ] **Step 1: Write the failing tests**

In `tests/test_recipe_defs.gd`, find the line inside `test_smeltery_def_shape`:

```gdscript
	assert_eq(int(DataDefs.buildings.get("plot_count", 0)), 7, "seventh plot: no softlock")
```

and replace it with:

```gdscript
	assert_eq(int(DataDefs.buildings.get("plot_count", 0)), 8, "eighth plot: every home building keeps a pad")
```

Then append this test at the end of the file:

```gdscript
func test_crew_quarters_def_shape() -> void:
	var def: Dictionary = (DataDefs.buildings.get("defs", {}) as Dictionary).get("crew_quarters", {})
	assert_eq(String(def.get("name", "")), "Crew Quarters")
	assert_eq(int(def.get("max_level", 0)), 1, "a pure unlock: nothing to upgrade")
	var rows: Array = def.get("levels", [])
	assert_eq(rows.size(), 1)
	assert_eq(int(((rows[0] as Dictionary).get("cost", {}) as Dictionary).get("scrap", 0)), 40,
		"cheap on purpose: crew should unlock early (owner request, 2026-10-17)")
	assert_true(int((rows[0] as Dictionary).get("build_seconds", 0)) <= 60, "a quick first build")
	assert_eq(String(def.get("islet", "")), "", "a home building")
	assert_false(def.has("recipes"), "the bunkhouse converts nothing")
	assert_false((DataDefs.crew.get("workable", []) as Array).has("crew_quarters"),
		"no one works the bunkhouse")
	assert_true((DataDefs.island_layout.get("plots", {}) as Dictionary).has("plot_7"),
		"the new plot has a map position")
```

- [ ] **Step 2: Run the suite to verify the new assertions fail**

Run: `$GODOT --headless --import`
Then: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL in test_recipe_defs.gd (plot_count still 7, crew_quarters missing) and in test_island_layout_defs.gd once plot_count flips.

- [ ] **Step 3: Author the data**

In `game/data/buildings.json`, change:

```json
	"plot_count": 7,
```

to:

```json
	"plot_count": 8,
```

Then find the end of the `foundry_annex` def:

```json
			"levels": [
				{
					"cost": {
						"scrap": 900,
						"brasswork": 6
					},
					"build_seconds": 3600
				},
				{
					"cost": {
						"scrap": 2000,
						"brasswork": 14
					},
					"build_seconds": 7200
				}
			]
		}
	}
}
```

and replace it with:

```json
			"levels": [
				{
					"cost": {
						"scrap": 900,
						"brasswork": 6
					},
					"build_seconds": 3600
				},
				{
					"cost": {
						"scrap": 2000,
						"brasswork": 14
					},
					"build_seconds": 7200
				}
			]
		},
		"crew_quarters": {
			"name": "Crew Quarters",
			"flavor": "Eight bunks, one kettle, no questions asked.",
			"description": "Gives castaways a place to sleep. Until it stands, survivors drift past your expeditions unseen.",
			"max_level": 1,
			"levels": [
				{
					"cost": {
						"scrap": 40
					},
					"build_seconds": 45
				}
			]
		}
	}
}
```

In `game/data/island_layout.json`, change:

```json
    "plot_6": [
      520,
      660
    ],
```

to:

```json
    "plot_6": [
      520,
      660
    ],
    "plot_7": [
      360,
      810
    ],
```

(Position check, already verified: nearest neighbors are plot_5 at distance 178 and plot_6 at 219, both over the 150 px crowding floor; y 810 + 64 stays inside the 720 x 1750 map and on the home plateau.)

- [ ] **Step 4: Run the suite to verify it passes**

Run: `$GODOT --headless --import`
Then: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS. (test_island_layout_defs.gd and test_island_screen.gd's pad-count test pick up plot_7/plot_count automatically.)

- [ ] **Step 5: Commit**

```bash
git add game/data/buildings.json game/data/island_layout.json tests/test_recipe_defs.gd
git commit -m "feat: Crew Quarters def on a new eighth plot"
```

---

### Task 2: CraftModel.craftable_ids

**Files:**
- Modify: `game/base/craft_model.gd`
- Test: `tests/test_craft_model.gd`

**Interfaces:**
- Consumes: existing `CraftModel.rarity_unlocked(island, gizmo_defs, gizmo_id)`.
- Produces: `static func craftable_ids(data: Dictionary, gizmo_defs: Dictionary, economy: Node) -> Array[String]`. Task 6 calls `CraftModel.craftable_ids(GameState.data, DataDefs.gizmos, Economy).size()`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_craft_model.gd` (setup gives workshop level 1, scrap 5000, cloudsilk 50, parts 50):

```gdscript
func test_craftable_ids_counts_resource_affordable_distinct_gizmos() -> void:
	state.data["currencies"]["parts"] = 2
	state.data["currencies"]["cloudsilk"] = 0
	var ids: Array[String] = CraftModel.craftable_ids(state.data, DataDefs.gizmos, econ)
	assert_eq(ids.size(), 3, "workshop level 1 with 2 parts: the three 2-part commons")
	for id in ["wind_fan", "balloon_cluster", "cargo_net"]:
		assert_true(ids.has(id), "%s costs 2 parts at an unlocked rarity" % id)

func test_craftable_ids_ignores_slot_occupancy() -> void:
	CraftModel.start_craft(state.data, DataDefs.gizmos, econ, timers, "wind_fan", 1000)
	assert_true(CraftModel.craftable_ids(state.data, DataDefs.gizmos, econ).has("balloon_cluster"),
		"the bubble advertises what resources allow, not what the queue allows this minute")

func test_craftable_ids_respects_rarity_and_max_level() -> void:
	assert_false(CraftModel.craftable_ids(state.data, DataDefs.gizmos, econ).has("chime_bell"),
		"uncommon waits for workshop level 2")
	state.data["gizmos"]["owned"]["wind_fan"] = 5
	assert_false(CraftModel.craftable_ids(state.data, DataDefs.gizmos, econ).has("wind_fan"),
		"a maxed gizmo leaves the count")

func test_craftable_ids_empty_without_a_workshop() -> void:
	state.data["island"]["plots"].clear()
	assert_eq(CraftModel.craftable_ids(state.data, DataDefs.gizmos, econ).size(), 0,
		"no workshop means no rarity is unlocked")
```

- [ ] **Step 2: Run to verify failure**

Run: `$GODOT --headless --import`
Then: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gselect=test_craft_model.gd -gexit`
Expected: FAIL ("craftable_ids" not found).

- [ ] **Step 3: Implement**

Append to `game/base/craft_model.gd`:

```gdscript
static func craftable_ids(data: Dictionary, gizmo_defs: Dictionary, economy: Node) -> Array[String]:
	# Distinct gizmos the player could craft on resources alone (the workshop
	# speech bubble, owner request 2026-10-17). Slot occupancy is deliberately
	# ignored: the bubble advertises what the resources allow, not what the
	# queue allows this minute.
	var out: Array[String] = []
	var owned: Dictionary = (data.get("gizmos", {}) as Dictionary).get("owned", {})
	for gizmo_id in gizmo_defs.get("defs", {}):
		var def: Dictionary = (gizmo_defs["defs"] as Dictionary)[gizmo_id]
		if not rarity_unlocked(data.get("island", {}), gizmo_defs, String(gizmo_id)):
			continue
		if int(owned.get(String(gizmo_id), 0)) >= int(gizmo_defs.get("craft_max_level", 5)):
			continue
		if not economy.can_afford(def.get("craft_cost", {})):
			continue
		out.append(String(gizmo_id))
	return out
```

- [ ] **Step 4: Run the FULL suite**

Run: `$GODOT --headless --import`
Then: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add game/base/craft_model.gd tests/test_craft_model.gd
git commit -m "feat: CraftModel.craftable_ids counts resource-affordable gizmos"
```

---

### Task 3: Survivors wait for the Crew Quarters

**Files:**
- Modify: `game/run/salvage_run.gd` (function `_maybe_schedule_survivor`, near line 311)
- Test: `tests/test_survivor_rescue.gd`

**Interfaces:**
- Consumes: `IslandModel.building_level(island, "crew_quarters")` and the Task 1 def id.
- Produces: nothing new; the gate is internal to the run scene.

- [ ] **Step 1: Update the test setup and write the failing test**

In `tests/test_survivor_rescue.gd`, in `before_each`, after the line `GameState.data["fuel"]["updated_at"] = 1000`, add:

```gdscript
	GameState.data["island"]["plots"]["plot_7"] = {"building": "crew_quarters", "level": 1}
```

Then append this test at the end of the file:

```gdscript
func test_no_spawn_scheduling_without_crew_quarters() -> void:
	# Crew gate (owner request, 2026-10-17): castaways only sign on once
	# there is somewhere for them to sleep.
	(GameState.data["island"]["plots"] as Dictionary).erase("plot_7")
	var survivor_defs: Dictionary = DataDefs.crew["survivor"]
	var old_chance: float = float(survivor_defs["chance_per_run"])
	survivor_defs["chance_per_run"] = 1.0
	scene._on_start_pressed()
	scene._maybe_schedule_survivor()
	assert_eq(scene._survivor_id, "", "no quarters, no castaways, even at chance 1.0")
	survivor_defs["chance_per_run"] = old_chance
```

- [ ] **Step 2: Run to verify the new test fails**

Run: `$GODOT --headless --import`
Then: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gselect=test_survivor_rescue.gd -gexit`
Expected: the new test FAILS (a survivor is drawn); the pre-existing tests still pass thanks to the before_each quarters.

- [ ] **Step 3: Implement the gate**

In `game/run/salvage_run.gd`, `_maybe_schedule_survivor` currently begins:

```gdscript
func _maybe_schedule_survivor() -> void:
	# Crew spec section 6: at most one survivor per run, drawn on the scene's
	# injected rng, only while someone is still out there.
	var pool := CrewModel.unrescued_ids(GameState.data, DataDefs.crew)
```

Insert the gate so it reads:

```gdscript
func _maybe_schedule_survivor() -> void:
	# Crew spec section 6: at most one survivor per run, drawn on the scene's
	# injected rng, only while someone is still out there.
	# Castaways only sign on once there is somewhere to sleep: the Crew
	# Quarters gate (owner request, 2026-10-17).
	if IslandModel.building_level(GameState.data.get("island", {}), "crew_quarters") < 1:
		return
	var pool := CrewModel.unrescued_ids(GameState.data, DataDefs.crew)
```

- [ ] **Step 4: Run the FULL suite**

Run: `$GODOT --headless --import`
Then: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add game/run/salvage_run.gd tests/test_survivor_rescue.gd
git commit -m "feat: survivors only appear once the Crew Quarters stands"
```

---

### Task 4: Speech bubble and lettered fallback on the plot pad

**Files:**
- Modify: `game/base/plot_node.gd`
- Test: `tests/test_plot_node.gd`

**Interfaces:**
- Consumes: nothing new.
- Produces: IslandPlotNode reads two optional state keys: `bubble: String` (nonempty shows a rounded white bubble floating above the pad with that text) and `letter: String` (shown large on the pad only when the state is NOT "empty" and the art texture failed to load). Internal nodes `_bubble: PanelContainer`, `_bubble_label: Label`, `_letter_label: Label` (tests reach them directly, matching the file's existing style). Task 6 supplies both keys from `_plot_state`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_plot_node.gd`:

```gdscript
func test_bubble_shows_and_hides_with_the_state() -> void:
	var node := make_node()
	node.render({"kind": "built", "art": "res://game/art/buildings/gardens.png",
		"status": "", "ready": false, "bubble": "+37 scrap"})
	assert_true(node._bubble.visible)
	assert_eq(node._bubble_label.text, "+37 scrap")
	assert_true(node._bubble.position.y < 0.0, "the bubble floats above the pad")
	node.render({"kind": "built", "art": "res://game/art/buildings/gardens.png",
		"status": "", "ready": false})
	assert_false(node._bubble.visible, "no bubble key, no bubble")


func test_missing_built_art_falls_back_to_a_letter() -> void:
	var node := make_node()
	node.render({"kind": "built", "art": "res://game/art/buildings/not_a_building.png",
		"status": "", "ready": false, "letter": "C"})
	assert_null(node._art.texture)
	assert_true(node._letter_label.visible, "an artless building still reads on the map")
	assert_eq(node._letter_label.text, "C")
	node.render({"kind": "built", "art": "res://game/art/buildings/workshop.png",
		"status": "", "ready": false, "letter": "W"})
	assert_false(node._letter_label.visible, "delivered art silences the letter")


func test_empty_pad_never_shows_a_letter() -> void:
	var node := make_node()
	node.render({"kind": "empty", "status": "", "ready": false, "letter": "X"})
	assert_false(node._letter_label.visible, "the pad art alone marks an empty build spot")
```

(The existing `test_children_never_block_the_tap` will also guard the new children's mouse filters.)

- [ ] **Step 2: Run to verify failure**

Run: `$GODOT --headless --import`
Then: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gselect=test_plot_node.gd -gexit`
Expected: FAIL (`_bubble` not declared).

- [ ] **Step 3: Implement**

In `game/base/plot_node.gd`, add to the var block after `var _ready_badge: Label`:

```gdscript
var _bubble: PanelContainer
var _bubble_label: Label
var _letter_label: Label
```

In `_init`, after the `_ready_badge.visible = false` line, append:

```gdscript
	_letter_label = _child_label(Rect2(16, 4, 96, 96), 40)
	_letter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_letter_label.modulate = Color(1, 1, 1, 0.9)
	_letter_label.visible = false
	# Speech bubble (owner request, 2026-10-17): a drawn rounded panel until
	# bubble art lands in the Phase B art pass.
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bubble_style := StyleBoxFlat.new()
	bubble_style.bg_color = Color(1, 1, 1, 0.92)
	bubble_style.set_corner_radius_all(12)
	bubble_style.content_margin_left = 10.0
	bubble_style.content_margin_right = 10.0
	bubble_style.content_margin_top = 4.0
	bubble_style.content_margin_bottom = 4.0
	_bubble.add_theme_stylebox_override("panel", bubble_style)
	_bubble_label = Label.new()
	_bubble_label.add_theme_font_size_override("font_size", 14)
	_bubble_label.add_theme_color_override("font_color", Color(0.13, 0.17, 0.32))
	_bubble_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(_bubble_label)
	_bubble.visible = false
	add_child(_bubble)
```

In `render`, after the `_art.modulate.a = ...` line, add:

```gdscript
	# The lettered fallback keeps an artless BUILT building legible (the Crew
	# Quarters ships before its illustration); empty pads keep their pad art.
	if not _empty and _art.texture == null:
		_letter_label.text = String(state.get("letter", ""))
		_letter_label.visible = _letter_label.text != ""
	else:
		_letter_label.visible = false
	var bubble_text := String(state.get("bubble", ""))
	_bubble_label.text = bubble_text
	_bubble.visible = bubble_text != ""
	if _bubble.visible:
		_bubble.reset_size()
		_bubble.position = Vector2((PLOT_SIZE - _bubble.size.x) / 2.0, -36.0)
```

- [ ] **Step 4: Run the FULL suite**

Run: `$GODOT --headless --import`
Then: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add game/base/plot_node.gd tests/test_plot_node.gd
git commit -m "feat: plot pads grow a speech bubble and a lettered art fallback"
```

---

### Task 5: HUD teardown part 1: crates to the sky, slot into the modal, map to the bottom

**Files:**
- Modify: `game/base/island_screen.tscn`
- Modify: `game/base/island_screen.gd`
- Test: `tests/test_island_screen.gd`

**Interfaces:**
- Consumes: existing handlers `_on_crate_pressed`, `_on_bonus_crate_pressed`; `IslandModel.unlock_second_slot`, `IslandModel.active_constructions`.
- Produces: scene nodes `DailyCrateIcon`, `BonusCrateIcon` (TextureButtons), `BonusCrateIcon/AdBadge`, `BuildModal/VBox/ModalSlotButton`; screen methods `_refresh_modal_slot_offer()` and `_on_modal_slot_pressed()`. `_on_slot_pressed` is DELETED. GardensButton, CrateButton, BonusCrateButton, SlotButton scene nodes are DELETED (`_on_gardens_pressed` the method survives until Task 6 renames it). Task 6 relies on the scene already lacking those four nodes.

- [ ] **Step 1: Write the failing tests**

In `tests/test_island_screen.gd`:

1a. DELETE these two whole test functions:

```gdscript
func test_slot_button_unlocks_second_slot() -> void:
	GameState.data["currencies"]["crystals"] = 30
	screen._on_slot_pressed()
	assert_eq(int(GameState.data["island"]["build_slots"]), 2)
	assert_eq(Economy.balance("crystals"), 10)
```

and

```gdscript
func test_slot_button_disabled_when_crystals_are_short() -> void:
	GameState.data["currencies"]["crystals"] = 0
	screen._rebuild()
	assert_true(screen.get_node("SlotButton").disabled)
```

1b. In their place (where the first deleted test sat), add:

```gdscript
func test_modal_offers_the_second_slot_when_builders_are_busy() -> void:
	GameState.data["currencies"]["crystals"] = 30
	screen._open_build_modal("plot_0")
	screen._on_modal_confirm_pressed()
	screen._open_build_modal("plot_1")
	var offer: Button = screen.get_node("BuildModal/VBox/ModalSlotButton")
	assert_true(offer.visible, "every builder busy and a slot still for sale")
	assert_string_contains(offer.text, "20 crystals")
	screen._on_modal_slot_pressed()
	assert_eq(int(GameState.data["island"]["build_slots"]), 2)
	assert_eq(Economy.balance("crystals"), 10)
	assert_false(offer.visible, "bought: the offer leaves the modal")
	assert_true(screen.get_node("BuildModal").visible, "the player carries on building")

func test_modal_slot_offer_disabled_when_crystals_are_short() -> void:
	GameState.data["currencies"]["crystals"] = 0
	screen._open_build_modal("plot_0")
	screen._on_modal_confirm_pressed()
	screen._open_build_modal("plot_1")
	assert_true(screen.get_node("BuildModal/VBox/ModalSlotButton").visible)
	assert_true(screen.get_node("BuildModal/VBox/ModalSlotButton").disabled)

func test_modal_hides_the_slot_offer_while_a_builder_is_free() -> void:
	screen._open_build_modal("plot_0")
	assert_false(screen.get_node("BuildModal/VBox/ModalSlotButton").visible)

func test_modal_never_offers_a_third_slot() -> void:
	GameState.data["island"]["build_slots"] = 2
	GameState.data["currencies"]["crystals"] = 30
	screen._open_build_modal("plot_0")
	screen._on_modal_confirm_pressed()
	screen._open_build_modal("plot_1")
	screen._on_modal_confirm_pressed()
	screen._open_build_modal("plot_2")
	assert_false(screen.get_node("BuildModal/VBox/ModalSlotButton").visible,
		"both builders busy but there is no third slot to sell")

func test_crate_icons_float_only_while_claimable() -> void:
	GameState.data["daily_crate"]["last_claim_day"] = 0
	screen._rebuild()
	assert_true(screen.get_node("DailyCrateIcon").visible)
	assert_true(screen.get_node("BonusCrateIcon").visible)
	screen._on_crate_pressed()
	assert_false(screen.get_node("DailyCrateIcon").visible, "claimed today: the icon leaves the sky")
	screen._on_bonus_crate_pressed()
	assert_false(screen.get_node("BonusCrateIcon").visible, "the ad crate obeys its daily limit")

func test_the_hud_row_is_gone() -> void:
	for gone in ["GardensButton", "CrateButton", "BonusCrateButton", "SlotButton"]:
		assert_null(screen.get_node_or_null(String(gone)),
			"%s dissolved into the map (owner request, 2026-10-17)" % String(gone))
```

- [ ] **Step 2: Run to verify failure**

Run: `$GODOT --headless --import`
Then: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gselect=test_island_screen.gd -gexit`
Expected: FAIL (ModalSlotButton and the icons do not exist; the HUD nodes still do).

- [ ] **Step 3: Edit the scene**

In `game/base/island_screen.tscn`:

3a. DELETE these four whole node blocks (each starts at its `[node name=...` line and ends before the next `[node`):

```
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
offset_right = 280.0
offset_bottom = 1216.0
text = "Unlock 2nd build slot"
```

3b. Extend the map to the bottom. Change the MapScroll node's `offset_bottom = 1080.0` to `offset_bottom = 1270.0`. Change the MapMist node's `offset_top = 950.0` to `offset_top = 1140.0` and its `offset_bottom = 1080.0` to `offset_bottom = 1270.0`.

3c. Move the BackButton to the top left. Replace its block with:

```
[node name="BackButton" type="Button" parent="."]
offset_left = 10.0
offset_top = 14.0
offset_right = 150.0
offset_bottom = 70.0
text = "Back"
```

3d. Immediately after the RefreshTimer node block, add the crate icons:

```
[node name="DailyCrateIcon" type="TextureButton" parent="."]
visible = false
offset_left = 640.0
offset_top = 14.0
offset_right = 708.0
offset_bottom = 82.0
ignore_texture_size = true
stretch_mode = 5

[node name="BonusCrateIcon" type="TextureButton" parent="."]
visible = false
offset_left = 640.0
offset_top = 92.0
offset_right = 708.0
offset_bottom = 160.0
ignore_texture_size = true
stretch_mode = 5

[node name="AdBadge" type="TextureRect" parent="BonusCrateIcon"]
offset_left = 40.0
offset_top = 40.0
offset_right = 68.0
offset_bottom = 68.0
mouse_filter = 2
expand_mode = 1
stretch_mode = 5
```

3e. In BuildModal/VBox, immediately after the ModalStatus node block and before the NavRow block, add:

```
[node name="ModalSlotButton" type="Button" parent="BuildModal/VBox"]
visible = false
text = "Hire a second builder"
```

- [ ] **Step 4: Edit the script**

In `game/base/island_screen.gd`:

4a. In `_ready`, DELETE these three lines:

```gdscript
	$GardensButton.pressed.connect(_on_gardens_pressed)
	$CrateButton.pressed.connect(_on_crate_pressed)
	$SlotButton.pressed.connect(_on_slot_pressed)
```

and this line:

```gdscript
	$BonusCrateButton.pressed.connect(_on_bonus_crate_pressed)
```

4b. In `_ready`, after the line `$RefreshTimer.timeout.connect(_refresh_tick)`, add:

```gdscript
	$DailyCrateIcon.pressed.connect(_on_crate_pressed)
	$BonusCrateIcon.pressed.connect(_on_bonus_crate_pressed)
	$BuildModal/VBox/ModalSlotButton.pressed.connect(_on_modal_slot_pressed)
	if ResourceLoader.exists("res://game/art/icons/daily_crate.png"):
		$DailyCrateIcon.texture_normal = load("res://game/art/icons/daily_crate.png")
	if ResourceLoader.exists("res://game/art/icons/bonus_crate.png"):
		$BonusCrateIcon.texture_normal = load("res://game/art/icons/bonus_crate.png")
	if ResourceLoader.exists("res://game/art/icons/ad_badge.png"):
		$BonusCrateIcon/AdBadge.texture = load("res://game/art/icons/ad_badge.png")
```

4c. In `_ready`, in the modal-button styling loop, change the path list from:

```gdscript
	for path in ["NavRow/PrevButton", "NavRow/NextButton", "ActionRow/ConfirmButton", "ActionRow/CancelButton"]:
```

to:

```gdscript
	for path in ["NavRow/PrevButton", "NavRow/NextButton", "ActionRow/ConfirmButton", "ActionRow/CancelButton", "ModalSlotButton"]:
```

4d. Replace the whole `_refresh_static_controls` function with:

```gdscript
func _refresh_static_controls(now: int) -> void:
	# The HUD row dissolved into the map (owner request, 2026-10-17): crates
	# float top right only while claimable; the trickle, the 2nd slot, the
	# workshop and the crew live on the pads, in the modal and in the sheets.
	$DailyCrateIcon.visible = DailyCrate.can_claim(GameState.data, now)
	$BonusCrateIcon.visible = Ads.service.is_available(AdService.Placement.BONUS_CRATE) \
		and AdLimits.can_use(GameState.data, "bonus_crate", _bonus_crate_limit(), now)
```

4e. Replace the whole `_on_slot_pressed` function with these two functions:

```gdscript
func _refresh_modal_slot_offer() -> void:
	# The 2nd build slot moved from the HUD into the moment it matters: the
	# player is trying to build and every builder is busy (owner request,
	# 2026-10-17).
	var slots_cfg: Dictionary = DataDefs.buildings.get("build_slots", {})
	var slots := int(GameState.data["island"].get("build_slots", 1))
	var offer: Button = $BuildModal/VBox/ModalSlotButton
	offer.visible = slots < int(slots_cfg.get("max", 2)) \
		and IslandModel.active_constructions(TimerService, TimeUtil.now()) >= slots
	if not offer.visible:
		return
	var cost := int(slots_cfg.get("second_slot_crystal_cost", 20))
	offer.text = "Hire a second builder (%d crystals)" % cost
	offer.disabled = not Economy.can_afford({"crystals": cost})


func _on_modal_slot_pressed() -> void:
	if IslandModel.unlock_second_slot(GameState.data["island"], DataDefs.buildings, Economy):
		GameState.save_game()
	$BuildModal/VBox/ModalStatus.text = ""
	_render_modal()
```

4f. In `_render_modal`, add this as the FIRST line of the function body (before `var building_id := _modal_building()`):

```gdscript
	_refresh_modal_slot_offer()
```

- [ ] **Step 5: Run the FULL suite**

Run: `$GODOT --headless --import`
Then: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS. (The crate payout, reward modal, skip, and notification tests call their handlers directly and keep passing.)

- [ ] **Step 6: Commit**

```bash
git add game/base/island_screen.tscn game/base/island_screen.gd tests/test_island_screen.gd
git commit -m "feat: crates float top right, the 2nd slot sells inside the build modal, the map reaches the bottom"
```

---

### Task 6: HUD teardown part 2: tap gameplay (trickle, bubbles, crew quarters, workshop sheet)

**Files:**
- Modify: `game/base/island_screen.tscn`
- Modify: `game/base/island_screen.gd`
- Test: `tests/test_island_screen.gd`

**Interfaces:**
- Consumes: `CraftModel.craftable_ids` (Task 2), plot-node `bubble`/`letter` keys (Task 4), def `crew_quarters` (Task 1), `TrickleModel.pending/collect`.
- Produces: `_collect_trickle()` (rename of `_on_gardens_pressed`); `_plot_state` emits `bubble` and `letter`; `_on_plot_tapped` routes gardens-with-pending to the collect and built crew_quarters to `_open_crew_sheet()`; the workshop sheet's first action is an "Enter the workshop" button wired to `_on_workshop_pressed`. WorkshopButton and CrewButton scene nodes are DELETED.

- [ ] **Step 1: Write the failing tests**

In `tests/test_island_screen.gd`:

1a. Replace the whole `test_gardens_collect_credits_scrap` function with:

```gdscript
func test_gardens_tap_collects_the_trickle() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	GameState.data["trickle"]["last_collect"] = TimeUtil.now() - 3600
	screen._rebuild()
	var scrap_before := Economy.balance("scrap")
	screen._on_plot_tapped("plot_2")
	assert_eq(Economy.balance("scrap"), scrap_before + 20)
	assert_eq(TrickleModel.pending(GameState.data, DataDefs.buildings, TimeUtil.now()), 0)
	assert_false(screen.get_node("PlotSheet").visible,
		"the tap collects; the vanishing bubble is the receipt (owner request, 2026-10-17)")

func test_gardens_tap_with_nothing_pending_opens_the_sheet() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	GameState.data["trickle"]["last_collect"] = TimeUtil.now()
	screen._rebuild()
	screen._on_plot_tapped("plot_2")
	assert_true(screen.get_node("PlotSheet").visible, "collected out: the next tap talks shop")

func test_gardens_bubble_carries_the_pending_scrap() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	GameState.data["trickle"]["last_collect"] = TimeUtil.now() - 3600
	screen._rebuild()
	assert_eq(String(screen._plot_state("plot_2", TimeUtil.now()).get("bubble", "")), "+20 scrap")
	GameState.data["trickle"]["last_collect"] = TimeUtil.now()
	assert_eq(String(screen._plot_state("plot_2", TimeUtil.now()).get("bubble", "")), "",
		"nothing pending, no bubble")

func test_trickle_bubble_appears_on_a_plain_tick() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	GameState.data["trickle"]["last_collect"] = TimeUtil.now()
	screen._rebuild()
	var node: IslandPlotNode = screen._plot_nodes["plot_2"]
	assert_false(node._bubble.visible)
	GameState.data["trickle"]["last_collect"] = TimeUtil.now() - 3600
	screen._refresh_tick()
	assert_true(node._bubble.visible,
		"pending scrap is not structural; the label refresh path must carry the bubble")

func test_done_gardens_batch_outranks_the_trickle_on_one_tap() -> void:
	GameState.data["island"]["plots"]["plot_2"] = {"building": "gardens", "level": 1}
	GameState.data["trickle"]["last_collect"] = TimeUtil.now() - 3600
	screen._rebuild()
	screen._on_batch_start_pressed("gardens", "put_up_provisions")
	TimerService._state.data["timers"]["convert_gardens"]["ends_at"] = 0
	var scrap_before := Economy.balance("scrap")
	screen._on_plot_tapped("plot_2")
	assert_eq(Economy.balance("provisions"), 2, "the finished batch collects first")
	assert_eq(Economy.balance("scrap"), scrap_before, "the trickle stays for the next tap")
```

1b. Append these new tests after the batch tests (near `test_balloonworks_row_offers_all_three_recipes`):

```gdscript
func test_workshop_bubble_counts_distinct_craftable_gizmos() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	GameState.data["currencies"]["parts"] = 2
	screen._rebuild()
	assert_eq(String(screen._plot_state("plot_0", TimeUtil.now()).get("bubble", "")), "3 craftable",
		"2 parts afford wind_fan, balloon_cluster and cargo_net at workshop level 1")
	GameState.data["currencies"]["parts"] = 0
	assert_eq(String(screen._plot_state("plot_0", TimeUtil.now()).get("bubble", "")), "",
		"no resources means no bubble, never a zero")

func test_workshop_sheet_offers_the_enter_button() -> void:
	GameState.data["island"]["plots"]["plot_0"] = {"building": "workshop", "level": 1}
	screen._rebuild()
	screen._on_plot_tapped("plot_0")
	var first: Button = screen.get_node("PlotSheet/VBox/SheetActions").get_child(0)
	assert_eq(first.text, "Enter the workshop",
		"the HUD Workshop button moved into the workshop's own sheet")

func test_non_workshop_sheet_has_no_enter_button() -> void:
	with_smeltery(1)
	screen._on_plot_tapped("plot_1")
	var first: Button = screen.get_node("PlotSheet/VBox/SheetActions").get_child(0)
	assert_string_contains(first.text, "Upgrade")

func test_crew_quarters_tap_opens_the_crew_sheet() -> void:
	GameState.data["island"]["plots"]["plot_7"] = {"building": "crew_quarters", "level": 1}
	screen._rebuild()
	screen._on_plot_tapped("plot_7")
	assert_true(screen.get_node("CrewSheet").visible,
		"the quarters' sheet IS the crew sheet (owner request, 2026-10-17)")
	assert_false(screen.get_node("PlotSheet").visible)

func test_constructing_crew_quarters_tap_opens_the_plot_sheet() -> void:
	screen._open_build_modal("plot_7")
	while screen._modal_building() != "crew_quarters":
		screen._on_modal_next_pressed()
	screen._on_modal_confirm_pressed()
	screen._on_plot_tapped("plot_7")
	assert_true(screen.get_node("PlotSheet").visible, "a countdown, not a roster")
	assert_false(screen.get_node("CrewSheet").visible)

func test_built_plot_without_art_states_its_letter() -> void:
	GameState.data["island"]["plots"]["plot_7"] = {"building": "crew_quarters", "level": 1}
	screen._rebuild()
	assert_eq(String(screen._plot_state("plot_7", TimeUtil.now()).get("letter", "")), "C",
		"the lettered fallback carries the Crew Quarters until its art lands")
```

1c. Replace the whole `test_crew_button_opens_the_crew_sheet` function with nothing (DELETE it; the crew_quarters tap test above replaces it).

1d. In `test_gardens_collect_pays_the_crewed_rate`, replace the line:

```gdscript
	screen._on_gardens_pressed()
```

with:

```gdscript
	screen._on_plot_tapped("plot_2")
```

1e. In `test_the_hud_row_is_gone` (added by Task 5), replace the list line:

```gdscript
	for gone in ["GardensButton", "CrateButton", "BonusCrateButton", "SlotButton"]:
```

with:

```gdscript
	for gone in ["GardensButton", "CrateButton", "BonusCrateButton", "SlotButton", "WorkshopButton", "CrewButton"]:
```

- [ ] **Step 2: Run to verify failure**

Run: `$GODOT --headless --import`
Then: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gselect=test_island_screen.gd -gexit`
Expected: FAIL (no bubble key, taps open sheets, WorkshopButton and CrewButton still exist).

- [ ] **Step 3: Edit scene and script**

3a. In `game/base/island_screen.tscn`, DELETE these two whole node blocks:

```
[node name="CrewButton" type="Button" parent="."]
offset_left = 290.0
offset_top = 1160.0
offset_right = 420.0
offset_bottom = 1216.0
text = "Crew"

[node name="WorkshopButton" type="Button" parent="."]
offset_left = 430.0
offset_top = 1160.0
offset_right = 560.0
offset_bottom = 1216.0
text = "Workshop"
```

3b. In `game/base/island_screen.gd` `_ready`, DELETE these two lines:

```gdscript
	$WorkshopButton.pressed.connect(_on_workshop_pressed)
```

```gdscript
	$CrewButton.pressed.connect(_open_crew_sheet)
```

3c. In `_plot_state`, in the CONSTRUCTING branch, extend the state dictionary. Replace:

```gdscript
		var state := {
			"kind": "constructing",
			"art": "res://game/art/buildings/%s.png" % building,
			"status": "%ds" % TimerService.remaining(timer_id, now),
			"ready": false,
		}
```

with:

```gdscript
		var state := {
			"kind": "constructing",
			"art": "res://game/art/buildings/%s.png" % building,
			"status": "%ds" % TimerService.remaining(timer_id, now),
			"ready": false,
			"letter": String((defs.get(building, {}) as Dictionary).get("name", building)).left(1),
		}
```

3d. In `_plot_state`, in the BUILT branch, just before its `return state` line (after the convert-timer block), add:

```gdscript
		state["letter"] = String(def.get("name", building)).left(1)
		# Speech bubbles (owner request, 2026-10-17): the gardens advertise
		# their pending trickle, the workshop its craftable count. Zero means
		# no bubble, never a zero.
		if building == "gardens":
			var pending_scrap := TrickleModel.pending(GameState.data, DataDefs.buildings, now, DataDefs.crew)
			if pending_scrap > 0:
				state["bubble"] = "+%d scrap" % pending_scrap
		elif building == "workshop":
			var craftable := CraftModel.craftable_ids(GameState.data, DataDefs.gizmos, Economy).size()
			if craftable > 0:
				state["bubble"] = "%d craftable" % craftable
```

3e. In `_on_plot_tapped`, replace the tail of the function:

```gdscript
	var building := String((plots[plot] as Dictionary).get("building", ""))
	var convert_id := "convert_" + building
	if TimerService.active_timers().has(convert_id) and TimerService.is_done(convert_id, now):
		_on_batch_collect_pressed(building)
		return
	_open_plot_sheet(plot)
```

with:

```gdscript
	var building := String((plots[plot] as Dictionary).get("building", ""))
	var convert_id := "convert_" + building
	if TimerService.active_timers().has(convert_id) and TimerService.is_done(convert_id, now):
		_on_batch_collect_pressed(building)
		return
	if building == "gardens" and TrickleModel.pending(GameState.data, DataDefs.buildings, now, DataDefs.crew) > 0:
		# The trickle collects on the tap itself; the vanishing bubble is the
		# receipt, and the next tap opens the sheet as before (owner request,
		# 2026-10-17).
		_collect_trickle()
		return
	if building == "crew_quarters":
		# The Crew button left the HUD; the quarters' sheet IS the crew sheet.
		_open_crew_sheet()
		return
	_open_plot_sheet(plot)
```

3f. Rename `_on_gardens_pressed` to `_collect_trickle` (the body is unchanged):

```gdscript
func _collect_trickle() -> void:
	var amount := TrickleModel.collect(GameState.data, DataDefs.buildings, TimeUtil.now(), DataDefs.crew)
	if amount > 0:
		Economy.add("scrap", amount)
		GameState.save_game()
	_rebuild()
```

3g. In `_render_sheet`, in the non-constructing branch, just before the `var upgrade := Button.new()` line, add:

```gdscript
	if building == "workshop":
		# The HUD Workshop button moved into the workshop's own sheet
		# (owner request, 2026-10-17).
		var enter := Button.new()
		enter.text = "Enter the workshop"
		enter.pressed.connect(_on_workshop_pressed)
		_style_sheet_button(enter)
		actions.add_child(enter)
```

- [ ] **Step 4: Run the FULL suite**

Run: `$GODOT --headless --import`
Then: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS. Watch for ripples: `test_builds_map_nodes_for_plots_islets_and_crew` (pad count follows plot_count), the assign-cycle tests (crew_quarters is not workable, so the cycle is untouched), and the Task 5 modal tests (plot_7 now exists for `test_constructing_crew_quarters_tap_opens_the_plot_sheet`).

- [ ] **Step 5: Commit**

```bash
git add game/base/island_screen.tscn game/base/island_screen.gd tests/test_island_screen.gd
git commit -m "feat: trickle, crew and workshop move onto the map's own buildings"
```

---

### Task 7: Audit doc stamp and final gate

**Files:**
- Modify: `docs/art/placeholder-graphics-audit.md`

**Interfaces:** none; documentation plus the suite gate.

- [ ] **Step 1: Stamp the audit**

In `docs/art/placeholder-graphics-audit.md`, find the art-brief table added for the island map (rows like "Empty plot pad") and append these two rows to that table:

```markdown
| Crew Quarters illustration | 256 x 256 | Bunkhouse with a kettle chimney, matching the other home-building illustrations. File: `game/art/buildings/crew_quarters.png`; a lettered pad fallback draws until it exists. |
| Speech bubble | ~128 x 48 | Rounded comic bubble for the gardens/workshop pending counters. A drawn StyleBoxFlat panel carries it until delivered. |
```

Then, in the same file's wiring-status header paragraph, append this sentence at the end of the paragraph:

```markdown
The bottom HUD row is gone (2026-10-17): crates float top right as icons, the 2nd slot sells inside the build modal, the trickle collects on the Gardens pad, the Workshop sheet carries the enter button, and the new Crew Quarters opens the crew sheet.
```

- [ ] **Step 2: Run the FULL suite one last time**

Run: `$GODOT --headless --import`
Then: `$GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS.
Then run `git status --porcelain` and stage any straggler `.gd.uid` sidecars.

- [ ] **Step 3: Commit**

```bash
git add docs/art/placeholder-graphics-audit.md
git commit -m "docs: audit rows for the crew quarters art and speech bubbles"
```
