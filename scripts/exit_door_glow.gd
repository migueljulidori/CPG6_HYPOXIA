extends Node2D
## Brilho na porta de saida da sala de funcoes: overlay acima do escuro + farol no shader.

const GLOW_LAYER := 121
const LAYER_NAME := "FunctionDoorGlowLayer"

@export var door_texture: Texture2D
@export var glow_color: Color = Color(0.55, 1.0, 0.78, 0.55)
@export var halo_color: Color = Color(0.4, 0.95, 0.72, 0.35)
@export var sprite_scale: Vector2 = Vector2(2.2, 2.2)
@export var beacon_strength: float = 0.38
@export var beacon_radius: float = 120.0
@export var pulse_amount: float = 0.12
@export var pulse_speed: float = 1.25

var _door_anchor: Node2D
var _overlay_layer: CanvasLayer
var _overlay_outer: Sprite2D
var _overlay_inner: Sprite2D
var _pulse_t: float = 0.0


func _ready() -> void:
	_door_anchor = get_parent() as Node2D
	_build_overlay()
	call_deferred("_register_beacon")


func _exit_tree() -> void:
	_unregister_beacon()
	_remove_overlay()


func _process(delta: float) -> void:
	_pulse_t += delta * pulse_speed
	var pulse := 1.0 + sin(_pulse_t) * pulse_amount
	if _door_anchor == null or not is_instance_valid(_door_anchor):
		return
	var pos := _door_anchor.global_position
	if _overlay_outer:
		_overlay_outer.global_position = pos
		var h := halo_color
		var breathe := 0.86 + sin(_pulse_t * 0.7) * 0.14
		_overlay_outer.modulate = Color(h.r, h.g, h.b, h.a * breathe)
	if _overlay_inner:
		_overlay_inner.global_position = pos
		var c := glow_color
		_overlay_inner.modulate = Color(c.r * pulse, c.g * pulse, c.b * pulse, c.a)


func _register_beacon() -> void:
	var overlay := get_tree().get_first_node_in_group("vision_overlay")
	if overlay == null or _door_anchor == null:
		return
	if overlay.has_method("register_exit_beacon"):
		overlay.register_exit_beacon(_door_anchor, beacon_radius, beacon_strength)


func _unregister_beacon() -> void:
	var overlay := get_tree().get_first_node_in_group("vision_overlay")
	if overlay and _door_anchor and overlay.has_method("unregister_exit_beacon"):
		overlay.unregister_exit_beacon(_door_anchor)


func _build_overlay() -> void:
	var tex := door_texture
	if tex == null:
		tex = load("res://assets/doors/porta.png") as Texture2D
	if tex == null:
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	_overlay_layer = scene_root.get_node_or_null(LAYER_NAME) as CanvasLayer
	if _overlay_layer == null:
		_overlay_layer = CanvasLayer.new()
		_overlay_layer.name = LAYER_NAME
		_overlay_layer.layer = GLOW_LAYER
		_overlay_layer.follow_viewport_enabled = true
		scene_root.add_child(_overlay_layer)
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_overlay_outer = Sprite2D.new()
	_overlay_outer.name = "ExitHaloOverlay"
	_overlay_outer.texture = tex
	_overlay_outer.scale = sprite_scale * 1.28
	_overlay_outer.z_index = 10
	_overlay_outer.material = add_mat
	_overlay_outer.modulate = halo_color
	_overlay_layer.add_child(_overlay_outer)
	_overlay_inner = Sprite2D.new()
	_overlay_inner.name = "ExitGlowOverlay"
	_overlay_inner.texture = tex
	_overlay_inner.scale = sprite_scale * 1.1
	_overlay_inner.z_index = 11
	_overlay_inner.material = add_mat
	_overlay_inner.modulate = glow_color
	_overlay_layer.add_child(_overlay_inner)
	if _door_anchor:
		var pos := _door_anchor.global_position
		_overlay_outer.global_position = pos
		_overlay_inner.global_position = pos


func _remove_overlay() -> void:
	if _overlay_outer and is_instance_valid(_overlay_outer):
		_overlay_outer.queue_free()
		_overlay_outer = null
	if _overlay_inner and is_instance_valid(_overlay_inner):
		_overlay_inner.queue_free()
		_overlay_inner = null
	if _overlay_layer and is_instance_valid(_overlay_layer):
		if _overlay_layer.get_child_count() == 0:
			_overlay_layer.queue_free()
			_overlay_layer = null
