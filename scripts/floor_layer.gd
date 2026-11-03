extends Node2D
## Chao abaixo do World (CanvasLayer -10); o sonar revela via screen_texture no shader.

@export var area_min: Vector2 = Vector2(-1170, -690)
@export var area_max: Vector2 = Vector2(1170, 690)
@export var tile_scale: Vector2 = Vector2(4.0, 4.0)
@export var layout_seed: int = 0

const TILE_PATHS: Array[String] = [
	"res://assets/floor/pedra_1.png",
	"res://assets/floor/pedra_2.png",
	"res://assets/floor/pedra_3.png",
	"res://assets/floor/pedra_4.png",
	"res://assets/floor/pedra_5.png",
]

const TILE_PX := Vector2(32, 32)


func _ready() -> void:
	z_index = -95
	if layout_seed == 0:
		var scene := get_tree().current_scene
		if scene and scene.scene_file_path:
			layout_seed = int(hash(scene.scene_file_path)) & 0x7FFFFFFF
		else:
			layout_seed = 42
	_build_floor()


func _build_floor() -> void:
	for child in get_children():
		child.queue_free()

	var textures: Array[Texture2D] = []
	for path in TILE_PATHS:
		var tex: Texture2D = load(path) as Texture2D
		if tex:
			textures.append(tex)
	if textures.is_empty():
		push_warning("FloorLayer: missing textures in assets/floor/")
		return

	var step := TILE_PX * tile_scale
	var cols := int(ceili((area_max.x - area_min.x) / step.x))
	var rows := int(ceili((area_max.y - area_min.y) / step.y))
	var grid: Array = []

	for gy in range(rows):
		var row: Array[int] = []
		for gx in range(cols):
			row.append(_pick_tile_index(gx, gy, grid, row, textures.size()))
		grid.append(row)

	for gy in range(rows):
		for gx in range(cols):
			var idx: int = grid[gy][gx]
			var sprite := Sprite2D.new()
			sprite.name = "Stone_%d_%d" % [gx, gy]
			sprite.texture = textures[idx]
			sprite.scale = tile_scale
			sprite.centered = true
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.position = area_min + Vector2((gx + 0.5) * step.x, (gy + 0.5) * step.y)
			sprite.z_index = -95
			var bright := 0.92 + _hash01(gx, gy, 17) * 0.16
			sprite.modulate = Color(bright, bright, bright * 1.02, 1.0)
			add_child(sprite)


func _pick_tile_index(gx: int, gy: int, grid: Array, row: Array[int], count: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed ^ (gx * 374761) ^ (gy * 668265)
	var forbidden: Array[int] = []
	if gx > 0:
		forbidden.append(row[gx - 1])
	if gy > 0 and grid.size() > gy - 1:
		forbidden.append((grid[gy - 1] as Array)[gx])
	var options: Array[int] = []
	for i in range(count):
		if i not in forbidden:
			options.append(i)
	if options.is_empty():
		for i in range(count):
			options.append(i)
	return options[rng.randi_range(0, options.size() - 1)]


func _hash01(gx: int, gy: int, salt: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed ^ (gx * 91203) ^ (gy * 53177) ^ salt
	return rng.randf()
