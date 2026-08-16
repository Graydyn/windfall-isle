extends GutTest

const VaneScene := preload("res://game/run/gizmos/splitter_vane.tscn")
const PodScene := preload("res://game/run/pod.tscn")


class StubContext:
	extends Node

	var accept := true
	var requests: Array = []

	func request_split(pod: RigidBody2D) -> bool:
		requests.append(pod)
		return accept


var vane
var context_stub: StubContext


func before_each() -> void:
	context_stub = add_child_autofree(StubContext.new())
	vane = add_child_autofree(VaneScene.instantiate())
	vane.setup((DataDefs.gizmos["defs"]["splitter_vane"] as Dictionary).duplicate(), 1, context_stub)


func make_pod() -> Pod:
	return add_child_autofree(PodScene.instantiate())


func test_split_halves_value_and_marks_pod() -> void:
	var pod := make_pod()
	vane._on_body_entered(pod)
	assert_eq(context_stub.requests.size(), 1)
	assert_almost_eq(float(pod.get_meta("value_mult")), 0.5, 0.001)
	assert_true(pod.has_meta("split"))

func test_rejected_split_reverts_the_halving() -> void:
	context_stub.accept = false
	var pod := make_pod()
	pod.set_meta("value_mult", 0.8)
	vane._on_body_entered(pod)
	assert_almost_eq(float(pod.get_meta("value_mult")), 0.8, 0.001,
		"no benefit means no penalty")
	assert_false(pod.has_meta("split"), "the pod may retry once capacity frees")

func test_split_pod_never_splits_again() -> void:
	var pod := make_pod()
	vane._on_body_entered(pod)
	vane._on_body_entered(pod)
	assert_eq(context_stub.requests.size(), 1)

func test_caught_pod_is_ignored() -> void:
	var pod := make_pod()
	pod.set_meta("caught", true)
	vane._on_body_entered(pod)
	assert_eq(context_stub.requests.size(), 0)

func test_level_softens_the_penalty() -> void:
	var strong = add_child_autofree(VaneScene.instantiate())
	strong.setup((DataDefs.gizmos["defs"]["splitter_vane"] as Dictionary).duplicate(), 3, context_stub)
	var pod := make_pod()
	strong._on_body_entered(pod)
	assert_almost_eq(float(pod.get_meta("value_mult")), 0.75, 0.001,
		"scaled(0.5) at level 3 is 0.75")
