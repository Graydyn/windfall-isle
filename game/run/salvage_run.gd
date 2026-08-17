extends Node2D
## Glue for one expedition: DropController -> RunModel -> Pod physics ->
## Skyfield catchers -> Economy. Fuel was already spent by the launcher
## (main.gd); this scene only runs the drops. Loot is credited per catch, so
## abandoning or being killed by the OS never loses anything (spec 3.2).

const PodScene := preload("res://game/run/pod.tscn")

var model: RunModel
var pod_defs: Dictionary
var _next_barge_multiplier := 1.0

@onready var board: Skyfield = $Skyfield
@onready var controller: DropController = $DropController


func _ready() -> void:
	var run_defs: Dictionary = DataDefs.run
	pod_defs = run_defs.get("pod", {})
	var region: Dictionary = DataDefs.skyfield("region_1")
	var run_config: Dictionary = run_defs.duplicate()
	run_config["drops_per_run"] = IslandEffects.drops_per_run(run_defs, GameState.data["island"], DataDefs.buildings)
	run_config["quota_tiers"] = region.get("quota_tiers", [])
	model = RunModel.new(run_config)
	board.build(region, run_defs)
	var gizmos_state: Dictionary = GameState.data["gizmos"]
	board.install_gizmos(
		GizmoLoadout.loadout_for(gizmos_state, "region_1"),
		DataDefs.gizmos,
		GizmoLoadout.owned(gizmos_state),
		self)
	controller.configure(region.get("board", {}), float(pod_defs.get("radius", 12.0)))
	board.pod_caught.connect(_on_pod_caught)
	controller.drop_requested.connect(_on_drop_requested)
	model.run_over.connect(_on_run_over)
	$UI/AbandonButton.pressed.connect(_on_abandon_pressed)
	$UI/Results/VBox/ReturnButton.pressed.connect(_on_return_pressed)
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
	if source == "barge" and _next_barge_multiplier > 1.0:
		var boosted := {}
		for currency in payout:
			boosted[currency] = roundi(float(payout[currency]) * _next_barge_multiplier)
		payout = boosted
		_next_barge_multiplier = 1.0
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
	for pod in get_tree().get_nodes_in_group("pods"):
		pod.set_meta("caught", true)
		pod.queue_free()
	GameState.save_game()
	$UI/Results/VBox/Summary.text = _summary_text()
	$UI/Results.visible = true


func _on_abandon_pressed() -> void:
	model.abandon()


func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://game/main.tscn")


func _compute_payout(pod: Node, base: Dictionary) -> Dictionary:
	# Central payout resolution: the run's quota-tier multiplier and the
	# pod-carried multipliers (Crystal Prism, Splitter Vane) apply here so
	# every catch path (barge, sea, watchdog) gets identical treatment.
	var mult := model.payout_multiplier()
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
