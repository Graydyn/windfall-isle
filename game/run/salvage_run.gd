extends Node2D
## Glue for one expedition: DropController -> RunModel -> Pod physics ->
## Skyfield catchers -> Economy. Fuel was already spent by the launcher
## (main.gd); this scene only runs the drops. Loot is credited per catch, so
## abandoning or being killed by the OS never loses anything (spec 3.2).

const PodScene := preload("res://game/run/pod.tscn")

var model: RunModel
var pod_defs: Dictionary

@onready var board: Skyfield = $Skyfield
@onready var controller: DropController = $DropController


func _ready() -> void:
	var run_defs: Dictionary = DataDefs.run
	pod_defs = run_defs.get("pod", {})
	var region: Dictionary = DataDefs.skyfield("region_1")
	model = RunModel.new(run_defs)
	board.build(region, run_defs)
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


func _on_pod_caught(pod: Node, payout: Dictionary) -> void:
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
	_on_pod_caught(pod, board.sea_payout.duplicate())


func _on_run_over() -> void:
	controller.enabled = false
	for pod in get_tree().get_nodes_in_group("pods"):
		pod.queue_free()
	GameState.save_game()
	$UI/Results/VBox/Summary.text = _summary_text()
	$UI/Results.visible = true


func _on_abandon_pressed() -> void:
	model.abandon()


func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://game/main.tscn")


func _refresh_hud() -> void:
	var parts := PackedStringArray()
	for currency in model.loot:
		parts.append("%s +%d" % [currency, int(model.loot[currency])])
	$UI/HudLabel.text = "Drops left: %d\n%s" % [model.drops_remaining(), " ".join(parts)]


func _summary_text() -> String:
	if model.loot.is_empty():
		return "Expedition complete.\nNothing salvaged this time."
	var lines := PackedStringArray(["Expedition complete. Salvaged:"])
	for currency in model.loot:
		lines.append("  %s: %d" % [currency, int(model.loot[currency])])
	return "\n".join(lines)
