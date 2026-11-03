extends CharacterBody2D
## Top-down move, Ctrl sonar, Alt dash (breaks webs, costs O2).

const SPEED: float = 220.0
const DASH_SPEED: float = 520.0
const DASH_TIME: float = 0.16
const DASH_HIT_RADIUS: float = 38.0
const SONAR_COOLDOWN: float = 2.7
const WEB_ESCAPE_IFRAME: float = 0.45
## Imune a dano de bixo durante o dash e um pouco depois (tempo de acertar o golpe).
const ATTACK_IFRAME: float = 0.36
## Breve invulnerabilidade apos levar hit (evita dano em cadeia).
const HURT_IFRAME: float = 0.5

var _attack_cooldown: float = 0.0
var _attack_iframe: float = 0.0
var _hurt_iframe: float = 0.0
var _sonar_cooldown: float = 0.0
var _dashing: bool = false
var _dash_time_left: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT

var _web_stuck: bool = false
var _web_refs: Array[Area2D] = []
var _web_escape_timer: float = 0.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _dash_hitbox: Area2D = $DashHitbox
var _face_right: bool = true
var _dash_hit_ids: Dictionary = {}
var _terminal_active: bool = false
var _function_puzzle_locked: bool = false

const _FRAMES_RIGHT := [
	"res://assets/batt/Morcego/Direita/morcedodireita_0001.png",
	"res://assets/batt/Morcego/Direita/morcedodireita_0002.png",
	"res://assets/batt/Morcego/Direita/morcedodireita_0003.png",
	"res://assets/batt/Morcego/Direita/morcedodireita_0004.png",
]
const _FRAMES_LEFT := [
	"res://assets/batt/Morcego/Esquerda/morcedoesquerda_0001.png",
	"res://assets/batt/Morcego/Esquerda/morcedoesquerda_0002.png",
	"res://assets/batt/Morcego/Esquerda/morcedoesquerda_0003.png",
	"res://assets/batt/Morcego/Esquerda/morcedoesquerda_0004.png",
]


func _ready() -> void:
	_sprite.sprite_frames = _build_sprite_frames()
	_sprite.play(&"fly_right")
	if _dash_hitbox:
		_dash_hitbox.body_entered.connect(_on_dash_hit_body)
		_dash_hitbox.monitoring = false


func _build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation(&"fly_right")
	sf.set_animation_loop(&"fly_right", true)
	sf.set_animation_speed(&"fly_right", 11.0)
	for path in _FRAMES_RIGHT:
		var tex: Texture2D = load(path)
		if tex:
			sf.add_frame(&"fly_right", tex, 1.0)
	sf.add_animation(&"fly_left")
	sf.set_animation_loop(&"fly_left", true)
	sf.set_animation_speed(&"fly_left", 11.0)
	for path in _FRAMES_LEFT:
		var tex: Texture2D = load(path)
		if tex:
			sf.add_frame(&"fly_left", tex, 1.0)
	return sf


func _update_sprite_facing() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if _function_puzzle_locked:
		return
	# Direction from held movement keys (WASD / arrows share the same actions).
	if Input.is_action_pressed(&"move_left"):
		_face_right = false
	elif Input.is_action_pressed(&"move_right"):
		_face_right = true
	var anim := &"fly_right" if _face_right else &"fly_left"
	if _sprite.animation != anim:
		_sprite.play(anim)
	elif not _sprite.is_playing():
		_sprite.play(anim)


func _physics_process(delta: float) -> void:
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta
	if _sonar_cooldown > 0.0:
		_sonar_cooldown -= delta
	if _web_escape_timer > 0.0:
		_web_escape_timer -= delta
	if _attack_iframe > 0.0:
		_attack_iframe -= delta
	if _hurt_iframe > 0.0:
		_hurt_iframe -= delta

	_update_web_stuck_state()
	_update_sprite_facing()

	if _dashing:
		_dash_time_left -= delta
		velocity = _dash_dir * DASH_SPEED
		move_and_slide()
		_update_dash_hitbox_position()
		_check_dash_hits_nearby()
		if absf(_dash_dir.x) > 0.08:
			_face_right = _dash_dir.x >= 0.0
		if _dash_time_left <= 0.0:
			_end_dash()
		return

	if _web_stuck:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _terminal_active or _function_puzzle_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dir := Vector2(
		Input.get_axis(&"move_left", &"move_right"),
		Input.get_axis(&"move_up", &"move_down")
	)
	if dir.length_squared() > 1.0:
		dir = dir.normalized()

	velocity = dir * SPEED
	move_and_slide()


func set_terminal_active(active: bool) -> void:
	_terminal_active = active
	if active:
		velocity = Vector2.ZERO


func is_terminal_active() -> bool:
	return _terminal_active


func is_function_puzzle_mode() -> bool:
	return _function_puzzle_locked


func set_function_puzzle_locked(locked: bool) -> void:
	_function_puzzle_locked = locked
	if locked:
		velocity = Vector2.ZERO
		_end_dash()


func _unhandled_input(event: InputEvent) -> void:
	if _terminal_active:
		return
	if event.is_action_pressed(&"sonar_pulse"):
		_do_sonar()
		get_viewport().set_input_as_handled()
		return
	if _function_puzzle_locked:
		return
	if event.is_action_pressed(&"attack"):
		_do_dash()
		get_viewport().set_input_as_handled()


func enter_web(web: Area2D) -> void:
	if _web_escape_timer > 0.0:
		return
	if web in _web_refs:
		return
	AudioManager.play_web()
	_web_refs.append(web)
	if web.has_method("notify_caught"):
		web.notify_caught(self)
	_update_web_stuck_state()
	_sync_web_visual()


func exit_web(web: Area2D) -> void:
	## Preso na teia: so o dash liberta (release_from_webs).
	if _web_stuck:
		return
	_web_refs.erase(web)
	_update_web_stuck_state()
	_sync_web_visual()


func _update_web_stuck_state() -> void:
	_web_stuck = _web_refs.size() > 0


func _sync_web_visual() -> void:
	if _web_stuck:
		modulate = Color(0.75, 0.82, 1.0, 1.0)
	else:
		modulate = Color.WHITE


func release_from_webs() -> void:
	_web_refs.clear()
	_web_stuck = false
	_web_escape_timer = WEB_ESCAPE_IFRAME
	_sync_web_visual()


func can_be_hurt_by_enemy() -> bool:
	if _web_escape_timer > 0.0 or _attack_iframe > 0.0 or _hurt_iframe > 0.0:
		return false
	return true


func apply_enemy_hit(from_world: Vector2) -> bool:
	if not can_be_hurt_by_enemy():
		return false
	if not GameManager.lose_life_from_enemy():
		return false
	_hurt_iframe = HURT_IFRAME
	_apply_hit_feedback(from_world)
	return true


func _apply_hit_feedback(from_world: Vector2) -> void:
	var knock := global_position - from_world
	if knock.length_squared() > 1.0:
		global_position += knock.normalized() * 14.0
	modulate = Color(1.2, 0.65, 0.65, 1.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE if not _web_stuck else Color(0.75, 0.82, 1.0), 0.2)


func _on_dash_hit_body(body: Node2D) -> void:
	if not _dashing:
		return
	_try_dash_damage(body)


func _try_dash_damage(body: Node2D) -> void:
	if not body.is_in_group("enemy"):
		return
	var id := body.get_instance_id()
	if _dash_hit_ids.has(id):
		return
	_dash_hit_ids[id] = true
	if body.has_method("take_dash_hit"):
		body.take_dash_hit(_dash_dir)


func _update_dash_hitbox_position() -> void:
	if _dash_hitbox == null:
		return
	_dash_hitbox.position = _dash_dir.normalized() * 22.0


func _check_dash_hits_nearby() -> void:
	for node in get_tree().get_nodes_in_group("enemy"):
		if node == self or not (node is Node2D):
			continue
		var foe := node as Node2D
		if global_position.distance_to(foe.global_position) <= DASH_HIT_RADIUS:
			_try_dash_damage(foe)


func _end_dash() -> void:
	_dashing = false
	_dash_hit_ids.clear()
	if _dash_hitbox:
		_dash_hitbox.monitoring = false


func is_sonar_recharging() -> bool:
	return _sonar_cooldown > 0.0


func get_sonar_cooldown_ratio() -> float:
	if SONAR_COOLDOWN <= 0.0:
		return 0.0
	return clampf(_sonar_cooldown / SONAR_COOLDOWN, 0.0, 1.0)


func _do_sonar() -> void:
	if _sonar_cooldown > 0.0:
		return
	_sonar_cooldown = SONAR_COOLDOWN
	AudioManager.play_sonar()
	var overlay := get_tree().get_first_node_in_group("vision_overlay")
	if overlay and overlay.has_method("trigger_pulse"):
		overlay.trigger_pulse()


func _do_dash() -> void:
	if _dashing or _attack_cooldown > 0.0:
		return
	_attack_cooldown = 0.28
	_attack_iframe = ATTACK_IFRAME
	var aim := velocity.normalized()
	if aim.length_squared() < 0.0001:
		aim = Vector2.RIGHT
	_dash_dir = aim
	_dashing = true
	_dash_time_left = DASH_TIME
	_dash_hit_ids.clear()
	if _dash_hitbox:
		_dash_hitbox.monitoring = true
		_update_dash_hitbox_position()
	release_from_webs()
	AudioManager.play_dash()
	GameManager.spend_dash_o2()
