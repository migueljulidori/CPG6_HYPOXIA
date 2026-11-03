class_name EnemyMeleeAttack
## Shared melee attack timing + VFX for spiders and rats.

const VFX_SCENE := preload("res://scenes/enemy_attack_vfx.tscn")
const ATTACK_RANGE := 58.0
const ATTACK_DURATION := 0.4
const HIT_FRAME_TIME := 0.3
const BUMP_DAMAGE_DELAY := 0.18


static func wants_attack(chasing: bool, dist: float, hit_cd: float, attacking: bool) -> bool:
	return chasing and not attacking and hit_cd <= 0.0 and dist <= ATTACK_RANGE


static func spawn_vfx(parent: Node, world_pos: Vector2, direction: Vector2) -> void:
	if parent == null or VFX_SCENE == null:
		return
	var dir := direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	var vfx: Node2D = VFX_SCENE.instantiate()
	parent.add_child(vfx)
	vfx.global_position = world_pos + dir * 26.0
	if vfx.has_method("setup"):
		vfx.call("setup", dir)


static func try_damage_player(player: Node2D, from_world: Vector2) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if player.has_method("apply_enemy_hit"):
		return player.apply_enemy_hit(from_world)
	if player.has_method("can_be_hurt_by_enemy") and not player.can_be_hurt_by_enemy():
		return false
	return GameManager.lose_life_from_enemy()
