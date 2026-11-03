extends Node
## Places the player on the matching SpawnMarker after a scene change.


func _ready() -> void:
	if AudioManager:
		AudioManager.call_deferred("ensure_bgm_playing")
	call_deferred("_apply_spawn")


func _apply_spawn() -> void:
	var spawn_id := GameManager.consume_spawn_id()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and not spawn_id.is_empty():
		for node in get_tree().get_nodes_in_group("spawn_marker"):
			if node is Marker2D and node.get("spawn_id") == spawn_id:
				player.global_position = (node as Marker2D).global_position
				break
	call_deferred("_refresh_mobs_away_from_player")


func _refresh_mobs_away_from_player() -> void:
	var layout := load("res://scripts/gameplay_mob_layout.gd")
	if layout:
		layout.call("request_refresh_from_scene", self)
