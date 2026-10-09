extends GutTest

const JarScene := preload("res://game/run/gizmos/lightning_jar.tscn")
const PodScene := preload("res://game/run/pod.tscn")


class StubContext:
	extends Node

	var bonuses: Array = []

	func add_bonus(payout: Dictionary) -> void:
		bonuses.append(payout)


var jar
var context_stub: StubContext
var jar_defs: Dictionary


func before_each() -> void:
	jar_defs = (DataDefs.gizmos["defs"]["lightning_jar"] as Dictionary).duplicate()
	context_stub = add_child_autofree(StubContext.new())
	jar = add_child_autofree(JarScene.instantiate())
	jar.position = Vector2(360, 500)
	jar.setup(jar_defs, 1, context_stub)


func make_peg(at: Vector2) -> StaticBody2D:
	var peg := StaticBody2D.new()
	peg.position = at
	peg.add_to_group("pegs")
	add_child_autofree(peg)
	return peg

func make_pod() -> Pod:
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	return pod


func test_zap_removes_nearby_pegs_and_credits_bonus() -> void:
	make_peg(Vector2(360, 420))
	make_peg(Vector2(420, 500))
	make_peg(Vector2(360, 900))
	jar._on_body_entered(make_pod())
	await wait_physics_frames(1)
	assert_eq(get_tree().get_nodes_in_group("pegs").size(), 1, "only the far peg survives")
	assert_eq(context_stub.bonuses.size(), 1)
	assert_eq(int(context_stub.bonuses[0]["scrap"]), 4, "2 scrap per peg, 2 pegs zapped")

func test_zap_caps_pegs_per_charge() -> void:
	for i in 5:
		make_peg(Vector2(360 + i * 10, 480))
	jar._on_body_entered(make_pod())
	await wait_physics_frames(1)
	assert_eq(get_tree().get_nodes_in_group("pegs").size(), 2, "pegs_zapped is 3")

func test_charges_deplete_and_no_zap_without_pegs() -> void:
	make_peg(Vector2(360, 480))
	jar._on_body_entered(make_pod())
	make_peg(Vector2(360, 480))
	jar._on_body_entered(make_pod())
	make_peg(Vector2(360, 480))
	jar._on_body_entered(make_pod())
	await wait_physics_frames(1)
	assert_eq(context_stub.bonuses.size(), 2, "charges is 2; the third contact does nothing")
	assert_eq(get_tree().get_nodes_in_group("pegs").size(), 1)

func test_caught_pod_triggers_nothing() -> void:
	make_peg(Vector2(360, 480))
	var pod := make_pod()
	pod.set_meta("caught", true)
	jar._on_body_entered(pod)
	assert_eq(context_stub.bonuses.size(), 0)

func test_zap_prefers_nearest_pegs() -> void:
	make_peg(Vector2(360, 380))
	make_peg(Vector2(360, 460))
	make_peg(Vector2(360, 520))
	make_peg(Vector2(460, 500))
	jar._on_body_entered(make_pod())
	await wait_physics_frames(1)
	var survivors: Array = get_tree().get_nodes_in_group("pegs")
	assert_eq(survivors.size(), 1)
	assert_eq((survivors[0] as Node2D).position, Vector2(360, 380),
		"the farthest in-range peg survives when the cap bites")

func test_out_of_range_contact_consumes_no_charge() -> void:
	make_peg(Vector2(360, 900))
	jar._on_body_entered(make_pod())
	jar._on_body_entered(make_pod())
	jar._on_body_entered(make_pod())
	assert_eq(context_stub.bonuses.size(), 0, "no pegs in range, no bonus ever")
	make_peg(Vector2(360, 480))
	jar._on_body_entered(make_pod())
	assert_eq(context_stub.bonuses.size(), 1,
		"charges were never consumed by the empty zaps")

func test_zap_spawns_bolts_that_clean_up() -> void:
	make_peg(Vector2(360, 420))
	make_peg(Vector2(420, 500))
	jar._on_body_entered(make_pod())
	assert_eq(get_tree().get_nodes_in_group("zap_bolts").size(), 2,
		"one bolt per zapped peg")
	await wait_seconds(0.6)
	assert_eq(get_tree().get_nodes_in_group("zap_bolts").size(), 0,
		"bolts free themselves when the effect ends")

func test_zapped_peg_lingers_for_effect_then_frees() -> void:
	var peg := make_peg(Vector2(360, 480))
	jar._on_body_entered(make_pod())
	assert_false(peg.is_in_group("pegs"), "gameplay removal stays immediate")
	await wait_physics_frames(2)
	assert_true(is_instance_valid(peg), "the visual lingers for the zap flash")
	await wait_seconds(0.6)
	assert_false(is_instance_valid(peg), "the peg frees once the flash ends")

func test_recharge_restores_charges_and_visual() -> void:
	jar._charges = 0
	jar.get_node("Visual").modulate.a = 0.25
	jar.recharge()
	assert_eq(jar._charges, int(DataDefs.gizmos["defs"]["lightning_jar"]["charges"]))
	assert_almost_eq(jar.get_node("Visual").modulate.a, 1.0, 0.001)
