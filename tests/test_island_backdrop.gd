extends GutTest
## The map backdrop: vista art when delivered, code-drawn fallback until
## then, and the bridges that span between the home island and the islets.


func make_backdrop() -> IslandBackdrop:
	var node := IslandBackdrop.new()
	node.size = Vector2(720, 2000)
	add_child_autofree(node)
	return node


func test_backdrop_ignores_the_mouse() -> void:
	var node := make_backdrop()
	assert_eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the backdrop must never eat taps meant for pads")


func test_vista_art_is_not_delivered_yet_so_fallback_draws() -> void:
	var node := make_backdrop()
	assert_null(node._vista, "no island_vista.png in the repo yet; code fallback carries the screen")




func test_landmass_art_loads() -> void:
	var node := make_backdrop()
	assert_not_null(node._island, "island_home.png wired as the plateau")


func test_cloud_sea_fades_in_instead_of_cutting_a_hard_edge() -> void:
	# A flat cloud-sea rect read as a big white bar at the bottom of the map
	# when scrolled all the way down; the sea must fade in from transparent.
	assert_eq(IslandBackdrop.CLOUD_SEA_TOP.a, 0.0,
		"the cloud sea's top edge must be fully transparent so it blends into the sky")
	assert_gt(IslandBackdrop.CLOUD_SEA_BOTTOM.a, 0.0,
		"the sea still closes the very bottom of the map")
	assert_gt(IslandBackdrop.CLOUD_SEA_HEIGHT, 160.0,
		"a taller fade keeps the blend gradual instead of a short dense band")
