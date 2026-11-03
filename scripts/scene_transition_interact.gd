extends Area2D
## Press E in this zone to change scene (hub door, sala exit, etc.).

@export_file("*.tscn") var target_scene: String = ""
@export var enter_spawn_id: String = ""
@export var hint_ready: String = "[E] ENTRAR"
@export var ignore_function_puzzle_lock: bool = false
@export var block_if_sala_cleared: String = ""
@export var hint_sala_cleared: String = "Sala concluida"

@onready var _hint: Label = $HintLabel

var _player_inside: bool = false


func _ready() -> void:
	monitoring = true
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	call_deferred("_post_ready_setup")


func _post_ready_setup() -> void:
	var sala := _blocked_sala_id()
	if sala != "" and not GameManager.salas_progress_changed.is_connected(_on_salas_progress):
		GameManager.salas_progress_changed.connect(_on_salas_progress)
	_apply_sala_block_state()
	_refresh_hint()


func configure_sala_entry_block(sala_id: String, hint_blocked: String = "") -> void:
	block_if_sala_cleared = sala_id
	if hint_blocked != "":
		hint_sala_cleared = hint_blocked
	if is_inside_tree():
		call_deferred("_post_ready_setup")


func _input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if _is_sala_entry_blocked():
		return
	if MathTerminalUI and MathTerminalUI.visible:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("is_terminal_active") and player.is_terminal_active():
		return
	if (
		not ignore_function_puzzle_lock
		and player
		and player.has_method("is_function_puzzle_mode")
		and player.is_function_puzzle_mode()
	):
		return
	if event.is_action_pressed(&"interact") and not event.is_echo():
		_prepare_scene_change()
		_transition()
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_refresh_hint()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_refresh_hint()


func _on_salas_progress(_cleared: int, _total: int) -> void:
	_apply_sala_block_state()
	_refresh_hint()


func _blocked_sala_id() -> String:
	if not block_if_sala_cleared.is_empty():
		return block_if_sala_cleared
	if GameManager:
		return GameManager.sala_id_for_scene(target_scene)
	return ""


func _is_sala_entry_blocked() -> bool:
	var sala := _blocked_sala_id()
	return sala != "" and not GameManager.can_enter_sala(sala)


func _apply_sala_block_state() -> void:
	monitoring = not _is_sala_entry_blocked()


func _refresh_hint() -> void:
	if _hint == null:
		return
	if _is_sala_entry_blocked():
		_hint.text = hint_sala_cleared
		_hint.visible = _player_inside
		return
	if _player_inside:
		_hint.text = hint_ready
		_hint.visible = hint_ready != ""
	else:
		_hint.visible = false


func _prepare_scene_change() -> void:
	var puzzle := get_tree().get_first_node_in_group("function_puzzle")
	if puzzle and puzzle.has_method("_shutdown_puzzle"):
		puzzle.call("_shutdown_puzzle")


func _transition() -> void:
	if _is_sala_entry_blocked():
		return
	if target_scene.is_empty():
		push_error("scene_transition_interact: target_scene is empty on %s" % name)
		return
	if not ResourceLoader.exists(target_scene):
		push_error("scene_transition_interact: missing scene %s" % target_scene)
		return
	if not enter_spawn_id.is_empty():
		GameManager.queue_spawn(enter_spawn_id)
	if AudioManager:
		AudioManager.play_door()
		AudioManager.call_deferred("ensure_bgm_playing")
	var tree := get_tree()
	if tree:
		tree.call_deferred("change_scene_to_file", target_scene)
