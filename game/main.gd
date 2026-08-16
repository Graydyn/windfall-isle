extends Control
## Island home screen placeholder: balances readout plus the expedition
## launcher. Fuel is spent HERE, before the run scene loads, so the run scene
## never touches fuel (spec 3.2 step 1). Plan 4 grows this into the island.

@onready var debug_label: Label = $DebugLabel
@onready var launch_button: Button = $LaunchButton


func _ready() -> void:
	Economy.balance_changed.connect(_on_balance_changed)
	launch_button.pressed.connect(_on_launch_pressed)
	$GizmosButton.pressed.connect(_on_gizmos_pressed)
	$RefreshTimer.timeout.connect(_refresh)
	_refresh()


func _on_balance_changed(_currency: String, _amount: int) -> void:
	_refresh()


func _refresh() -> void:
	var now := TimeUtil.now()
	var fuel: Dictionary = GameState.data["fuel"]
	debug_label.text = "Scrap: %d\nCloudsilk: %d\nCrystals: %d\nFuel: %d/%d" % [
		Economy.balance("scrap"),
		Economy.balance("cloudsilk"),
		Economy.balance("crystals"),
		FuelModel.current(fuel, now),
		int(fuel["cap"]),
	]
	launch_button.disabled = FuelModel.current(fuel, now) < int(DataDefs.run.get("fuel_cost", 1))


func _on_launch_pressed() -> void:
	var cost := int(DataDefs.run.get("fuel_cost", 1))
	if not FuelModel.spend(GameState.data["fuel"], cost, TimeUtil.now()):
		_refresh()
		return
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/run/salvage_run.tscn")


func _on_gizmos_pressed() -> void:
	get_tree().change_scene_to_file("res://game/ui/loadout_screen.tscn")
