extends CanvasLayer
## UI da pergunta central do hub (404). O2 continua drenando; inimigos congelam.

const FONT_PATH := "res://assets/fonts/PressStart2P.ttf"

@onready var _title_label: Label = $Center/Panel/Margin/VBox/TitleLabel
@onready var _sequence_label: Label = $Center/Panel/Margin/VBox/SequenceLabel
@onready var _hint_label: Label = $Center/Panel/Margin/VBox/HintLabel
@onready var _answer_edit: LineEdit = $Center/Panel/Margin/VBox/AnswerEdit

var _expected_answer: String = ""
var _terminal: Node = null
var _last_text_len: int = 0
var _menu_font: Font
var _hub_frozen: bool = false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _title_label:
		_title_label.visible = false
	var loaded := load(FONT_PATH)
	if loaded is Font:
		_menu_font = loaded
		_apply_font_recursive(self)
	if _answer_edit:
		_answer_edit.text_submitted.connect(_on_text_submitted)
		_answer_edit.text_changed.connect(_on_text_changed)
	if GameManager:
		GameManager.game_over.connect(_on_game_over)


func open_question(
	terminal: Node,
	question: String,
	answer: String,
	hint: String = "Resposta | Enter confirmar | Esc cancelar",
	freeze_hub: bool = true,
) -> void:
	if _sequence_label == null or _hint_label == null or _answer_edit == null:
		push_error("MathTerminalUI nodes missing; check scene tree paths.")
		return
	_terminal = terminal
	_expected_answer = answer.strip_edges()
	_apply_question_font_sizes()
	_sequence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sequence_label.text = question
	_hint_label.text = hint
	_answer_edit.text = ""
	_answer_edit.placeholder_text = "..."
	_last_text_len = 0
	_set_hub_frozen(freeze_hub and _is_hub_life_terminal())
	visible = true
	call_deferred("_focus_answer")


func close() -> void:
	_set_hub_frozen(false)
	visible = false
	_terminal = null
	if _answer_edit:
		_answer_edit.release_focus()


func force_close() -> void:
	_set_hub_frozen(false)
	visible = false
	_terminal = null
	if _answer_edit:
		_answer_edit.release_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()


func _on_text_changed(new_text: String) -> void:
	if new_text.length() > _last_text_len:
		AudioManager.play_terminal_key()
	_last_text_len = new_text.length()


func _on_text_submitted(text: String) -> void:
	if _answer_edit == null:
		return
	var guess := text.strip_edges()
	if guess == _expected_answer:
		AudioManager.play_terminal_success()
		if _terminal and _terminal.has_method("on_question_solved"):
			_terminal.on_question_solved()
		close()
	else:
		AudioManager.play_terminal_error()
		if _is_hub_life_terminal():
			if _terminal and _terminal.has_method("on_question_failed"):
				_terminal.on_question_failed()
			close()
			return
		_answer_edit.text = ""
		_last_text_len = 0
		_answer_edit.grab_focus()


func _cancel() -> void:
	if _terminal and _terminal.has_method("on_question_cancelled"):
		_terminal.on_question_cancelled()
	close()


func _on_game_over() -> void:
	force_close()


func _focus_answer() -> void:
	if _answer_edit:
		_answer_edit.grab_focus()


func _is_hub_life_terminal() -> bool:
	return _terminal != null and _terminal.is_in_group("hub_life_question")


func _set_hub_frozen(frozen: bool) -> void:
	if frozen == _hub_frozen:
		return
	_hub_frozen = frozen
	if GameManager:
		GameManager.set_hub_gameplay_frozen(frozen)


func _apply_font_recursive(node: Node) -> void:
	if _menu_font == null:
		return
	if node is Label:
		(node as Label).add_theme_font_override(&"font", _menu_font)
	elif node is LineEdit:
		(node as LineEdit).add_theme_font_override(&"font", _menu_font)
	for child in node.get_children():
		_apply_font_recursive(child)


func _apply_question_font_sizes() -> void:
	if _sequence_label:
		_sequence_label.add_theme_font_size_override(&"font_size", 12)
	if _hint_label:
		_hint_label.add_theme_font_size_override(&"font_size", 9)
	if _answer_edit:
		_answer_edit.add_theme_font_size_override(&"font_size", 12)
