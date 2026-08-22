class_name IslandEffects
## Idempotent application of building effects (spec 4.1, 4.3). Effects are
## always recomputed from base defs plus levels, never incremented, so
## re-applying at every load self-heals the save.

const MIN_REGEN_SECONDS := 300


static func apply_fuel(data: Dictionary, economy_defs: Dictionary, building_defs: Dictionary) -> void:
	var base: Dictionary = economy_defs.get("fuel", {})
	var def: Dictionary = (building_defs.get("defs", {}) as Dictionary).get("wind_still", {})
	var level := IslandModel.building_level(data.get("island", {}), "wind_still")
	var fuel: Dictionary = data.get("fuel", {})
	fuel["cap"] = int(base.get("cap", 5)) + level * int(def.get("fuel_cap_bonus_per_level", 1))
	fuel["regen_seconds"] = maxi(MIN_REGEN_SECONDS,
		int(base.get("regen_seconds", 1200)) + level * int(def.get("regen_delta_per_level", -120.0)))
	fuel["amount"] = mini(int(fuel.get("amount", 0)), int(fuel["cap"]))


static func drops_per_run(run_defs: Dictionary, island: Dictionary, building_defs: Dictionary) -> int:
	var def: Dictionary = (building_defs.get("defs", {}) as Dictionary).get("balloonworks", {})
	var level := IslandModel.building_level(island, "balloonworks")
	return int(run_defs.get("drops_per_run", 8)) + level * int(def.get("drops_bonus_per_level", 1))


static func payout_multiplier(island: Dictionary, building_defs: Dictionary) -> float:
	var def: Dictionary = (building_defs.get("defs", {}) as Dictionary).get("lens_array", {})
	var level := IslandModel.building_level(island, "lens_array")
	return 1.0 + float(level) * float(def.get("payout_bonus_per_level", 0.0))
