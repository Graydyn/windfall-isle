extends GutTest

const BellScene := preload("res://game/run/gizmos/chime_bell.tscn")
const PodScene := preload("res://game/run/pod.tscn")


class StubContext:
	extends Node

	var factors: Array = []

	func set_next_barge_multiplier(factor: float) -> void:
		factors.append(factor)


var bell
var context_stub: StubContext


func before_each() -> void:
	context_stub = add_child_autofree(StubContext.new())
	bell = add_child_autofree(BellScene.instantiate())
	bell.setup((DataDefs.gizmos["defs"]["chime_bell"] as Dictionary).duplicate(), 1, context_stub)


func make_pod() -> Pod:
	return add_child_autofree(PodScene.instantiate())


func test_ring_sets_barge_multiplier() -> void:
	bell._on_body_entered(make_pod())
	assert_eq(context_stub.factors.size(), 1)
	assert_almost_eq(float(context_stub.factors[0]), 2.0, 0.001)

func test_same_pod_rings_once() -> void:
	var pod := make_pod()
	bell._on_body_entered(pod)
	bell._on_body_entered(pod)
	assert_eq(context_stub.factors.size(), 1)

func test_uses_deplete() -> void:
	bell._on_body_entered(make_pod())
	bell._on_body_entered(make_pod())
	bell._on_body_entered(make_pod())
	assert_eq(context_stub.factors.size(), 2, "uses_per_run is 2")
	assert_almost_eq(bell.get_node("Visual").modulate.a, 0.25, 0.001)

func test_caught_pod_rings_nothing() -> void:
	var pod := make_pod()
	pod.set_meta("caught", true)
	bell._on_body_entered(pod)
	assert_eq(context_stub.factors.size(), 0)

func test_recharge_restores_rings_and_visual() -> void:
	bell._uses_left = 0
	bell.get_node("Visual").modulate.a = 0.25
	bell.recharge()
	assert_eq(bell._uses_left, int(DataDefs.gizmos["defs"]["chime_bell"]["uses_per_run"]))
	assert_almost_eq(bell.get_node("Visual").modulate.a, 1.0, 0.001)
