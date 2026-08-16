extends GutTest

const ECON_DEFS := {
	"starting_balances": {"scrap": 100, "cloudsilk": 0, "crystals": 10},
	"fuel": {"starting": 5, "cap": 5, "regen_seconds": 1200},
}


func data_with_wind_still(level: int) -> Dictionary:
	var data := SaveSchema.default_data(ECON_DEFS)
	if level > 0:
		data["island"]["plots"]["plot_0"] = {"building": "wind_still", "level": level}
	return data


func test_apply_fuel_without_wind_still_keeps_base() -> void:
	var data := data_with_wind_still(0)
	IslandEffects.apply_fuel(data, ECON_DEFS, DataDefs.buildings)
	assert_eq(int(data["fuel"]["cap"]), 5)
	assert_eq(int(data["fuel"]["regen_seconds"]), 1200)

func test_apply_fuel_scales_with_wind_still_level() -> void:
	var data := data_with_wind_still(2)
	IslandEffects.apply_fuel(data, ECON_DEFS, DataDefs.buildings)
	assert_eq(int(data["fuel"]["cap"]), 7, "base 5 + 2 levels x 1")
	assert_eq(int(data["fuel"]["regen_seconds"]), 960, "base 1200 + 2 x -120")

func test_apply_fuel_is_idempotent_and_clamps() -> void:
	var data := data_with_wind_still(1)
	data["fuel"]["amount"] = 99
	IslandEffects.apply_fuel(data, ECON_DEFS, DataDefs.buildings)
	IslandEffects.apply_fuel(data, ECON_DEFS, DataDefs.buildings)
	assert_eq(int(data["fuel"]["cap"]), 6, "applying twice must not stack")
	assert_eq(int(data["fuel"]["amount"]), 6, "amount clamps to the new cap")

func test_drops_per_run_scales_with_balloonworks() -> void:
	var island := {"plots": {"plot_1": {"building": "balloonworks", "level": 2}}, "build_slots": 1}
	assert_eq(IslandEffects.drops_per_run({"drops_per_run": 8}, island, DataDefs.buildings), 10)
	assert_eq(IslandEffects.drops_per_run({"drops_per_run": 8}, {"plots": {}, "build_slots": 1}, DataDefs.buildings), 8)
