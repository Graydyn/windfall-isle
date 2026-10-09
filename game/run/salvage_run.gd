extends Node2D
## Glue for one expedition: a SETUP phase over the built board (drag gizmos
## into slots, fuel unspent), then Start spends fuel, installs gizmos, and
## runs the drops. Loot is credited per catch, so abandoning or being killed
## by the OS never loses anything (spec 3.2; fuel-on-Start amended by the
## 2026-08-23 drag-drop setup spec).

const PodScene := preload("res://game/run/pod.tscn")
const SlotTargetScript := preload("res://game/run/slot_target.gd")

var model: RunModel
var pod_defs: Dictionary
var _next_barge_multiplier := 1.0
var _payout_doubled := false
var _rng := RandomNumberGenerator.new()
var _current_offer: Array = []
var _offer_rerolled := false
var _pending_offers := 0
var _island_mult := 1.0

enum Phase { SETUP, RUNNING, OVER }
var _phase := Phase.SETUP
var _region_id := ""
var _survivor_id := ""
var _survivor_from_left := true
var _kit_elected: Dictionary = {}
var _provision_mult := 1.0
var _free_rerolls := 0

@onready var board: Skyfield = $Skyfield
@onready var controller: DropController = $DropController


func _ready() -> void:
	var run_defs: Dictionary = DataDefs.run
	pod_defs = run_defs.get("pod", {})
	_region_id = RegionModel.selected_id(GameState.data, run_defs, GameState.data["island"])
	var region: Dictionary = DataDefs.skyfield(_region_id)
	var run_config: Dictionary = run_defs.duplicate()
	run_config["drops_per_run"] = IslandEffects.drops_per_run(run_defs, GameState.data["island"], DataDefs.buildings)
	run_config["quota_tiers"] = region.get("quota_tiers", [])
	model = RunModel.new(run_config)
	# Island state cannot change mid-run; read the Lens Array bonus once.
	_island_mult = IslandEffects.payout_multiplier(GameState.data["island"], DataDefs.buildings)
	board.build(region, run_defs, _region_id)
	controller.configure(region.get("board", {}), float(pod_defs.get("radius", 12.0)))
	board.pod_caught.connect(_on_pod_caught)
	controller.drop_requested.connect(_on_drop_requested)
	model.run_over.connect(_on_run_over)
	model.tier_reached.connect(_on_tier_reached)
	_rng.seed = TimeUtil.now()
	for i in 3:
		($UI/BoonOffer/VBox.get_node("Pick%d" % i) as Button).pressed.connect(_on_boon_picked.bind(i))
	$UI/BoonOffer/VBox/RerollButton.pressed.connect(_on_reroll_pressed)
	$UI/BoonOffer/VBox/SkipButton.pressed.connect(_on_boon_skipped)
	$UI/AbandonButton.pressed.connect(_on_abandon_pressed)
	$UI/Results/VBox/ReturnButton.pressed.connect(_on_return_pressed)
	$UI/Results/VBox/DoubleButton.pressed.connect(_on_double_pressed)
	controller.enabled = false
	$UI/AbandonButton.visible = false
	# Godot's default panel stylebox is translucent; menus on this screen sit
	# over the busy skyfield, so they get solid backing (owner request,
	# 2026-10-09: no transparent menu backgrounds here).
	for panel in [$UI/SetupUI/KitPanel, $UI/SetupUI/TrayPanel, $UI/Results, $UI/BoonOffer]:
		(panel as PanelContainer).add_theme_stylebox_override("panel", _opaque_panel_style())
	$UI/SetupUI/StartButton.pressed.connect(_on_start_pressed)
	$UI/SetupUI/BackButton.pressed.connect(_on_setup_back_pressed)
	$UI/SetupUI/SetupRefreshTimer.timeout.connect(_setup_tick)
	_setup_tick()
	_build_setup_ui(region)
	_build_kit_panel()
	_refresh_hud()


func _on_drop_requested(x: float) -> void:
	if _phase != Phase.RUNNING:
		return
	if not model.begin_drop():
		return
	var pod: Pod = PodScene.instantiate()
	pod.position = Vector2(x, controller.drop_y)
	pod.setup(pod_defs)
	board.add_child(pod)
	_start_watchdog(pod)
	_refresh_hud()


func _start_watchdog(pod: Pod) -> void:
	# A child Timer dies with this scene and a WeakRef survives the pod being
	# freed; a SceneTreeTimer bound to the raw pod errors on both counts
	# (freed pods fail typed-argument marshalling before the handler runs).
	var watchdog := Timer.new()
	watchdog.one_shot = true
	watchdog.wait_time = float(DataDefs.run.get("pod_timeout_seconds", 12.0))
	add_child(watchdog)
	watchdog.timeout.connect(_on_pod_timeout.bind(weakref(pod), watchdog))
	watchdog.start()


func _on_pod_caught(pod: Node, payout: Dictionary, source: String = "barge") -> void:
	payout = _compute_payout(pod, payout)
	var source_mult := 1.0
	if source == "barge":
		source_mult = model.barge_boon_multiplier()
		if _next_barge_multiplier > 1.0:
			# Chime Bell: one-shot, consumed only by a barge catch, composing
			# multiplicatively with the run-long Barge Bounty boon.
			source_mult *= _next_barge_multiplier
			_next_barge_multiplier = 1.0
	elif source == "sea":
		source_mult = model.sea_boon_multiplier()
	if not is_equal_approx(source_mult, 1.0):
		var boosted := {}
		for currency in payout:
			var value := roundi(float(payout[currency]) * source_mult)
			if value > 0:
				boosted[currency] = value
		payout = boosted
	var bonus := model.bonus_scrap_per_catch()
	if bonus > 0 and not payout.is_empty():
		# Heavy Loot: flat scrap after all multipliers; empty payouts stay
		# empty so "nothing salvaged" remains truthful.
		payout = payout.duplicate()
		payout["scrap"] = int(payout.get("scrap", 0)) + bonus
	if is_instance_valid(pod):
		pod.queue_free()
	for currency in payout:
		Economy.add(currency, int(payout[currency]))
	model.resolve_pod(payout)
	_refresh_hud()


func _on_pod_timeout(pod_ref: WeakRef, watchdog: Timer) -> void:
	# Watchdog: a pod balanced on a peg must never deadlock the run.
	watchdog.queue_free()
	var pod: Node = pod_ref.get_ref()
	if pod == null or pod.has_meta("caught"):
		return
	pod.set_meta("caught", true)
	_on_pod_caught(pod, board.sea_payout.duplicate(), "sea")


func _on_run_over() -> void:
	_phase = Phase.OVER
	controller.enabled = false
	$UI/BoonOffer.visible = false
	_pending_offers = 0
	_current_offer = []
	for pod in get_tree().get_nodes_in_group("pods"):
		pod.set_meta("caught", true)
		pod.queue_free()
	for survivor in get_tree().get_nodes_in_group("survivors"):
		survivor.queue_free()
	GameState.save_game()
	$UI/Results/VBox/Summary.text = _summary_text()
	$UI/Results/VBox/DoubleButton.visible = Ads.service.is_available(AdService.Placement.PAYOUT_DOUBLE) \
		and not model.loot.is_empty()
	$UI/Results/VBox/DoubleButton.disabled = false
	$UI/Results.visible = true


func _on_abandon_pressed() -> void:
	if _phase != Phase.RUNNING:
		return
	model.abandon()


func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://game/main.tscn")


func _on_start_pressed() -> void:
	# The single commit point (spec: fuel-on-Start). Back before this is free.
	if _phase != Phase.SETUP:
		return
	var cost := RegionModel.fuel_cost(RegionModel.entry(DataDefs.run, _region_id), GameState.data["island"])
	if not FuelModel.spend(GameState.data["fuel"], cost, TimeUtil.now()):
		$UI/SetupUI/SetupStatus.text = "Not enough fuel."
		return
	_consume_kit()
	GameState.save_game()
	var gizmos_state: Dictionary = GameState.data["gizmos"]
	board.install_gizmos(
		GizmoLoadout.loadout_for(gizmos_state, _region_id),
		DataDefs.gizmos,
		GizmoLoadout.owned(gizmos_state),
		self)
	_phase = Phase.RUNNING
	$UI/SetupUI.visible = false
	$UI/SetupUI/SetupRefreshTimer.stop()
	$UI/AbandonButton.visible = true
	controller.enabled = true
	_maybe_schedule_survivor()
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
	_refresh_kit_panel()


func _build_kit_panel() -> void:
	var kit: Dictionary = DataDefs.run.get("kit", {})
	var flow: HFlowContainer = $UI/SetupUI/KitPanel/KitFlow
	for kit_id in ["ballast", "wind_charm", "storm_oil", "provision"]:
		if not kit.has(kit_id):
			continue
		var chip := Button.new()
		chip.toggle_mode = true
		chip.name = "Kit_" + kit_id
		# The panel owns the top band (the setup prompt lives in SetupStatus,
		# and the HUD label is blank until the run starts); it must stay above
		# y=132 where regions 3/4 slot targets begin (guarded by
		# test_kit_panel_intersects_no_slot_target_in_any_region), so the
		# chips hold two text lines via a 14px font.
		chip.custom_minimum_size = Vector2(332.0, 46.0)
		chip.add_theme_font_size_override("font_size", 14)
		# PASS, not STOP: the chip still takes its press, but a drag-drop
		# released over the kit area falls through to any slot target beneath
		# (region 2's lowest slots overlap this rect; Plan 9 drop-walk lesson).
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.toggled.connect(_on_kit_toggled.bind(kit_id))
		flow.add_child(chip)
	_refresh_kit_panel()


func _on_kit_toggled(pressed: bool, kit_id: String) -> void:
	if _phase != Phase.SETUP:
		return
	_kit_elected[kit_id] = pressed
	_refresh_kit_panel()


func _refresh_kit_panel() -> void:
	var kit: Dictionary = DataDefs.run.get("kit", {})
	for chip_node in $UI/SetupUI/KitPanel/KitFlow.get_children():
		var chip := chip_node as Button
		var kit_id := String(chip.name).trim_prefix("Kit_")
		var entry: Dictionary = kit.get(kit_id, {})
		var display := String(entry.get("name", kit_id))
		var affordable: bool
		if kit_id == "provision":
			var cost := int(entry.get("cost", 3))
			chip.text = "%s\n%s" % [display, _kit_blurb(kit_id, entry)]
			affordable = Economy.balance("provisions") >= cost
		else:
			chip.text = "%s x%d\n%s" % [display, Economy.balance(kit_id), _kit_blurb(kit_id, entry)]
			affordable = Economy.balance(kit_id) >= 1
		chip.disabled = not affordable
		if not affordable and chip.button_pressed:
			chip.set_pressed_no_signal(false)
			_kit_elected[kit_id] = false


func _kit_blurb(kit_id: String, entry: Dictionary) -> String:
	# One-line effect text on each kit chip; numbers read from the defs so the
	# label can never drift from what _apply_consumable actually grants.
	if kit_id == "ballast":
		return "+%d extra drops this run" % int(entry.get("drops_bonus", 2))
	if kit_id == "wind_charm":
		var rerolls := int(entry.get("free_rerolls", 1))
		return "Free boon reroll" if rerolls == 1 else "%d free boon rerolls" % rerolls
	if kit_id == "storm_oil":
		return "Bouncier pods this run"
	if kit_id == "provision":
		var pct := roundi((float(entry.get("payout_multiplier", 1.15)) - 1.0) * 100.0)
		return "+%d%% payouts (%d provisions)" % [pct, int(entry.get("cost", 3))]
	return ""


func _consume_kit() -> void:
	# Run-kit spec section 5: elections are paid only after the fuel spend
	# succeeds; an unaffordable election is silently dropped, never blocking.
	var kit: Dictionary = DataDefs.run.get("kit", {})
	for kit_id in _kit_elected:
		if not bool(_kit_elected[kit_id]):
			continue
		var entry: Dictionary = kit.get(String(kit_id), {})
		if String(kit_id) == "provision":
			if Economy.pay({"provisions": int(entry.get("cost", 3))}):
				_provision_mult = float(entry.get("payout_multiplier", 1.15))
		elif Economy.pay({String(kit_id): 1}):
			_apply_consumable(String(kit_id), entry)


func _apply_consumable(kit_id: String, entry: Dictionary) -> void:
	if kit_id == "ballast":
		model.add_drops(int(entry.get("drops_bonus", 2)))
	elif kit_id == "wind_charm":
		_free_rerolls += int(entry.get("free_rerolls", 1))
	elif kit_id == "storm_oil":
		# Featherfall pattern: duplicate before bumping; the shared defs are
		# never mutated.
		pod_defs = pod_defs.duplicate()
		pod_defs["bounce"] = minf(1.0, float(pod_defs.get("bounce", 0.55)) + float(entry.get("bounce_bonus", 0.15)))


func _maybe_schedule_survivor() -> void:
	# Crew spec section 6: at most one survivor per run, drawn on the scene's
	# injected rng, only while someone is still out there.
	var pool := CrewModel.unrescued_ids(GameState.data, DataDefs.crew)
	if pool.is_empty():
		return
	var survivor_defs: Dictionary = DataDefs.crew.get("survivor", {})
	if _rng.randf() >= float(survivor_defs.get("chance_per_run", 0.25)):
		return
	_survivor_id = String(pool[_rng.randi_range(0, pool.size() - 1)])
	_survivor_from_left = _rng.randf() < 0.5
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = _rng.randf_range(float(survivor_defs.get("spawn_delay_min", 2.0)), float(survivor_defs.get("spawn_delay_max", 8.0)))
	add_child(timer)
	timer.timeout.connect(_spawn_survivor.bind(timer))
	timer.start()


func _spawn_survivor(timer: Timer) -> void:
	timer.queue_free()
	if _phase != Phase.RUNNING or _survivor_id == "":
		return
	var survivor := Survivor.new()
	var board_rect: Dictionary = DataDefs.skyfield(_region_id).get("board", {})
	survivor.setup(_survivor_id, DataDefs.crew.get("survivor", {}), _survivor_from_left, board_rect)
	survivor.rescued.connect(_on_survivor_rescued)
	board.add_child(survivor)


func _on_survivor_rescued(crew_id: String) -> void:
	if not CrewModel.rescue(GameState.data, crew_id):
		return
	# Persist instantly: a rescue must survive an OS kill (save-anywhere).
	GameState.save_game()
	var member := CrewModel.entry(DataDefs.crew, crew_id)
	$UI/RescueBanner.text = "Rescued %s! \"%s\"" % [String(member.get("name", crew_id)), String(member.get("line", ""))]
	$UI/RescueBanner.visible = true
	var hide := Timer.new()
	hide.one_shot = true
	hide.wait_time = 4.0
	add_child(hide)
	hide.timeout.connect(_hide_banner.bind(hide))
	hide.start()


func _hide_banner(timer: Timer) -> void:
	timer.queue_free()
	$UI/RescueBanner.visible = false


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
	# set_script also installs SlotTarget._draw on the panel; slot_id "" keeps
	# it from painting a slot outline over the tray.
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
		chip.custom_minimum_size = Vector2(110.0, 96.0)
		chip.set_dimmed(placed.has(id))
		flow.add_child(chip)


func _opaque_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.15, 0.19)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _chip_text(gizmo_id: String) -> String:
	var def: Dictionary = (DataDefs.gizmos.get("defs", {}) as Dictionary).get(gizmo_id, {})
	return String(def.get("name", gizmo_id))


func _compute_payout(pod: Node, base: Dictionary) -> Dictionary:
	# Central payout resolution: the run's quota-tier multiplier and the
	# pod-carried multipliers (Crystal Prism, Splitter Vane) apply here so
	# every catch path (barge, sea, watchdog) gets identical treatment.
	var mult := model.payout_multiplier() * _island_mult * _provision_mult
	if is_instance_valid(pod) and pod.has_meta("value_mult"):
		mult *= float(pod.get_meta("value_mult"))
	if is_equal_approx(mult, 1.0):
		return base.duplicate()
	var out := {}
	for currency in base:
		var value := roundi(float(base[currency]) * mult)
		if value > 0:
			out[currency] = value
	return out


func _refresh_hud() -> void:
	if _phase == Phase.SETUP:
		# The kit panel owns the top band during setup; the prompt shows in
		# SetupStatus by the Start button instead (until a fuel error replaces it).
		$UI/HudLabel.text = ""
		if String($UI/SetupUI/SetupStatus.text) == "":
			$UI/SetupUI/SetupStatus.text = "Place your gizmos, then press Start."
		return
	var parts := PackedStringArray()
	for currency in model.loot:
		parts.append("%s +%d" % [currency, int(model.loot[currency])])
	$UI/HudLabel.text = "Drops left: %d   Tier %d\n%s" % [model.drops_remaining(), model.tier, " ".join(parts)]


func _summary_text() -> String:
	if model.loot.is_empty():
		return "Expedition complete.\nNothing salvaged this time."
	var lines := PackedStringArray(["Expedition complete. Salvaged:"])
	for currency in model.loot:
		lines.append("  %s: %d" % [currency, int(model.loot[currency])])
	return "\n".join(lines)


func add_bonus(payout: Dictionary) -> void:
	# Gizmo context: Lightning Jar bonuses credit like any other loot.
	for currency in payout:
		Economy.add(currency, int(payout[currency]))
	model.add_bonus_loot(payout)
	_refresh_hud()


func set_next_barge_multiplier(factor: float) -> void:
	# Gizmo context: Chime Bell. Non-stacking; the strongest pending ring wins.
	_next_barge_multiplier = maxf(_next_barge_multiplier, factor)


func request_split(pod: RigidBody2D) -> bool:
	# Gizmo context: Splitter Vane. The clone mirrors horizontal velocity and
	# carries the original's value_mult (already halved by the vane).
	if not is_instance_valid(pod) or pod.has_meta("caught"):
		return false
	if not model.add_split_pod():
		return false
	var clone: Pod = PodScene.instantiate()
	var side := -1.0 if pod.linear_velocity.x >= 0.0 else 1.0
	clone.position = pod.position + Vector2(30.0 * side, 0.0)
	clone.setup(pod_defs)
	clone.linear_velocity = Vector2(-pod.linear_velocity.x, pod.linear_velocity.y)
	# Absent value_mult meta is fine: _compute_payout falls back to a 1.0
	# default, so only copy the meta when the original actually carries one.
	if pod.has_meta("value_mult"):
		clone.set_meta("value_mult", pod.get_meta("value_mult"))
	clone.set_meta("split", true)
	clone.mark_split()
	if pod is Pod:
		(pod as Pod).mark_split()
	# request_split runs from Area2D.body_entered during a physics-query
	# flush; entering the tree synchronously here throws "Can't change this
	# state while flushing queries", so the add is deferred to end of frame.
	board.add_child.call_deferred(clone)
	_start_watchdog(clone)
	_refresh_hud()
	return true


func _on_double_pressed() -> void:
	if _payout_doubled or not Ads.service.is_available(AdService.Placement.PAYOUT_DOUBLE):
		return
	Ads.service.request_reward(AdService.Placement.PAYOUT_DOUBLE, _grant_payout_double)


func _grant_payout_double() -> void:
	# Once per run (spec 6 placement 3), credited straight to the economy;
	# model.loot stays the true single-run tally.
	if _payout_doubled:
		return
	_payout_doubled = true
	for currency in model.loot:
		Economy.add(currency, int(model.loot[currency]))
	GameState.save_game()
	$UI/Results/VBox/Summary.text = _summary_text() + "\nPayout doubled!"
	$UI/Results/VBox/DoubleButton.disabled = true


func _on_tier_reached(_tier: int) -> void:
	# Spec 3.2 step 4: each tier crossing offers a boon. One rich catch can
	# cross two tiers; the offers queue and serve one at a time.
	_pending_offers += 1
	if not $UI/BoonOffer.visible:
		_show_next_offer()


func _show_next_offer() -> void:
	if _pending_offers <= 0 or model.is_over():
		return
	_pending_offers -= 1
	_current_offer = BoonModel.offer((DataDefs.boons.get("defs", {}) as Dictionary).keys(), model.boons, _rng)
	if _current_offer.is_empty():
		# Exhausted pool (Plan 7 tripwire): nothing to offer, so close out the
		# way a skip would; _close_offer drains any remaining queued offers and
		# re-enables the controller when the run is not over.
		_close_offer()
		return
	_offer_rerolled = false
	controller.enabled = false
	_render_offer()
	$UI/BoonOffer.visible = true


func _render_offer() -> void:
	var defs: Dictionary = DataDefs.boons.get("defs", {})
	for i in 3:
		var button: Button = $UI/BoonOffer/VBox.get_node("Pick%d" % i)
		if i < _current_offer.size():
			var def: Dictionary = defs.get(String(_current_offer[i]), {})
			button.text = "%s\n%s" % [String(def.get("name", _current_offer[i])), String(def.get("description", ""))]
			var icon_path := "res://game/art/icons/boon_%s.png" % String(_current_offer[i])
			button.icon = load(icon_path) if ResourceLoader.exists(icon_path) else null
			button.add_theme_constant_override("icon_max_width", 48)
			button.visible = true
		else:
			button.visible = false
	$UI/BoonOffer/VBox/RerollButton.text = "Reroll (free)" if _free_rerolls > 0 else "Reroll (ad)"
	$UI/BoonOffer/VBox/RerollButton.visible = _has_reroll_candidates() and not _offer_rerolled \
		and (_free_rerolls > 0 or Ads.service.is_available(AdService.Placement.BOON_REROLL))


func _on_boon_picked(index: int) -> void:
	if index >= _current_offer.size():
		return
	var boon_id := String(_current_offer[index])
	model.add_boon(boon_id, DataDefs.boons)
	_apply_scene_boon(boon_id)
	_close_offer()


func _apply_scene_boon(boon_id: String) -> void:
	# Scene-side effects: the model handles payout magnitudes; the scene owns
	# pod construction (Featherfall) and the live gizmo nodes (Second Wind).
	var def: Dictionary = (DataDefs.boons.get("defs", {}) as Dictionary).get(boon_id, {})
	if boon_id == "featherfall":
		pod_defs = pod_defs.duplicate()
		pod_defs["bounce"] = minf(1.0, float(pod_defs.get("bounce", 0.55)) + float(def.get("bounce_bonus", 0.2)))
	elif boon_id == "second_wind":
		for gizmo in board.get_node("Gizmos").get_children():
			(gizmo as GizmoBase).recharge()


func _on_boon_skipped() -> void:
	# Spec: skip forfeits the offer; there is no banking.
	_close_offer()


func _close_offer() -> void:
	$UI/BoonOffer.visible = false
	_current_offer = []
	_refresh_hud()
	if _pending_offers > 0:
		_show_next_offer()
		return
	if not model.is_over() and _phase == Phase.RUNNING:
		controller.enabled = true


func _on_reroll_pressed() -> void:
	if _offer_rerolled or not _has_reroll_candidates():
		return
	if _free_rerolls > 0:
		# Wind Charm (run-kit spec section 5): the free reroll consumes no ad
		# and is used before any ad request; still at most one per offer.
		_free_rerolls -= 1
		_grant_reroll()
		return
	if not Ads.service.is_available(AdService.Placement.BOON_REROLL):
		return
	Ads.service.request_reward(AdService.Placement.BOON_REROLL, _grant_reroll)


func _grant_reroll() -> void:
	# One reroll per offer (spec 6 placement 5), granted at reward time. The
	# current trio joins the exclusions so the redraw is always disjoint;
	# the exclusion is per-reroll only, never permanent. The candidate guard
	# repeats here because the pool can be covered between show and grant.
	if _offer_rerolled or not _has_reroll_candidates():
		return
	_offer_rerolled = true
	var exclusions: Array = (model.boons as Array).duplicate()
	exclusions.append_array(_current_offer)
	var redraw := BoonModel.offer((DataDefs.boons.get("defs", {}) as Dictionary).keys(), exclusions, _rng)
	if not redraw.is_empty():
		_current_offer = redraw
	_render_offer()


func _has_reroll_candidates() -> bool:
	return not BoonModel.reroll_candidates(
		(DataDefs.boons.get("defs", {}) as Dictionary).keys(), model.boons, _current_offer).is_empty()
