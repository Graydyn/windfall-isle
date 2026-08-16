class_name GizmoBase
extends Node2D
## Common interface for all gizmos (spec 3.3, 7.2): self-contained scenes,
## configured from game/data/gizmos.json, installed at skyfield slot markers.
## `context` is the run scene; the duck-type methods gizmos may call on it
## (landing in Plan 3b) are:
##   add_bonus(payout: Dictionary) -> void
##   set_next_barge_multiplier(factor: float) -> void
##   request_split(pod: RigidBody2D) -> bool
## Pod-carried effects use pod metadata; "value_mult" (float) multiplies the
## pod's payouts at resolution.

var defs: Dictionary = {}
var level: int = 1
var context: Node = null


func setup(gizmo_defs: Dictionary, gizmo_level: int, run_context: Node) -> void:
	defs = gizmo_defs
	level = gizmo_level
	context = run_context
	_configure()


func _configure() -> void:
	pass


func scaled(base: float) -> float:
	# Upgrade levels (crafted duplicates merge, spec 3.3): +25% per level.
	return base * (1.0 + 0.25 * float(level - 1))
