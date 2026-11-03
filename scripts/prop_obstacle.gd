extends StaticBody2D

@export_file("*.png", "*.webp") var texture_path: String = ""
@export var sprite_scale: Vector2 = Vector2(2.5, 2.5)
## Ajuste fino apos deteccao do contorno opaco da textura.
@export var collision_fit: Vector2 = Vector2(1.0, 1.0)

const KIND_FIT: Dictionary = {
	"mesa": Vector2(0.88, 0.72),
	"cadeira": Vector2(0.78, 0.78),
	"caixa": Vector2(0.52, 0.50),
}


func _ready() -> void:
	apply_visual()


func apply_visual() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if texture_path.is_empty() or sprite == null:
		return
	var tex: Texture2D = load(texture_path) as Texture2D
	if tex == null:
		return
	sprite.texture = tex
	sprite.scale = sprite_scale

	var kind := _infer_kind(texture_path)
	var kind_fit: Vector2 = KIND_FIT.get(kind, Vector2(0.85, 0.85))
	var fit := Vector2(collision_fit.x * kind_fit.x, collision_fit.y * kind_fit.y)

	var tex_size := Vector2(float(tex.get_width()), float(tex.get_height()))
	var visual := tex_size * sprite_scale
	var footprint := _texture_opaque_rect(tex)
	var body_size := Vector2(
		maxf(visual.x * footprint.size.x * fit.x, 10.0),
		maxf(visual.y * footprint.size.y * fit.y, 10.0),
	)

	if shape_node and shape_node.shape is RectangleShape2D:
		var shape := shape_node.shape.duplicate() as RectangleShape2D
		shape.size = body_size
		shape_node.shape = shape
		var center_norm := footprint.position + footprint.size * 0.5
		shape_node.position = (center_norm - Vector2(0.5, 0.5)) * visual


func _infer_kind(path: String) -> String:
	var lower := path.to_lower()
	if "mesa" in lower:
		return "mesa"
	if "cadeira" in lower:
		return "cadeira"
	if "caixa" in lower:
		return "caixa"
	return "prop"


func _texture_opaque_rect(tex: Texture2D) -> Rect2:
	var img := tex.get_image()
	if img == null or img.is_empty():
		return Rect2(0.0, 0.0, 1.0, 1.0)
	var used := img.get_used_rect()
	var tw := maxf(1.0, float(tex.get_width()))
	var th := maxf(1.0, float(tex.get_height()))
	return Rect2(
		Vector2(float(used.position.x) / tw, float(used.position.y) / th),
		Vector2(float(used.size.x) / tw, float(used.size.y) / th),
	)
