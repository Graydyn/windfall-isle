class_name Skyfield
extends Node2D
## One skyfield board (spec 3.1), built entirely from region JSON so new
## regions are data additions. Natural pegs are static; barges and the cloud
## sea are Area2D catchers. Gizmo slots are Marker2D anchors that Plan 3
## attaches crafted gizmos to.

signal pod_caught(pod: RigidBody2D, payout: Dictionary, source: String)

const PEG_VARIANTS := 3
const MATERIAL_PENNANTS := ["cloudsilk", "brasswork", "rimeglass", "stormglass"]

var sea_payout: Dictionary = {}
var _peg_art_prefix := ""


func build(region_defs: Dictionary, run_defs: Dictionary, region_id: String = "") -> void:
	# Peg art is themed per region (audit 2.2): region_N maps to peg_rN_1..3.
	_peg_art_prefix = "peg_r" + region_id.trim_prefix("region_") if region_id != "" else ""
	sea_payout = (region_defs.get("sea_payout", run_defs.get("sea_payout", {"scrap": 1})) as Dictionary).duplicate()
	var board: Dictionary = region_defs.get("board", {})
	_build_background(region_id)
	_build_walls(board)
	_build_pegs(region_defs.get("pegs", []))
	_build_barges(region_defs.get("barges", []))
	_build_sea(board)
	_build_slots(region_defs.get("gizmo_slots", []))
	_build_drift_zones(region_defs.get("drift_zones", []))


func _build_background(region_id: String) -> void:
	# Region backdrop (audit 2.1), authored at 2x the 720x1280 design size with
	# the cloud sea painted into its bottom band. Drawn first so the whole
	# board sits on top; regions without art keep the clear color.
	var path := "res://game/art/regions/%s_bg.png" % region_id
	if region_id == "" or not ResourceLoader.exists(path):
		return
	var bg := Sprite2D.new()
	bg.name = "Background"
	bg.texture = load(path)
	bg.centered = false
	bg.scale = Vector2(720.0, 1280.0) / bg.texture.get_size()
	add_child(bg)
	move_child(bg, 0)


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
	var natural_index := 0
	for peg in pegs:
		var type := String((peg as Dictionary).get("type", ""))
		if type == "storm":
			var storm := StormPeg.new()
			storm.setup(peg as Dictionary)
			storm.body_entered.connect(_on_storm_peg_body)
			$Pegs.add_child(storm)
			continue
		if type != "" and type != "ice":
			# Fail-open authoring guard: a typo costs the hazard, not the board.
			push_warning("Region JSON has unknown peg type '%s'; building a normal peg" % type)
			type = ""
		var body := StaticBody2D.new()
		body.add_to_group("pegs")
		body.position = Vector2(float(peg["x"]), float(peg["y"]))
		var collider := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = float(peg.get("r", 14.0))
		collider.shape = shape
		body.add_child(collider)
		var art_name := ""
		if type == "ice":
			# Ice peg (spec 3.4 hazard): absorbent negates the peg's own bounce
			# in Godot's combine, so a FULL bounce of 1.0 subtracts the pod's
			# 0.55 restitution to zero: clamp(0.55 - 1.0, 0, 1). A zero-bounce
			# absorbent material would contribute nothing.
			var material := PhysicsMaterial.new()
			material.bounce = 1.0
			material.absorbent = true
			body.physics_material_override = material
			art_name = "peg_ice"
		elif _peg_art_prefix != "":
			# Cycle the region's variants so grids don't look stamped.
			art_name = "%s_%d" % [_peg_art_prefix, (natural_index % PEG_VARIANTS) + 1]
			natural_index += 1
		body.add_child(peg_visual(art_name, shape.radius, Color(0.7, 0.85, 0.95) if type == "ice" else Color(0.55, 0.6, 0.7)))
		$Pegs.add_child(body)


static func peg_visual(art_name: String, radius: float, fallback: Color) -> Node2D:
	# Peg art is authored at 2x a 28 px peg (radius 14); anything without a
	# matching sprite keeps the old placeholder circle.
	var path := "res://game/art/regions/%s.png" % art_name
	if art_name != "" and ResourceLoader.exists(path):
		var sprite := Sprite2D.new()
		sprite.texture = load(path)
		sprite.scale = Vector2.ONE * (radius / 14.0) * 0.5
		return sprite
	var visual := Polygon2D.new()
	visual.polygon = Geometry.circle_points(radius)
	visual.color = fallback
	return visual


func _on_storm_peg_body(body: Node2D) -> void:
	# Same guard set as _on_catcher_body: only live, unresolved pods count.
	if not (body is RigidBody2D):
		return
	if body.has_meta("caught"):
		return
	body.set_meta("caught", true)
	_storm_swallow_puff(body.global_position)
	pod_caught.emit(body, {}, "storm")


func _storm_swallow_puff(at: Vector2) -> void:
	# Swallowed-pod feedback (audit 2.4 nice-to-have): a one-shot puff that
	# swells and fades where the pod vanished, then frees itself.
	var path := "res://game/art/regions/storm_swallow.png"
	if not ResourceLoader.exists(path):
		return
	var puff := Sprite2D.new()
	puff.texture = load(path)
	puff.global_position = at
	puff.scale = Vector2.ONE * 0.4
	add_child(puff)
	var tween := puff.create_tween()
	tween.set_parallel(true)
	tween.tween_property(puff, "scale", Vector2.ONE * 0.6, 0.35)
	tween.tween_property(puff, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(puff.queue_free)


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
		area.add_child(_barge_visual(String(barge.get("art", "")), half))
		_add_barge_pennant(area, barge.get("payout", {}) as Dictionary, half)
		area.body_entered.connect(_on_catcher_body.bind((barge.get("payout", {}) as Dictionary).duplicate(), "barge", area))
		$Barges.add_child(area)


func _barge_visual(art: String, half: Vector2) -> Node2D:
	# Barge sprites are authored square at 2x (200x200) with the hull in the
	# lower half, so the balloons float above the catch rect while the hull
	# spans it. The "art" tier lets high-payout barges look richer (audit 1.3);
	# anything without a matching sprite falls back to the old placeholder rectangle.
	var path := "res://game/art/run/barge%s.png" % ("_" + art if art != "" else "")
	if ResourceLoader.exists(path):
		var sprite := Sprite2D.new()
		sprite.texture = load(path)
		sprite.scale = Vector2.ONE * (half.x * 2.0 / sprite.texture.get_width())
		return sprite
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	visual.color = Color(0.35, 0.55, 0.4)
	return visual


func _add_barge_pennant(area: Area2D, payout: Dictionary, half: Vector2) -> void:
	# Material barges fly a tinted pennant (audit 1.3 "still wanted") so the
	# barges that pay the region's material read apart from scrap-only ones.
	for material in MATERIAL_PENNANTS:
		if not payout.has(material):
			continue
		var path := "res://game/art/run/barge_pennant_%s.png" % material
		if not ResourceLoader.exists(path):
			return
		var pennant := Sprite2D.new()
		pennant.texture = load(path)
		pennant.scale = Vector2.ONE * 0.5
		# Hoisted off the hull's outer corner, above the barge sprite's balloons.
		pennant.position = Vector2(half.x * 0.7, -half.y - 44.0)
		area.add_child(pennant)
		return


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


func _on_catcher_body(body: Node2D, payout: Dictionary, source: String, catcher: CanvasItem = null) -> void:
	if not (body is RigidBody2D):
		return
	if body.has_meta("caught"):
		return
	body.set_meta("caught", true)
	if catcher != null:
		_flash(catcher)
	pod_caught.emit(body, payout.duplicate(), source)


func _flash(item: CanvasItem) -> void:
	# Catch feedback: over-brighten the catcher, then ease back. Modulate above
	# white is Godot's no-spritesheet flash; the tween is owned by the item so
	# it dies with the board. Restarting from WHITE keeps rapid double catches
	# reading as two distinct flashes instead of compounding.
	item.modulate = Color.WHITE
	var tween := item.create_tween()
	tween.tween_property(item, "modulate", Color(2.5, 2.5, 2.5), 0.06)
	tween.tween_property(item, "modulate", Color.WHITE, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
