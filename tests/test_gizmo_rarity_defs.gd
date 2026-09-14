extends GutTest
## Authoring pins for gizmo rarity tiers (Plan 13, spec 3.3): rarity is an
## acquisition gate keyed to Workshop level; these tests keep the data honest.


func test_rarity_unlocks_map_exists() -> void:
	var unlocks: Dictionary = DataDefs.gizmos.get("rarity_unlocks", {})
	assert_eq(unlocks, {"common": 1.0, "uncommon": 2.0, "rare": 3.0})


func test_every_def_has_a_known_rarity() -> void:
	var unlocks: Dictionary = DataDefs.gizmos.get("rarity_unlocks", {})
	for gizmo_id in DataDefs.gizmos["defs"]:
		var def: Dictionary = (DataDefs.gizmos["defs"] as Dictionary)[gizmo_id]
		var rarity := String(def.get("rarity", ""))
		assert_true(unlocks.has(rarity),
			"%s has missing or unknown rarity '%s'" % [gizmo_id, rarity])


func test_unlock_levels_fit_the_workshop() -> void:
	var workshop: Dictionary = (DataDefs.buildings["defs"] as Dictionary)["workshop"]
	var max_level := int(workshop.get("max_level", 0))
	var unlocks: Dictionary = DataDefs.gizmos["rarity_unlocks"]
	for rarity in unlocks:
		var lv := int(unlocks[rarity])
		assert_true(lv >= 1 and lv <= max_level,
			"rarity '%s' unlocks at unreachable workshop level %d" % [rarity, lv])


func test_tier_table_is_pinned() -> void:
	var expected := {
		"wind_fan": "common",
		"balloon_cluster": "common",
		"cargo_net": "common",
		"magnet_buoy": "common",
		"crystal_prism": "uncommon",
		"lightning_jar": "uncommon",
		"chime_bell": "uncommon",
		"splitter_vane": "rare",
		"gyro_damper": "rare",
		"piston_kicker": "rare",
		"sleet_sail": "rare",
		"gale_vent": "rare",
	}
	for gizmo_id in expected:
		assert_eq(String(((DataDefs.gizmos["defs"] as Dictionary)[gizmo_id] as Dictionary).get("rarity", "")),
			String(expected[gizmo_id]), gizmo_id)
	assert_eq((DataDefs.gizmos["defs"] as Dictionary).size(), expected.size(),
		"a new gizmo must join this tier table deliberately")


func test_starting_inventory_is_exactly_the_commons() -> void:
	var starters: Dictionary = DataDefs.gizmos["starting_inventory"]
	for gizmo_id in DataDefs.gizmos["defs"]:
		var rarity := String(((DataDefs.gizmos["defs"] as Dictionary)[gizmo_id] as Dictionary).get("rarity", ""))
		assert_eq(starters.has(gizmo_id), rarity == "common",
			"%s: only commons are starters (Plan 13)" % gizmo_id)
	for gizmo_id in starters:
		assert_eq(int(starters[gizmo_id]), 1, "starters are granted at level 1")
