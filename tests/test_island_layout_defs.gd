extends GutTest
## island_layout.json authoring guards: every plot the game can open must
## have a map position, positions must fit the map, and pads must not crowd.


func layout() -> Dictionary:
	return DataDefs.island_layout


func test_layout_file_loads() -> void:
	assert_false(layout().is_empty(), "island_layout.json exists and parses")


func test_every_plot_id_has_a_position() -> void:
	var positions: Dictionary = layout()["plots"]
	for i in int(DataDefs.buildings["plot_count"]):
		assert_true(positions.has("plot_%d" % i), "home plot_%d has a map position" % i)
	for islet_v in IsletModel.islets(DataDefs.islets):
		for plot in (islet_v as Dictionary).get("plots", []):
			assert_true(positions.has(String(plot)), "islet plot %s has a map position" % String(plot))


func test_positions_fit_the_map_with_a_half_pad_margin() -> void:
	var map_size: Array = layout()["map_size"]
	var half := float(layout()["plot_size"]) / 2.0
	for plot in layout()["plots"]:
		var pos: Array = (layout()["plots"] as Dictionary)[plot]
		assert_between(float(pos[0]), half, float(map_size[0]) - half, "%s x inside the map" % String(plot))
		assert_between(float(pos[1]), half, float(map_size[1]) - half, "%s y inside the map" % String(plot))


func test_no_two_pads_crowd_each_other() -> void:
	var positions: Dictionary = layout()["plots"]
	var ids: Array = positions.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: Array = positions[ids[i]]
			var b: Array = positions[ids[j]]
			var dist := Vector2(float(a[0]), float(a[1])).distance_to(Vector2(float(b[0]), float(b[1])))
			assert_true(dist >= 150.0, "%s and %s are %d px apart (need 150)" % [String(ids[i]), String(ids[j]), int(dist)])


func test_every_islet_has_a_position() -> void:
	var islets_layout: Dictionary = layout()["islets"]
	for islet_v in IsletModel.islets(DataDefs.islets):
		var islet_id := String((islet_v as Dictionary).get("id", ""))
		assert_true(islets_layout.has(islet_id), "%s has a layout entry" % islet_id)
		var entry: Dictionary = islets_layout[islet_id]
		assert_eq((entry.get("pos", []) as Array).size(), 2, "%s pos is [x, y]" % islet_id)


func test_layout_carries_no_crew_band() -> void:
	# Crew left the map for the crew sheet (owner request, 2026-10-16); a
	# reintroduced band would be dead data the screen no longer reads.
	assert_false(layout().has("crew_band"), "island_layout.json has no crew_band")
