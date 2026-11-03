extends Area2D
## Saida de vitoria: liberada apos concluir as 3 salas de funcoes.

@export var requires_all_salas: bool = true

var _won: bool = false
var _player_inside: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	monitoring = true
	if GameManager and not GameManager.salas_progress_changed.is_connected(_on_salas_progress):
		GameManager.salas_progress_changed.connect(_on_salas_progress)
	_sync_requirement()


func _on_salas_progress(_cleared: int, _total: int) -> void:
	_sync_requirement()


func _sync_requirement() -> void:
	if GameManager:
		requires_all_salas = not GameManager.are_all_salas_cleared()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or _won or requires_all_salas:
		return
	if not event.is_action_pressed(&"interact") or event.is_echo():
		return
	if not GameManager.are_all_salas_cleared():
		return
	_won = true
	monitoring = false
	get_viewport().set_input_as_handled()
	GameManager.complete_escape()
