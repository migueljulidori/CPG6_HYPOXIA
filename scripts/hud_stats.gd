extends Control
## HUD: O2 + 3 coracoes (parados; animacao ao perder vida).

const O2_DIR := "res://assets/hud/o2/"
const HEART_IDLE := "res://assets/hud/hearts/heart_idle.png"
const HEART_LOSE_DIR := "res://assets/hud/hearts/heart_lose_%02d.png"
const HEART_LOSE_COUNT := 2
const HEART_EMPTY := "res://assets/hud/hearts/heart_empty.png"
const HEART_TEX_PX := 64.0
const O2_SIZE := Vector2(80, 136)
const HEART_COUNT := 3
const HEART_DISPLAY_SIDE := 149.0
const HEART_SEPARATION := -26
const HEART_SLOT_WIDTH_MUL := 0.48
const HUD_MARGIN := 14

enum HeartState { IDLE, LOSING, EMPTY }

var _o2_frames: Array[Texture2D] = []
var _heart_sprites: Array[AnimatedSprite2D] = []
var _heart_states: Array[int] = []
var _heart_idle_frames: SpriteFrames
var _heart_lose_frames: SpriteFrames
var _heart_empty_frames: SpriteFrames
var _o2_icon: TextureRect
var _o2_percent_label: Label
var _pulse_clock: Control


func _ready() -> void:
	_apply_fullscreen_hud()
	_load_o2_frames()
	_heart_idle_frames = _build_idle_frames()
	_heart_lose_frames = _build_lose_frames()
	_heart_empty_frames = _build_empty_frames()
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_resized)
	GameManager.oxygen_changed.connect(_on_oxygen_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.heart_lost.connect(_on_heart_lost)
	_refresh_all()


func _build_idle_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation(&"idle")
	var tex: Texture2D = load(HEART_IDLE)
	if tex:
		sf.add_frame(&"idle", tex, 1.0)
	return sf


func _build_lose_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation(&"lose")
	sf.set_animation_loop(&"lose", false)
	sf.set_animation_speed(&"lose", 8.0)
	for i in range(HEART_LOSE_COUNT):
		var path := HEART_LOSE_DIR % i
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			if tex:
				sf.add_frame(&"lose", tex, 1.0)
	return sf


func _build_empty_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation(&"empty")
	var tex: Texture2D = load(HEART_EMPTY)
	if tex:
		sf.add_frame(&"empty", tex, 1.0)
	return sf


func _heart_display_size() -> Vector2:
	return Vector2(HEART_DISPLAY_SIDE, HEART_DISPLAY_SIDE)


func _heart_scale() -> Vector2:
	var side := _heart_display_size().x
	return Vector2(side / HEART_TEX_PX, side / HEART_TEX_PX)


func _load_o2_frames() -> void:
	_o2_frames.clear()
	var i := 0
	while true:
		var path := O2_DIR + "o2_%02d.png" % i
		if not ResourceLoader.exists(path):
			break
		var tex: Texture2D = load(path)
		if tex:
			_o2_frames.append(tex)
		i += 1


func _apply_fullscreen_hud() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_viewport_resized() -> void:
	_position_o2_bottom_left()


func _position_o2_bottom_left() -> void:
	if _o2_icon == null:
		return
	var h := maxf(size.y, get_viewport_rect().size.y)
	var y := h - O2_SIZE.y - HUD_MARGIN
	_o2_icon.position = Vector2(HUD_MARGIN, y)
	if _o2_percent_label:
		_o2_percent_label.position = Vector2(HUD_MARGIN + 4.0, y + O2_SIZE.y - 18.0)


func _build_ui() -> void:
	_apply_fullscreen_hud()

	var hearts_wrap := MarginContainer.new()
	hearts_wrap.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hearts_wrap.offset_left = HUD_MARGIN
	hearts_wrap.offset_top = HUD_MARGIN
	add_child(hearts_wrap)

	var hearts_box := HBoxContainer.new()
	hearts_box.add_theme_constant_override("separation", HEART_SEPARATION)
	hearts_wrap.add_child(hearts_box)

	var heart_px := _heart_display_size()
	var slot_w := heart_px.x * HEART_SLOT_WIDTH_MUL
	var count := mini(HEART_COUNT, GameManager.MAX_LIVES)
	for _i in range(count):
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(slot_w, heart_px.y)
		hearts_box.add_child(slot)

		var heart := AnimatedSprite2D.new()
		heart.centered = true
		heart.position = Vector2(slot_w * 0.5, heart_px.y * 0.5)
		heart.sprite_frames = _heart_idle_frames
		heart.animation = &"idle"
		heart.scale = _heart_scale()
		heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		heart.stop()
		heart.frame = 0
		heart.animation_finished.connect(_on_heart_animation_finished.bind(heart))
		slot.add_child(heart)
		_heart_sprites.append(heart)
		_heart_states.append(HeartState.IDLE)

	_o2_icon = TextureRect.new()
	_o2_icon.custom_minimum_size = O2_SIZE
	_o2_icon.size = O2_SIZE
	_o2_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_o2_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_o2_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_o2_icon)

	_o2_percent_label = Label.new()
	_o2_percent_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_o2_percent_label.add_theme_font_size_override(&"font_size", 10)
	_o2_percent_label.add_theme_color_override(&"font_color", Color(0.55, 0.92, 1.0, 0.95))
	add_child(_o2_percent_label)
	call_deferred("_position_o2_bottom_left")

	_pulse_clock = load("res://scripts/pulse_clock_hud.gd").new()
	add_child(_pulse_clock)


func _on_oxygen_changed(_value: float) -> void:
	_update_o2_icon()


func _on_lives_changed(_value: int) -> void:
	_sync_hearts_from_lives()


func _on_heart_lost(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _heart_sprites.size():
		return
	_play_lose_animation(slot_index)


func _refresh_all() -> void:
	_sync_hearts_from_lives()
	_update_o2_icon()


func _sync_hearts_from_lives() -> void:
	for i in _heart_sprites.size():
		if _heart_states[i] == HeartState.LOSING:
			continue
		if i < GameManager.lives:
			_set_heart_idle(i)
		else:
			_set_heart_empty(i)


func _set_heart_idle(index: int) -> void:
	var heart := _heart_sprites[index]
	_heart_states[index] = HeartState.IDLE
	heart.sprite_frames = _heart_idle_frames
	heart.animation = &"idle"
	heart.stop()
	heart.frame = 0
	heart.modulate = Color.WHITE


func _set_heart_empty(index: int) -> void:
	var heart := _heart_sprites[index]
	_heart_states[index] = HeartState.EMPTY
	heart.sprite_frames = _heart_empty_frames
	heart.animation = &"empty"
	heart.stop()
	heart.frame = 0
	heart.modulate = Color(0.5, 0.5, 0.55, 0.9)


func _play_lose_animation(index: int) -> void:
	var heart := _heart_sprites[index]
	_heart_states[index] = HeartState.LOSING
	heart.sprite_frames = _heart_lose_frames
	heart.modulate = Color.WHITE
	if heart.sprite_frames.has_animation(&"lose") and heart.sprite_frames.get_frame_count(&"lose") > 0:
		heart.play(&"lose")
	else:
		_set_heart_empty(index)


func _on_heart_animation_finished(heart: AnimatedSprite2D) -> void:
	if heart.animation != &"lose":
		return
	var index := _heart_sprites.find(heart)
	if index < 0:
		return
	_set_heart_empty(index)


func _update_o2_icon() -> void:
	if _o2_frames.is_empty() or _o2_icon == null:
		return
	var ratio := clampf(GameManager.oxygen / GameManager.MAX_O2, 0.0, 1.0)
	var idx := int(round((1.0 - ratio) * float(_o2_frames.size() - 1)))
	_o2_icon.texture = _o2_frames[idx]
	if _o2_percent_label:
		_o2_percent_label.text = "%d%%" % int(round(ratio * 100.0))
		var low := ratio <= GameManager.O2_ALERT_RATIO
		_o2_percent_label.add_theme_color_override(
			&"font_color",
			Color(1.0, 0.45, 0.4, 1.0) if low else Color(0.55, 0.92, 1.0, 0.95),
		)
