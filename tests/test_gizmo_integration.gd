extends GutTest

const SkyfieldScene := preload("res://game/run/skyfield.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var run_defs := {"sea_payout": {"scrap": 1}, "pod": {"radius": 12.0, "bounce": 0.55, "friction": 0.2}}


func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_gizmo_integration.json", "test_gizmo_integration.json.tmp", "test_gizmo_integration.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos)


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

func test_cargo_net_catches_holds_and_redrops_to_barge() -> void:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	board.build(DataDefs.load_json("res://tests/fixtures/test_region_slot.json"), run_defs)
	board.install_gizmos({"slot_0": "cargo_net"}, DataDefs.gizmos, {"cargo_net": 1}, self)
	var pod: Pod = PodScene.instantiate()
	pod.position = Vector2(360, 160)
	pod.setup(run_defs["pod"])
	board.add_child(pod)
	var caught: bool = await wait_for_signal(board.pod_caught, 12.0)
	assert_true(caught, "held, re-dropped, and still landed within 12s")
	var net: GizmoBase = board.get_node("Gizmos").get_child(0)
	assert_eq(net._uses_left, 0, "the net consumed its single use on the way down")

func test_level_2_cargo_net_keeps_a_use_after_a_real_catch() -> void:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	board.build(DataDefs.load_json("res://tests/fixtures/test_region_slot.json"), run_defs)
	board.install_gizmos({"slot_0": "cargo_net"}, DataDefs.gizmos, {"cargo_net": 2}, self)
	var pod: Pod = PodScene.instantiate()
	pod.position = Vector2(360, 160)
	pod.setup(run_defs["pod"])
	board.add_child(pod)
	var caught: bool = await wait_for_signal(board.pod_caught, 12.0)
	assert_true(caught, "held, re-dropped, and still landed within 12s")
	var net: GizmoBase = board.get_node("Gizmos").get_child(0)
	assert_eq(net._uses_left, 1, "a level 2 net has a second catch left after one real contact")

func test_splitter_through_the_real_scene_credits_two_half_pods() -> void:
	GameState._io = SaveIO.new("user://test_gizmo_integration.json")
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	var scene = add_child_autofree(preload("res://game/run/salvage_run.tscn").instantiate())
	scene._on_start_pressed()
	var scrap_before := Economy.balance("scrap")
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	pod.linear_velocity = Vector2(80, 150)
	var vane = preload("res://game/run/gizmos/splitter_vane.tscn").instantiate()
	scene.board.get_node("Gizmos").add_child(vane)
	vane.setup((DataDefs.gizmos["defs"]["splitter_vane"] as Dictionary).duplicate(), 1, scene)
	vane._on_body_entered(pod)
	await wait_physics_frames(1)
	assert_eq(get_tree().get_nodes_in_group("pods").size(), 2)
	var pods: Array = get_tree().get_nodes_in_group("pods").duplicate()
	scene._on_pod_caught(pods[0], {"scrap": 10}, "barge")
	scene._on_pod_caught(pods[1], {"scrap": 10}, "barge")
	assert_eq(Economy.balance("scrap"), scrap_before + 10,
		"two half-value pods together equal one full payout (5 + 5)")
	assert_eq(scene.model.pods_in_flight, 0, "one drop, two pods, both resolved")
	assert_eq(scene.model.drops_remaining(), int(DataDefs.run["drops_per_run"]) - 1,
		"the split twin consumed no drop")

func test_splitter_splits_on_real_contact_without_errors() -> void:
	GameState._io = SaveIO.new("user://test_gizmo_integration.json")
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	var scene = add_child_autofree(preload("res://game/run/salvage_run.tscn").instantiate())
	scene._on_start_pressed()
	var vane = preload("res://game/run/gizmos/splitter_vane.tscn").instantiate()
	# x=130 sits 30-35px from every real peg column in region_1 (peg+pod
	# radii sum to 26), clearing a straight fall; x=360 lands dead-center on
	# a peg column and traps the pod bouncing forever instead of reaching
	# the vane, so this test cannot reuse the drop column used elsewhere.
	vane.position = Vector2(130, 500)
	scene.board.get_node("Gizmos").add_child(vane)
	vane.setup((DataDefs.gizmos["defs"]["splitter_vane"] as Dictionary).duplicate(), 1, scene)
	scene._on_drop_requested(130.0)
	await wait_seconds(1.2)
	assert_eq(get_tree().get_nodes_in_group("pods").size(), 2,
		"a real falling pod through the vane must split without engine errors")
	assert_eq(scene.model.pods_in_flight, 2)

func test_sleet_sail_slows_a_real_drop_and_restores_gravity() -> void:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	board.build(DataDefs.load_json("res://tests/fixtures/test_region_slot.json"), run_defs)
	board.install_gizmos({"slot_0": "sleet_sail"}, DataDefs.gizmos, {"sleet_sail": 1}, self)
	var pod: Pod = PodScene.instantiate()
	pod.position = Vector2(360, 160)
	pod.setup(run_defs["pod"])
	board.add_child(pod)
	var slowed := false
	var restored := false
	for i in 240:
		await wait_physics_frames(1)
		if not is_instance_valid(pod) or pod.has_meta("caught"):
			break
		if not slowed and is_equal_approx(pod.gravity_scale, 0.5):
			slowed = true
		elif slowed and is_equal_approx(pod.gravity_scale, 1.0):
			restored = true
			break
	assert_true(slowed, "the falling pod entered the column at half gravity")
	assert_true(restored, "gravity came back once the pod left the column")


func test_gale_vent_kicks_a_real_drop_once() -> void:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	board.build(DataDefs.load_json("res://tests/fixtures/test_region_slot.json"), run_defs)
	board.install_gizmos({"slot_0": "gale_vent"}, DataDefs.gizmos, {"gale_vent": 1}, self)
	var vent: GizmoBase = board.get_node("Gizmos").get_child(0)
	var meta_key := "gale_vented_%d" % vent.get_instance_id()
	var pod: Pod = PodScene.instantiate()
	pod.position = Vector2(360, 160)
	pod.setup(run_defs["pod"])
	board.add_child(pod)
	var kicked := false
	for i in 240:
		await wait_physics_frames(1)
		if not is_instance_valid(pod):
			break
		if pod.has_meta(meta_key):
			kicked = true
			break
	assert_true(kicked, "real contact triggers the vent exactly once, without engine errors")
	var caught: bool = await wait_for_signal(board.pod_caught, 12.0)
	assert_true(caught, "the kicked pod still lands within 12s")
