extends GutTest
## End-to-end boon flywheel through the real run scene (spec sections 3-7):
## a catch crosses region 1's first quota tier, the offer appears and gates
## drops, a picked Barge Bounty boosts the next barge catch on top of the
## tier multiplier, Spare Pods extends the run, and the run finishes with
## everything banked. Determinism: fixed rng seed for the organic offer,
## forced offers where a specific boon is required.

const RunScene := preload("res://game/run/salvage_run.tscn")
const TEST_SAVE := "user://test_boon_integration.json"

var scene


func before_each() -> void:
	GameState._io = SaveIO.new(TEST_SAVE)
	GameState.data = SaveSchema.default_data(DataDefs.economy, DataDefs.gizmos)
	GameState.data["created_at"] = 1000
	GameState.data["fuel"]["updated_at"] = 1000
	scene = add_child_autofree(RunScene.instantiate())
	scene._rng.seed = 20260818

func after_all() -> void:
	var dir := DirAccess.open("user://")
	for f in ["test_boon_integration.json", "test_boon_integration.json.tmp", "test_boon_integration.json.bak"]:
		if dir.file_exists(f):
			dir.remove(f)
	GameState._io = SaveIO.new()
	GameState.load_game(DataDefs.economy, TimeUtil.now(), DataDefs.gizmos, DataDefs.buildings)


func test_boon_flywheel_end_to_end() -> void:
	var scrap_before := Economy.balance("scrap")
	# Catch 25 scrap: exactly region 1's first quota. The crossing catch pays
	# at the old tier and the offer opens.
	scene._on_drop_requested(360.0)
	var pod: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(pod, {"scrap": 25}, "barge")
	assert_eq(Economy.balance("scrap"), scrap_before + 25, "the crossing catch pays at tier 0")
	assert_eq(scene.model.tier, 1)
	assert_true(scene.get_node("UI/BoonOffer").visible)
	assert_false(scene.get_node("DropController").enabled)
	# Force a known trio so the pick is deterministic, then take Barge Bounty.
	scene._current_offer = ["barge_bounty", "rich_seas", "second_wind"]
	scene._render_offer()
	scene._on_boon_picked(0)
	assert_true(scene.model.has_boon("barge_bounty"))
	assert_true(scene.get_node("DropController").enabled)
	# The next barge catch pays tier 1 (x1.25) then Barge Bounty (x1.5):
	# 8 -> 10 -> 15.
	scene._on_drop_requested(300.0)
	await wait_physics_frames(1)
	var pod2: Node = get_tree().get_nodes_in_group("pods")[0]
	scene._on_pod_caught(pod2, {"scrap": 8}, "barge")
	assert_eq(Economy.balance("scrap"), scrap_before + 25 + 15)
	assert_eq(int(scene.model.loot["scrap"]), 40)
	# A second forced offer grants Spare Pods; the run extends immediately.
	var drops_before: int = scene.model.drops_remaining()
	scene._current_offer = ["spare_pods", "heavy_loot", "featherfall"]
	scene._render_offer()
	scene._on_boon_picked(0)
	assert_eq(scene.model.drops_remaining(), drops_before + 2)
	assert_eq(scene.model.boons, ["barge_bounty", "spare_pods"], "pick order preserved")

func test_organic_offer_is_seed_deterministic() -> void:
	scene._on_tier_reached(1)
	var first: Array = (scene._current_offer as Array).duplicate()
	assert_eq(first.size(), 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260818
	var expected := BoonModel.offer((DataDefs.boons.get("defs", {}) as Dictionary).keys(), [], rng)
	assert_eq(first, expected, "the scene's draw is exactly the seeded model draw")
