extends GutTest
## Peg hazards (Plan 14, spec 3.4): ice pegs deaden bounce via physics
## material; storm pegs consume uncaught pods through the pod_caught flow.

const SkyfieldScene := preload("res://game/run/skyfield.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var run_defs := {"sea_payout": {"scrap": 1}, "pod": {"radius": 12.0, "bounce": 0.55, "friction": 0.2}}


func build_board() -> Skyfield:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	board.build(DataDefs.load_json("res://tests/fixtures/test_region_hazards.json"), run_defs)
	return board


func make_pod(board: Skyfield, at: Vector2) -> Pod:
	var pod: Pod = PodScene.instantiate()
	pod.position = at
	pod.setup(run_defs["pod"])
	board.add_child(pod)
	return pod


func test_ice_peg_builds_with_dead_bounce_material() -> void:
	var board := build_board()
	var ice: StaticBody2D = board.get_node("Pegs").get_child(0) as StaticBody2D
	assert_not_null(ice.physics_material_override, "ice pegs carry their own material")
	assert_eq(ice.physics_material_override.bounce, 0.0)
	assert_true(ice.physics_material_override.absorbent,
		"absorbent subtracts the peg's bounce during combination, deadening the pod's own material")


func test_storm_peg_builds_as_area_in_group() -> void:
	var board := build_board()
	var storm: Node = board.get_node("Pegs").get_child(1)
	assert_true(storm is StormPeg)
	assert_true(storm.is_in_group("storm_pegs"))


func test_unknown_peg_type_warns_and_builds_a_normal_peg() -> void:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	board.build({
		"board": {"left": 20, "right": 700, "top": 140, "bottom": 1020},
		"pegs": [{"x": 300, "y": 500, "r": 14, "type": "lava"}],
		"gizmo_slots": [], "barges": [],
	}, run_defs)
	assert_push_warning_count(1)
	var peg: StaticBody2D = board.get_node("Pegs").get_child(0) as StaticBody2D
	assert_not_null(peg, "fail-open: a typo costs the hazard, not the board")
	assert_null(peg.physics_material_override)


func test_ice_peg_kills_rebound_on_real_contact() -> void:
	var board := build_board()
	var pod := make_pod(board, Vector2(200, 380))
	var strongest_rebound := 0.0
	for i in 90:
		await wait_physics_frames(1)
		if not is_instance_valid(pod) or pod.has_meta("caught"):
			break
		strongest_rebound = minf(strongest_rebound, pod.linear_velocity.y)
	assert_true(strongest_rebound > -80.0,
		"an ice peg deadens the bounce: the pod never rebounds sharply upward (saw %s)" % strongest_rebound)


func test_storm_peg_consumes_a_real_falling_pod() -> void:
	var board := build_board()
	var captured: Array = []
	board.pod_caught.connect(func(_pod: RigidBody2D, payout: Dictionary, source: String) -> void:
		captured.append([payout, source]))
	var pod := make_pod(board, Vector2(500, 380))
	for i in 180:
		await wait_physics_frames(1)
		if not captured.is_empty():
			break
	assert_eq(captured.size(), 1, "the falling pod was consumed exactly once")
	assert_true((captured[0][0] as Dictionary).is_empty(), "a consumed drop earns nothing")
	assert_eq(String(captured[0][1]), "storm")
	assert_true(pod.has_meta("caught"), "the meta guard keeps catchers and the watchdog off a consumed pod")


func test_storm_peg_ignores_a_caught_pod() -> void:
	var board := build_board()
	var captured: Array = []
	board.pod_caught.connect(func(_pod: RigidBody2D, payout: Dictionary, source: String) -> void:
		captured.append(source))
	var pod := make_pod(board, Vector2(500, 490))
	pod.set_meta("caught", true)
	await wait_physics_frames(4)
	assert_eq(captured, [], "already-resolved pods pass through storm pegs untouched")
