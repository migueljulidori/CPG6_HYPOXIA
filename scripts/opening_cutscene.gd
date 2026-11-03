extends Control
## Cutscene de abertura antes do menu. Enter pula para o menu.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const FONT_PATH := "res://assets/fonts/PressStart2P.ttf"
const TEXT_PANEL_BG := "res://assets/ui/menu/background_texto.png"
const CHAR_DELAY := 0.04
const AUTO_ADVANCE_AFTER_TEXT := 3.2
const FADE_SLIDE_SEC := 0.35
const TEXT_PANEL_WIDTH := 720.0
const TEXT_PANEL_HEIGHT := 84.0
const TEXT_PANEL_BOTTOM := 22.0
const TEXT_PANEL_FONT_SIZE := 10

const SLIDES: Array[Dictionary] = [
	{
		"image": "res://assets/cutscene/cutscene_01.png",
		"text": "A noite estava perfeita para um voo tranquilo...",
	},
	{
		"image": "res://assets/cutscene/cutscene_02.png",
		"text": "...at\u00e9 um pequeno erro de c\u00e1lculo mudar a rota.",
	},
	{
		"image": "res://assets/cutscene/cutscene_03.png",
		"text": "Preso num por\u00e3o abandonado, o ar \u00e9 denso e t\u00f3xico. O tempo \u00e9 curto...",
	},
]

const BLACK_SLIDE_TEXT := "A l\u00f3gica \u00e9 a \u00fanica sa\u00edda."

var _slide_index: int = 0
var _typing: bool = false
var _typed_chars: int = 0
var _type_accum: float = 0.0
var _hold_timer: float = 0.0
var _full_text: String = ""
var _font: Font
var _image: TextureRect
var _black: ColorRect
var _caption: Label
var _skip_hint: Label
var _text_panel: PanelContainer
var _fade: ColorRect
var _fade_tween: Tween
var _leaving: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var loaded := load(FONT_PATH)
	if loaded is Font:
		_font = loaded
	_build_ui()
	if GameManager:
		GameManager.set_run_active(false)
	_show_slide(0, false)


func _build_ui() -> void:
	_black = ColorRect.new()
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.color = Color(0.02, 0.02, 0.04, 1.0)
	_black.visible = false
	add_child(_black)

	_image = TextureRect.new()
	_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_image)

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	_text_panel = PanelContainer.new()
	_text_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_text_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_text_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var half_w := TEXT_PANEL_WIDTH * 0.5
	_text_panel.offset_left = -half_w
	_text_panel.offset_right = half_w
	_text_panel.offset_bottom = -TEXT_PANEL_BOTTOM
	_text_panel.offset_top = -(TEXT_PANEL_BOTTOM + TEXT_PANEL_HEIGHT)
	if ResourceLoader.exists(TEXT_PANEL_BG):
		var sb := StyleBoxTexture.new()
		sb.texture = load(TEXT_PANEL_BG)
		sb.texture_margin_left = 8.0
		sb.texture_margin_top = 8.0
		sb.texture_margin_right = 8.0
		sb.texture_margin_bottom = 8.0
		_text_panel.add_theme_stylebox_override(&"panel", sb)
	add_child(_text_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 12)
	margin.add_theme_constant_override(&"margin_top", 8)
	margin.add_theme_constant_override(&"margin_right", 12)
	margin.add_theme_constant_override(&"margin_bottom", 8)
	_text_panel.add_child(margin)

	_caption = Label.new()
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_color_override(&"font_color", Color(0.92, 0.95, 1.0, 1.0))
	if _font:
		_caption.add_theme_font_override(&"font", _font)
	_caption.add_theme_font_size_override(&"font_size", TEXT_PANEL_FONT_SIZE)
	margin.add_child(_caption)

	_skip_hint = Label.new()
	_skip_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_hint.offset_left = -360.0
	_skip_hint.offset_top = -22.0
	_skip_hint.offset_right = -16.0
	_skip_hint.offset_bottom = -6.0
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint.text = "[ ENTER ] pular"
	_skip_hint.add_theme_color_override(&"font_color", Color(0.55, 0.58, 0.65, 0.9))
	if _font:
		_skip_hint.add_theme_font_override(&"font", _font)
	_skip_hint.add_theme_font_size_override(&"font_size", 9)
	add_child(_skip_hint)


func _input(event: InputEvent) -> void:
	if _leaving or not event.is_pressed() or event.is_echo():
		return
	if _is_skip_to_menu(event):
		_consume_input_event()
		_skip_to_menu()
		return
	if _is_advance_input(event):
		_consume_input_event()
		_advance_input()


func _consume_input_event() -> void:
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()


func _is_skip_to_menu(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_accept"):
		return true
	if event is InputEventKey:
		var key_ev := event as InputEventKey
		if key_ev.keycode == KEY_ENTER or key_ev.physical_keycode == KEY_ENTER:
			return true
		if key_ev.keycode == KEY_KP_ENTER or key_ev.physical_keycode == KEY_KP_ENTER:
			return true
		if key_ev.key_label == KEY_ENTER or key_ev.key_label == KEY_KP_ENTER:
			return true
		if key_ev.unicode == 10 or key_ev.unicode == 13:
			return true
	return false


func _is_advance_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventKey:
		var key_ev := event as InputEventKey
		return key_ev.keycode == KEY_SPACE or key_ev.physical_keycode == KEY_SPACE
	return false


func _advance_input() -> void:
	if _typing:
		_finish_typing()
		return
	if _hold_timer > 0.0:
		_go_next_slide()


func _process(delta: float) -> void:
	if _leaving:
		return
	if _typing:
		_type_accum += delta
		while _type_accum >= CHAR_DELAY and _typed_chars < _full_text.length():
			_type_accum -= CHAR_DELAY
			_typed_chars += 1
			_caption.text = _full_text.substr(0, _typed_chars)
		if _typed_chars >= _full_text.length():
			_typing = false
			_hold_timer = AUTO_ADVANCE_AFTER_TEXT
		return
	if _hold_timer > 0.0:
		_hold_timer -= delta
		if _hold_timer <= 0.0:
			_go_next_slide()


func _show_slide(index: int, with_fade: bool) -> void:
	_slide_index = index
	_hold_timer = 0.0
	_typing = false
	_type_accum = 0.0
	_typed_chars = 0

	if index < SLIDES.size():
		var slide: Dictionary = SLIDES[index]
		_black.visible = false
		_image.visible = true
		var path: String = str(slide.get("image", ""))
		if ResourceLoader.exists(path):
			_image.texture = load(path)
		else:
			_image.texture = null
		_begin_typewriter(str(slide.get("text", "")))
	elif index == SLIDES.size():
		_image.visible = false
		_black.visible = true
		_begin_typewriter(BLACK_SLIDE_TEXT)
	else:
		_skip_to_menu()
		return

	if with_fade:
		_play_fade_in()


func _begin_typewriter(text: String) -> void:
	_full_text = text
	_caption.text = ""
	_typed_chars = 0
	_type_accum = 0.0
	_typing = true


func _finish_typing() -> void:
	_typing = false
	_caption.text = _full_text
	_hold_timer = AUTO_ADVANCE_AFTER_TEXT


func _go_next_slide() -> void:
	if _leaving:
		return
	_hold_timer = 0.0
	_show_slide(_slide_index + 1, true)


func _play_fade_in() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade.color = Color(0, 0, 0, 1)
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color", Color(0, 0, 0, 0), FADE_SLIDE_SEC)


func _skip_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	set_process_input(false)
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	var tree := get_tree()
	if tree:
		tree.call_deferred("change_scene_to_file", MENU_SCENE)
