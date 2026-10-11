extends GutTest
## IslandPlotNode is pure presentation: feed it a state dictionary, check
## what it shows. Every rule lives in the models, none in here.


func make_node(id := "plot_0") -> IslandPlotNode:
	var node := IslandPlotNode.new(id)
	add_child_autofree(node)
	return node


func test_empty_state_invites_building() -> void:
	var node := make_node()
	node.render({"kind": "empty", "name": "(empty)", "status": "Tap to build", "ready": false})
	assert_eq(node._name_label.text, "(empty)")
	assert_eq(node._status_label.text, "Tap to build")
	assert_false(node._overlay.visible)
	assert_false(node._worker_badge.visible)
	assert_false(node._ready_badge.visible)


func test_constructing_state_dims_art_and_shows_the_scaffold() -> void:
	var node := make_node()
	node.render({"kind": "constructing", "art": "res://game/art/buildings/workshop.png",
		"name": "Workshop", "status": "42s", "ready": false})
	assert_not_null(node._art.texture, "the building art shows while it builds")
	assert_almost_eq(node._art.modulate.a, 0.5, 0.01, "constructing art dims")
	assert_true(node._overlay.visible, "construction_overlay.png is wired at last (audit 4.2)")


func test_ready_state_shows_the_badge() -> void:
	var node := make_node()
	node.render({"kind": "constructing", "art": "res://game/art/buildings/workshop.png",
		"name": "Workshop", "status": "Tap to collect!", "ready": true})
	assert_true(node._ready_badge.visible)


func test_built_state_shows_the_worker_badge() -> void:
	var node := make_node()
	node.render({"kind": "built", "art": "res://game/art/buildings/gardens.png",
		"name": "Gardens Lv 1", "status": "", "ready": false,
		"worker_portrait": "res://game/art/crew/odo.png"})
	assert_true(node._worker_badge.visible)
	assert_not_null(node._worker_badge.texture)
	assert_almost_eq(node._art.modulate.a, 1.0, 0.01, "built art shows at full strength")


func test_missing_art_keeps_the_node_alive() -> void:
	var node := make_node()
	node.render({"kind": "built", "art": "res://game/art/buildings/not_a_building.png",
		"name": "Mystery", "status": "", "ready": false})
	assert_null(node._art.texture, "missing art falls back to no texture, no crash")


func test_tap_emits_the_plot_id() -> void:
	var node := make_node("plot_3")
	watch_signals(node)
	node.pressed.emit()
	assert_signal_emitted_with_parameters(node, "plot_tapped", ["plot_3"])


func test_children_never_block_the_tap() -> void:
	var node := make_node()
	for child in node.get_children():
		assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"repo lesson: children of a tappable Button must ignore the mouse")
