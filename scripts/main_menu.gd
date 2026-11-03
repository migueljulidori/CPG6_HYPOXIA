extends Control
## Main menu: start game, instructions, credits.

const GAME_SCENE := "res://scenes/main.tscn"
const FONT_PATH := "res://assets/fonts/PressStart2P.ttf"

const INSTRUCTIONS_TEXT := (
	"OBJETIVO > Explore o hub, entre nas 3 salas (em qualquer ordem) e monte o caminho "
	+ "do morcego com funcoes (afim, quadratica e exponencial). "
	+ "Conclua as 3 salas para liberar a saida antes do oxigenio acabar!\n\n"
	+ "HUB > Portas sempre abertas. Terminal central [E]: resposta 404 = -15s no tempo final.\n\n"
	+ "CONTROLES:\n\n"
	+ "[ WASD ] ou [ Setas ] - Movimentar.\n\n"
	+ "[ CTRL ] - Pulso de sonar (cooldown ~2,7s).\n\n"
	+ "[ ALT ] - Dash / ataque (consome oxigenio; liberta teias).\n\n"
	+ "NAS SALAS > 4 opcoes por trecho; passe o mouse para ver o caminho.\n\n"
	+ "[ E ] - Portas e voltar ao hub.\n\n"
	+ "Bom jogo!"
)

const CREDITS_TEXT := (
	"EQUIPE DE DESENVOLVIMENTO:\n\n"
	+ "[Miguel Julidori]: Programa\u00e7\u00e3o (Godot) e Level Design\n\n"
	+ "[Yan Gabardo]: Pixel Art, UI e Anima\u00e7\u00f5es\n\n"
	+ "[Iury Gon\u00e7alves]: \u00c1udio (SFX/BGM) e Game Design\n\n"
	+ "Desenvolvido em 36h para o Coding, Pizza & Glory (CDG) - 2026"
)

const LOGO_WIDTH_RATIO := 0.74
const LOGO_MIN_WIDTH := 520.0
const LOGO_MAX_WIDTH := 980.0
const LOGO_TOP_Y_RATIO := 0.09
const LOGO_TOP_Y_MIN := 64.0
const LOGO_TOP_Y_MAX := 104.0
const INSTRUCTIONS_LINE_SPACING := 8

@onready var _menu_panel: Control = $MenuPanel
@onready var _logo: TextureRect = $Logo
@onready var _instructions_panel: Control = $InstructionsPanel
@onready var _credits_panel: Control = $CreditsPanel
@onready var _btn_start: Button = $MenuPanel/Center/MenuRoot/BtnStart
@onready var _btn_instructions: Button = $MenuPanel/Center/MenuRoot/BtnInstructions
@onready var _btn_credits: Button = $MenuPanel/Center/MenuRoot/BtnCredits
@onready var _btn_back_instructions: Button = $InstructionsPanel/Margin/VBox/BtnBack
@onready var _btn_back_credits: Button = $CreditsPanel/Margin/VBox/BtnBack
@onready var _instructions_header: Label = $InstructionsPanel/Margin/VBox/Header
@onready var _instructions_body: Label = $InstructionsPanel/Margin/VBox/Scroll/Body
@onready var _credits_header: Label = $CreditsPanel/Margin/VBox/Header
@onready var _credits_body: Label = $CreditsPanel/Margin/VBox/Scroll/Body
@onready var _menu_center: CenterContainer = $MenuPanel/Center

var _menu_font: Font
var _starting: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var loaded := load(FONT_PATH)
	if loaded is Font:
		_menu_font = loaded
		_apply_font_recursive(self)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_setup_menu()


func _on_viewport_resized() -> void:
	_layout_logo()


func _set_logo_visible(show_logo: bool) -> void:
	if _logo:
		_logo.visible = show_logo


func _layout_logo() -> void:
	if _logo == null:
		return
	var vp := get_viewport_rect().size
	var logo_w := clampf(vp.x * LOGO_WIDTH_RATIO, LOGO_MIN_WIDTH, LOGO_MAX_WIDTH)
	var logo_h := logo_w * (1184.0 / 3546.0)
	_logo.custom_minimum_size = Vector2(logo_w, logo_h)
	_logo.size = Vector2(logo_w, logo_h)
	_logo.offset_left = -logo_w * 0.5
	_logo.offset_right = logo_w * 0.5
	_logo.offset_top = clampf(vp.y * LOGO_TOP_Y_RATIO, LOGO_TOP_Y_MIN, LOGO_TOP_Y_MAX)
	_logo.offset_bottom = _logo.offset_top + logo_h
	if _menu_center:
		_menu_center.offset_top = logo_h + 36.0


func _setup_menu() -> void:
	_layout_logo()
	if GameManager:
		GameManager.set_run_active(false)

	_menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_show_main_buttons()
	_btn_start.text = "> INICIAR"
	_btn_instructions.text = "> INSTRU\u00c7\u00d5ES"
	_btn_credits.text = "> CR\u00c9DITOS"
	if _instructions_header:
		_instructions_header.text = "INSTRU\u00c7\u00d5ES"
	if _credits_header:
		_credits_header.text = "CR\u00c9DITOS"

	if _instructions_body:
		_instructions_body.text = INSTRUCTIONS_TEXT
		_instructions_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_instructions_body.add_theme_font_size_override(&"font_size", 12)
		_instructions_body.add_theme_constant_override(&"line_spacing", INSTRUCTIONS_LINE_SPACING)
	if _credits_body:
		_credits_body.text = CREDITS_TEXT
		_credits_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_credits_body.add_theme_font_size_override(&"font_size", 11)
		_credits_body.add_theme_constant_override(&"line_spacing", 6)

	_style_all_menu_buttons()

	if not _btn_start.pressed.is_connected(_on_start_pressed):
		_btn_start.pressed.connect(_on_start_pressed)
	if not _btn_instructions.pressed.is_connected(_on_instructions_pressed):
		_btn_instructions.pressed.connect(_on_instructions_pressed)
	if not _btn_credits.pressed.is_connected(_on_credits_pressed):
		_btn_credits.pressed.connect(_on_credits_pressed)
	if not _btn_back_instructions.pressed.is_connected(_show_main_buttons):
		_btn_back_instructions.pressed.connect(_show_main_buttons)
	if not _btn_back_credits.pressed.is_connected(_show_main_buttons):
		_btn_back_credits.pressed.connect(_show_main_buttons)

	_btn_start.grab_focus()

	if has_node("/root/AudioManager"):
		AudioManager.call_deferred("ensure_bgm_playing")


func _unhandled_input(event: InputEvent) -> void:
	if _starting:
		return
	if not _menu_panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and (
		event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER
	):
		_on_start_pressed()
		get_viewport().set_input_as_handled()


func _style_all_menu_buttons() -> void:
	for btn in [
		_btn_start,
		_btn_instructions,
		_btn_credits,
		_btn_back_instructions,
		_btn_back_credits,
	]:
		_style_text_button(btn)


func _style_text_button(btn: Button) -> void:
	if btn == null:
		return
	btn.flat = true
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override(&"normal", empty)
	btn.add_theme_stylebox_override(&"hover", empty)
	btn.add_theme_stylebox_override(&"pressed", empty)
	btn.add_theme_stylebox_override(&"focus", empty)
	btn.add_theme_stylebox_override(&"disabled", empty)
	btn.add_theme_color_override(&"font_color", Color(0.92, 0.95, 1.0, 1.0))
	btn.add_theme_color_override(&"font_hover_color", Color(0.45, 1.0, 0.65, 1.0))
	btn.add_theme_color_override(&"font_pressed_color", Color(0.35, 0.85, 0.5, 1.0))
	btn.add_theme_color_override(&"font_focus_color", Color(0.55, 1.0, 0.72, 1.0))


func _apply_font_recursive(node: Node) -> void:
	if _menu_font == null:
		return
	if node is Label:
		(node as Label).add_theme_font_override(&"font", _menu_font)
	elif node is Button:
		(node as Button).add_theme_font_override(&"font", _menu_font)
	for child in node.get_children():
		_apply_font_recursive(child)


func _show_main_buttons() -> void:
	_menu_panel.visible = true
	_menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_instructions_panel.visible = false
	_credits_panel.visible = false
	_instructions_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_credits_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_logo_visible(true)
	_btn_start.grab_focus()


func _on_start_pressed() -> void:
	if _starting:
		return
	_starting = true
	if GameManager:
		GameManager.start_new_run()
	if not ResourceLoader.exists(GAME_SCENE):
		push_error("MainMenu: cena do jogo nao encontrada: %s" % GAME_SCENE)
		_starting = false
		return
	var err := get_tree().change_scene_to_file(GAME_SCENE)
	if err != OK:
		push_error("MainMenu: falha ao trocar cena (%s)" % error_string(err))
		_starting = false


func _on_instructions_pressed() -> void:
	_menu_panel.visible = false
	_set_logo_visible(false)
	_instructions_panel.visible = true
	_instructions_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_credits_panel.visible = false
	_btn_back_instructions.grab_focus()


func _on_credits_pressed() -> void:
	_menu_panel.visible = false
	_set_logo_visible(false)
	_instructions_panel.visible = false
	_credits_panel.visible = true
	_credits_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_btn_back_credits.grab_focus()
