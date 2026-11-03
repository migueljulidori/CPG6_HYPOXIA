extends Control
## Relogio de recarga do pulso: 1 volta sincronizada com o cooldown.

const CLOCK_DIR := "res://assets/ui/relogio/"
const CLOCK_FRAME_COUNT := 5
const CLOCK_DISPLAY_SIZE := 72.0
const HUD_MARGIN := 14.0

var _sprite: AnimatedSprite2D
var _spin_frames: SpriteFrames


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spin_frames = _build_spin_frames()
	_sprite = AnimatedSprite2D.new()
	_sprite.centered = true
	_sprite.sprite_frames = _spin_frames
	_sprite.animation = &"spin"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var scale_factor := CLOCK_DISPLAY_SIZE / 64.0
	_sprite.scale = Vector2(scale_factor, scale_factor)
	add_child(_sprite)
	visible = false
	get_viewport().size_changed.connect(_position_clock)
	call_deferred("_position_clock")


func _build_spin_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation(&"spin")
	sf.set_animation_loop(&"spin", false)
	sf.set_animation_speed(&"spin", 1.0)
	for i in range(CLOCK_FRAME_COUNT):
		var path := CLOCK_DIR + "clock_%02d.png" % (i + 1)
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			if tex:
				sf.add_frame(&"spin", tex, 1.0)
	return sf


func _position_clock() -> void:
	if _sprite == null:
		return
	var vp := get_viewport_rect().size
	var half := CLOCK_DISPLAY_SIZE * 0.5
	_sprite.position = Vector2(
		vp.x - HUD_MARGIN - half,
		vp.y - HUD_MARGIN - half,
	)


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("is_sonar_recharging"):
		visible = false
		return
	if not player.is_sonar_recharging():
		visible = false
		_sprite.stop()
		_sprite.frame = 0
		return

	visible = true
	_sprite.stop()
	var ratio: float = player.get_sonar_cooldown_ratio()
	var progress := 1.0 - ratio
	var frame_idx := clampi(
		int(floor(progress * float(CLOCK_FRAME_COUNT))),
		0,
		CLOCK_FRAME_COUNT - 1,
	)
	_sprite.frame = frame_idx
