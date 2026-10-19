extends Control
## Island home screen placeholder: balances readout plus the expedition
## launcher. Fuel is spent by the run scene's Start button (drag-drop setup spec);
## this screen gates the Launch button on affordability. Plan 4 grows this into the island.

@onready var launch_button: Button = $LaunchButton


func _ready() -> void:
	Economy.balance_changed.connect(_on_balance_changed)
	launch_button.pressed.connect(_on_launch_pressed)
	$IslandButton.pressed.connect(_on_island_pressed)
	$FuelRefillIcon.pressed.connect(_on_refill_pressed)
	$AdModal/VBox/AdWatch.pressed.connect(_on_refill_watch_pressed)
	$AdModal/VBox/AdCancel.pressed.connect(_on_refill_cancel_pressed)
	$RegionPrev.pressed.connect(_on_region_prev_pressed)
	$RegionNext.pressed.connect(_on_region_next_pressed)
	$RefreshTimer.timeout.connect(_refresh)
	if ResourceLoader.exists("res://game/art/icons/fuel.png"):
		$FuelRow/FuelIcon.texture = load("res://game/art/icons/fuel.png")
		$FuelRefillIcon.texture_normal = load("res://game/art/icons/fuel.png")
	if ResourceLoader.exists("res://game/art/icons/ad_badge.png"):
		$FuelRefillIcon/AdBadge.texture = load("res://game/art/icons/ad_badge.png")
	_refresh()


func _on_balance_changed(_currency: String, _amount: int) -> void:
	_refresh()


func _refresh() -> void:
	var now := TimeUtil.now()
	var fuel: Dictionary = GameState.data["fuel"]
	$FuelRow/FuelLabel.text = "%d / %d" % [FuelModel.current(fuel, now), int(fuel["cap"])]
	$FuelRefillIcon.visible = Ads.service.is_available(AdService.Placement.FUEL_REFILL) \
		and FuelModel.current(fuel, now) < int(fuel["cap"]) \
		and AdLimits.can_use(GameState.data, "fuel_refill", _refill_limit(), now)
	var region_entry := RegionModel.entry(DataDefs.run, _selected_region())
	var cost := RegionModel.fuel_cost(region_entry, GameState.data["island"])
	$RegionLabel.text = String(region_entry.get("name", "?"))
	launch_button.text = "Launch Expedition (%d fuel)" % cost
	var bg_path := "res://game/art/regions/%s_bg.png" % _selected_region()
	$RegionBackground.texture = load(bg_path) if ResourceLoader.exists(bg_path) else null
	var has_cycle := RegionModel.unlocked_entries(DataDefs.run, GameState.data["island"]).size() > 1
	$RegionPrev.visible = has_cycle
	$RegionNext.visible = has_cycle
	launch_button.disabled = FuelModel.current(fuel, now) < cost


func _on_launch_pressed() -> void:
	# Fuel is spent by the run scene's Start button now (drag-drop setup
	# spec); this button only gates on affordability via _refresh.
	GameState.save_game()
	get_tree().change_scene_to_file("res://game/run/salvage_run.tscn")


func _on_island_pressed() -> void:
	get_tree().change_scene_to_file("res://game/base/island_screen.tscn")


func _on_refill_pressed() -> void:
	# The modal stands between the tap and the ad so the player always
	# knows one is about to play (owner request, 2026-10-19).
	var now := TimeUtil.now()
	if not Ads.service.is_available(AdService.Placement.FUEL_REFILL):
		return
	if not AdLimits.can_use(GameState.data, "fuel_refill", _refill_limit(), now):
		return
	if FuelModel.current(GameState.data["fuel"], now) >= int(GameState.data["fuel"]["cap"]):
		return
	$ModalBlock.visible = true
	$AdModal.visible = true


func _on_refill_watch_pressed() -> void:
	_close_ad_modal()
	Ads.service.request_reward(AdService.Placement.FUEL_REFILL, _grant_fuel_refill)


func _on_refill_cancel_pressed() -> void:
	_close_ad_modal()


func _close_ad_modal() -> void:
	$ModalBlock.visible = false
	$AdModal.visible = false


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


func _on_region_next_pressed() -> void:
	_select_region(RegionModel.next_region_id(DataDefs.run, GameState.data["island"], _selected_region()))


func _on_region_prev_pressed() -> void:
	_select_region(RegionModel.prev_region_id(DataDefs.run, GameState.data["island"], _selected_region()))


func _select_region(region_id: String) -> void:
	if region_id == _selected_region():
		return
	if not GameState.data.has("expedition"):
		GameState.data["expedition"] = {"region": RegionModel.FALLBACK_ID}
	(GameState.data["expedition"] as Dictionary)["region"] = region_id
	GameState.save_game()
	_refresh()
