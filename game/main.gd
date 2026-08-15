extends Control
## Temporary boot scene: proves the autoload stack works end to end.
## Plan 2 replaces the body with real island/skyfield navigation.

@onready var debug_label: Label = $DebugLabel


func _ready() -> void:
	Economy.balance_changed.connect(_refresh)
	_refresh("", 0)


func _refresh(_currency: String, _amount: int) -> void:
	var fuel: Dictionary = GameState.data["fuel"]
	debug_label.text = "Scrap: %d\nCrystals: %d\nFuel: %d/%d" % [
		Economy.balance("scrap"),
		Economy.balance("crystals"),
		FuelModel.current(fuel, TimeUtil.now()),
		int(fuel["cap"]),
	]
