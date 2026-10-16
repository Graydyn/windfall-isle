extends GutTest
## Islet markers on the island map: pure presentation nodes. (Crew tokens
## left the map for the crew sheet, owner request 2026-10-16.)


func make_islet(id := "lantern_shoal") -> IslandIsletNode:
	var node := IslandIsletNode.new(id)
	add_child_autofree(node)
	return node


func test_islet_renders_art_name_and_status() -> void:
	var node := make_islet()
	node.render({"art": "res://game/art/buildings/islet_lantern_shoal_ruined.png",
		"name": "Lantern Shoal", "status": "600 scrap, 4 cloudsilk", "dim": false})
	assert_not_null(node._art.texture)
	assert_eq(node._name_label.text, "Lantern Shoal")
	assert_eq(node._status_label.text, "600 scrap, 4 cloudsilk")
	assert_almost_eq(node.modulate.a, 1.0, 0.01)


func test_locked_islet_dims() -> void:
	var node := make_islet("foundry_rock")
	node.render({"art": "res://game/art/buildings/islet_foundry_rock_ruined.png",
		"name": "Foundry Rock", "status": "beyond a broken bridge", "dim": true})
	assert_almost_eq(node.modulate.a, 0.4, 0.01, "Plan 8 polish: locked islets dim at last")


func test_islet_tap_emits_the_id() -> void:
	var node := make_islet("foundry_rock")
	watch_signals(node)
	node.pressed.emit()
	assert_signal_emitted_with_parameters(node, "islet_tapped", ["foundry_rock"])


func test_islet_children_never_block_the_tap() -> void:
	var node := make_islet()
	for child in node.get_children():
		assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)
