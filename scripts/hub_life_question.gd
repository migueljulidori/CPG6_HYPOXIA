extends Area2D
## Terminal central do hub: pergunta da vida (resposta 404), uma vez por partida.

const QUESTION := "Qual o sentido da vida?"
const ANSWER := "404"

const COLOR_SCREEN_IDLE := Color(0.05, 0.18, 0.1, 1.0)
const COLOR_SCREEN_ACTIVE := Color(0.08, 0.28, 0.14, 1.0)
const COLOR_SCREEN_SOLVED := Color(0.06, 0.1, 0.08, 1.0)
const COLOR_SCREEN_FLASH := Color(0.2, 0.95, 0.45, 1.0)

var _player_inside: bool = false
var _solved: bool = false
var _failed: bool = false
var _reacting: bool = false
var _tween: Tween

@onready var _screen: Polygon2D = $Screen
@onready var _seq_label: Label = $ScreenSeqLabel
@onready var _solved_mark: Label = $SolvedMark
@onready var _prompt: Label = $PromptLabel


func _ready() -> void:
	add_to_group("hub_life_question")
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if GameManager and GameManager.hub_life_question_solved:
		_mark_solved_idle()
	elif GameManager and GameManager.hub_life_question_failed:
		_mark_failed_idle()
	else:
		_apply_idle_visual()
		_refresh_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if _solved or _failed or _reacting or not _player_inside:
		return
	if event.is_action_pressed(&"interact"):
		_try_open()
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_refresh_prompt()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_refresh_prompt()


func _try_open() -> void:
	if _solved or _failed or _reacting:
		return
	if GameManager and not GameManager.can_attempt_hub_life_question():
		return
	if _screen:
		_screen.color = COLOR_SCREEN_ACTIVE
	if _seq_label:
		_seq_label.text = "?"
		_seq_label.visible = true
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_terminal_active"):
		player.set_terminal_active(true)
	MathTerminalUI.open_question(self, QUESTION, ANSWER)


func on_question_solved() -> void:
	if _solved or _reacting:
		return
	if GameManager == null or not GameManager.try_solve_hub_life_question():
		return
	_reacting = true
	monitoring = false
	if AudioManager:
		AudioManager.play_key()
	_play_solved_reaction()
	_close_player_terminal()


func on_question_failed() -> void:
	if _solved or _failed:
		return
	if GameManager:
		GameManager.mark_hub_life_question_failed()
	_mark_failed_idle()
	_close_player_terminal()


func on_question_cancelled() -> void:
	if _solved or _failed:
		return
	_clear_screen()
	_apply_idle_visual()
	_close_player_terminal()


func _play_solved_reaction() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	scale = Vector2.ONE
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "scale", Vector2(1.14, 1.14), 0.1).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(_screen, "color", COLOR_SCREEN_FLASH, 0.08)
	if _seq_label:
		_tween.tween_property(_seq_label, "modulate:a", 0.0, 0.42)
	var chain := create_tween()
	chain.tween_interval(0.1)
	chain.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC)
	chain.parallel().tween_property(_screen, "color", COLOR_SCREEN_SOLVED, 0.35)
	chain.tween_callback(_finish_solved_reaction)


func _finish_solved_reaction() -> void:
	_mark_solved_idle()
	_reacting = false


func _mark_solved_idle() -> void:
	_solved = true
	_failed = false
	_reacting = false
	monitoring = false
	_clear_screen()
	if _screen:
		_screen.color = COLOR_SCREEN_SOLVED
	if _solved_mark:
		_solved_mark.text = "OK"
		_solved_mark.add_theme_color_override(&"font_color", Color(0.35, 1, 0.5, 1.0))
		_solved_mark.visible = true
		_solved_mark.modulate.a = 1.0
	_refresh_prompt()


func _mark_failed_idle() -> void:
	_failed = true
	_solved = false
	_reacting = false
	monitoring = false
	_clear_screen()
	if _screen:
		_screen.color = Color(0.08, 0.06, 0.08, 1.0)
	if _solved_mark:
		_solved_mark.visible = true
		_solved_mark.text = "X"
		_solved_mark.add_theme_color_override(&"font_color", Color(0.95, 0.35, 0.35, 1.0))
		_solved_mark.modulate.a = 1.0
	_refresh_prompt()


func _clear_screen() -> void:
	if _seq_label:
		_seq_label.text = ""
		_seq_label.visible = false
		_seq_label.modulate = Color(0.55, 1.0, 0.7, 1.0)


func _apply_idle_visual() -> void:
	if _screen:
		_screen.color = COLOR_SCREEN_IDLE
	if _solved_mark:
		_solved_mark.text = "OK"
		_solved_mark.add_theme_color_override(&"font_color", Color(0.35, 1, 0.5, 1.0))
		_solved_mark.visible = false


func _refresh_prompt() -> void:
	if _prompt == null:
		return
	if _failed:
		_prompt.text = ""
	elif _solved:
		_prompt.text = "OK -15s tempo"
		_prompt.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.55, 1.0))
	elif _player_inside:
		_prompt.text = "[E] ?"
		_prompt.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.65, 1.0))
	else:
		_prompt.text = "[E] ?"


func _close_player_terminal() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_terminal_active"):
		player.set_terminal_active(false)
