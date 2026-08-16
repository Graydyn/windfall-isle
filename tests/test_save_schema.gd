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

func test_migrate_v1_to_v2_grants_gizmo_structure() -> void:
	var v1 := SaveSchema.default_data(DEFS)
	v1["version"] = 1
	v1["gizmos"] = {}
	v1["currencies"]["scrap"] = 777
	var migrated := SaveSchema.migrate(v1, GIZMO_DEFS)
	assert_eq(int(migrated["version"]), 2)
	assert_eq(migrated["gizmos"], {"owned": {"wind_fan": 1, "crystal_prism": 1}, "loadout": {}})
	assert_eq(int(migrated["currencies"]["scrap"]), 777, "migration must be lossless")

func test_migrate_v1_without_gizmo_defs_still_structures() -> void:
	var v1 := SaveSchema.default_data(DEFS)
	v1["version"] = 1
	v1["gizmos"] = {}
	var migrated := SaveSchema.migrate(v1)
	assert_eq(migrated["gizmos"], {"owned": {}, "loadout": {}})
