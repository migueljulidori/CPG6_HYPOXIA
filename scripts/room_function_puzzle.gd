extends Node2D
## Sala de funcoes: 3 escolhas, preview pontilhado, morcego arrastado ao longo da curva.

@export var sala_id: String = "sala1"
@export var prop_scene: PackedScene
@export var goal_door_texture: Texture2D
@export var random_prop_count: int = 26
@export var bright_test_room: bool = false
@export var entrance_inset: Vector2 = Vector2(48.0, 0.0)

const PROP_DEFS: Array[Dictionary] = [
	{"path": "res://assets/props/mesas/azul.png", "scale": Vector2(2.5, 2.5), "fit": Vector2(1.0, 1.0)},
	{"path": "res://assets/props/mesas/laranja.png", "scale": Vector2(2.5, 2.5), "fit": Vector2(1.0, 1.0)},
	{"path": "res://assets/props/mesas/rosa.png", "scale": Vector2(2.5, 2.5), "fit": Vector2(1.0, 1.0)},
	{"path": "res://assets/props/cadeiras/Azul.png", "scale": Vector2(2.5, 2.5), "fit": Vector2(1.0, 1.0)},
	{"path": "res://assets/props/cadeiras/Laranja.png", "scale": Vector2(2.5, 2.5), "fit": Vector2(1.0, 1.0)},
	{"path": "res://assets/props/cadeiras/Rosa.png", "scale": Vector2(2.5, 2.5), "fit": Vector2(1.0, 1.0)},
	{"path": "res://assets/props/caixas/azul.png", "scale": Vector2(2.5, 2.5), "fit": Vector2(1.0, 1.0)},
	{"path": "res://assets/props/caixas/laranja.png", "scale": Vector2(2.5, 2.5), "fit": Vector2(1.0, 1.0)},
	{"path": "res://assets/props/caixas/Rosa.png", "scale": Vector2(2.5, 2.5), "fit": Vector2(1.0, 1.0)},
]

const PATH_CLEAR_RADIUS := 52.0
const PLAYER_HIT_RADIUS := 22.0
const HUB_SCENE := "res://scenes/main.tscn"
const WALL_X := 1060.0
const WALL_Y := 640.0
const GOAL_DOOR_SAFE_RADIUS := 130.0
const PATH_START_SNAP := 14.0
const DOT_SPACING := 6.0
const PREVIEW_LINE_WIDTH := 7.0
const DOT_RADIUS := 6.0
const WRONG_CHOICE_O2_COST := 5.0
const FONT_PATH := "res://assets/fonts/PressStart2P.ttf"
const OPTION_FONT_SIZE := 9
const UI_LABEL_FONT_SIZE := 11
const FUNC_HINT_ICON_SIZE := Vector2(80, 80)
const OPTION_BTN_SIZE := Vector2(360, 54)
const OPTION_GRID_H_SEP := 32
const OPTION_GRID_V_SEP := 14
const OPTIONS_BAR_LEFT_MARGIN := 108.0
const OPTIONS_BAR_RIGHT_MARGIN := 16.0
const FUNC_HINT_COLUMN_WIDTH := 112.0
const FUNC_HINT_PATHS: Dictionary = {
	FunctionPathMath.FuncType.AFFINE: "res://assets/ui/funcoes/afim.png",
	FunctionPathMath.FuncType.QUADRATIC: "res://assets/ui/funcoes/quad.png",
	FunctionPathMath.FuncType.EXPONENTIAL: "res://assets/ui/funcoes/exp.png",
}
const ENTRANCE_FALLBACK: Dictionary = {
	"sala1": Vector2(-1020.0, 60.0),
	"sala2": Vector2(-1020.0, 80.0),
	"sala3": Vector2(0.0, 560.0),
}
const GOAL_FALLBACK: Dictionary = {
	"sala1": Vector2(1020.0, 100.0),
	"sala2": Vector2(1020.0, 100.0),
	"sala3": Vector2(0.0, -620.0),
}

var _rng := RandomNumberGenerator.new()
var _player: CharacterBody2D
var _room_start: Vector2
var _goal_pos: Vector2
var _progress_axis: int = FunctionPathMath.ProgressAxis.PLUS_X
var _column_426: Vector2 = Vector2.ZERO
var _column_852: Vector2 = Vector2.ZERO
var _segments: Array[Dictionary] = []
var _segment_index: int = 0
var _step_start: Vector2
var _selected_option_index: int = -1
var _busy: bool = false
var _completed: bool = false

var _preview_root: Node2D
var _preview_line: Line2D
var _target_layer: CanvasLayer
var _target_marker: Node2D
var _goal_door: Node2D
var _goal_area: Area2D
var _goal_hub_exit: Area2D
var _ui_layer: CanvasLayer
var _option_buttons: Array[Button] = []
var _title_label: Label
var _status_label: Label
var _func_hint_root: Control
var _func_hint_icon: TextureRect
var _func_hint_label: Label
var _required_func_type: int = -1
var _props_spawned: Node2D
var _move_tween: Tween
var _current_options: Array[Dictionary] = []
var _section_type_order: Array[int] = []
var _ui_font: Font


func _ready() -> void:
	add_to_group("function_puzzle")
	_rng.randomize()
	if prop_scene == null:
		prop_scene = load("res://scenes/prop_obstacle.tscn") as PackedScene
	if goal_door_texture == null:
		goal_door_texture = load("res://assets/doors/porta.png") as Texture2D
	call_deferred("_boot")


func _boot() -> void:
	_hide_legacy_nodes()
	_apply_bright_room()
	_player = await _await_player()
	if _player == null:
		push_error("RoomFunctionPuzzle: player not found")
		return
	if not GameManager.can_enter_sala(sala_id):
		_eject_to_hub_immediately()
		return
	_build_ui()
	_build_preview_root()
	_build_target_marker()
	_generate_puzzle()
	if _player.has_method("set_function_puzzle_locked"):
		_player.set_function_puzzle_locked(true)
	await get_tree().process_frame
	await get_tree().process_frame
	_place_player_at_start()
	_begin_segment_choice()


func _hide_legacy_nodes() -> void:
	var gameplay := get_parent()
	if gameplay == null:
		return
	for child in gameplay.get_children():
		var n := str(child.name)
		if n.begins_with("MathTerminal"):
			child.queue_free()
		elif n in ["DoorSala1", "DoorSala2", "ExitDoor", "ExitZone", "Webs", "Rats", "Spiders"]:
			child.queue_free()
		elif n in ["SpawnSala1Entry", "SpawnSala2Entry"]:
			child.queue_free()


const HUB_RETURN_SPAWN: Dictionary = {
	"sala1": "sala1_to_hub",
	"sala2": "sala2_to_hub",
	"sala3": "sala3_to_hub",
}


func _eject_to_hub_immediately() -> void:
	var spawn_id: String = str(HUB_RETURN_SPAWN.get(sala_id, "sala1_to_hub"))
	GameManager.queue_spawn(spawn_id)
	if _player and is_instance_valid(_player) and _player.has_method("set_function_puzzle_locked"):
		_player.set_function_puzzle_locked(false)
	var tree := get_tree()
	if tree:
		tree.call_deferred("change_scene_to_file", HUB_SCENE)


func _apply_bright_room() -> void:
	if not bright_test_room:
		return
	var scene := get_tree().current_scene
	if scene:
		var vision := scene.get_node_or_null("VisionLayer")
		if vision:
			vision.visible = false


func _await_player() -> CharacterBody2D:
	for _attempt in 24:
		var found := get_tree().get_first_node_in_group("player") as CharacterBody2D
		if found and is_instance_valid(found):
			return found
		await get_tree().process_frame
	return null


func _ensure_ui_font() -> void:
	if _ui_font != null:
		return
	var loaded := load(FONT_PATH)
	if loaded is Font:
		_ui_font = loaded


func _apply_ui_font(control: Control, font_size: int) -> void:
	_ensure_ui_font()
	if _ui_font:
		control.add_theme_font_override(&"font", _ui_font)
	control.add_theme_font_size_override(&"font_size", font_size)


func _make_option_stylebox(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb


func _style_option_button(btn: Button) -> void:
	_apply_ui_font(btn, OPTION_FONT_SIZE)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.flat = false
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.add_theme_stylebox_override(
		&"normal",
		_make_option_stylebox(Color(0.06, 0.1, 0.14, 0.92), Color(0.22, 0.38, 0.48, 0.95)),
	)
	btn.add_theme_stylebox_override(
		&"hover",
		_make_option_stylebox(Color(0.08, 0.16, 0.2, 0.96), Color(0.35, 0.95, 0.7, 1.0)),
	)
	btn.add_theme_stylebox_override(
		&"pressed",
		_make_option_stylebox(Color(0.1, 0.22, 0.16, 0.98), Color(0.45, 1.0, 0.75, 1.0)),
	)
	btn.add_theme_stylebox_override(
		&"focus",
		_make_option_stylebox(Color(0.08, 0.16, 0.2, 0.96), Color(0.35, 0.95, 0.7, 1.0)),
	)
	btn.add_theme_stylebox_override(
		&"disabled",
		_make_option_stylebox(Color(0.05, 0.08, 0.1, 0.7), Color(0.18, 0.24, 0.3, 0.8)),
	)
	btn.add_theme_color_override(&"font_color", Color(0.92, 0.95, 1.0, 1.0))
	btn.add_theme_color_override(&"font_hover_color", Color(0.55, 1.0, 0.78, 1.0))
	btn.add_theme_color_override(&"font_pressed_color", Color(0.4, 0.95, 0.65, 1.0))
	btn.add_theme_color_override(&"font_focus_color", Color(0.55, 1.0, 0.78, 1.0))
	btn.add_theme_color_override(&"font_disabled_color", Color(0.55, 0.6, 0.65, 0.8))


func _build_ui() -> void:
	_ensure_ui_font()
	var ui_parent := _find_ui_parent()
	var stale := ui_parent.get_node_or_null("FunctionPuzzleUI")
	if stale:
		ui_parent.remove_child(stale)
		stale.free()
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "FunctionPuzzleUI"
	_ui_layer.layer = 210
	ui_parent.add_child(_ui_layer)
	_option_buttons.clear()
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_ui_font(_title_label, UI_LABEL_FONT_SIZE)
	_title_label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	_title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title_label.offset_top = 8.0
	_title_label.offset_bottom = 36.0
	_ui_layer.add_child(_title_label)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_ui_font(_status_label, UI_LABEL_FONT_SIZE)
	_status_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.75))
	_status_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_status_label.offset_top = 36.0
	_status_label.offset_bottom = 56.0
	_ui_layer.add_child(_status_label)
	var bottom_bar := HBoxContainer.new()
	bottom_bar.name = "OptionsBottomBar"
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_top = -148.0
	bottom_bar.offset_bottom = -10.0
	bottom_bar.offset_left = OPTIONS_BAR_LEFT_MARGIN
	bottom_bar.offset_right = -OPTIONS_BAR_RIGHT_MARGIN
	bottom_bar.add_theme_constant_override(&"separation", 20)
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_ui_layer.add_child(bottom_bar)
	var options_center := CenterContainer.new()
	options_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom_bar.add_child(options_center)
	var options_panel := PanelContainer.new()
	options_panel.add_theme_stylebox_override(
		&"panel",
		_make_option_stylebox(Color(0.04, 0.06, 0.1, 0.55), Color(0.16, 0.28, 0.36, 0.75)),
	)
	options_center.add_child(options_panel)
	var options_margin := MarginContainer.new()
	options_margin.add_theme_constant_override(&"margin_left", 14)
	options_margin.add_theme_constant_override(&"margin_top", 10)
	options_margin.add_theme_constant_override(&"margin_right", 14)
	options_margin.add_theme_constant_override(&"margin_bottom", 10)
	options_panel.add_child(options_margin)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", OPTION_GRID_H_SEP)
	grid.add_theme_constant_override(&"v_separation", OPTION_GRID_V_SEP)
	options_margin.add_child(grid)
	for i in 4:
		var cell := PanelContainer.new()
		cell.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
		grid.add_child(cell)
		var btn := Button.new()
		btn.custom_minimum_size = OPTION_BTN_SIZE
		_style_option_button(btn)
		btn.focus_mode = Control.FOCUS_NONE
		var idx := i
		btn.pressed.connect(func() -> void:
			_on_option_pressed(idx)
		)
		btn.mouse_entered.connect(func() -> void:
			_on_option_hover(idx)
		)
		btn.mouse_exited.connect(_on_option_unhover)
		cell.add_child(btn)
		_option_buttons.append(btn)
	_build_func_type_hint(bottom_bar)


func _build_func_type_hint(bottom_bar: HBoxContainer) -> void:
	_func_hint_root = CenterContainer.new()
	_func_hint_root.name = "FuncTypeHint"
	_func_hint_root.custom_minimum_size = Vector2(FUNC_HINT_COLUMN_WIDTH, 0)
	_func_hint_root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_func_hint_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_bar.add_child(_func_hint_root)
	var hint_panel := PanelContainer.new()
	hint_panel.add_theme_stylebox_override(
		&"panel",
		_make_option_stylebox(Color(0.05, 0.09, 0.12, 0.88), Color(0.2, 0.42, 0.38, 0.9)),
	)
	_func_hint_root.add_child(hint_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 8)
	var hint_margin := MarginContainer.new()
	hint_margin.add_theme_constant_override(&"margin_left", 10)
	hint_margin.add_theme_constant_override(&"margin_top", 8)
	hint_margin.add_theme_constant_override(&"margin_right", 10)
	hint_margin.add_theme_constant_override(&"margin_bottom", 8)
	hint_panel.add_child(hint_margin)
	hint_margin.add_child(box)
	_func_hint_icon = TextureRect.new()
	_func_hint_icon.custom_minimum_size = FUNC_HINT_ICON_SIZE
	_func_hint_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_func_hint_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_func_hint_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_func_hint_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_func_hint_icon.visible = false
	box.add_child(_func_hint_icon)
	_func_hint_label = Label.new()
	_func_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_func_hint_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_ui_font(_func_hint_label, UI_LABEL_FONT_SIZE)
	_func_hint_label.add_theme_color_override(&"font_color", Color(0.55, 1.0, 0.75, 1.0))
	box.add_child(_func_hint_label)


func _set_func_type_hint(func_type: int) -> void:
	if _func_hint_root == null:
		return
	var path: String = str(FUNC_HINT_PATHS.get(func_type, FunctionPathMath.type_icon_path(func_type)))
	if path.is_empty() or not ResourceLoader.exists(path):
		_func_hint_icon.visible = false
		_func_hint_icon.texture = null
	else:
		_func_hint_icon.texture = load(path)
		_func_hint_icon.visible = true
	_func_hint_label.text = FunctionPathMath.type_display_name(func_type)


func _option_button_label(opt: Dictionary, from_pos: Vector2, target_col: int, index: int) -> String:
	var shown := FunctionPathMath.with_start(opt, from_pos)
	var body := FunctionPathMath.format_equation_body(int(shown["type"]), shown["params"])
	var eq := body
	if target_col != 0:
		var hit: Vector2 = opt.get("column_point", shown["end"])
		if FunctionPathMath.axis_is_horizontal(_progress_axis):
			eq = "%s  (y=%.0f)" % [body, hit.y]
		else:
			eq = "%s  (x=%.0f)" % [body, hit.x]
	return "[%d]  %s" % [index + 1, eq]


func _find_ui_parent() -> Node:
	var scene := get_tree().current_scene
	if scene:
		var ui := scene.get_node_or_null("UILayer")
		if ui:
			return ui
	return get_tree().root


func _build_preview_root() -> void:
	_preview_root = Node2D.new()
	_preview_root.z_index = 50
	add_child(_preview_root)
	_preview_line = Line2D.new()
	_preview_line.width = PREVIEW_LINE_WIDTH
	_preview_line.default_color = Color(0.25, 0.95, 1.0, 0.55)
	_preview_line.antialiased = true
	_preview_line.z_index = 49
	_preview_root.add_child(_preview_line)


func _build_target_marker() -> void:
	_target_layer = CanvasLayer.new()
	_target_layer.layer = 121
	_target_layer.follow_viewport_enabled = true
	add_child(_target_layer)
	_target_marker = Node2D.new()
	_target_marker.visible = false
	_target_layer.add_child(_target_marker)
	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(0.35, 1.0, 0.55, 1.0)
	var ring_points := PackedVector2Array()
	for i in 33:
		var angle := TAU * float(i) / 32.0
		ring_points.append(Vector2(cos(angle), sin(angle)) * 22.0)
	ring.points = ring_points
	_target_marker.add_child(ring)
	var center := Polygon2D.new()
	center.color = Color(0.35, 1.0, 0.55, 0.95)
	center.polygon = PackedVector2Array([
		Vector2(0, -9), Vector2(9, 0), Vector2(0, 9), Vector2(-9, 0),
	])
	_target_marker.add_child(center)
	var label := Label.new()
	label.text = "ALVO"
	label.position = Vector2(-28, -47)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override(&"font_color", Color(0.35, 1.0, 0.55))
	_apply_ui_font(label, 9)
	_target_marker.add_child(label)


func _entrance_spawn_id() -> String:
	return "hub_to_%s" % sala_id


func _find_entrance_position() -> Vector2:
	var gameplay := get_parent()
	if gameplay:
		var hub_exit := gameplay.get_node_or_null("ExitToHub") as Node2D
		if hub_exit:
			return hub_exit.global_position
		var marker := gameplay.get_node_or_null("SpawnHubEntry") as Marker2D
		if marker:
			return marker.global_position
	var wanted := _entrance_spawn_id()
	for node in get_tree().get_nodes_in_group("spawn_marker"):
		if str(node.get("spawn_id")) == wanted and node is Node2D:
			return (node as Node2D).global_position
	if ENTRANCE_FALLBACK.has(sala_id):
		return ENTRANCE_FALLBACK[sala_id]
	return FunctionPathMath.layout_point(0.0, FunctionPathMath.NODE_Y_HIGH)


func _entrance_nudge(door_pos: Vector2) -> Vector2:
	if door_pos.x < -400.0:
		return Vector2(entrance_inset.x, 0.0)
	if door_pos.x > 400.0:
		return Vector2(-entrance_inset.x, 0.0)
	if door_pos.y > 300.0:
		return Vector2(0.0, -absf(entrance_inset.x))
	if door_pos.y < -300.0:
		return Vector2(0.0, absf(entrance_inset.x))
	return entrance_inset


func _find_goal_position() -> Vector2:
	var gameplay := get_parent()
	if gameplay:
		for door_name in ["DoorSala2", "DoorSala3", "PuzzleGoal", "ExitDoor"]:
			var door := gameplay.get_node_or_null(door_name) as Node2D
			if door:
				return door.global_position
	if GOAL_FALLBACK.has(sala_id):
		return GOAL_FALLBACK[sala_id]
	if gameplay:
		var hub_exit := gameplay.get_node_or_null("ExitToHub") as Node2D
		if hub_exit:
			return hub_exit.global_position + Vector2(
				FunctionPathMath.LAYOUT_WIDTH,
				FunctionPathMath.NODE_Y_HIGH - hub_exit.global_position.y,
			)
	var entrance := _find_entrance_position()
	return entrance + Vector2(FunctionPathMath.LAYOUT_WIDTH, FunctionPathMath.NODE_Y_HIGH)


func _place_player_at_start() -> void:
	if _player and is_instance_valid(_player):
		_player.global_position = _room_start


func _clamp_entrance_position(pos: Vector2) -> Vector2:
	## Porta fica na parede (fora do DOMAIN do puzzle); spawn usa a area jogavel da sala.
	return FunctionPathMath.clamp_play_area(pos)


func _setup_layout_anchors() -> void:
	var door_pos := _find_entrance_position()
	var anchor := door_pos + _entrance_nudge(door_pos)
	_room_start = _clamp_entrance_position(anchor)
	_goal_pos = FunctionPathMath.clamp_domain(_find_goal_position())
	_progress_axis = FunctionPathMath.infer_progress_axis(_room_start)
	_column_426 = FunctionPathMath.column_anchor_from_entrance(_room_start, 1, _progress_axis)
	_column_852 = FunctionPathMath.column_anchor_from_entrance(_room_start, 2, _progress_axis)


func _generate_puzzle() -> void:
	_setup_layout_anchors()
	_rng.seed = hash(
		"%s_%s_%d" % [sala_id, str(Time.get_unix_time_from_system()), randi()]
	)
	var types := FunctionPathMath.pick_section_types(_rng, _section_type_order)
	_section_type_order = types.duplicate()
	_segments.clear()
	for i in FunctionPathMath.SECTION_COUNT:
		_segments.append({
			"type": types[i],
			"segment_type_name": FunctionPathMath.type_display_name(types[i]),
			"section_index": i,
			"target_column": 1 if i == 0 else (2 if i == 1 else 0),
		})
	_clear_baked_props()
	_spawn_random_props()
	_show_goal_at(_goal_pos, false)


func _clear_baked_props() -> void:
	var hub := get_parent().get_parent() if get_parent() else null
	if hub == null:
		return
	var props := hub.get_node_or_null("Obstacles/Props") as Node2D
	if props == null:
		return
	for child in props.get_children():
		child.queue_free()


func _spawn_random_props() -> void:
	_props_spawned = Node2D.new()
	_props_spawned.name = "FunctionPuzzleProps"
	var hub := get_parent().get_parent() if get_parent() else null
	if hub:
		var obstacles := hub.get_node_or_null("Obstacles") as Node2D
		if obstacles:
			obstacles.add_child(_props_spawned)
		else:
			add_child(_props_spawned)
	else:
		add_child(_props_spawned)
	var clear_min := FunctionPathMath.DOMAIN_MIN - Vector2(PATH_CLEAR_RADIUS, PATH_CLEAR_RADIUS)
	var clear_max := FunctionPathMath.DOMAIN_MAX + Vector2(PATH_CLEAR_RADIUS, PATH_CLEAR_RADIUS)
	var placed := 0
	var attempts := 0
	while placed < random_prop_count and attempts < random_prop_count * 40:
		attempts += 1
		var pos := Vector2(
			_rng.randf_range(FunctionPathMath.PLAY_MIN.x, FunctionPathMath.PLAY_MAX.x),
			_rng.randf_range(FunctionPathMath.PLAY_MIN.y, FunctionPathMath.PLAY_MAX.y),
		)
		if pos.x > clear_min.x and pos.x < clear_max.x and pos.y > clear_min.y and pos.y < clear_max.y:
			continue
		if pos.distance_to(_room_start) < GOAL_DOOR_SAFE_RADIUS:
			continue
		if pos.distance_to(_goal_pos) < GOAL_DOOR_SAFE_RADIUS:
			continue
		if _overlaps_prop(pos, 70.0):
			continue
		var def: Dictionary = PROP_DEFS[_rng.randi() % PROP_DEFS.size()]
		var prop := prop_scene.instantiate() as StaticBody2D
		prop.global_position = pos
		prop.set("texture_path", def["path"])
		prop.set("sprite_scale", def["scale"])
		prop.set("collision_fit", def["fit"])
		_props_spawned.add_child(prop)
		placed += 1


func _overlaps_prop(pos: Vector2, min_dist: float) -> bool:
	if _props_spawned == null:
		return false
	for child in _props_spawned.get_children():
		if child is Node2D and child.global_position.distance_to(pos) < min_dist:
			return true
	return false


func _attach_exit_door_glow(door_root: Node2D) -> void:
	if door_root.get_node_or_null("ExitDoorGlow"):
		return
	var glow := Node2D.new()
	glow.name = "ExitDoorGlow"
	glow.set_script(load("res://scripts/exit_door_glow.gd"))
	if goal_door_texture:
		glow.set("door_texture", goal_door_texture)
	glow.set("sprite_scale", Vector2(2.2, 2.2))
	glow.set("beacon_strength", 0.4)
	glow.set("beacon_radius", 128.0)
	door_root.add_child(glow)
	door_root.move_child(glow, 0)


func _show_goal_at(pos: Vector2, open: bool) -> void:
	if _goal_door:
		_goal_door.queue_free()
		_goal_door = null
	_goal_door = Node2D.new()
	_goal_door.name = "FunctionRoomExitDoor"
	_goal_door.z_index = 8
	_goal_door.global_position = pos
	add_child(_goal_door)
	_attach_exit_door_glow(_goal_door)
	var spr := Sprite2D.new()
	spr.name = "DoorSprite"
	spr.texture = goal_door_texture
	spr.scale = Vector2(2.2, 2.2)
	spr.z_index = 1
	spr.modulate = Color(0.82, 1.0, 0.9, 1.0)
	_goal_door.add_child(spr)
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-90, -70)
	lbl.add_theme_color_override("font_color", Color(0.65, 1.0, 0.82, 1.0))
	_apply_ui_font(lbl, UI_LABEL_FONT_SIZE)
	lbl.text = "PORTA" if not open else "PORTA [OK]"
	_goal_door.add_child(lbl)
	if not open:
		_goal_area = Area2D.new()
		_goal_area.collision_layer = 0
		_goal_area.collision_mask = 2
		_goal_area.monitoring = true
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(120, 140)
		shape.shape = rect
		_goal_area.add_child(shape)
		_goal_door.add_child(_goal_area)
		_goal_area.body_entered.connect(_on_goal_reached)
	_attach_goal_hub_exit(open)


func _hub_spawn_id() -> String:
	return "%s_to_hub" % sala_id


func _attach_goal_hub_exit(open: bool) -> void:
	if _goal_hub_exit and is_instance_valid(_goal_hub_exit):
		_goal_hub_exit.queue_free()
	var interact := Area2D.new()
	interact.name = "GoalHubExit"
	interact.collision_layer = 0
	interact.collision_mask = 2
	interact.monitoring = true
	interact.set_script(load("res://scripts/scene_transition_interact.gd"))
	interact.set("target_scene", HUB_SCENE)
	interact.set("enter_spawn_id", _hub_spawn_id())
	interact.set("ignore_function_puzzle_lock", bright_test_room or open)
	interact.set("hint_ready", "[E] VOLTAR AO HUB")
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(150, 170)
	col.shape = rect
	interact.add_child(col)
	var hint := Label.new()
	hint.name = "HintLabel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(-100, -92)
	hint.add_theme_color_override("font_color", Color(0.55, 1.0, 0.75))
	_apply_ui_font(hint, UI_LABEL_FONT_SIZE)
	hint.visible = false
	interact.add_child(hint)
	_goal_door.add_child(interact)
	_goal_hub_exit = interact


func _set_puzzle_header_visible(show_header: bool) -> void:
	if _title_label:
		_title_label.visible = show_header
	if _status_label:
		_status_label.visible = show_header


func _begin_segment_choice() -> void:
	if _completed or _segment_index >= _segments.size():
		return
	if _option_buttons.is_empty() or _ui_layer == null or not is_instance_valid(_ui_layer):
		_build_ui()
	_clear_preview()
	_busy = false
	_selected_option_index = -1
	_set_puzzle_header_visible(true)
	if _ui_layer:
		_ui_layer.visible = true
	var seg: Dictionary = _segments[_segment_index]
	var from_pos: Vector2 = _room_start if _segment_index == 0 else _player.global_position
	_step_start = from_pos
	var required_type: int = seg["type"]
	_required_func_type = required_type
	_set_func_type_hint(required_type)
	_title_label.text = "ETAPA %d/%d - FUNCAO %s - ALCANCE O ALVO" % [
		_segment_index + 1, _segments.size(), FunctionPathMath.type_display_name(required_type).to_upper(),
	]
	_status_label.text = "[1-4] escolher e prever | [ENTER] confirmar"
	var target_col: int = int(seg.get("target_column", 1))
	if target_col == 0:
		_current_options = FunctionPathMath.build_goal_options(
			from_pos, _goal_pos, required_type, _rng, _progress_axis,
		)
	else:
		var col_anchor := _column_426 if target_col == 1 else _column_852
		_current_options = FunctionPathMath.build_column_options(
			from_pos, col_anchor, target_col, _progress_axis, required_type, _rng,
		)
	for i in _option_buttons.size():
		if i >= _current_options.size():
			_option_buttons[i].visible = false
			continue
		_option_buttons[i].visible = true
		var opt: Dictionary = _current_options[i]
		_option_buttons[i].text = _option_button_label(opt, from_pos, target_col, i)
		_option_buttons[i].disabled = false
		_option_buttons[i].modulate = Color.WHITE
	for option in _current_options:
		if option.get("leads_to_door", false):
			_target_marker.global_position = FunctionPathMath.curve_endpoint(option)
			_target_marker.visible = true
			break


func _unhandled_input(event: InputEvent) -> void:
	if _completed or _busy or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if event.is_action_pressed(&"ui_accept"):
		_confirm_selected_option()
		get_viewport().set_input_as_handled()
		return
	var index := -1
	match key_event.keycode:
		KEY_1:
			index = 0
		KEY_2:
			index = 1
		KEY_3:
			index = 2
		KEY_4:
			index = 3
	if index >= 0:
		_on_option_pressed(index)
		get_viewport().set_input_as_handled()


func _on_option_hover(index: int) -> void:
	if _completed or _busy or index >= _current_options.size():
		return
	_draw_path_preview(_runtime_segment(_current_options[index]))


func _on_option_unhover() -> void:
	if not _busy:
		if _selected_option_index >= 0:
			_draw_path_preview(_runtime_segment(_current_options[_selected_option_index]))
		else:
			_clear_preview()


func _on_option_pressed(index: int) -> void:
	if _completed or _busy or index >= _current_options.size():
		return
	_selected_option_index = index
	for i in _option_buttons.size():
		_option_buttons[i].modulate = Color(0.72, 1.0, 0.78) if i == index else Color.WHITE
	_draw_path_preview(_runtime_segment(_current_options[index]))
	_status_label.text = "Opcao %d selecionada | [ENTER] confirmar | [1-4] trocar" % (index + 1)


func _confirm_selected_option() -> void:
	if _completed or _busy or _selected_option_index < 0:
		return
	_confirm_segment(_current_options[_selected_option_index])


func _confirm_segment(segment: Dictionary) -> void:
	_busy = true
	for btn in _option_buttons:
		btn.disabled = true
	var runtime := _runtime_segment(segment)
	_draw_path_preview(runtime, Color(0.35, 1.0, 0.75, 1.0), Color(0.2, 1.0, 0.85, 0.7))
	await _tween_along_segment(runtime)
	if not _busy:
		return
	if segment.get("is_wall_trap", false) or not segment.get("leads_to_door", true):
		_retry_current_segment()
		return
	var landing: Vector2 = FunctionPathMath.curve_endpoint(runtime)
	_player.global_position = landing
	_segment_index += 1
	if _segment_index >= _segments.size():
		_on_all_segments_done()
	else:
		_begin_segment_choice()


func _runtime_segment(segment: Dictionary) -> Dictionary:
	if _player == null:
		return segment
	return FunctionPathMath.with_start(segment, _player.global_position)


func _movement_points(segment: Dictionary, sample_count: int = 72) -> PackedVector2Array:
	var pts := FunctionPathMath.sample_segment(segment, sample_count)
	var out := PackedVector2Array()
	if _player == null or pts.is_empty():
		return pts
	var axis := int(segment.get("progress_axis", _progress_axis))
	var increasing := FunctionPathMath.forward_increases(axis)
	var bound := FunctionPathMath.primary_coord(_player.global_position, axis) - 1.0
	var start_i := 0
	for i in pts.size():
		if _player.global_position.distance_to(pts[i]) <= PATH_START_SNAP:
			start_i = i
	if start_i == 0 and _player.global_position.distance_to(pts[0]) > PATH_START_SNAP:
		var bridge := _player.global_position
		var bridge_p := FunctionPathMath.primary_coord(bridge, axis)
		if increasing:
			if bridge_p >= bound - 0.5:
				out.append(bridge)
		elif bridge_p <= bound + 0.5:
			out.append(bridge)
	for i in range(start_i, pts.size()):
		var p: Vector2 = pts[i]
		var pc := FunctionPathMath.primary_coord(p, axis)
		if increasing:
			if pc < bound - FunctionPathMath.FORWARD_X_EPS:
				continue
		elif pc > bound + FunctionPathMath.FORWARD_X_EPS:
			continue
		out.append(p)
		if increasing:
			bound = maxf(bound, pc)
		else:
			bound = minf(bound, pc)
	if out.is_empty():
		out.append(FunctionPathMath.curve_endpoint(segment))
		return out
	var tip := FunctionPathMath.curve_endpoint(segment)
	if out[out.size() - 1].distance_to(tip) > 4.0:
		out.append(tip)
	else:
		out[out.size() - 1] = tip
	return out


func _tween_along_segment(segment: Dictionary) -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	var pts := _movement_points(segment, 72)
	if pts.is_empty():
		return
	var step := maxi(1, int(float(pts.size()) / 28.0))
	var step_time := 0.032
	_move_tween = create_tween()
	for i in range(0, pts.size(), step):
		var p: Vector2 = pts[i]
		_move_tween.tween_property(_player, "global_position", p, step_time)
	await _move_tween.finished
	if not _busy:
		return
	if _player.has_method("set_function_puzzle_locked"):
		_player.set_function_puzzle_locked(true)


func _retry_current_segment() -> void:
	GameManager.drain_o2(WRONG_CHOICE_O2_COST)
	if GameManager.is_game_over:
		return
	_busy = false
	_player.global_position = _step_start
	_selected_option_index = -1
	if AudioManager:
		AudioManager.play_web()
	_clear_preview()
	for btn in _option_buttons:
		btn.disabled = false
		btn.modulate = Color.WHITE
	_status_label.text = "Tente outra opcao nesta etapa. -5 O2 | [1-4] escolher"
	if _player.has_method("set_function_puzzle_locked"):
		_player.set_function_puzzle_locked(true)


func _on_all_segments_done() -> void:
	_completed = true
	_busy = false
	GameManager.mark_sala_cleared(sala_id)
	if _player and _player.has_method("set_function_puzzle_locked"):
		_player.set_function_puzzle_locked(false)
	_clear_preview()
	if _target_marker:
		_target_marker.visible = false
	_set_puzzle_header_visible(true)
	_title_label.text = "Caminho completo!"
	_status_label.text = "Va ate a porta e pressione [E] para voltar ao hub."
	for btn in _option_buttons:
		btn.visible = false
	_show_goal_at(_goal_pos, true)
	var gameplay := get_parent()
	if gameplay:
		var hub_exit := gameplay.get_node_or_null("ExitToHub")
		if hub_exit:
			hub_exit.visible = true


func _on_goal_reached(body: Node2D) -> void:
	if not _completed or not body.is_in_group("player"):
		return
	_set_puzzle_header_visible(true)
	_status_label.text = "Sala concluida! Pressione [E] na porta para o hub."


func _draw_path_preview(
	segment: Dictionary,
	dot_color: Color = Color(0.45, 0.98, 1.0, 1.0),
	line_color: Color = Color(0.2, 0.92, 1.0, 0.65),
) -> void:
	_clear_preview()
	var pts := _movement_points(segment, 80)
	if _preview_line:
		_preview_line.default_color = line_color
		_preview_line.points = pts
	var dist := 0.0
	var prev := pts[0]
	for i in range(1, pts.size()):
		var cur: Vector2 = pts[i]
		dist += prev.distance_to(cur)
		if dist >= DOT_SPACING:
			var dot := _make_dot(cur, dot_color)
			_preview_root.add_child(dot)
			dist = 0.0
		prev = cur
	# Garante pontos nas extremidades.
	_preview_root.add_child(_make_dot(pts[0], dot_color))
	_preview_root.add_child(_make_dot(pts[pts.size() - 1], dot_color))


func _make_dot(pos: Vector2, color: Color) -> Node2D:
	var n := Node2D.new()
	n.global_position = pos
	var poly := Polygon2D.new()
	poly.color = color
	var r := DOT_RADIUS
	poly.polygon = PackedVector2Array([
		Vector2(-r, 0), Vector2(0, -r), Vector2(r, 0), Vector2(0, r),
	])
	n.add_child(poly)
	var glow := Polygon2D.new()
	glow.color = Color(color.r, color.g, color.b, color.a * 0.35)
	var gr := r * 1.8
	glow.polygon = PackedVector2Array([
		Vector2(-gr, 0), Vector2(0, -gr), Vector2(gr, 0), Vector2(0, gr),
	])
	glow.z_index = -1
	n.add_child(glow)
	return n


func _clear_preview() -> void:
	if _preview_line:
		_preview_line.points = PackedVector2Array()
	if _preview_root:
		for c in _preview_root.get_children():
			if c != _preview_line:
				c.queue_free()


func _exit_tree() -> void:
	_shutdown_puzzle()


func _shutdown_puzzle() -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_busy = false
	_completed = false
	_segment_index = 0
	_option_buttons.clear()
	_func_hint_root = null
	_func_hint_icon = null
	_func_hint_label = null
	if _ui_layer and is_instance_valid(_ui_layer):
		var parent := _ui_layer.get_parent()
		if parent:
			parent.remove_child(_ui_layer)
		_ui_layer.free()
		_ui_layer = null
	if _player and is_instance_valid(_player) and _player.has_method("set_function_puzzle_locked"):
		_player.set_function_puzzle_locked(false)
