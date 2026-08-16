extends GutTest

const SkyfieldScene := preload("res://game/run/skyfield.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var run_defs := {"sea_payout": {"scrap": 1}, "pod": {"radius": 12.0, "bounce": 0.55, "friction": 0.2}}


func test_slotted_balloon_bounces_a_real_drop_then_pod_lands() -> void:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	board.build(DataDefs.load_json("res://tests/fixtures/test_region_slot.json"), run_defs)
	board.install_gizmos({"slot_0": "balloon_cluster"}, DataDefs.gizmos, {"balloon_cluster": 1}, self)
	var balloon: GizmoBase = board.get_node("Gizmos").get_child(0)
	var pod: Pod = PodScene.instantiate()
	pod.position = Vector2(360, 160)
	pod.setup(run_defs["pod"])
	board.add_child(pod)
	var caught: bool = await wait_for_signal(board.pod_caught, 10.0)
	assert_true(caught, "the pod must still reach the barge after bouncing")
	assert_true(balloon._hits_left < int(DataDefs.gizmos["defs"]["balloon_cluster"]["max_hits"]),
		"the balloon consumed at least one bounce on the way down")

func test_prism_multiplies_a_real_catch() -> void:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	board.build(DataDefs.load_json("res://tests/fixtures/test_region_slot.json"), run_defs)
	board.install_gizmos({"slot_0": "crystal_prism"}, DataDefs.gizmos, {"crystal_prism": 1}, self)
	var pod: Pod = PodScene.instantiate()
	pod.position = Vector2(360, 160)
	pod.setup(run_defs["pod"])
	board.add_child(pod)
	var caught: bool = await wait_for_signal(board.pod_caught, 10.0)
	assert_true(caught)
	assert_almost_eq(float(pod.get_meta("value_mult")), 1.5, 0.001,
		"falling through the prism must mark the pod before the catch")
