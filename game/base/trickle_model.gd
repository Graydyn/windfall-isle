class_name TrickleModel
## Gardens & Cisterns idle faucet (spec 4.1, 5): scrap trickles while away,
## capped, must be collected. Lazy math over trickle.last_collect, same
## pattern as FuelModel. The rate scales with the assigned crew's multiplier
## (crew spec section 5); callers that pass no crew defs get the baseline.


static func rate_per_hour(data: Dictionary, building_defs: Dictionary, crew_defs: Dictionary = {}) -> float:
	var level := IslandModel.building_level(data.get("island", {}), "gardens")
	if level <= 0:
		return 0.0
	var def: Dictionary = (building_defs.get("defs", {}) as Dictionary).get("gardens", {})
	return float(level * int(def.get("scrap_per_hour_per_level", 20))) \
		* CrewModel.multiplier_for(data, crew_defs, "gardens")


static func pending(data: Dictionary, building_defs: Dictionary, now: int, crew_defs: Dictionary = {}) -> int:
	var rate := rate_per_hour(data, building_defs, crew_defs)
	if rate <= 0.0:
		return 0
	var def: Dictionary = (building_defs.get("defs", {}) as Dictionary).get("gardens", {})
	var elapsed_hours := maxf(0.0, float(now - int((data.get("trickle", {}) as Dictionary).get("last_collect", 0))) / 3600.0)
	var capped_hours: float = minf(elapsed_hours, float(def.get("cap_hours", 8.0)))
	return int(floor(capped_hours * rate))


static func collect(data: Dictionary, building_defs: Dictionary, now: int, crew_defs: Dictionary = {}) -> int:
	var amount := pending(data, building_defs, now, crew_defs)
	(data.get("trickle", {}) as Dictionary)["last_collect"] = now
	return amount
