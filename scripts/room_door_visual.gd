extends Node2D
## Open connector door between rooms (sprite).

@export var sign_text: String = "SALA [OPEN]"

@onready var _door_label: Label = $DoorSign/Label
@onready var _door_sprite: Sprite2D = $DoorSprite
@onready var _open_glow: Sprite2D = $OpenGlow


func _ready() -> void:
	if _door_label:
		_door_label.text = sign_text
	if _door_sprite:
		_door_sprite.texture = load("res://assets/doors/porta.png")
	if _open_glow:
		_open_glow.texture = load("res://assets/doors/porta.png")
