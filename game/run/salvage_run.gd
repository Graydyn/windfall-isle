extends Node2D
## Glue for one expedition: DropController -> RunModel -> Pod physics ->
## Skyfield catchers -> Economy. Fuel was already spent by the launcher
## (main.gd); this scene only runs the drops. Loot is credited per catch, so
## abandoning or being killed by the OS never loses anything (spec 3.2).

const PodScene := preload("res://game/run/pod.tscn")

var model: RunModel
var pod_defs: Dictionary
var _next_barge_multiplier := 1.0
var _payout_doubled := false
var _rng := RandomNumberGenerator.new()
var _current_offer: Array = []
var _offer_rerolled := false
var _pending_offers := 0
var _island_mult := 1.0

@onready var board: Skyfield = $Skyfield
@onready var controller: DropController = $DropController


func _ready() -> void:
	var run_defs: Dictionary = DataDefs.run
	pod_defs = run_defs.get("pod", {})
	var region_id := RegionModel.selected_id(GameState.data, run_defs, GameState.data["island"])
	var region: Dictionary = DataDefs.skyfield(region_id)
	var run_config: Dictionary = run_defs.duplicate()
	run_config["drops_per_run"] = IslandEffects.drops_per_run(run_defs, GameState.data["island"], DataDefs.buildings)
	run_config["quota_tiers"] = region.get("quota_tiers", [])
	model = RunModel.new(run_config)
	# Island state cannot change mid-run; read the Lens Array bonus once.
	_island_mult = IslandEffects.payout_multiplier(GameState.data["island"], DataDefs.buildings)
	board.build(region, run_defs)
	var gizmos_state: Dictionary = GameState.data["gizmos"]
	board.install_gizmos(
		GizmoLoadout.loadout_for(gizmos_state, region_id),
		DataDefs.gizmos,
		GizmoLoadout.owned(gizmos_state),
		self)
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
	_refresh_hud()


func _on_drop_requested(x: float) -> void:
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
	controller.enabled = false
	$UI/BoonOffer.visible = false
	_pending_offers = 0
	_current_offer = []
	for pod in get_tree().get_nodes_in_group("pods"):
		pod.set_meta("caught", true)
		pod.queue_free()
	GameState.save_game()
	$UI/Results/VBox/Summary.text = _summary_text()
	$UI/Results/VBox/DoubleButton.visible = Ads.service.is_available(AdService.Placement.PAYOUT_DOUBLE) \
		and not model.loot.is_empty()
	$UI/Results/VBox/DoubleButton.disabled = false
	$UI/Results.visible = true


func _on_abandon_pressed() -> void:
	model.abandon()


func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://game/main.tscn")


func _compute_payout(pod: Node, base: Dictionary) -> Dictionary:
	# Central payout resolution: the run's quota-tier multiplier and the
	# pod-carried multipliers (Crystal Prism, Splitter Vane) apply here so
	# every catch path (barge, sea, watchdog) gets identical treatment.
	var mult := model.payout_multiplier() * _island_mult
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
			button.visible = true
		else:
			button.visible = false
	$UI/BoonOffer/VBox/RerollButton.visible = Ads.service.is_available(AdService.Placement.BOON_REROLL) \
		and not _offer_rerolled


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
	if not model.is_over():
		controller.enabled = true


func _on_reroll_pressed() -> void:
	if _offer_rerolled or not Ads.service.is_available(AdService.Placement.BOON_REROLL):
		return
	Ads.service.request_reward(AdService.Placement.BOON_REROLL, _grant_reroll)


func _grant_reroll() -> void:
	# One reroll per offer (spec 6 placement 5), granted at reward time. The
	# current trio joins the exclusions so the redraw is always disjoint;
	# the exclusion is per-reroll only, never permanent.
	if _offer_rerolled:
		return
	_offer_rerolled = true
	var exclusions: Array = (model.boons as Array).duplicate()
	exclusions.append_array(_current_offer)
	var redraw := BoonModel.offer((DataDefs.boons.get("defs", {}) as Dictionary).keys(), exclusions, _rng)
	if not redraw.is_empty():
		_current_offer = redraw
	_render_offer()
