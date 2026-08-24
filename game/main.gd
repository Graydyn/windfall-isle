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
	$IslandButton.pressed.connect(_on_island_pressed)
	$RefillButton.pressed.connect(_on_refill_pressed)
	$RegionButton.pressed.connect(_on_region_pressed)
	$RefreshTimer.timeout.connect(_refresh)
	_refresh()


func _on_balance_changed(_currency: String, _amount: int) -> void:
	_refresh()


func _refresh() -> void:
	var now := TimeUtil.now()
	var fuel: Dictionary = GameState.data["fuel"]
	debug_label.text = "Scrap: %d\nCloudsilk: %d\nBrasswork: %d\nCrystals: %d\nFuel: %d/%d" % [
		Economy.balance("scrap"),
		Economy.balance("cloudsilk"),
		Economy.balance("brasswork"),
		Economy.balance("crystals"),
		FuelModel.current(fuel, now),
		int(fuel["cap"]),
	]
	$RefillButton.visible = Ads.service.is_available(AdService.Placement.FUEL_REFILL)
	$RefillButton.disabled = FuelModel.current(fuel, now) >= int(fuel["cap"]) \
		or not AdLimits.can_use(GameState.data, "fuel_refill", _refill_limit(), now)
	var region_entry := RegionModel.entry(DataDefs.run, _selected_region())
	var cost := RegionModel.fuel_cost(region_entry, GameState.data["island"])
	$RegionButton.text = "Region: %s (%d fuel)" % [String(region_entry.get("name", "?")), cost]
	launch_button.disabled = FuelModel.current(fuel, now) < cost


func _on_launch_pressed() -> void:
	# Fuel is spent by the run scene's Start button now (drag-drop setup
	# spec); this button only gates on affordability via _refresh.
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/run/salvage_run.tscn")


func _on_gizmos_pressed() -> void:
	get_tree().change_scene_to_file("res://game/ui/loadout_screen.tscn")


func _on_island_pressed() -> void:
	get_tree().change_scene_to_file("res://game/base/island_screen.tscn")


func _on_refill_pressed() -> void:
	var now := TimeUtil.now()
	if not Ads.service.is_available(AdService.Placement.FUEL_REFILL):
		return
	if not AdLimits.can_use(GameState.data, "fuel_refill", _refill_limit(), now):
		return
	if FuelModel.current(GameState.data["fuel"], now) >= int(GameState.data["fuel"]["cap"]):
		return
	Ads.service.request_reward(AdService.Placement.FUEL_REFILL, _grant_fuel_refill)


func _grant_fuel_refill() -> void:
	# The limit is consumed at GRANT time so a dismissed real ad costs nothing.
	var now := TimeUtil.now()
	if not AdLimits.use(GameState.data, "fuel_refill", _refill_limit(), now):
		return
	var fuel: Dictionary = GameState.data["fuel"]
	FuelModel.materialize(fuel, now)
	fuel["amount"] = int(fuel["cap"])
	GameState.save_game()
	_refresh()


func _refill_limit() -> int:
	return int((DataDefs.retention.get("ads", {}) as Dictionary).get("fuel_refills_per_day", 2))


func _selected_region() -> String:
	return RegionModel.selected_id(GameState.data, DataDefs.run, GameState.data["island"])


func _on_region_pressed() -> void:
	var next := RegionModel.next_region_id(DataDefs.run, GameState.data["island"], _selected_region())
	if next == _selected_region():
		return
	if not GameState.data.has("expedition"):
		GameState.data["expedition"] = {"region": RegionModel.FALLBACK_ID}
	(GameState.data["expedition"] as Dictionary)["region"] = next
	GameState.save_game()
	_refresh()
