class_name FuelModel
## Pure fuel-regeneration math (spec 4.3). Operates on the fuel dict stored in
## the save: {"amount", "cap", "regen_seconds", "updated_at"}, all ints,
## timestamps in Unix seconds. Callers pass `now` explicitly; this class never
## reads the wall clock, which is what makes offline regen testable.


static func materialize(fuel: Dictionary, now: int) -> void:
	var regen: int = maxi(1, int(fuel["regen_seconds"]))
	var elapsed: int = maxi(0, now - int(fuel["updated_at"]))
	@warning_ignore("integer_division")
	var gained: int = elapsed / regen
	if gained > 0 and int(fuel["amount"]) < int(fuel["cap"]):
		fuel["amount"] = mini(int(fuel["cap"]), int(fuel["amount"]) + gained)
		fuel["updated_at"] = int(fuel["updated_at"]) + gained * regen
	if int(fuel["amount"]) >= int(fuel["cap"]):
		# Sitting at cap accrues nothing; restart the clock so a later spend
		# regenerates from spend time, not from a stale timestamp.
		fuel["updated_at"] = now


static func current(fuel: Dictionary, now: int) -> int:
	var copy := fuel.duplicate()
	materialize(copy, now)
	return int(copy["amount"])


static func spend(fuel: Dictionary, amount: int, now: int) -> bool:
	materialize(fuel, now)
	if int(fuel["amount"]) < amount:
		return false
	fuel["amount"] = int(fuel["amount"]) - amount
	return true


static func seconds_until_full(fuel: Dictionary, now: int) -> int:
	var copy := fuel.duplicate()
	materialize(copy, now)
	var missing: int = int(copy["cap"]) - int(copy["amount"])
	if missing <= 0:
		return 0
	var partial: int = now - int(copy["updated_at"])
	return missing * int(copy["regen_seconds"]) - partial
