extends Node2D
## Short-lived melee swipe VFX (spider / rat).

const FRAMES := [
	"res://assets/vfx/enemy_attack/ataque_01.png",
	"res://assets/vfx/enemy_attack/ataque_02.png",
	"res://assets/vfx/enemy_attack/ataque_03.png",
	"res://assets/vfx/enemy_attack/ataque_04.png",
]

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_sprite.sprite_frames = _build_frames()
	_sprite.animation_finished.connect(queue_free)
	_sprite.play(&"swipe")


func setup(direction: Vector2) -> void:
	var dir := direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	rotation = dir.angle()


func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation(&"swipe")
	sf.set_animation_loop(&"swipe", false)
	sf.set_animation_speed(&"swipe", 14.0)
	for path in FRAMES:
		var tex: Texture2D = load(path)
		if tex:
			sf.add_frame(&"swipe", tex, 1.0)
	return sf
