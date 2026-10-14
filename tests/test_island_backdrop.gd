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


func test_set_bridges_stores_and_requests_a_redraw() -> void:
	var node := make_backdrop()
	node.set_bridges([
		{"from": Vector2(240, 1040), "to": Vector2(180, 1160), "state": "broken"},
		{"from": Vector2(330, 1400), "to": Vector2(480, 1510), "state": "restored"},
	])
	assert_eq(node._bridges.size(), 2)


func test_landmass_and_bridge_art_load() -> void:
	var node := make_backdrop()
	assert_not_null(node._island, "island_home.png wired as the plateau")
	assert_not_null(node._rock, "islet_rock.png wired under the islets")
	assert_eq(node._bridge_art.size(), 3, "all three bridge states have art")
