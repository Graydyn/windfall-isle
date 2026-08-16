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
	assert_eq(data["island"], {})
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

func test_current_version_is_three_and_defaults_grant_eight() -> void:
	assert_eq(SaveSchema.CURRENT_VERSION, 3)
	var data := SaveSchema.default_data(DEFS, DataDefs.gizmos)
	assert_eq((data["gizmos"]["owned"] as Dictionary).size(), 8,
		"all eight MVP gizmos are starters until the Workshop lands (Plan 4)")
