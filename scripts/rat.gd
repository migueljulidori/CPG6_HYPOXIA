extends CharacterBody2D
## Patrols, chases, melee attack with VFX. Killed by dash.

const PATROL_SPEED: float = 110.0
const CHASE_SPEED: float = 140.0
const CHASE_RANGE: float = 320.0
const HIT_COOLDOWN: float = 0.8

@export var patrol_axis: Vector2 = Vector2.RIGHT

const _ANIM_DIRS := {
	"walk_right": [
		"res://assets/rat/direita_01.png",
		"res://assets/rat/direita_02.png",
		"res://assets/rat/direita_03.png",
	],
	"walk_left": [
		"res://assets/rat/esquerda_01.png",
		"res://assets/rat/esquerda_02.png",
		"res://assets/rat/esquerda_03.png",
	],
	"walk_up": [
		"res://assets/rat/cima_01.png",
		"res://assets/rat/cima_02.png",
		"res://assets/rat/cima_03.png",
	],
	"walk_down": [
		"res://assets/rat/baixo_01.png",
		"res://assets/rat/baixo_02.png",
		"res://assets/rat/baixo_03.png",
	],
}

var _dir: Vector2 = Vector2.RIGHT
var _hit_cd: float = 0.0
var _audio: AudioStreamPlayer2D
var _player: Node2D
var _dead: bool = false
var _chasing: bool = false
var _attacking: bool = false
var _attack_timer: float = 0.0
var _attack_target: Node2D
var _bump_touch_time: float = -1.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("rat")
	add_to_group("enemy")
	_dir = patrol_axis.normalized()
	if _dir.length_squared() < 0.001:
		_dir = Vector2.RIGHT
	_sprite.sprite_frames = _build_sprite_frames()
	_sprite.play(&"walk_right")
	_audio = AudioStreamPlayer2D.new()
	_audio.name = "RatAudio"
	add_child(_audio)
	AudioManager.setup_rat_audio(_audio)


func _build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	for anim_name in _ANIM_DIRS.keys():
		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, true)
		sf.set_animation_speed(anim_name, 10.0)
		for path in _ANIM_DIRS[anim_name]:
			var tex: Texture2D = load(path)
			if tex:
				sf.add_frame(anim_name, tex, 1.0)
	return sf


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if GameManager and GameManager.is_hub_gameplay_frozen():
		velocity = Vector2.ZERO
		return
	if _hit_cd > 0.0:
		_hit_cd -= delta
	if _attack_timer > 0.0:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_finish_attack()
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D

	if _attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_chasing = false
	if _player:
		var to_player := _player.global_position - global_position
		var dist := to_player.length()
		if dist < CHASE_RANGE and dist > 8.0:
			_chasing = true
			if EnemyMeleeAttack.wants_attack(_chasing, dist, _hit_cd, _attacking):
				_begin_attack(_player, to_player)
				velocity = Vector2.ZERO
			else:
				velocity = to_player.normalized() * CHASE_SPEED
		else:
			velocity = _dir * PATROL_SPEED
	else:
		velocity = _dir * PATROL_SPEED

	move_and_slide()
	_update_sprite_animation(velocity)

	var touching_player := false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var body := col.get_collider()
		if body and body.is_in_group("player"):
			touching_player = true
			if not _attacking:
				_try_bump_attack_player(body as Node2D, delta)
			continue
		if col.get_normal().length_squared() > 0.01:
			_dir = _dir.bounce(col.get_normal()).normalized()
	if not touching_player:
		_bump_touch_time = -1.0


func _begin_attack(target: Node2D, to_target: Vector2) -> void:
	_attacking = true
	_attack_target = target
	_attack_timer = EnemyMeleeAttack.ATTACK_DURATION
	var atk_dir := to_target.normalized()
	EnemyMeleeAttack.spawn_vfx(get_parent(), global_position, atk_dir)
	get_tree().create_timer(EnemyMeleeAttack.HIT_FRAME_TIME).timeout.connect(
		_apply_attack_hit,
		CONNECT_ONE_SHOT,
	)


func _apply_attack_hit() -> void:
	if _dead or not _attacking:
		return
	if GameManager and GameManager.is_hub_gameplay_frozen():
		return
	if _attack_target and is_instance_valid(_attack_target):
		var dist := global_position.distance_to(_attack_target.global_position)
		if dist <= EnemyMeleeAttack.ATTACK_RANGE + 14.0:
			_try_attack_player(_attack_target)


func _finish_attack() -> void:
	_attacking = false
	_attack_target = null


func _update_sprite_animation(move_vel: Vector2) -> void:
	if _sprite == null or _sprite.sprite_frames == null or _attacking:
		return
	if move_vel.length_squared() < 16.0:
		return
	var anim := _anim_from_velocity(move_vel)
	if _sprite.animation != anim:
		_sprite.play(anim)
	elif not _sprite.is_playing():
		_sprite.play(anim)


func _anim_from_velocity(v: Vector2) -> StringName:
	if absf(v.x) >= absf(v.y):
		return &"walk_right" if v.x >= 0.0 else &"walk_left"
	return &"walk_up" if v.y < 0.0 else &"walk_down"


func _try_bump_attack_player(body: Node2D, delta: float) -> void:
	if _hit_cd > 0.0 or _dead:
		return
	if _bump_touch_time < 0.0:
		_bump_touch_time = 0.0
	else:
		_bump_touch_time += delta
	if _bump_touch_time < EnemyMeleeAttack.BUMP_DAMAGE_DELAY:
		return
	_try_attack_player(body)


func _try_attack_player(body: Node2D) -> void:
	if _hit_cd > 0.0 or _dead:
		return
	if GameManager and GameManager.is_hub_gameplay_frozen():
		return
	if not EnemyMeleeAttack.try_damage_player(body, global_position):
		return
	_hit_cd = HIT_COOLDOWN
	_bump_touch_time = -1.0
	if _audio:
		_audio.volume_db = 2.0
		get_tree().create_timer(0.25).timeout.connect(_restore_rat_volume)


func take_dash_hit(knock_dir: Vector2) -> void:
	if _dead:
		return
	_dead = true
	_attacking = false
	velocity = Vector2.ZERO
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	if _audio:
		_audio.stop()
	modulate = Color(1.3, 0.9, 0.5, 1.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position", global_position + knock_dir.normalized() * 24.0, 0.1)
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(queue_free)


func _restore_rat_volume() -> void:
	if _audio and is_instance_valid(_audio):
		_audio.volume_db = -12.0
