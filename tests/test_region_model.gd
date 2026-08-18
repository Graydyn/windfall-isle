extends GutTest

const RUN_DEFS := {
	"fuel_cost": 1,
	"regions": [
		{"id": "region_1", "name": "Home Skies", "fuel_cost": 1, "min_dock_level": 0},
		{"id": "region_2", "name": "Brasswork Reach", "fuel_cost": 2, "min_dock_level": 1,
			"reduced_fuel_cost": 1, "reduced_at_dock_level": 2},
	],
}


func island_with_dock(level: int) -> Dictionary:
	if level <= 0:
		return {"plots": {}, "build_slots": 1}
	return {"plots": {"plot_0": {"building": "dock", "level": level}}, "build_slots": 1}


func test_region_1_is_always_unlocked_at_one_fuel() -> void:
	var entry: Dictionary = RUN_DEFS["regions"][0]
	assert_true(RegionModel.unlocked(entry, island_with_dock(0)))
	assert_eq(RegionModel.fuel_cost(entry, island_with_dock(0)), 1)
	assert_eq(RegionModel.fuel_cost(entry, island_with_dock(2)), 1, "no discount keys, no change")

func test_region_2_needs_the_dock() -> void:
	var entry: Dictionary = RUN_DEFS["regions"][1]
	assert_false(RegionModel.unlocked(entry, island_with_dock(0)))
	assert_true(RegionModel.unlocked(entry, island_with_dock(1)),
		"spec 4.1: the Dock unlocks new skyfield regions")

func test_dock_level_2_reduces_region_2_fuel_cost() -> void:
	var entry: Dictionary = RUN_DEFS["regions"][1]
	assert_eq(RegionModel.fuel_cost(entry, island_with_dock(1)), 2)
	assert_eq(RegionModel.fuel_cost(entry, island_with_dock(2)), 1,
		"spec 4.1: higher Dock levels reduce expedition fuel costs")

func test_unlocked_entries_keep_declared_order() -> void:
	var locked := RegionModel.unlocked_entries(RUN_DEFS, island_with_dock(0))
	assert_eq(locked.size(), 1)
	assert_eq(String((locked[0] as Dictionary)["id"]), "region_1")
	var open := RegionModel.unlocked_entries(RUN_DEFS, island_with_dock(1))
	assert_eq(open.size(), 2)
	assert_eq(String((open[1] as Dictionary)["id"]), "region_2")

func test_entry_lookup_and_unknown_id() -> void:
	assert_eq(String(RegionModel.entry(RUN_DEFS, "region_2").get("name", "")), "Brasswork Reach")
	assert_eq(RegionModel.entry(RUN_DEFS, "region_9"), {})

func test_missing_regions_key_yields_an_implicit_region_1() -> void:
	var entries := RegionModel.unlocked_entries({"fuel_cost": 3}, island_with_dock(0))
	assert_eq(entries.size(), 1)
	assert_eq(String((entries[0] as Dictionary)["id"]), "region_1")
	assert_eq(RegionModel.fuel_cost(entries[0], island_with_dock(0)), 3,
		"the implicit entry carries the flat run fuel_cost")

func test_selected_id_reads_the_save_and_falls_back() -> void:
	var data := {"expedition": {"region": "region_2"}}
	assert_eq(RegionModel.selected_id(data, RUN_DEFS, island_with_dock(1)), "region_2")
	assert_eq(RegionModel.selected_id(data, RUN_DEFS, island_with_dock(0)), "region_1",
		"a locked selection falls back, never crashes")
	assert_eq(RegionModel.selected_id({"expedition": {"region": "region_9"}}, RUN_DEFS, island_with_dock(2)), "region_1")
	assert_eq(RegionModel.selected_id({}, RUN_DEFS, island_with_dock(2)), "region_1",
		"a missing expedition section falls back")

func test_shipped_run_defs_carry_both_regions() -> void:
	var regions: Array = DataDefs.run.get("regions", [])
	assert_eq(regions.size(), 2)
	assert_eq(String((regions[0] as Dictionary)["id"]), "region_1")
	assert_eq(String((regions[1] as Dictionary)["id"]), "region_2")
	assert_eq(int((regions[1] as Dictionary)["fuel_cost"]), 2)
	assert_eq(int((regions[1] as Dictionary)["min_dock_level"]), 1)

func test_selected_id_tolerates_a_wrong_typed_expedition_section() -> void:
	assert_eq(RegionModel.selected_id({"expedition": "region_2"}, RUN_DEFS, island_with_dock(2)), "region_1",
		"a hand-edited save must fall back, never crash")

func test_next_region_id_cycles_unlocked_regions_in_order() -> void:
	assert_eq(RegionModel.next_region_id(RUN_DEFS, island_with_dock(0), "region_1"), "region_1",
		"nothing to cycle to without a Dock")
	assert_eq(RegionModel.next_region_id(RUN_DEFS, island_with_dock(1), "region_1"), "region_2")
	assert_eq(RegionModel.next_region_id(RUN_DEFS, island_with_dock(1), "region_2"), "region_1", "wraps")

func test_next_region_id_recovers_an_unknown_current() -> void:
	assert_eq(RegionModel.next_region_id(RUN_DEFS, island_with_dock(1), "region_9"), "region_2",
		"an unknown current id scans as index 0 and steps to the next entry")
