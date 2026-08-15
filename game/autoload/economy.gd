extends Node
## Currency faucets and sinks (spec 4.2). Operates on GameState.data by
## reference so every mutation is automatically captured by the next save.

signal balance_changed(currency: String, amount: int)

var _state: Node


func setup(state: Node) -> void:
	_state = state


func _ready() -> void:
	if _state == null:
		setup(GameState)


func _currencies() -> Dictionary:
	return _state.data["currencies"]


func balance(currency: String) -> int:
	return int(_currencies().get(currency, 0))


func add(currency: String, amount: int) -> void:
	assert(amount >= 0, "use spend() to remove currency")
	_currencies()[currency] = balance(currency) + amount
	balance_changed.emit(currency, balance(currency))


func spend(currency: String, amount: int) -> bool:
	if balance(currency) < amount:
		return false
	_currencies()[currency] = balance(currency) - amount
	balance_changed.emit(currency, balance(currency))
	return true


func can_afford(cost: Dictionary) -> bool:
	for currency in cost:
		if balance(currency) < int(cost[currency]):
			return false
	return true


func pay(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for currency in cost:
		spend(currency, int(cost[currency]))
	return true
