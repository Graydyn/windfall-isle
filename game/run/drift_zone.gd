class_name DriftZone
extends Area2D
## One drift current (spec 3.4 hazard; region JSON "drift_zones"): a hostile
## wind column pushing pods sideways every physics frame, the board-owned
## twin of the Wind Fan. A board feature, not a gizmo: no level, no defs
## lookup, no context. Gyro Dampers (group "gyro_dampers") null the push for
## any pod inside their field; the zone asks, the damper just exists.

var force_vector := Vector2.ZERO


func setup(zone_defs: Dictionary) -> void:
	position = Vector2(float(zone_defs.get("x", 0)), float(zone_defs.get("y", 0)))
	force_vector = Vector2(float(zone_defs.get("force", 220.0)) * float(zone_defs.get("direction", 1.0)), 0.0)
	var half := Vector2(float(zone_defs.get("half_width", 100)), float(zone_defs.get("half_height", 60)))
	var shape := RectangleShape2D.new()
	shape.size = half * 2.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	var corners := PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	# Full-alpha mask-only polygon: clips the wind streaks to the zone
	# without attenuating them.
	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.polygon = corners
	visual.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	visual.add_child(_build_streaks(half))
	add_child(visual)
	add_to_group("drift_zones")


## Procedural wind streaks: no image asset, the particle texture and fade
## ramp are generated here. Speed tracks the zone's force; direction flips
## with it.
func _build_streaks(half: Vector2) -> GPUParticles2D:
	var streaks := GPUParticles2D.new()
	streaks.name = "Streaks"
	var speed := absf(force_vector.x)
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(half.x, half.y, 1.0)
	mat.direction = Vector3(signf(force_vector.x), 0.0, 0.0)
	mat.spread = 0.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = speed * 0.8
	mat.initial_velocity_max = speed * 1.2
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0),
	])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	streaks.process_material = mat
	# Lifetime spans roughly one crossing of the zone, so streaks fade near its edge.
	streaks.lifetime = clampf(half.x * 2.0 / maxf(speed, 1.0), 0.4, 1.6)
	streaks.amount = clampi(int(half.x * half.y / 4000.0), 8, 48)
	streaks.preprocess = streaks.lifetime
	streaks.texture = _streak_texture()
	return streaks


func _streak_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 24
	tex.height = 4
	tex.fill_from = Vector2(0.0, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is RigidBody2D and not _damped(body):
			body.apply_central_force(force_vector)


func _damped(body: Node2D) -> bool:
	for damper in get_tree().get_nodes_in_group("gyro_dampers"):
		if body.global_position.distance_to((damper as Node2D).global_position) <= float(damper.field_radius):
			return true
	return false
