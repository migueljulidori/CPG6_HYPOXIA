extends ColorRect
## Sonar ring + echo memory texture (fades slowly where the wave passed).

@export var player_path: NodePath
@export var expand_speed: float = 620.0
@export var max_radius: float = 420.0
@export var hold_at_peak: float = 0.015
@export var fade_out_duration: float = 0.08

@export var echo_fade_seconds: float = 0.72
@export var echo_stamp_strength: float = 0.92
@export var echo_memory_scale: float = 0.5
@export var ring_width: float = 36.0
@export var player_halo_radius: float = 56.0
@export var player_halo_strength: float = 0.52
@export var exit_beacon_radius: float = 120.0
@export var exit_beacon_strength: float = 0.38

const MAX_EXIT_BEACONS := 6

var _player: Node2D
var _exit_beacons: Array[Dictionary] = []
var _cam: Camera2D
var _radius: float = 0.0
var _phase: int = 0
var _hold_timer: float = 0.0
var _fade_t: float = 0.0

var _echo_img: Image
var _echo_tex: ImageTexture
var _echo_size: Vector2i = Vector2i.ZERO
var _last_viewport_size: Vector2i = Vector2i.ZERO
var _echo_decay_accum: float = 0.0


func _ready() -> void:
	add_to_group("vision_overlay")
	anchors_preset = PRESET_FULL_RECT
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if player_path:
		_player = get_node(player_path) as Node2D
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/darkness_overlay.gdshader")
	material = sm
	_init_echo_buffer()
	_refresh_viewport_uniform()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		var vs := get_viewport_rect().size
		var sz := Vector2i(maxi(1, int(vs.x)), maxi(1, int(vs.y)))
		if sz == _last_viewport_size:
			return
		_last_viewport_size = sz
		call_deferred("_init_echo_buffer")
		call_deferred("_refresh_viewport_uniform")


func _init_echo_buffer() -> void:
	var vs := get_viewport_rect().size
	var w := maxi(32, int(vs.x * echo_memory_scale))
	var h := maxi(32, int(vs.y * echo_memory_scale))
	_echo_size = Vector2i(w, h)
	_echo_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	_echo_img.fill(Color(0, 0, 0, 1))
	_echo_tex = ImageTexture.create_from_image(_echo_img)
	var sm := material as ShaderMaterial
	if sm:
		sm.set_shader_parameter("echo_memory", _echo_tex)


func _refresh_viewport_uniform() -> void:
	var sm := material as ShaderMaterial
	if sm == null:
		return
	var vs := get_viewport_rect().size
	sm.set_shader_parameter("viewport_size", vs)


## Revelacao para o chao: memoria + halo (sem o anel do pulso ao vivo).
func get_ambient_reveal_at_world(world_pos: Vector2) -> float:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _cam == null:
		_cam = get_viewport().get_camera_2d()
	if _cam == null or _player == null:
		return 0.0

	var vs := get_viewport_rect().size
	if vs.x <= 1.0 or vs.y <= 1.0:
		return 0.0

	var xf := _cam.get_canvas_transform()
	var screen_pos: Vector2 = xf * world_pos
	var screen_center: Vector2 = xf * _player.global_position
	var dist := screen_pos.distance_to(screen_center)

	var memory := _sample_echo_memory_smooth(screen_pos, vs)

	var halo := (1.0 - smoothstep(0.0, player_halo_radius, dist)) * player_halo_strength
	var beacon := _beacon_reveal_at_screen(screen_pos)
	return clampf(max(max(memory, halo), beacon), 0.0, 1.0)


func _sample_echo_memory_smooth(screen_pos: Vector2, vs: Vector2) -> float:
	if _echo_img == null or _echo_size.x < 2 or _echo_size.y < 2:
		return 0.0
	var uv := Vector2(screen_pos.x / vs.x, screen_pos.y / vs.y).clamp(Vector2.ZERO, Vector2.ONE)
	var fx := uv.x * float(_echo_size.x - 1)
	var fy := uv.y * float(_echo_size.y - 1)
	var x0 := clampi(int(floor(fx)), 0, _echo_size.x - 1)
	var y0 := clampi(int(floor(fy)), 0, _echo_size.y - 1)
	var x1 := clampi(x0 + 1, 0, _echo_size.x - 1)
	var y1 := clampi(y0 + 1, 0, _echo_size.y - 1)
	var tx := fx - float(x0)
	var ty := fy - float(y0)
	var c00 := _echo_img.get_pixel(x0, y0).r
	var c10 := _echo_img.get_pixel(x1, y0).r
	var c01 := _echo_img.get_pixel(x0, y1).r
	var c11 := _echo_img.get_pixel(x1, y1).r
	return lerpf(lerpf(c00, c10, tx), lerpf(c01, c11, tx), ty)


## 0 = escuro total, 1 = totalmente revelado (memoria do sonar + onda atual).
func get_reveal_factor_at_world(world_pos: Vector2) -> float:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _cam == null:
		_cam = get_viewport().get_camera_2d()
	if _cam == null or _player == null:
		return 0.0

	var vs := get_viewport_rect().size
	if vs.x <= 1.0 or vs.y <= 1.0:
		return 0.0

	var xf := _cam.get_canvas_transform()
	var screen_pos: Vector2 = xf * world_pos
	var screen_center: Vector2 = xf * _player.global_position
	var dist := screen_pos.distance_to(screen_center)

	var memory := _sample_echo_memory_smooth(screen_pos, vs)

	var pulse := 0.0
	if _phase >= 1 and _phase <= 3:
		var active_r := _radius
		if _phase == 3:
			active_r = max_radius
		var dist_wave := absf(dist - active_r)
		var on_ring := 1.0 - smoothstep(0.0, ring_width, dist_wave)
		var inside := (1.0 if dist <= active_r else 0.0)
		inside *= 1.0 - smoothstep(0.0, ring_width * 0.85, dist_wave)
		var echo := inside * 0.12
		pulse = clampf(on_ring + echo, 0.0, 1.0)
		if _phase == 3:
			var fade := 1.0 - clampf(_fade_t / maxf(fade_out_duration, 0.001), 0.0, 1.0)
			pulse *= fade

	var halo := (1.0 - smoothstep(0.0, player_halo_radius, dist)) * player_halo_strength
	var beacon := _beacon_reveal_at_screen(screen_pos)
	return clampf(max(max(max(memory, pulse), halo), beacon), 0.0, 1.0)


func register_exit_beacon(
	node: Node2D,
	world_radius: float = -1.0,
	strength: float = -1.0,
) -> void:
	if node == null:
		return
	for b in _exit_beacons:
		if b.get("node") == node:
			return
	_exit_beacons.append({
		"node": node,
		"radius": exit_beacon_radius if world_radius < 0.0 else world_radius,
		"strength": exit_beacon_strength if strength < 0.0 else strength,
	})


func unregister_exit_beacon(node: Node2D) -> void:
	var kept: Array[Dictionary] = []
	for b in _exit_beacons:
		if b.get("node") != node:
			kept.append(b)
	_exit_beacons = kept


func _prune_exit_beacons() -> void:
	var kept: Array[Dictionary] = []
	for b in _exit_beacons:
		var n: Node2D = b.get("node") as Node2D
		if n and is_instance_valid(n):
			kept.append(b)
	_exit_beacons = kept


func _beacon_reveal_at_screen(screen_pos: Vector2) -> float:
	var best := 0.0
	for b in _exit_beacons:
		var n: Node2D = b.get("node") as Node2D
		if n == null or not is_instance_valid(n):
			continue
		if _cam == null:
			continue
		var sp: Vector2 = _cam.get_canvas_transform() * n.global_position
		var rad: float = float(b.get("radius", exit_beacon_radius))
		var str: float = float(b.get("strength", exit_beacon_strength))
		var sx := rad
		var sy := rad
		var d := Vector2(
			(screen_pos.x - sp.x) / maxf(sx, 1.0),
			(screen_pos.y - sp.y) / maxf(sy, 1.0),
		).length()
		best = maxf(best, (1.0 - smoothstep(0.0, 1.0, d)) * str)
	return best


func _update_exit_beacon_uniforms() -> void:
	var sm := material as ShaderMaterial
	if sm == null:
		return
	_prune_exit_beacons()
	var centers := PackedVector2Array()
	centers.resize(MAX_EXIT_BEACONS)
	var count := mini(_exit_beacons.size(), MAX_EXIT_BEACONS)
	var max_strength := exit_beacon_strength
	var max_radius := exit_beacon_radius
	if _cam == null or count == 0:
		sm.set_shader_parameter("beacon_count", 0)
		sm.set_shader_parameter("beacon_centers", centers)
		return
	var xf := _cam.get_canvas_transform()
	for i in count:
		var n: Node2D = _exit_beacons[i].get("node") as Node2D
		if n and is_instance_valid(n):
			centers[i] = xf * n.global_position
			max_strength = maxf(max_strength, float(_exit_beacons[i].get("strength", exit_beacon_strength)))
			max_radius = maxf(max_radius, float(_exit_beacons[i].get("radius", exit_beacon_radius)))
	sm.set_shader_parameter("beacon_count", count)
	sm.set_shader_parameter("beacon_centers", centers)
	sm.set_shader_parameter("beacon_radius", max_radius)
	sm.set_shader_parameter("beacon_strength", max_strength)


func trigger_pulse() -> void:
	if _phase != 0:
		return
	_radius = 0.0
	_phase = 1


func _decay_echo(delta: float) -> void:
	if _echo_img == null or echo_fade_seconds <= 0.0:
		return
	_echo_decay_accum += delta
	if _echo_decay_accum < 0.04:
		return
	var step := _echo_decay_accum
	_echo_decay_accum = 0.0
	var factor := clampf(1.0 - step / echo_fade_seconds, 0.0, 1.0)
	if factor >= 0.999:
		return
	var data := _echo_img.get_data()
	var n := data.size()
	for i in range(0, n, 4):
		data[i] = int(data[i] * factor)
	_echo_img.set_data(_echo_size.x, _echo_size.y, false, Image.FORMAT_RGBA8, data)


func _stamp_echo_disk(screen_center: Vector2, screen_radius: float, strength: float) -> void:
	if _echo_img == null or screen_radius <= 1.0:
		return
	var vs := get_viewport_rect().size
	var sx := float(_echo_size.x) / vs.x
	var sy := float(_echo_size.y) / vs.y
	var cx := screen_center.x * sx
	var cy := screen_center.y * sy
	var rad := screen_radius * (sx + sy) * 0.5
	var x0 := int(maxf(0.0, floor(cx - rad)))
	var x1 := int(minf(float(_echo_size.x), ceil(cx + rad)))
	var y0 := int(maxf(0.0, floor(cy - rad)))
	var y1 := int(minf(float(_echo_size.y), ceil(cy + rad)))
	var r2 := rad * rad
	for y in range(y0, y1):
		for x in range(x0, x1):
			var dx := float(x) - cx
			var dy := float(y) - cy
			var d2 := dx * dx + dy * dy
			if d2 > r2:
				continue
			var t := 1.0 - sqrt(d2) / maxf(rad, 0.001)
			var v := strength * (0.35 + 0.65 * t)
			var old := _echo_img.get_pixel(x, y).r
			_echo_img.set_pixel(x, y, Color(minf(1.0, maxf(old, v)), 0.0, 0.0, 1.0))


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return
	_cam = get_viewport().get_camera_2d()
	if _cam == null:
		return

	_decay_echo(delta)

	var vs := get_viewport_rect().size
	var sm := material as ShaderMaterial
	if sm == null:
		return

	sm.set_shader_parameter("viewport_size", vs)
	var xf := _cam.get_canvas_transform()
	var screen: Vector2 = xf * _player.global_position
	sm.set_shader_parameter("center_px", screen)

	match _phase:
		1:
			_radius = minf(_radius + expand_speed * delta, max_radius)
			_stamp_echo_disk(screen, _radius, echo_stamp_strength)
			if _radius >= max_radius:
				_phase = 2
				_hold_timer = hold_at_peak
		2:
			_hold_timer -= delta
			if _hold_timer <= 0.0:
				_phase = 3
				_fade_t = 0.0
		3:
			_fade_t += delta
			if _fade_t >= fade_out_duration:
				_phase = 0
				_radius = 0.0
				_fade_t = 0.0

	var reveal_r: float = max_radius if _phase == 3 else _radius
	sm.set_shader_parameter("reveal_radius", reveal_r)

	var pulse_visual := 0.0
	if _phase == 1 or _phase == 2:
		pulse_visual = 1.0
	elif _phase == 3:
		pulse_visual = 1.0 - clampf(_fade_t / maxf(fade_out_duration, 0.001), 0.0, 1.0)
	sm.set_shader_parameter("pulse_visual", pulse_visual)

	if _echo_tex:
		_echo_tex.update(_echo_img)

	_update_exit_beacon_uniforms()
