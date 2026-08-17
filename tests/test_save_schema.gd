extends GutTest

const DEFS := {
	"starting_balances": {"scrap": 100, "cloudsilk": 0, "crystals": 10},
	"fuel": {"starting": 5, "cap": 5, "regen_seconds": 1200},
}


func test_default_data_shape() -> void:
	var data := SaveSchema.default_data(DEFS)
	assert_eq(int(data["version"]), SaveSchema.CURRENT_VERSION)
	assert_eq(int(data["currencies"]["scrap"]), 100)
	assert_eq(int(data["currencies"]["crystals"]), 10)
	assert_eq(int(data["fuel"]["amount"]), 5)
	assert_eq(int(data["fuel"]["cap"]), 5)
	assert_eq(int(data["fuel"]["regen_seconds"]), 1200)
	assert_eq(data["timers"], {})
	assert_eq(data["island"], {"plots": {}, "build_slots": 1})
	assert_eq(data["gizmos"], {"owned": {}, "loadout": {}})

func test_default_data_does_not_alias_defs() -> void:
	var data := SaveSchema.default_data(DEFS)
	data["currencies"]["scrap"] = 0
	assert_eq(int(DEFS["starting_balances"]["scrap"]), 100,
		"mutating a save must never mutate the defs")

func test_migrate_current_version_is_noop() -> void:
	var data := SaveSchema.default_data(DEFS)
	assert_eq(SaveSchema.migrate(data), data)

func test_migrate_rejects_unversioned_data() -> void:
	assert_eq(SaveSchema.migrate({"currencies": {}}), {})

func test_migrate_rejects_future_version() -> void:
	assert_eq(SaveSchema.migrate({"version": 99}), {})

const GIZMO_DEFS := {"starting_inventory": {"wind_fan": 1, "crystal_prism": 1}}


func test_default_data_grants_starting_gizmos() -> void:
	var data := SaveSchema.default_data(DEFS, GIZMO_DEFS)
	assert_eq(data["gizmos"]["owned"], {"wind_fan": 1, "crystal_prism": 1})
	data["gizmos"]["owned"]["wind_fan"] = 5
	assert_eq(int(GIZMO_DEFS["starting_inventory"]["wind_fan"]), 1,
		"granting must not alias the defs")

func test_migrate_v1_hops_to_current_with_grant() -> void:
	var v1 := SaveSchema.default_data(DEFS)
	v1["version"] = 1
	v1["gizmos"] = {}
	v1["currencies"]["scrap"] = 777
	var migrated := SaveSchema.migrate(v1, GIZMO_DEFS)
	assert_eq(int(migrated["version"]), SaveSchema.CURRENT_VERSION)
	assert_eq(migrated["gizmos"]["owned"], {"wind_fan": 1, "crystal_prism": 1})
	assert_eq(int(migrated["currencies"]["scrap"]), 777, "migration must be lossless")

func test_migrate_v1_without_gizmo_defs_still_structures() -> void:
	var v1 := SaveSchema.default_data(DEFS)
	v1["version"] = 1
	v1["gizmos"] = {}
	var migrated := SaveSchema.migrate(v1)
	assert_eq(migrated["gizmos"], {"owned": {}, "loadout": {}})

func test_migrate_v2_merge_grants_new_starters_preserving_levels() -> void:
	var v2 := SaveSchema.default_data(DEFS, {"starting_inventory": {"wind_fan": 1}})
	v2["version"] = 2
	v2["gizmos"]["owned"]["wind_fan"] = 4
	var migrated := SaveSchema.migrate(v2, GIZMO_DEFS)
	assert_eq(int(migrated["version"]), SaveSchema.CURRENT_VERSION)
	assert_eq(int(migrated["gizmos"]["owned"]["wind_fan"]), 4,
		"merge-grant must not reset an upgraded level")
	assert_eq(int(migrated["gizmos"]["owned"]["crystal_prism"]), 1,
		"newly introduced starters are granted")

func test_migrate_v2_preserves_loadout() -> void:
	var v2 := SaveSchema.default_data(DEFS, GIZMO_DEFS)
	v2["version"] = 2
	v2["gizmos"]["loadout"] = {"region_1": {"slot_0": "wind_fan"}}
	var migrated := SaveSchema.migrate(v2, GIZMO_DEFS)
	assert_eq(migrated["gizmos"]["loadout"], {"region_1": {"slot_0": "wind_fan"}})

func test_current_version_is_five_and_defaults_grant_eight() -> void:
	assert_eq(SaveSchema.CURRENT_VERSION, 5)
	var data := SaveSchema.default_data(DEFS, DataDefs.gizmos)
	assert_eq((data["gizmos"]["owned"] as Dictionary).size(), 8,
		"all eight MVP gizmos are starters until the Workshop lands (Plan 4)")

func test_default_data_has_v4_island_shape() -> void:
	var data := SaveSchema.default_data(DEFS)
	assert_eq(int(data["version"]), SaveSchema.CURRENT_VERSION)
	assert_eq(data["island"], {"plots": {}, "build_slots": 1})
	assert_eq(data["trickle"], {"last_collect": 0})
	assert_eq(data["daily_crate"], {"last_claim_day": 0})

func test_migrate_v3_to_v4_adds_island_losslessly() -> void:
	var v3 := SaveSchema.default_data(DEFS, GIZMO_DEFS)
	v3["version"] = 3
	v3.erase("island")
	v3["currencies"]["scrap"] = 555
	var migrated := SaveSchema.migrate(v3, GIZMO_DEFS)
	assert_eq(int(migrated["version"]), 5)
	assert_eq(migrated["island"], {"plots": {}, "build_slots": 1})
	assert_eq(int(migrated["currencies"]["scrap"]), 555)

func test_migrate_v1_hops_all_the_way_to_v4() -> void:
	var v1 := SaveSchema.default_data(DEFS)
	v1["version"] = 1
	v1["gizmos"] = {}
	var migrated := SaveSchema.migrate(v1, GIZMO_DEFS)
	assert_eq(int(migrated["version"]), 5)
	assert_has(migrated, "island")
	assert_has(migrated, "daily_crate")

func test_migrate_v2_self_heals_malformed_gizmos() -> void:
	var broken := SaveSchema.default_data(DEFS)
	broken["version"] = 2
	broken["gizmos"] = 7
	var healed := SaveSchema.migrate(broken, GIZMO_DEFS)
	assert_eq(healed["gizmos"]["owned"], {"wind_fan": 1, "crystal_prism": 1},
		"a wrong-typed gizmos section is rebuilt and granted")
	var missing_keys := SaveSchema.default_data(DEFS)
	missing_keys["version"] = 2
	missing_keys["gizmos"] = {"owned": {"wind_fan": 3}}
	var healed2 := SaveSchema.migrate(missing_keys, GIZMO_DEFS)
	assert_eq(healed2["gizmos"]["loadout"], {}, "missing loadout is backfilled")
	assert_eq(int(healed2["gizmos"]["owned"]["wind_fan"]), 3, "existing levels survive the heal")

func test_migrate_4_to_5_adds_ads_and_notifications_losslessly() -> void:
	var v4 := {
		"version": 4, "created_at": 1, "currencies": {"scrap": 5},
		"fuel": {"amount": 1, "cap": 5, "regen_seconds": 1200, "updated_at": 0},
		"timers": {}, "island": {"plots": {}, "build_slots": 1},
		"trickle": {"last_collect": 0}, "daily_crate": {"last_claim_day": 0},
		"gizmos": {"owned": {"wind_fan": 2}, "loadout": {}},
	}
	var out := SaveSchema.migrate(v4)
	assert_eq(int(out["version"]), 5)
	assert_eq(out["ads"], {"day": 0, "counts": {}})
	assert_eq(out["notifications"], {"permission_requested": false})
	assert_eq(int(out["gizmos"]["owned"]["wind_fan"]), 2, "owned levels untouched")
	assert_eq(int(out["currencies"]["scrap"]), 5, "balances untouched")

func test_default_data_has_v5_sections() -> void:
	var data := SaveSchema.default_data(DEFS)
	assert_eq(data["ads"], {"day": 0, "counts": {}})
	assert_false(bool((data["notifications"] as Dictionary)["permission_requested"]))

func test_backfill_heals_missing_keys_on_current_version() -> void:
	var damaged := {"version": 5, "currencies": {"scrap": 7}}
	var out := SaveSchema.migrate(damaged, GIZMO_DEFS)
	assert_eq(int(out["currencies"]["scrap"]), 7, "existing keys untouched")
	for key in ["fuel", "timers", "island", "trickle", "daily_crate", "gizmos", "ads", "notifications"]:
		assert_has(out, key)
	assert_eq(int((out["fuel"] as Dictionary)["cap"]), 5, "neutral fuel defaults")
	assert_eq(out["gizmos"]["owned"], {"wind_fan": 1, "crystal_prism": 1},
		"backfilled gizmos grant the starting inventory")
