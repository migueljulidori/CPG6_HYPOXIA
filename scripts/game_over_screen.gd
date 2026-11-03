extends Control
## Tela de game over (oxigenio ou vidas).

const MENU_SCENE := "res://scenes/main_menu.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const FONT_PATH := "res://assets/fonts/PressStart2P.ttf"

const REASON_OXYGEN := "O oxigenio acabou..."
const REASON_LIVES := "Todas as vidas foram perdidas..."

@onready var _bg: ColorRect = $Background
@onready var _title: Label = $Center/VBox/Title
@onready var _reason: Label = $Center/VBox/Reason
@onready var _btn_retry: Button = $Center/VBox/BtnRetry
@onready var _btn_menu: Button = $Center/VBox/BtnMenu

var _menu_font: Font
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var loaded := load(FONT_PATH)
	if loaded is Font:
		_menu_font = loaded
	_apply_reason_text()
	_style_ui()
	_btn_retry.pressed.connect(_on_retry_pressed)
	_btn_menu.pressed.connect(_on_menu_pressed)
	_btn_retry.grab_focus()
	_fade_in()


func _apply_reason_text() -> void:
	var txt := REASON_OXYGEN
	if GameManager:
		match GameManager.game_over_cause:
			GameManager.GameOverCause.LIVES:
				txt = REASON_LIVES
			GameManager.GameOverCause.OXYGEN:
				txt = REASON_OXYGEN
	_reason.text = txt


func _style_ui() -> void:
	if _bg:
		_bg.color = Color(0.1, 0.05, 0.16, 1.0)
	if _title:
		_title.text = "GAME OVER"
		_title.add_theme_font_size_override(&"font_size", 42)
		_title.add_theme_color_override(&"font_color", Color(0.78, 0.42, 1.0, 1.0))
		_title.add_theme_color_override(&"font_outline_color", Color(0.25, 0.08, 0.35, 1.0))
		_title.add_theme_constant_override(&"outline_size", 6)
	if _reason:
		_reason.add_theme_font_size_override(&"font_size", 12)
		_reason.add_theme_color_override(&"font_color", Color(0.72, 0.58, 0.92, 1.0))
	for btn in [_btn_retry, _btn_menu]:
		_style_button(btn)
	if _menu_font:
		_apply_font(self)


func _style_button(btn: Button) -> void:
	if btn == null:
		return
	btn.flat = true
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override(&"normal", empty)
	btn.add_theme_stylebox_override(&"hover", empty)
	btn.add_theme_stylebox_override(&"pressed", empty)
	btn.add_theme_stylebox_override(&"focus", empty)
	btn.add_theme_color_override(&"font_color", Color(0.88, 0.78, 1.0, 1.0))
	btn.add_theme_color_override(&"font_hover_color", Color(0.95, 0.55, 1.0, 1.0))
	btn.add_theme_color_override(&"font_pressed_color", Color(0.7, 0.4, 0.95, 1.0))
	btn.add_theme_font_size_override(&"font_size", 14)


func _apply_font(node: Node) -> void:
	if node is Label:
		(node as Label).add_theme_font_override(&"font", _menu_font)
	elif node is Button:
		(node as Button).add_theme_font_override(&"font", _menu_font)
	for child in node.get_children():
		_apply_font(child)


func _fade_in() -> void:
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_retry_pressed() -> void:
	if _busy:
		return
	_busy = true
	if GameManager:
		GameManager.start_new_run()
	_change_scene(GAME_SCENE)


func _on_menu_pressed() -> void:
	if _busy:
		return
	_busy = true
	if GameManager:
		GameManager.set_run_active(false)
	_change_scene(MENU_SCENE)


func _change_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("GameOver: cena nao encontrada: %s" % path)
		_busy = false
		return
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("GameOver: falha ao trocar cena (%s)" % error_string(err))
		_busy = false
