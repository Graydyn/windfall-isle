extends GutTest

const SkyfieldScene := preload("res://game/run/skyfield.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var run_defs := {"sea_payout": {"scrap": 1}, "pod": {"radius": 12.0, "bounce": 0.55, "friction": 0.2}}

const DRIFT_REGION := {
	"name": "Drift Test",
	"board": {"left": 20, "right": 700, "top": 140, "bottom": 1020},
	"pegs": [], "gizmo_slots": [], "barges": [],
	"drift_zones": [
		{"x": 360, "y": 400, "half_width": 300, "half_height": 200, "force": 220.0, "direction": 1.0},
	],
}


func build_board(region: Dictionary) -> Skyfield:
	var board: Skyfield = add_child_autofree(SkyfieldScene.instantiate())
	board.build(region, run_defs)
	return board


func test_build_creates_drift_zone_nodes_from_data() -> void:
	var board := build_board(DRIFT_REGION)
	assert_eq(board.get_node("DriftZones").get_child_count(), 1)
	var zone: DriftZone = board.get_node("DriftZones").get_child(0)
	assert_eq(zone.position, Vector2(360, 400))
	assert_almost_eq(zone.force_vector.x, 220.0, 0.001)
	assert_true(zone.is_in_group("drift_zones"))

func test_region_without_drift_zones_builds_none() -> void:
	var board := build_board(DataDefs.skyfield("region_1"))
	assert_eq(board.get_node("DriftZones").get_child_count(), 0, "region 1 is calm skies")

func test_pod_falling_through_a_zone_is_pushed_sideways() -> void:
	var board := build_board(DRIFT_REGION)
	var pod: Pod = PodScene.instantiate()
	pod.position = Vector2(360, 250)
	pod.setup(run_defs["pod"])
	board.add_child(pod)
	autofree(pod)
	await wait_seconds(0.5)
	assert_true(pod.linear_velocity.x > 30.0,
		"spec 3.4: the drift current pushes the pod in its direction")

func test_setup_adds_wind_streak_particles_blowing_with_the_current() -> void:
	var board := build_board(DRIFT_REGION)
	var zone: DriftZone = board.get_node("DriftZones").get_child(0)
	var streaks: GPUParticles2D = zone.get_node("Visual/Streaks")
	assert_not_null(streaks, "drift zones animate wind streaks instead of static art")
	assert_true(streaks.emitting)
	assert_eq(zone.get_node("Visual").clip_children, CanvasItem.CLIP_CHILDREN_ONLY,
		"streaks stay inside the zone rectangle, masked at full alpha")
	assert_eq(zone.get_node("Visual").get_child_count(), 1,
		"the streaks alone mark the zone; no tint rectangle")
	var mat: ParticleProcessMaterial = streaks.process_material
	assert_true(mat.direction.x > 0.0, "streaks travel in the zone's push direction")

func test_leftward_zone_streaks_blow_left() -> void:
	var region := DRIFT_REGION.duplicate(true)
	region["drift_zones"][0]["direction"] = -1.0
	var board := build_board(region)
	var zone: DriftZone = board.get_node("DriftZones").get_child(0)
	var mat: ParticleProcessMaterial = zone.get_node("Visual/Streaks").process_material
	assert_true(mat.direction.x < 0.0, "streaks mirror when the current blows left")

func test_region_sea_payout_overrides_the_run_default() -> void:
	var region := DRIFT_REGION.duplicate(true)
	region["sea_payout"] = {"scrap": 2}
	var board := build_board(region)
	assert_eq(board.sea_payout, {"scrap": 2})

func test_run_sea_payout_still_applies_without_an_override() -> void:
	var board := build_board(DRIFT_REGION)
	assert_eq(board.sea_payout, {"scrap": 1})
