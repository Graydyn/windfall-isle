class_name LightningJar
extends GizmoBase
## Lightning Jar (spec 3.3): chain-zaps nearby natural pegs into bonus scrap.
## Zapped pegs are removed from the board; each pays scrap via context.add_bonus.

var _charges := 0
var _zap_radius := 150.0
var _pegs_zapped := 3
var _scrap_per_peg := 2

@onready var zone: Area2D = $Zone


func _configure() -> void:
	_charges = int(defs.get("charges", 2))
	_zap_radius = float(defs.get("zap_radius", 150.0))
	_pegs_zapped = int(defs.get("pegs_zapped", 3))
	_scrap_per_peg = int(round(scaled(float(defs.get("scrap_per_peg", 2)))))
	var circle := CircleShape2D.new()
	circle.radius = float(defs.get("zone_radius", 24.0))
	$Zone/Shape.shape = circle
	var visual: Polygon2D = $Visual
	visual.polygon = Geometry.circle_points(circle.radius, 6)
	visual.color = Color(0.95, 0.9, 0.4)
	zone.body_entered.connect(_on_body_entered)


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
		peg.queue_free()
		peg.remove_from_group("pegs")
		zapped += 1
	if zapped == 0:
		return
	_charges -= 1
	context.add_bonus({"scrap": _scrap_per_peg * zapped})
	if _charges <= 0:
		$Visual.modulate.a = 0.25


func recharge() -> void:
	_charges = int(defs.get("charges", 2))
	$Visual.modulate.a = 1.0
