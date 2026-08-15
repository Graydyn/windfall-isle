class_name Geometry
## Tiny 2D geometry helpers shared by placeholder visuals.


static func circle_points(radius: float, segments: int = 12) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * i / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
