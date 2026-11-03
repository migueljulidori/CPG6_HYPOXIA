extends Area2D
## Teia completa (centro) ou 1/4 nos cantos � texturas de assets/web/.

@export_enum("full", "corner") var web_kind: String = "full"
@export_enum("top_left", "top_right", "bottom_left", "bottom_right") var corner: String = "top_left"

const TEX_FULL := "res://assets/web/teia_completa.png"

const CORNER_CFG: Dictionary = {
	"top_left": {
		"path": "res://assets/web/cantos/teia_canto_tl.png",
		"flip_h": false,
		"flip_v": false,
	},
	"top_right": {
		"path": "res://assets/web/cantos/teia_canto_tr.png",
		"flip_h": true,
		"flip_v": false,
	},
	"bottom_left": {
		"path": "res://assets/web/cantos/teia_canto_bl.png",
		"flip_h": false,
		"flip_v": false,
	},
	"bottom_right": {
		"path": "res://assets/web/cantos/teia_canto_br.png",
		"flip_h": true,
		"flip_v": false,
	},
}

const SCALE_FULL := Vector2(6.0, 5.0)
const SCALE_CORNER := Vector2(4.2, 4.2)
const ALPHA_HIT_THRESHOLD := 12.0 / 255.0
## Encolhe um pouco para nao pegar nas bordas transparentes da PNG.
const HITBOX_SHRINK := 0.94
const HITBOX_SHRINK_CORNER := 0.9
const HITBOX_MIN_SIZE := Vector2(28.0, 28.0)

var _caught_player: CharacterBody2D


func _ready() -> void:
	add_to_group("web_trap")
	monitoring = true
	monitorable = false
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_apply_web_visual()


func _apply_web_visual() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if sprite == null:
		return

	var tex_path := TEX_FULL
	var web_scale := SCALE_FULL
	var is_corner := web_kind == "corner"
	var flip_h := false
	var flip_v := false
	var offset := Vector2.ZERO

	if is_corner:
		var cfg: Dictionary = CORNER_CFG.get(corner, CORNER_CFG["top_left"])
		tex_path = str(cfg.get("path", TEX_FULL))
		web_scale = SCALE_CORNER
		flip_h = bool(cfg.get("flip_h", false))
		flip_v = bool(cfg.get("flip_v", false))

	var tex: Texture2D = load(tex_path) as Texture2D
	if tex == null:
		push_warning("WebTrap: textura nao encontrada: %s" % tex_path)
		return

	sprite.texture = tex
	sprite.scale = web_scale
	sprite.centered = true
	sprite.flip_h = flip_h
	sprite.flip_v = flip_v

	var align_offset := Vector2.ZERO
	if is_corner:
		align_offset = _corner_align_offset(tex.get_size(), corner)
	sprite.offset = align_offset

	var hit := _hitbox_from_opaque_pixels(
		tex, web_scale, flip_h, flip_v, align_offset, is_corner,
	)
	if shape_node:
		var rect := shape_node.shape as RectangleShape2D
		if rect == null:
			rect = RectangleShape2D.new()
		else:
			rect = rect.duplicate() as RectangleShape2D
		shape_node.shape = rect
		rect.size = hit.size
		shape_node.position = hit.position


func _hitbox_from_opaque_pixels(
	tex: Texture2D,
	web_scale: Vector2,
	flip_h: bool,
	flip_v: bool,
	align_offset: Vector2,
	is_corner: bool,
) -> Dictionary:
	var img := tex.get_image()
	if img == null or img.is_empty():
		return {"position": Vector2.ZERO, "size": HITBOX_MIN_SIZE}
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a >= ALPHA_HIT_THRESHOLD:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return {"position": Vector2.ZERO, "size": HITBOX_MIN_SIZE}

	var tex_center := Vector2(w - 1, h - 1) * 0.5
	var corners_tex := [
		Vector2(min_x, min_y),
		Vector2(max_x, min_y),
		Vector2(min_x, max_y),
		Vector2(max_x, max_y),
	]
	var min_local := Vector2(1e9, 1e9)
	var max_local := Vector2(-1e9, -1e9)
	for c in corners_tex:
		var p := _tex_point_to_trap_local(
			c, w, h, tex_center, align_offset, flip_h, flip_v, web_scale,
		)
		min_local.x = minf(min_local.x, p.x)
		min_local.y = minf(min_local.y, p.y)
		max_local.x = maxf(max_local.x, p.x)
		max_local.y = maxf(max_local.y, p.y)

	var shrink := HITBOX_SHRINK_CORNER if is_corner else HITBOX_SHRINK
	var size := (max_local - min_local) * shrink
	var pos := (min_local + max_local) * 0.5
	size.x = maxf(size.x, HITBOX_MIN_SIZE.x)
	size.y = maxf(size.y, HITBOX_MIN_SIZE.y)
	return {"position": pos, "size": size}


func _tex_point_to_trap_local(
	tex_point: Vector2,
	tex_w: int,
	tex_h: int,
	tex_center: Vector2,
	align_offset: Vector2,
	flip_h: bool,
	flip_v: bool,
	web_scale: Vector2,
) -> Vector2:
	var p := tex_point
	if flip_h:
		p.x = float(tex_w - 1) - p.x
	if flip_v:
		p.y = float(tex_h - 1) - p.y
	var local_unscaled := p - tex_center + align_offset
	return Vector2(local_unscaled.x * web_scale.x, local_unscaled.y * web_scale.y)


func _corner_align_offset(tex_size: Vector2, corner_name: String) -> Vector2:
	var half := tex_size * 0.5
	match corner_name:
		"top_left":
			return Vector2(half.x, half.y)
		"top_right":
			return Vector2(-half.x, half.y)
		"bottom_left":
			return Vector2(half.x, -half.y)
		"bottom_right":
			return Vector2(-half.x, -half.y)
	return Vector2.ZERO


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("enter_web"):
		body.enter_web(self)


func _on_body_exited(body: Node2D) -> void:
	if body == _caught_player and body.has_method("exit_web"):
		body.exit_web(self)
	_caught_player = null


func notify_caught(player: CharacterBody2D) -> void:
	_caught_player = player
