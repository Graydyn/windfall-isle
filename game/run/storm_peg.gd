class_name StormPeg
extends Area2D
## Storm peg (spec 3.4 hazard; region JSON pegs with "type": "storm"): a board
## feature that consumes any uncaught pod on contact. The skyfield connects
## body_entered and routes the consumed pod through the normal pod_caught flow
## with an empty payout, so the drop resolves earning nothing.


func setup(peg_defs: Dictionary) -> void:
	position = Vector2(float(peg_defs.get("x", 0)), float(peg_defs.get("y", 0)))
	var shape := CircleShape2D.new()
	shape.radius = float(peg_defs.get("r", 14.0))
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	var visual := Polygon2D.new()
	visual.polygon = Geometry.circle_points(shape.radius)
	visual.color = Color(0.85, 0.45, 0.25)
	add_child(visual)
	add_to_group("storm_pegs")
