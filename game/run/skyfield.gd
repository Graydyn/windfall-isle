class_name Skyfield
extends Node2D
## One skyfield board (spec 3.1), built entirely from region JSON so new
## regions are data additions. Natural pegs are static; barges and the cloud
## sea are Area2D catchers. Gizmo slots are Marker2D anchors that Plan 3
## attaches crafted gizmos to.

signal pod_caught(pod: RigidBody2D, payout: Dictionary, source: String)

var sea_payout: Dictionary = {}


func build(region_defs: Dictionary, run_defs: Dictionary) -> void:
	sea_payout = (region_defs.get("sea_payout", run_defs.get("sea_payout", {"scrap": 1})) as Dictionary).duplicate()
	var board: Dictionary = region_defs.get("board", {})
	_build_walls(board)
	_build_pegs(region_defs.get("pegs", []))
	_build_barges(region_defs.get("barges", []))
	_build_sea(board)
	_build_slots(region_defs.get("gizmo_slots", []))
	_build_drift_zones(region_defs.get("drift_zones", []))


func _build_walls(board: Dictionary) -> void:
	# Walls span from above the drop line to below the sea, all derived from
	# board data so taller region-2+ boards keep pods contained (for region 1
	# this reproduces the original constants exactly).
	var bottom := float(board.get("bottom", 1020))
	var top_edge := -60.0
	var bottom_edge := bottom + 320.0
	for x in [float(board.get("left", 20)) - 10.0, float(board.get("right", 700)) + 10.0]:
		var wall := StaticBody2D.new()
		wall.position = Vector2(x, (top_edge + bottom_edge) / 2.0)
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(20, bottom_edge - top_edge)
		collider.shape = shape
		wall.add_child(collider)
		$Walls.add_child(wall)


func _build_pegs(pegs: Array) -> void:
	for peg in pegs:
		var body := StaticBody2D.new()
		body.add_to_group("pegs")
		body.position = Vector2(float(peg["x"]), float(peg["y"]))
		var collider := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = float(peg.get("r", 14.0))
		collider.shape = shape
		body.add_child(collider)
		var visual := Polygon2D.new()
		visual.polygon = Geometry.circle_points(shape.radius)
		visual.color = Color(0.55, 0.6, 0.7)
		body.add_child(visual)
		$Pegs.add_child(body)


static func duplicate_barge_ids(barges: Array) -> Array:
	# Region-authoring validation: duplicate ids make payout attribution
	# ambiguous and Godot silently renames the second Area2D.
	var seen := {}
	var dupes: Array = []
	for barge in barges:
		var id := String((barge as Dictionary).get("id", "barge"))
		if seen.has(id) and not dupes.has(id):
			dupes.append(id)
		seen[id] = true
	return dupes


func _build_barges(barges: Array) -> void:
	for id in duplicate_barge_ids(barges):
		push_warning("Region JSON has duplicate barge id '%s'" % id)
	for barge in barges:
		var area := Area2D.new()
		area.name = String(barge.get("id", "barge"))
		area.position = Vector2(float(barge["x"]), float(barge["y"]))
		var half := Vector2(float(barge.get("half_width", 50)), float(barge.get("half_height", 25)))
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = half * 2.0
		collider.shape = shape
		area.add_child(collider)
		var visual := Polygon2D.new()
		visual.polygon = PackedVector2Array([
			Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(half.x, half.y), Vector2(-half.x, half.y),
		])
		visual.color = Color(0.35, 0.55, 0.4)
		area.add_child(visual)
		area.body_entered.connect(_on_catcher_body.bind((barge.get("payout", {}) as Dictionary).duplicate(), "barge"))
		$Barges.add_child(area)


func _build_sea(board: Dictionary) -> void:
	var left := float(board.get("left", 20))
	var right := float(board.get("right", 700))
	var bottom := float(board.get("bottom", 1020))
	var sea := Area2D.new()
	sea.name = "Sea"
	sea.position = Vector2((left + right) / 2.0, bottom + 160.0)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(right - left + 80.0, 80.0)
	collider.shape = shape
	sea.add_child(collider)
	sea.body_entered.connect(_on_catcher_body.bind(sea_payout.duplicate(), "sea"))
	add_child(sea)


func _build_slots(slots: Array) -> void:
	for i in slots.size():
		var marker := Marker2D.new()
		marker.name = "slot_%d" % i
		marker.position = Vector2(float(slots[i]["x"]), float(slots[i]["y"]))
		$GizmoSlots.add_child(marker)


func _build_drift_zones(zones: Array) -> void:
	for zone_defs in zones:
		var zone := DriftZone.new()
		zone.setup(zone_defs as Dictionary)
		$DriftZones.add_child(zone)


func install_gizmos(loadout: Dictionary, gizmo_defs: Dictionary, owned: Dictionary, context: Node) -> void:
	var defs_by_id: Dictionary = gizmo_defs.get("defs", {})
	for slot in loadout:
		var gizmo_id: String = String(loadout[slot])
		var marker: Marker2D = $GizmoSlots.get_node_or_null(NodePath(slot))
		var def: Dictionary = defs_by_id.get(gizmo_id, {})
		var scene_path := String(def.get("scene", ""))
		if marker == null or def.is_empty() or not ResourceLoader.exists(scene_path):
			push_warning("Skipping gizmo '%s' in slot '%s' (unknown id, slot, or scene)" % [gizmo_id, slot])
			continue
		var gizmo: GizmoBase = (load(scene_path) as PackedScene).instantiate()
		gizmo.position = marker.position
		$Gizmos.add_child(gizmo)
		gizmo.setup(def, int(owned.get(gizmo_id, 1)), context)


func _on_catcher_body(body: Node2D, payout: Dictionary, source: String) -> void:
	if not (body is RigidBody2D):
		return
	if body.has_meta("caught"):
		return
	body.set_meta("caught", true)
	pod_caught.emit(body, payout.duplicate(), source)
