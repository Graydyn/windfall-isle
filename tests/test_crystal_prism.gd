extends GutTest

const PrismScene := preload("res://game/run/gizmos/crystal_prism.tscn")
const PodScene := preload("res://game/run/pod.tscn")

var prism
var prism_defs: Dictionary


func before_each() -> void:
	prism_defs = (DataDefs.gizmos["defs"]["crystal_prism"] as Dictionary).duplicate()
	prism = add_child_autofree(PrismScene.instantiate())
	prism.setup(prism_defs, 1, self)


func test_contact_multiplies_pod_value_meta() -> void:
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	prism._on_body_entered(pod)
	assert_almost_eq(float(pod.get_meta("value_mult")), 1.5, 0.001)

func test_same_prism_applies_once_per_pod() -> void:
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	prism._on_body_entered(pod)
	prism._on_body_entered(pod)
	assert_almost_eq(float(pod.get_meta("value_mult")), 1.5, 0.001)

func test_two_prisms_stack() -> void:
	var second = add_child_autofree(PrismScene.instantiate())
	second.setup(prism_defs, 1, self)
	var pod: Pod = add_child_autofree(PodScene.instantiate())
	prism._on_body_entered(pod)
	second._on_body_entered(pod)
	assert_almost_eq(float(pod.get_meta("value_mult")), 2.25, 0.001)
