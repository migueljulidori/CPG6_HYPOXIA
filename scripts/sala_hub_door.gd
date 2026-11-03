extends Node2D
## Porta do hub para uma sala (sempre aberta ate a sala ser concluida).

@export_file("*.tscn") var target_scene: String = ""
@export var enter_spawn_id: String = ""
@export var door_label: String = "SALA"
@export var sala_id: String = ""

@onready var _blocker: StaticBody2D = $DoorBlocker
@onready var _door_sprite: Sprite2D = $DoorSprite
@onready var _open_glow: Sprite2D = $OpenGlow
@onready var _door_sign: Label = $DoorSign/Label
@onready var _interact: Area2D = $DoorInteract


func _ready() -> void:
	if sala_id.is_empty() and GameManager:
		sala_id = GameManager.sala_id_for_scene(target_scene)
	if _door_sign:
		_door_sign.text = door_label
	_apply_door_facing()
	configure_interact()
	if GameManager and not GameManager.salas_progress_changed.is_connected(_on_salas_progress):
		GameManager.salas_progress_changed.connect(_on_salas_progress)
	call_deferred("_sync_cleared_visual")


func configure_interact() -> void:
	if _interact == null:
		return
	_interact.set("target_scene", target_scene)
	_interact.set("enter_spawn_id", enter_spawn_id)
	if _interact.has_method("configure_sala_entry_block"):
		_interact.call(
			"configure_sala_entry_block",
			sala_id,
			"Sala concluida",
		)


func _apply_door_facing() -> void:
	## Interact zone fica para dentro do hub (como a porta antiga DoorRoom1).
	if _interact == null:
		return
	var inward := Vector2(-48.0, 0.0)
	if absf(position.x) > 400.0:
		inward.x = -48.0 if position.x > 0.0 else 48.0
	elif absf(position.y) > 400.0:
		inward = Vector2(0.0, -48.0 if position.y > 0.0 else 48.0)
	_interact.position = inward


func _on_salas_progress(_cleared: int, _total: int) -> void:
	_sync_cleared_visual()


func _sync_cleared_visual() -> void:
	var cleared := sala_id != "" and not GameManager.can_enter_sala(sala_id)
	if cleared:
		_close_door_visuals()
	else:
		_open_door_visuals(false)
	if _door_sign:
		_door_sign.text = "%s [OK]" % door_label if cleared else door_label
		if cleared:
			_door_sign.add_theme_color_override(
				&"font_color", Color(0.55, 1.0, 0.72, 1.0)
			)
		else:
			_door_sign.add_theme_color_override(
				&"font_color", Color(0.95, 0.45, 0.5, 1.0)
			)
	configure_interact()
	if _interact and _interact.has_method("_refresh_hint"):
		_interact.call("_refresh_hint")


func _open_door_visuals(_animate: bool) -> void:
	if _blocker:
		for child in _blocker.get_children():
			if child is CollisionShape2D:
				(child as CollisionShape2D).set_deferred(&"disabled", true)
		_blocker.set_deferred(&"collision_layer", 0)
	if _open_glow:
		_open_glow.visible = true
	if _door_sprite:
		_door_sprite.visible = false


func _close_door_visuals() -> void:
	if _blocker:
		_blocker.set_deferred(&"collision_layer", 1)
		for child in _blocker.get_children():
			if child is CollisionShape2D:
				(child as CollisionShape2D).set_deferred(&"disabled", false)
	if _open_glow:
		_open_glow.visible = false
	if _door_sprite:
		_door_sprite.visible = true
