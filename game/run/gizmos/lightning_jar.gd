class_name LightningJar
extends GizmoBase
## Lightning Jar (spec 3.3): chain-zaps nearby natural pegs into bonus scrap.
## Zapped pegs are removed from the board; each pays scrap via context.add_bonus.

const BASE_TEXTURE := preload("res://game/art/gizmos/lightning_jar.png")
const SPENT_TEXTURE := preload("res://game/art/gizmos/lightning_jar_spent.png")

const BOLT_SEGMENTS := 6
const BOLT_JITTER := 7.0
const BOLT_FADE := 0.15
const BOLT_STAGGER := 0.05
const PEG_FLASH := 0.12
const OVERBRIGHT := Color(1.6, 1.8, 2.5)

var _charges := 0
var _zap_radius := 150.0
var _pegs_zapped := 3
var _scrap_per_peg := 2
var _visual_base_scale := Vector2.ONE

@onready var zone: Area2D = $Zone


func _configure() -> void:
	_charges = int(defs.get("charges", 2))
	_zap_radius = float(defs.get("zap_radius", 150.0))
	_pegs_zapped = int(defs.get("pegs_zapped", 3))
	_scrap_per_peg = int(round(scaled(float(defs.get("scrap_per_peg", 2)))))
	var circle := CircleShape2D.new()
	circle.radius = float(defs.get("zone_radius", 24.0))
	$Zone/Shape.shape = circle
	zone.body_entered.connect(_on_body_entered)
	_visual_base_scale = $Visual.scale


func _on_body_entered(body: Node2D) -> void:
	if _charges <= 0 or not (body is RigidBody2D) or body.has_meta("caught"):
		return
	var candidates: Array = []
	for peg in get_tree().get_nodes_in_group("pegs"):
		if peg.global_position.distance_to(global_position) <= _zap_radius:
			candidates.append(peg)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))
	var zapped := 0
	for peg in candidates:
		if zapped >= _pegs_zapped:
			break
		_zap_peg(peg, zapped)
		zapped += 1
	if zapped == 0:
		return
	_charges -= 1
	context.add_bonus({"scrap": _scrap_per_peg * zapped})
	_flash_jar(_charges <= 0)


func _zap_peg(peg: Node2D, index: int) -> void:
	# Gameplay removal is immediate (group + collision); only the visual
	# lingers for the zap flash. Stagger reads as a chain, not one blast.
	peg.remove_from_group("pegs")
	for child in peg.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
	var delay := index * BOLT_STAGGER
	_spawn_bolt(peg.global_position, delay)
	var tween := peg.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void: peg.modulate = OVERBRIGHT)
	tween.tween_property(peg, "modulate:a", 0.0, PEG_FLASH)
	tween.tween_callback(peg.queue_free)


func _spawn_bolt(target: Vector2, delay: float) -> void:
	# A jagged core line with a wider faint glow behind it; both live on a
	# self-freeing holder so headless tests can count them via the group.
	var points := _bolt_points(to_local(target))
	var bolt := Node2D.new()
	bolt.add_to_group("zap_bolts")
	bolt.modulate.a = 0.0
	var glow := Line2D.new()
	glow.points = points
	glow.width = 9.0
	glow.default_color = Color(0.5, 0.7, 1.0, 0.4)
	bolt.add_child(glow)
	var core := Line2D.new()
	core.points = points
	core.width = 3.0
	core.default_color = OVERBRIGHT
	bolt.add_child(core)
	add_child(bolt)
	var tween := bolt.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void: bolt.modulate.a = 1.0)
	tween.tween_property(bolt, "modulate:a", 0.0, BOLT_FADE)
	tween.tween_callback(bolt.queue_free)


func _bolt_points(to_point: Vector2) -> PackedVector2Array:
	# Subdivide the straight jar-to-peg line and jitter the interior points
	# perpendicular to it so the bolt reads as lightning, not a laser.
	var points := PackedVector2Array()
	var perpendicular := to_point.normalized().orthogonal()
	for i in BOLT_SEGMENTS + 1:
		var point := to_point * (float(i) / BOLT_SEGMENTS)
		if i > 0 and i < BOLT_SEGMENTS:
			point += perpendicular * randf_range(-BOLT_JITTER, BOLT_JITTER)
		points.append(point)
	return points


func _flash_jar(spend: bool) -> void:
	# Same overbright-then-settle trick as skyfield's catch flash, plus a
	# small scale punch so the jar reads as the source of the bolts. The
	# spent swap waits for the flash so the two don't fight over modulate.
	var visual: Sprite2D = $Visual
	visual.modulate = OVERBRIGHT
	var tween := visual.create_tween()
	tween.tween_property(visual, "scale", _visual_base_scale * 1.15, 0.06)
	tween.parallel().tween_property(visual, "modulate", Color.WHITE, 0.06)
	tween.tween_property(visual, "scale", _visual_base_scale, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if spend:
		tween.tween_callback(func() -> void:
			visual.texture = SPENT_TEXTURE
			visual.modulate.a = 0.25)


func recharge() -> void:
	_charges = int(defs.get("charges", 2))
	$Visual.texture = BASE_TEXTURE
	$Visual.modulate.a = 1.0
