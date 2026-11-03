extends Node2D
## Hub: pergunta 404 no centro; tres portas sempre abertas; saida apos limpar as salas.

const HUB_LIFE_QUESTION_SCENE := "res://scenes/hub_life_question.tscn"
const HUB_LIFE_QUESTION_POS := Vector2(0, 80)

@export_file("*.tscn") var sala1_scene: String = "res://scenes/sala1.tscn"
@export_file("*.tscn") var sala2_scene: String = "res://scenes/sala2.tscn"
@export_file("*.tscn") var sala3_scene: String = "res://scenes/sala3.tscn"

var _exit_label: Label
var _exit_zone: Area2D


func _ready() -> void:
	call_deferred("_setup_hub")


func _setup_hub() -> void:
	var gameplay := get_parent()
	if gameplay:
		_exit_label = gameplay.get_node_or_null("ExitDoor/DoorLabel") as Label
		_exit_zone = gameplay.get_node_or_null("ExitZone") as Area2D
	_spawn_life_question()
	_configure_doors()
	_sync_exit()
	GameManager.salas_progress_changed.connect(_on_salas_progress)


func _on_salas_progress(_cleared: int, _total: int) -> void:
	_sync_exit()
	_refresh_hub_doors()


func _spawn_life_question() -> void:
	if get_node_or_null("HubLifeQuestion"):
		return
	if not ResourceLoader.exists(HUB_LIFE_QUESTION_SCENE):
		push_error("HubGameplay: cena HubLifeQuestion ausente")
		return
	var packed: PackedScene = load(HUB_LIFE_QUESTION_SCENE) as PackedScene
	if packed == null:
		return
	var term := packed.instantiate()
	term.name = "HubLifeQuestion"
	term.position = HUB_LIFE_QUESTION_POS
	add_child(term)


func _configure_doors() -> void:
	var defs: Array[Dictionary] = [
		{
			"door_name": "DoorSala1",
			"pos": Vector2(980, -40),
			"scene": sala1_scene,
			"spawn": "hub_to_sala1",
			"label": "SALA 1",
			"sala_id": "sala1",
		},
		{
			"door_name": "DoorSala2",
			"pos": Vector2(-980, 80),
			"scene": sala2_scene,
			"spawn": "hub_to_sala2",
			"label": "SALA 2",
			"sala_id": "sala2",
		},
		{
			"door_name": "DoorSala3",
			"pos": Vector2(0, 560),
			"scene": sala3_scene,
			"spawn": "hub_to_sala3",
			"label": "SALA 3",
			"sala_id": "sala3",
		},
	]
	var door_scene: PackedScene = load("res://scenes/sala_hub_door.tscn") as PackedScene
	for d in defs:
		var door := get_node_or_null(d["door_name"])
		if door == null:
			if door_scene == null:
				continue
			door = door_scene.instantiate()
			door.name = d["door_name"]
		door.position = d["pos"]
		door.set("target_scene", d["scene"])
		door.set("enter_spawn_id", d["spawn"])
		door.set("door_label", d["label"])
		door.set("sala_id", d.get("sala_id", ""))
		if door.get_parent() == null:
			add_child(door)
		if door.has_method("configure_interact"):
			door.call("configure_interact")
		if door.has_method("_sync_cleared_visual"):
			door.call_deferred("_sync_cleared_visual")
	_add_spawn_markers()
	_refresh_hub_doors()


func _refresh_hub_doors() -> void:
	for door_name in ["DoorSala1", "DoorSala2", "DoorSala3"]:
		var door := get_node_or_null(door_name)
		if door and door.has_method("_sync_cleared_visual"):
			door.call("_sync_cleared_visual")


func _add_spawn_markers() -> void:
	var marker_script: Script = load("res://scripts/spawn_marker.gd") as Script
	var spots: Array[Dictionary] = [
		{"id": "hub_to_sala1", "pos": Vector2(920, -40)},
		{"id": "hub_to_sala2", "pos": Vector2(-920, 80)},
		{"id": "hub_to_sala3", "pos": Vector2(0, 560)},
		{"id": "sala1_to_hub", "pos": Vector2(918, -8)},
		{"id": "sala2_to_hub", "pos": Vector2(-918, 8)},
		{"id": "sala3_to_hub", "pos": Vector2(0, 500)},
	]
	for s in spots:
		if get_node_or_null("Spawn_" + s["id"]):
			continue
		var m := Marker2D.new()
		m.name = "Spawn_" + s["id"]
		m.position = s["pos"]
		m.set_script(marker_script)
		m.set("spawn_id", s["id"])
		m.add_to_group("spawn_marker")
		add_child(m)


func _sync_exit() -> void:
	var open := GameManager.are_all_salas_cleared()
	if _exit_label:
		if open:
			_exit_label.text = "VITORIA [E]"
			_exit_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.75))
		else:
			var n := GameManager.salas_cleared_count()
			_exit_label.text = "SAIDA (%d/3 salas)" % n
			_exit_label.add_theme_color_override("font_color", Color(0.9, 0.35, 0.4))
	if _exit_zone:
		_exit_zone.set("requires_all_salas", not open)
