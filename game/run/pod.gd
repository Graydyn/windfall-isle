class_name Pod
extends RigidBody2D
## A salvage pod: a dumb physics body. Catch detection belongs to the board's
## Area2D catchers; run accounting belongs to RunModel. setup() builds a fresh
## CircleShape2D per instance so pods never share a mutated shape resource.


func _ready() -> void:
	add_to_group("pods")


func setup(pod_defs: Dictionary) -> void:
	var radius := float(pod_defs.get("radius", 12.0))
	var shape := CircleShape2D.new()
	shape.radius = radius
	$CollisionShape2D.shape = shape
	var material := PhysicsMaterial.new()
	material.bounce = float(pod_defs.get("bounce", 0.55))
	material.friction = float(pod_defs.get("friction", 0.2))
	physics_material_override = material
	$Visual.polygon = Geometry.circle_points(radius)
