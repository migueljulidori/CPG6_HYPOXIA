extends RefCounted
## Afasta rats/aranhas das portas e spawns; adiciona ratos no centro do mapa.

const RAT_SCENE := preload("res://scenes/rat.tscn")
const DOOR_CLEAR_RADIUS := 240.0
## Maior que CHASE_RANGE de ratos/aranhas (~320-340) para nao aggro no spawn.
const PLAYER_CLEAR_RADIUS := 400.0
const PLAY_MIN := Vector2(-900.0, -580.0)
const PLAY_MAX := Vector2(900.0, 580.0)

const HUB_RAT_POSITIONS: Array[Vector2] = [
	Vector2(-420.0, -320.0),
	Vector2(420.0, -280.0),
	Vector2(-280.0, -180.0),
	Vector2(300.0, 120.0),
	Vector2(-520.0, 40.0),
	Vector2(520.0, 40.0),
	Vector2(0.0, -380.0),
]

static func apply(gameplay: Node2D) -> void:
	if gameplay == null:
		return
	var door_pts := _collect_door_points(gameplay)
	var player_pts := _collect_player_spawn_points(gameplay)
	_reposition_enemies(gameplay, door_pts, player_pts)
	_fill_hub_rats(gameplay, door_pts, player_pts)


static func request_refresh_from_scene(world: Node) -> void:
	if world == null:
		return
	var gameplay := world.get_node_or_null("Hub/Gameplay") as Node2D
	if gameplay == null:
		return
	var zone := "hub"
	var layout_node := gameplay.get_node_or_null("RoomLayout")
	if layout_node:
		zone = str(layout_node.get("puzzle_zone"))
	if zone == "hub":
		apply(gameplay)


static func _collect_door_points(gameplay: Node2D) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var scene_root := gameplay.get_tree().current_scene
	if scene_root == null:
		return pts
	for node in scene_root.find_children("*", "Marker2D", true, false):
		if node.is_in_group("spawn_marker"):
			pts.append((node as Marker2D).global_position)
	for node in scene_root.find_children("*", "", true, false):
		if not node is Node2D:
			continue
		var n := str(node.name)
		if n in ["ExitToHub", "ExitDoor", "ExitZone"] or n.begins_with("DoorSala"):
			pts.append((node as Node2D).global_position)
	return pts


static func _collect_player_spawn_points(gameplay: Node2D) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var tree := gameplay.get_tree()
	if tree == null:
		return pts
	var player := tree.get_first_node_in_group("player") as Node2D
	if player:
		pts.append(player.global_position)
	return pts


static func _reposition_enemies(
	gameplay: Node2D,
	door_pts: Array[Vector2],
	player_pts: Array[Vector2],
) -> void:
	for group_name in ["Rats", "Spiders"]:
		var root := gameplay.get_node_or_null(group_name) as Node2D
		if root == null:
			continue
		for child in root.get_children():
			if not child is Node2D:
				continue
			var n2d := child as Node2D
			var pushed := _push_away_from_zones(n2d.position, door_pts, DOOR_CLEAR_RADIUS)
			pushed = _push_away_from_zones(pushed, player_pts, PLAYER_CLEAR_RADIUS)
			n2d.position = _clamp_play(pushed)


static func _fill_hub_rats(
	gameplay: Node2D,
	door_pts: Array[Vector2],
	player_pts: Array[Vector2],
) -> void:
	var rats := _ensure_rats_root(gameplay)
	var target := HUB_RAT_POSITIONS.size()
	while rats.get_child_count() < target:
		var idx := rats.get_child_count()
		var pos := _safe_spawn_pos(HUB_RAT_POSITIONS[idx], door_pts, player_pts)
		_spawn_rat(rats, pos, idx)
	for i in rats.get_child_count():
		var rat := rats.get_child(i) as Node2D
		if rat == null:
			continue
		rat.position = _safe_spawn_pos(rat.position, door_pts, player_pts)


static func _safe_spawn_pos(
	pos: Vector2,
	door_pts: Array[Vector2],
	player_pts: Array[Vector2],
) -> Vector2:
	var out := _push_away_from_zones(pos, door_pts, DOOR_CLEAR_RADIUS)
	out = _push_away_from_zones(out, player_pts, PLAYER_CLEAR_RADIUS)
	return _clamp_play(out)


static func _ensure_rats_root(gameplay: Node2D) -> Node2D:
	var rats := gameplay.get_node_or_null("Rats") as Node2D
	if rats == null:
		rats = Node2D.new()
		rats.name = "Rats"
		gameplay.add_child(rats)
	return rats


static func _spawn_rat(parent: Node2D, pos: Vector2, index: int) -> void:
	var rat: CharacterBody2D = RAT_SCENE.instantiate()
	rat.name = "Rat_%d" % index
	rat.position = pos
	var axis := Vector2(1.0, 0.0) if index % 2 == 0 else Vector2(0.0, 1.0)
	if index % 3 == 0:
		axis = Vector2(0.6, 0.6)
	rat.set("patrol_axis", axis)
	parent.add_child(rat)


static func _push_away_from_zones(pos: Vector2, centers: Array[Vector2], min_dist: float) -> Vector2:
	var out := pos
	for _pass in 4:
		for center in centers:
			var delta := out - center
			var dist := delta.length()
			if dist < min_dist:
				var dir := delta.normalized() if dist > 0.5 else Vector2(1.0, 0.0)
				out = center + dir * min_dist
	return out


static func _clamp_play(p: Vector2) -> Vector2:
	return Vector2(
		clampf(p.x, PLAY_MIN.x, PLAY_MAX.x),
		clampf(p.y, PLAY_MIN.y, PLAY_MAX.y),
	)
