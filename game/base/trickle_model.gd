class_name TrickleModel
## Gardens & Cisterns idle faucet (spec 4.1, 5): scrap trickles while away,
## capped, must be collected. Lazy math over trickle.last_collect, same
## pattern as FuelModel.


static func pending(data: Dictionary, building_defs: Dictionary, now: int) -> int:
	var level := IslandModel.building_level(data.get("island", {}), "gardens")
	if level <= 0:
		return 0
	var def: Dictionary = (building_defs.get("defs", {}) as Dictionary).get("gardens", {})
	var rate := level * int(def.get("scrap_per_hour_per_level", 20))
	var elapsed_hours := maxf(0.0, float(now - int((data.get("trickle", {}) as Dictionary).get("last_collect", 0))) / 3600.0)
	var capped_hours: float = minf(elapsed_hours, float(def.get("cap_hours", 8.0)))
	return int(floor(capped_hours * float(rate)))


static func collect(data: Dictionary, building_defs: Dictionary, now: int) -> int:
	var amount := pending(data, building_defs, now)
	(data.get("trickle", {}) as Dictionary)["last_collect"] = now
	return amount
