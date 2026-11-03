extends RefCounted
class_name FunctionPathMath
## Curvas do puzzle: afim, parabola e exponencial (trajetoria tipo lousa).

enum FuncType { AFFINE, QUADRATIC, MODULAR, EXPONENTIAL, LOGARITHMIC }

## Direcao do puzzle a partir da porta de entrada (colunas a 426 / 852).
enum ProgressAxis { PLUS_X, MINUS_X, PLUS_Y, MINUS_Y }

const TYPE_NAMES_PT: PackedStringArray = [
	"Afim",
	"Quadratica",
	"Modular (seno)",
	"Exponencial",
	"Logaritmica",
]

const PLAY_MIN := Vector2(-980.0, -580.0)
const PLAY_MAX := Vector2(980.0, 580.0)
## Area segura para curvas do puzzle (dentro das paredes da sala).
const DOMAIN_MIN := Vector2(-820.0, -420.0)
const DOMAIN_MAX := Vector2(820.0, 420.0)
const SAMPLE_COUNT := 48
## Ultimos pontos da quadratica geram artefato em "V"; ignorar no caminho exibido.
const QUADRATIC_TAIL_TRIM := 2
const MIN_SEGMENT_DX := 72.0
const FORWARD_X_EPS := 1.5
const MAX_CHORD_DEVIATION := 42.0
const MAX_NET_DY_RATIO := 0.52
const WAYPOINT_Y_JITTER := 28.0
const OPTION_COUNT := 4
const DOOR_END_TOLERANCE := 14.0
## Tres secoes invisiveis de 426px (total 1278), como no layout da lousa.
const SECTION_COUNT := 3
const SECTION_WIDTH := 426.0
const LAYOUT_WIDTH := 1278.0
const LAYOUT_ORIGIN_X := -LAYOUT_WIDTH * 0.5
const NODE_Y_HIGH := -240.0
const NODE_Y_LOW := 260.0
const QUAD_LIFT_RATIO_MIN := 0.14
const QUAD_LIFT_RATIO_MAX := 0.26
const QUAD_MAX_LIFT_RATIO := 0.3
const QUAD_MIN_LIFT_RATIO := 0.18
const QUAD_MIN_SAGITTA := 40.0
const QUAD_MIN_ABS_A := 0.0018
const DOMAIN_CURVE_MARGIN := 28.0
const EXP_K_MIN := 2.0
const EXP_K_MAX := 3.8
const COLUMN_Y_MIN_SEP := 72.0
const VALID_OPTION_COUNT := 1
const TRAP_OPTION_COUNT := 3
const RIGHT_WALL_MARGIN := 10.0
## Caminhos errados (ultima escolha) nao podem passar nem terminar perto da porta.
const GOAL_EXCLUSION_RADIUS := 150.0
const GOAL_TRAP_MIN_Y_SEP := 180.0
const GOAL_TRAP_MIN_CROSS_SEP := 180.0

const PUZZLE_TYPES: Array[int] = [
	FuncType.AFFINE,
	FuncType.QUADRATIC,
	FuncType.EXPONENTIAL,
]


static func is_puzzle_type(func_type: int) -> bool:
	return (
		func_type == FuncType.AFFINE
		or func_type == FuncType.QUADRATIC
		or func_type == FuncType.EXPONENTIAL
	)


static func all_section_type_orders() -> Array:
	return [
		[FuncType.AFFINE, FuncType.QUADRATIC, FuncType.EXPONENTIAL],
		[FuncType.AFFINE, FuncType.EXPONENTIAL, FuncType.QUADRATIC],
		[FuncType.QUADRATIC, FuncType.AFFINE, FuncType.EXPONENTIAL],
		[FuncType.QUADRATIC, FuncType.EXPONENTIAL, FuncType.AFFINE],
		[FuncType.EXPONENTIAL, FuncType.AFFINE, FuncType.QUADRATIC],
		[FuncType.EXPONENTIAL, FuncType.QUADRATIC, FuncType.AFFINE],
	]


static func same_type_order(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if int(a[i]) != int(b[i]):
			return false
	return true


static func pick_section_types(
	rng: RandomNumberGenerator,
	previous_order: Array = [],
) -> Array[int]:
	var pool: Array = []
	for perm in all_section_type_orders():
		if same_type_order(perm, previous_order):
			continue
		if _order_has_consecutive_affine(perm):
			continue
		pool.append(perm)
	if pool.is_empty():
		for perm in all_section_type_orders():
			if not same_type_order(perm, previous_order):
				pool.append(perm)
	if pool.is_empty():
		pool = all_section_type_orders()
	var idx := rng.randi_range(0, pool.size() - 1)
	var picked: Array = pool[idx]
	var out: Array[int] = []
	for t in picked:
		out.append(int(t))
	return out


static func _order_has_consecutive_affine(order: Array) -> bool:
	for i in range(order.size() - 1):
		if int(order[i]) == FuncType.AFFINE and int(order[i + 1]) == FuncType.AFFINE:
			return true
	return false


static func infer_progress_axis(entrance: Vector2) -> int:
	if entrance.y > 280.0:
		return ProgressAxis.MINUS_Y
	if entrance.y < -280.0:
		return ProgressAxis.PLUS_Y
	if entrance.x < -400.0:
		return ProgressAxis.PLUS_X
	if entrance.x > 400.0:
		return ProgressAxis.MINUS_X
	return ProgressAxis.PLUS_X


static func axis_is_horizontal(axis: int) -> bool:
	return axis == ProgressAxis.PLUS_X or axis == ProgressAxis.MINUS_X


static func forward_increases(axis: int) -> bool:
	return axis == ProgressAxis.PLUS_X or axis == ProgressAxis.PLUS_Y


static func progress_delta(start: Vector2, end: Vector2, axis: int) -> float:
	match axis:
		ProgressAxis.MINUS_X:
			return start.x - end.x
		ProgressAxis.PLUS_Y:
			return end.y - start.y
		ProgressAxis.MINUS_Y:
			return start.y - end.y
		_:
			return end.x - start.x


static func primary_coord(p: Vector2, axis: int) -> float:
	if axis_is_horizontal(axis):
		return p.x
	return p.y


static func nudge_forward(start: Vector2, dist: float, axis: int) -> Vector2:
	match axis:
		ProgressAxis.MINUS_X:
			return clamp_domain(Vector2(start.x - dist, start.y))
		ProgressAxis.PLUS_Y:
			return clamp_domain(Vector2(start.x, start.y + dist))
		ProgressAxis.MINUS_Y:
			return clamp_domain(Vector2(start.x, start.y - dist))
		_:
			return clamp_domain(Vector2(start.x + dist, start.y))


static func ensure_forward_end(start: Vector2, end: Vector2, axis: int) -> Vector2:
	var safe := clamp_domain(end)
	if progress_delta(start, safe, axis) >= MIN_SEGMENT_DX:
		return safe
	return nudge_forward(start, MIN_SEGMENT_DX, axis)


static func column_anchor_from_entrance(
	entrance: Vector2,
	column_index: int,
	axis: int,
) -> Vector2:
	var dist := SECTION_WIDTH * float(column_index)
	match axis:
		ProgressAxis.MINUS_X:
			return Vector2(entrance.x - dist, entrance.y)
		ProgressAxis.PLUS_Y:
			return Vector2(entrance.x, entrance.y + dist)
		ProgressAxis.MINUS_Y:
			return Vector2(entrance.x, entrance.y - dist)
		_:
			return Vector2(entrance.x + dist, entrance.y)


static func ensure_column_anchor(start: Vector2, anchor: Vector2, axis: int) -> Vector2:
	var out := anchor
	if axis_is_horizontal(axis):
		if progress_delta(start, Vector2(out.x, start.y), axis) < MIN_SEGMENT_DX:
			out.x = nudge_forward(start, MIN_SEGMENT_DX, axis).x
	else:
		if progress_delta(start, Vector2(start.x, out.y), axis) < MIN_SEGMENT_DX:
			out.y = nudge_forward(start, MIN_SEGMENT_DX, axis).y
	return out


static func far_wall_coord(axis: int) -> float:
	match axis:
		ProgressAxis.MINUS_Y:
			return DOMAIN_MIN.y + RIGHT_WALL_MARGIN
		ProgressAxis.PLUS_Y:
			return DOMAIN_MAX.y - RIGHT_WALL_MARGIN
		ProgressAxis.MINUS_X:
			return DOMAIN_MIN.x + RIGHT_WALL_MARGIN
		_:
			return right_wall_x()


static func layout_point(local_x: float, y: float) -> Vector2:
	return clamp_domain(Vector2(LAYOUT_ORIGIN_X + local_x, y))


static func pick_column_x_values(rng: RandomNumberGenerator) -> Array[float]:
	var x_min := DOMAIN_MIN.x + 50.0
	var x_max := DOMAIN_MAX.x - 50.0
	var values: Array[float] = []
	for _attempt in 32:
		if values.size() >= OPTION_COUNT:
			break
		var x := rng.randf_range(x_min, x_max)
		var ok := true
		for existing in values:
			if absf(x - existing) < COLUMN_Y_MIN_SEP:
				ok = false
				break
		if ok:
			values.append(x)
	if values.size() < OPTION_COUNT:
		var step := (x_max - x_min) / float(OPTION_COUNT)
		values.clear()
		for i in OPTION_COUNT:
			values.append(x_min + step * (float(i) + 0.5))
	for i in values.size():
		var j := rng.randi_range(i, values.size() - 1)
		var tmp: float = values[i]
		values[i] = values[j]
		values[j] = tmp
	return values


static func pick_column_y_values(rng: RandomNumberGenerator) -> Array[float]:
	## Quatro alturas distintas na mesma coluna (uma por alternativa).
	var y_min := DOMAIN_MIN.y + 50.0
	var y_max := DOMAIN_MAX.y - 50.0
	var values: Array[float] = []
	for _attempt in 32:
		if values.size() >= OPTION_COUNT:
			break
		var y := rng.randf_range(y_min, y_max)
		var ok := true
		for existing in values:
			if absf(y - existing) < COLUMN_Y_MIN_SEP:
				ok = false
				break
		if ok:
			values.append(y)
	if values.size() < OPTION_COUNT:
		var step := (y_max - y_min) / float(OPTION_COUNT)
		values.clear()
		for i in OPTION_COUNT:
			values.append(y_min + step * (float(i) + 0.5))
	for i in values.size():
		var j := rng.randi_range(i, values.size() - 1)
		var tmp: float = values[i]
		values[i] = values[j]
		values[j] = tmp
	return values


static func right_wall_x() -> float:
	return DOMAIN_MAX.x - RIGHT_WALL_MARGIN


static func wall_trap_end(start: Vector2, cross: float, axis: int = ProgressAxis.PLUS_X) -> Vector2:
	match axis:
		ProgressAxis.MINUS_Y:
			var wy_up := far_wall_coord(axis)
			return clamp_domain(Vector2(
				cross,
				minf(wy_up, start.y - MIN_SEGMENT_DX),
			))
		ProgressAxis.PLUS_Y:
			var wy_dn := far_wall_coord(axis)
			return clamp_domain(Vector2(
				cross,
				maxf(wy_dn, start.y + MIN_SEGMENT_DX),
			))
		ProgressAxis.MINUS_X:
			var wx_l := far_wall_coord(axis)
			return clamp_domain(Vector2(
				minf(wx_l, start.x - MIN_SEGMENT_DX),
				cross,
			))
		_:
			var wx := maxf(far_wall_coord(axis), start.x + MIN_SEGMENT_DX)
			return clamp_domain(Vector2(wx, cross))


static func segment_near_point(segment: Dictionary, point: Vector2, radius: float) -> bool:
	if point == Vector2.ZERO:
		return false
	for p in sample_segment(segment, 36):
		if p.distance_to(point) < radius:
			return true
	return false


static func pick_goal_trap_cross_values(
	start: Vector2,
	goal: Vector2,
	count: int,
	rng: RandomNumberGenerator,
	axis: int,
) -> Array[float]:
	if axis_is_horizontal(axis):
		return _pick_goal_trap_y_values(start, goal, count, rng, axis)
	return _pick_goal_trap_x_values(start, goal, count, rng, axis)


static func _pick_goal_trap_y_values(
	start: Vector2,
	goal: Vector2,
	count: int,
	rng: RandomNumberGenerator,
	axis: int,
) -> Array[float]:
	var y_min := DOMAIN_MIN.y + 50.0
	var y_max := DOMAIN_MAX.y - 50.0
	var values: Array[float] = []
	var prefer_low := goal.y >= lerpf(NODE_Y_HIGH, NODE_Y_LOW, 0.5)
	for _attempt in 64:
		if values.size() >= count:
			break
		var y: float
		if prefer_low:
			y = rng.randf_range(y_min, y_min + (y_max - y_min) * 0.38)
		else:
			y = rng.randf_range(y_max - (y_max - y_min) * 0.38, y_max)
		if absf(y - goal.y) < GOAL_TRAP_MIN_CROSS_SEP:
			continue
		var end := wall_trap_end(start, y, axis)
		if end.distance_to(goal) < GOAL_EXCLUSION_RADIUS:
			continue
		var ok := true
		for existing in values:
			if absf(y - existing) < COLUMN_Y_MIN_SEP:
				ok = false
				break
		if ok:
			values.append(y)
	if values.size() < count:
		var fallbacks: Array[float] = [NODE_Y_HIGH + 60.0, NODE_Y_LOW - 60.0]
		for fb in fallbacks:
			if values.size() >= count:
				break
			var y_fb: float = clampf(fb, y_min, y_max)
			if absf(y_fb - goal.y) < GOAL_TRAP_MIN_CROSS_SEP:
				continue
			if wall_trap_end(start, y_fb, axis).distance_to(goal) < GOAL_EXCLUSION_RADIUS:
				continue
			values.append(y_fb)
	return values


static func _pick_goal_trap_x_values(
	start: Vector2,
	goal: Vector2,
	count: int,
	rng: RandomNumberGenerator,
	axis: int,
) -> Array[float]:
	var x_min := DOMAIN_MIN.x + 50.0
	var x_max := DOMAIN_MAX.x - 50.0
	var values: Array[float] = []
	var prefer_left := goal.x <= 0.0
	for _attempt in 64:
		if values.size() >= count:
			break
		var x: float
		if prefer_left:
			x = rng.randf_range(x_min, x_min + (x_max - x_min) * 0.38)
		else:
			x = rng.randf_range(x_max - (x_max - x_min) * 0.38, x_max)
		if absf(x - goal.x) < GOAL_TRAP_MIN_CROSS_SEP:
			continue
		var end := wall_trap_end(start, x, axis)
		if end.distance_to(goal) < GOAL_EXCLUSION_RADIUS:
			continue
		var ok := true
		for existing in values:
			if absf(x - existing) < COLUMN_Y_MIN_SEP:
				ok = false
				break
		if ok:
			values.append(x)
	if values.size() < count:
		var fallbacks: Array[float] = [-320.0, 320.0]
		for fb in fallbacks:
			if values.size() >= count:
				break
			var x_fb: float = clampf(fb, x_min, x_max)
			if absf(x_fb - goal.x) < GOAL_TRAP_MIN_CROSS_SEP:
				continue
			if wall_trap_end(start, x_fb, axis).distance_to(goal) < GOAL_EXCLUSION_RADIUS:
				continue
			values.append(x_fb)
	return values


static func make_wall_trap_segment(
	func_type: int,
	start: Vector2,
	cross: float,
	rng: RandomNumberGenerator,
	avoid_goal: Vector2 = Vector2.ZERO,
	axis: int = ProgressAxis.PLUS_X,
) -> Dictionary:
	if not is_puzzle_type(func_type):
		func_type = FuncType.AFFINE
	var end := wall_trap_end(start, cross, axis)
	var avoid := avoid_goal != Vector2.ZERO
	for _attempt in 64:
		var seg := make_segment(func_type, start, end, rng, true)
		seg["progress_axis"] = axis
		if not is_forward_path(seg, axis):
			continue
		if avoid and end.distance_to(avoid_goal) < GOAL_EXCLUSION_RADIUS:
			continue
		if avoid and segment_near_point(seg, avoid_goal, GOAL_EXCLUSION_RADIUS):
			continue
		seg = finalize_segment_targets(seg)
		seg["leads_to_door"] = false
		seg["column_index"] = -1
		seg["is_wall_trap"] = true
		seg["progress_axis"] = axis
		return seg
	var seg_fb := finalize_segment_targets(make_segment(func_type, start, end, rng, true))
	seg_fb["leads_to_door"] = false
	seg_fb["column_index"] = -1
	seg_fb["is_wall_trap"] = true
	seg_fb["progress_axis"] = axis
	return seg_fb


static func type_display_name(t: int) -> String:
	if t >= 0 and t < TYPE_NAMES_PT.size():
		return TYPE_NAMES_PT[t]
	return "?"


static func format_equation_body(t: int, params: Dictionary) -> String:
	match t:
		FuncType.AFFINE:
			return _format_affine(params.get("a", 0.0), params.get("b", 0.0))
		FuncType.QUADRATIC:
			return _format_parabola(
				params.get("a", 0.0),
				params.get("b", 0.0),
				params.get("c", 0.0),
			)
		FuncType.MODULAR:
			return "y = %.0f*sin(%.1f*t) + %.0f" % [
				params.get("amp", 0.0), params.get("freq", 1.0), params.get("base", 0.0),
			]
		FuncType.EXPONENTIAL:
			return _format_exponential(params)
		FuncType.LOGARITHMIC:
			return "y = %.0f*ln(t) + %.0f" % [params.get("amp", 0.0), params.get("base", 0.0)]
		_:
			return "?"


static func type_icon_path(t: int) -> String:
	match t:
		FuncType.AFFINE:
			return "res://assets/ui/funcoes/afim.png"
		FuncType.QUADRATIC:
			return "res://assets/ui/funcoes/quad.png"
		FuncType.EXPONENTIAL:
			return "res://assets/ui/funcoes/exp.png"
		_:
			return ""


static func make_segment(
	func_type: int,
	start: Vector2,
	end: Vector2,
	rng: RandomNumberGenerator,
	doorward: bool = false,
) -> Dictionary:
	var params := _doorward_params(func_type, start, end, rng) if doorward else _default_params(
		func_type, start, end, rng
	)
	return {
		"type": func_type,
		"start": clamp_domain(start),
		"end": clamp_domain(end),
		"params": params,
	}


static func is_forward_end(
	start: Vector2,
	end: Vector2,
	axis: int = ProgressAxis.PLUS_X,
) -> bool:
	return progress_delta(start, end, axis) >= MIN_SEGMENT_DX


static func is_forward_path(segment: Dictionary, axis: int = -1) -> bool:
	if axis < 0:
		axis = int(segment.get("progress_axis", ProgressAxis.PLUS_X))
	var start: Vector2 = segment.get("start", Vector2.ZERO)
	var end: Vector2 = segment.get("end", Vector2.ZERO)
	if not is_forward_end(start, end, axis):
		return false
	var pts := sample_segment(segment, 28)
	if pts.size() < 2:
		return false
	var increasing := forward_increases(axis)
	var prev := primary_coord(pts[0], axis)
	for i in range(1, pts.size()):
		var cur := primary_coord(pts[i], axis)
		if increasing:
			if cur < prev - FORWARD_X_EPS:
				return false
		elif cur > prev + FORWARD_X_EPS:
			return false
		prev = cur
	return true


static func is_doorward_path(segment: Dictionary, axis: int = -1) -> bool:
	if axis < 0:
		axis = int(segment.get("progress_axis", ProgressAxis.PLUS_X))
	if not is_forward_path(segment, axis):
		return false
	var start: Vector2 = segment.get("start", Vector2.ZERO)
	var end: Vector2 = segment.get("end", Vector2.ZERO)
	var span := progress_delta(start, end, axis)
	var cross := absf(end.y - start.y) if axis_is_horizontal(axis) else absf(end.x - start.x)
	if span < MIN_SEGMENT_DX:
		return false
	if cross > span * MAX_NET_DY_RATIO:
		return false
	var ft: int = segment.get("type", FuncType.AFFINE)
	if ft == FuncType.QUADRATIC:
		var lift := absf(float(segment.get("params", {}).get("mid_y_offset", 0.0)))
		if lift > span * QUAD_MAX_LIFT_RATIO:
			return false
		if lift < span * QUAD_MIN_LIFT_RATIO:
			return false
		if _max_deviation_from_chord(segment) < QUAD_MIN_SAGITTA:
			return false
		return segment_fits_domain(segment)
	if ft == FuncType.EXPONENTIAL:
		return true
	return _max_deviation_from_chord(segment) <= MAX_CHORD_DEVIATION


static func _max_deviation_from_chord(segment: Dictionary) -> float:
	var pts := sample_segment(segment, 32)
	if pts.size() < 2:
		return 0.0
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[pts.size() - 1]
	var max_d := 0.0
	for p in pts:
		max_d = maxf(max_d, _point_segment_distance(p, a, b))
	return max_d


static func _point_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func make_forward_segment(
	func_type: int,
	start: Vector2,
	end: Vector2,
	rng: RandomNumberGenerator,
	axis: int = ProgressAxis.PLUS_X,
) -> Dictionary:
	if not is_puzzle_type(func_type):
		func_type = FuncType.AFFINE
	var safe_end := ensure_forward_end(start, end, axis)
	if func_type == FuncType.QUADRATIC:
		var seg_q := make_quadratic_forward_segment(start, safe_end, rng, axis)
		seg_q["progress_axis"] = axis
		return seg_q
	for _attempt in 48:
		var seg := make_segment(func_type, start, safe_end, rng, true)
		seg["progress_axis"] = axis
		if is_doorward_path(seg, axis):
			return finalize_segment_targets(seg)
	var seg_fb := finalize_segment_targets(make_segment(func_type, start, safe_end, rng, true))
	seg_fb["progress_axis"] = axis
	return seg_fb


static func _candidate_quadratic_lifts(
	start: Vector2,
	end: Vector2,
	dx: float,
	rng: RandomNumberGenerator,
) -> Array[float]:
	var lifts: Array[float] = []
	for ratio in [0.3, -0.3, 0.26, -0.26, 0.22, -0.22, 0.18, -0.18]:
		lifts.append(dx * ratio)
	for _i in 16:
		lifts.append(_sketch_quadratic_lift(start, end, rng))
	lifts.sort_custom(func(a: float, b: float) -> bool: return absf(a) > absf(b))
	return lifts


static func _try_quadratic_segment(start: Vector2, end: Vector2, lift: float) -> Dictionary:
	return finalize_segment_targets({
		"type": FuncType.QUADRATIC,
		"start": start,
		"end": end,
		"params": _quadratic_params_with_lift(start, end, lift),
	})


static func _pick_best_quadratic_segment(
	start: Vector2,
	end: Vector2,
	lifts: Array[float],
	axis: int,
) -> Dictionary:
	var best: Dictionary = {}
	var best_sagitta := 0.0
	for lift in lifts:
		var seg := _try_quadratic_segment(start, end, lift)
		seg["progress_axis"] = axis
		if not is_doorward_path(seg, axis):
			continue
		var sagitta := _max_deviation_from_chord(seg)
		if sagitta > best_sagitta:
			best_sagitta = sagitta
			best = seg
	return best


static func make_quadratic_forward_segment(
	start: Vector2,
	end: Vector2,
	rng: RandomNumberGenerator,
	axis: int = ProgressAxis.PLUS_X,
) -> Dictionary:
	var safe_start := clamp_domain(start)
	var safe_end := end
	var span_ref := maxf(
		absf(safe_end.x - safe_start.x),
		progress_delta(safe_start, safe_end, axis) * 0.25,
	)
	var lifts := _candidate_quadratic_lifts(safe_start, safe_end, span_ref, rng)
	var best := _pick_best_quadratic_segment(safe_start, safe_end, lifts, axis)
	if not best.is_empty():
		best["progress_axis"] = axis
		return best
	var forced_signs: Array[float] = [-1.0, 1.0]
	for sign_val in forced_signs:
		var forced: float = sign_val * span_ref * QUAD_MAX_LIFT_RATIO
		var seg_f := _try_quadratic_segment(safe_start, safe_end, forced)
		seg_f["progress_axis"] = axis
		if segment_fits_domain(seg_f):
			return seg_f
	var seg_fb := _try_quadratic_segment(safe_start, safe_end, span_ref * QUAD_MIN_LIFT_RATIO)
	seg_fb["progress_axis"] = axis
	return seg_fb


static func build_column_options(
	start: Vector2,
	column_anchor: Vector2,
	column_index: int,
	axis: int,
	required_type: int,
	rng: RandomNumberGenerator,
) -> Array[Dictionary]:
	## Cada alternativa termina num ponto diferente da coluna (426 ou 852).
	if not is_puzzle_type(required_type):
		required_type = FuncType.AFFINE
	var anchor := ensure_column_anchor(start, column_anchor, axis)
	var options: Array[Dictionary] = []
	var correct_index := rng.randi_range(0, OPTION_COUNT - 1)
	var wrong_types := _other_puzzle_types(required_type)
	if axis_is_horizontal(axis):
		var y_values := pick_column_y_values(rng)
		for i in y_values.size():
			var y: float = y_values[i]
			var end := clamp_domain(Vector2(anchor.x, y))
			var func_type := required_type if i == correct_index else wrong_types[i % wrong_types.size()]
			var seg := make_forward_segment(func_type, start, end, rng, axis)
			seg["leads_to_door"] = i == correct_index
			seg["is_wall_trap"] = false
			seg["column_index"] = column_index
			options.append(seg)
	else:
		var x_values := pick_column_x_values(rng)
		for i in x_values.size():
			var x: float = x_values[i]
			var end := clamp_domain(Vector2(x, anchor.y))
			var func_type := required_type if i == correct_index else wrong_types[i % wrong_types.size()]
			var seg := make_forward_segment(func_type, start, end, rng, axis)
			seg["leads_to_door"] = i == correct_index
			seg["is_wall_trap"] = false
			seg["column_index"] = column_index
			options.append(seg)
	for i in options.size():
		var j := rng.randi_range(i, options.size() - 1)
		var tmp: Dictionary = options[i]
		options[i] = options[j]
		options[j] = tmp
	return options


static func _other_puzzle_types(required_type: int) -> Array[int]:
	var out: Array[int] = []
	for func_type in PUZZLE_TYPES:
		if func_type != required_type:
			out.append(func_type)
	return out


static func build_goal_options(
	start: Vector2,
	goal: Vector2,
	required_type: int,
	rng: RandomNumberGenerator,
	axis: int = ProgressAxis.PLUS_X,
) -> Array[Dictionary]:
	if not is_puzzle_type(required_type):
		required_type = FuncType.AFFINE
	var safe_goal := clamp_domain(goal)
	var trap_cross := pick_goal_trap_cross_values(start, safe_goal, TRAP_OPTION_COUNT, rng, axis)
	var options: Array[Dictionary] = []
	var wrong_types := _other_puzzle_types(required_type)
	for _i in VALID_OPTION_COUNT:
		var seg := make_forward_segment(required_type, start, safe_goal, rng, axis)
		seg["leads_to_door"] = true
		seg["is_wall_trap"] = false
		seg["column_index"] = 0
		options.append(seg)
	for i in TRAP_OPTION_COUNT:
		var cross: float
		if i < trap_cross.size():
			cross = trap_cross[i]
		elif axis_is_horizontal(axis):
			cross = DOMAIN_MIN.y + 60.0 if safe_goal.y > 0.0 else DOMAIN_MAX.y - 60.0
		else:
			cross = DOMAIN_MIN.x + 60.0 if safe_goal.x > 0.0 else DOMAIN_MAX.x - 60.0
		var trap_type := required_type if i == TRAP_OPTION_COUNT - 1 else wrong_types[i % wrong_types.size()]
		options.append(make_wall_trap_segment(trap_type, start, cross, rng, safe_goal, axis))
	for i in options.size():
		var j := rng.randi_range(i, options.size() - 1)
		var tmp: Dictionary = options[i]
		options[i] = options[j]
		options[j] = tmp
	return options


static func curve_point(segment: Dictionary, u: float) -> Vector2:
	var t: int = segment.get("type", FuncType.AFFINE)
	var start: Vector2 = segment.get("start", Vector2.ZERO)
	var end: Vector2 = segment.get("end", Vector2.ZERO)
	var params: Dictionary = segment.get("params", {})
	return _point_on_curve(t, start, end, params, clampf(u, 0.0, 1.0))


static func curve_endpoint(segment: Dictionary) -> Vector2:
	var end: Vector2 = segment.get("end", Vector2.ZERO)
	var p := curve_point(segment, 1.0)
	if p.distance_to(end) <= DOOR_END_TOLERANCE:
		return clamp_domain(end)
	return clamp_domain(p)


static func finalize_segment_targets(segment: Dictionary) -> Dictionary:
	var declared: Vector2 = clamp_domain(segment.get("end", Vector2.ZERO))
	var ft: int = segment.get("type", FuncType.AFFINE)
	var start: Vector2 = segment.get("start", Vector2.ZERO)
	var params: Dictionary = segment.get("params", {})
	match ft:
		FuncType.QUADRATIC:
			var lift_q: float = _ensure_quadratic_curvature(
				start, declared, float(params.get("mid_y_offset", 0.0))
			)
			params = _quadratic_params_with_lift(start, declared, lift_q)
		FuncType.AFFINE:
			params = _affine_params(start, declared)
		FuncType.EXPONENTIAL:
			params = _exponential_params(start, declared, float(params.get("k", 2.8)))
	segment["params"] = params
	segment["end"] = declared
	segment["column_point"] = declared
	return segment


static func sample_segment(segment: Dictionary, count: int = SAMPLE_COUNT) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(count)
	var t: int = segment.get("type", FuncType.AFFINE)
	var start: Vector2 = segment.get("start", Vector2.ZERO)
	var end: Vector2 = segment.get("end", Vector2.ZERO)
	var params: Dictionary = segment.get("params", {})
	var last := maxi(count - 1, 1)
	for i in count:
		var u := float(i) / float(last)
		if i == 0:
			pts[i] = clamp_domain(start)
		elif i == last:
			pts[i] = clamp_domain(end)
		else:
			var raw := _point_on_curve(t, start, end, params, u)
			if t == FuncType.QUADRATIC:
				pts[i] = raw
			else:
				pts[i] = clamp_domain(raw)
	return trim_path_tail(pts, segment)


static func clamp_play_area(p: Vector2) -> Vector2:
	return Vector2(
		clampf(p.x, PLAY_MIN.x, PLAY_MAX.x),
		clampf(p.y, PLAY_MIN.y, PLAY_MAX.y),
	)


static func clamp_domain(p: Vector2) -> Vector2:
	return Vector2(
		clampf(p.x, DOMAIN_MIN.x, DOMAIN_MAX.x),
		clampf(p.y, DOMAIN_MIN.y, DOMAIN_MAX.y),
	)


static func trim_path_tail(pts: PackedVector2Array, segment: Dictionary) -> PackedVector2Array:
	if int(segment.get("type", -1)) != FuncType.QUADRATIC:
		return pts
	if pts.size() <= QUADRATIC_TAIL_TRIM:
		return pts
	return pts.slice(0, pts.size() - QUADRATIC_TAIL_TRIM)


static func with_start(segment: Dictionary, new_start: Vector2) -> Dictionary:
	var out := segment.duplicate(true)
	var old_start: Vector2 = segment.get("start", new_start)
	var end: Vector2 = segment.get("end", Vector2.ZERO)
	var ft: int = segment.get("type", FuncType.AFFINE)
	out["start"] = clamp_domain(new_start)
	out["params"] = _params_for_endpoints(ft, new_start, end, segment.get("params", {}), old_start)
	return finalize_segment_targets(out)


static func _params_for_endpoints(
	func_type: int,
	start: Vector2,
	end: Vector2,
	prev_params: Dictionary,
	old_start: Vector2 = Vector2.ZERO,
) -> Dictionary:
	match func_type:
		FuncType.AFFINE:
			return _affine_params(start, end)
		FuncType.QUADRATIC:
			var lift: float = float(prev_params.get("mid_y_offset", 0.0))
			if absf(lift) < 8.0:
				var dx := end.x - start.x
				var dy := end.y - start.y
				lift = -dx * 0.14 if dy <= dx * 0.12 else dx * 0.14
			elif old_start != Vector2.ZERO and old_start.distance_to(start) > 4.0:
				var old_dx := end.x - old_start.x
				var new_dx := end.x - start.x
				if absf(old_dx) > MIN_SEGMENT_DX * 0.5:
					lift *= new_dx / old_dx
			return _quadratic_params_with_lift(start, end, lift)
		FuncType.EXPONENTIAL:
			return _exponential_params(start, end, float(prev_params.get("k", 2.8)))
		_:
			return _affine_params(start, end)
	return {}


static func _doorward_params(
	func_type: int,
	start: Vector2,
	end: Vector2,
	rng: RandomNumberGenerator,
) -> Dictionary:
	match func_type:
		FuncType.AFFINE:
			return _affine_params(start, end)
		FuncType.QUADRATIC:
			return _quadratic_params_with_lift(start, end, _sketch_quadratic_lift(start, end, rng))
		FuncType.EXPONENTIAL:
			return _exponential_params(start, end, rng.randf_range(EXP_K_MIN, EXP_K_MAX))
		_:
			return _affine_params(start, end)
	return {}


static func _default_params(
	func_type: int,
	start: Vector2,
	end: Vector2,
	rng: RandomNumberGenerator,
) -> Dictionary:
	var dy := end.y - start.y
	var dx := end.x - start.x
	match func_type:
		FuncType.AFFINE:
			return _affine_params(start, end)
		FuncType.QUADRATIC:
			var lift := dx * rng.randf_range(QUAD_LIFT_RATIO_MIN, QUAD_LIFT_RATIO_MAX)
			lift *= 1.0 if rng.randi() % 2 == 0 else -1.0
			return _quadratic_params_with_lift(start, end, _clamp_quadratic_lift(start, end, lift))
		FuncType.MODULAR:
			return {
				"amp": rng.randf_range(35.0, 75.0) * (1.0 if rng.randi() % 2 == 0 else -1.0),
				"freq": rng.randf_range(1.2, 3.5),
				"phase": rng.randf_range(0.0, TAU),
				"base": (start.y + end.y) * 0.5,
			}
		FuncType.EXPONENTIAL:
			return {
				"amp": rng.randf_range(40.0, 140.0) * (1.0 if dy >= 0.0 else -1.0),
				"k": rng.randf_range(1.5, 4.0),
				"base": start.y,
			}
		FuncType.LOGARITHMIC:
			return {
				"amp": rng.randf_range(60.0, 160.0) * (1.0 if dy >= 0.0 else -1.0),
				"base": start.y,
			}
	return {}


static func _point_on_curve(
	func_type: int,
	start: Vector2,
	end: Vector2,
	params: Dictionary,
	u: float,
) -> Vector2:
	var base := start.lerp(end, u)
	match func_type:
		FuncType.AFFINE:
			var a: float = params.get("a", 0.0)
			var b: float = params.get("b", 0.0)
			var x := lerpf(start.x, end.x, u)
			return Vector2(x, a * x + b)
		FuncType.QUADRATIC:
			var qa: float = params.get("a", 0.0)
			var qb: float = params.get("b", 0.0)
			var qc: float = params.get("c", 0.0)
			var xq := lerpf(start.x, end.x, u)
			return Vector2(xq, qa * xq * xq + qb * xq + qc)
		FuncType.MODULAR:
			var amp: float = params.get("amp", 60.0)
			var freq: float = params.get("freq", 2.0)
			var phase: float = params.get("phase", 0.0)
			var y_base: float = params.get("base", base.y)
			var wave := sin(freq * PI * u + phase)
			return Vector2(base.x, y_base + amp * wave * (1.0 - absf(u - 0.5) * 0.35))
		FuncType.EXPONENTIAL:
			var amp_e: float = params.get("amp", 80.0)
			var k: float = params.get("k", 2.5)
			var y0: float = params.get("base", start.y)
			var denom := exp(k) - 1.0
			if absf(denom) < 0.001:
				denom = 1.0
			var off := amp_e * (exp(k * u) - 1.0) / denom
			return Vector2(base.x, y0 + off)
		FuncType.LOGARITHMIC:
			var amp_l: float = params.get("amp", 90.0)
			var y0l: float = params.get("base", start.y)
			var t_log := u * 0.85 + 0.08
			var off_l := amp_l * log(t_log) / log(0.93)
			return Vector2(base.x, y0l + off_l)
	return base


static func _affine_params(start: Vector2, end: Vector2) -> Dictionary:
	var dx := end.x - start.x
	var slope := (end.y - start.y) / dx if absf(dx) > 1.0 else 0.0
	return {"a": slope, "b": start.y - slope * start.x}


static func segment_fits_domain(segment: Dictionary, sample_count: int = 32) -> bool:
	var margin := DOMAIN_CURVE_MARGIN
	var y_min := PLAY_MIN.y + margin
	var y_max := PLAY_MAX.y - margin
	var x_min := PLAY_MIN.x + margin
	var x_max := PLAY_MAX.x - margin
	var last := maxi(sample_count - 1, 1)
	for i in sample_count:
		var p := curve_point(segment, float(i) / float(last))
		if p.y < y_min or p.y > y_max or p.x < x_min or p.x > x_max:
			return false
	return true


static func _ensure_quadratic_curvature(start: Vector2, end: Vector2, lift: float) -> float:
	var dx := end.x - start.x
	var min_lift := absf(dx) * QUAD_MIN_LIFT_RATIO
	if absf(lift) >= min_lift:
		return lift
	var sign := 1.0 if lift > 0.0 else (-1.0 if lift < 0.0 else 0.0)
	if sign == 0.0:
		sign = -1.0 if (end.y - start.y) >= 0.0 else 1.0
	return sign * min_lift


static func _clamp_quadratic_lift(start: Vector2, end: Vector2, lift: float) -> float:
	var y_min := PLAY_MIN.y + DOMAIN_CURVE_MARGIN
	var y_max := PLAY_MAX.y - DOMAIN_CURVE_MARGIN
	var mid := start.lerp(end, 0.5)
	var dx := end.x - start.x
	var max_by_ratio := absf(dx) * QUAD_MAX_LIFT_RATIO
	var max_up := minf(y_max - mid.y, minf(y_max - start.y, y_max - end.y))
	var max_down := maxf(y_min - mid.y, maxf(y_min - start.y, y_min - end.y))
	var hi := minf(max_up, max_by_ratio)
	var lo := maxf(max_down, -max_by_ratio)
	if hi < lo:
		return clampf(lift, -max_by_ratio, max_by_ratio)
	return clampf(lift, lo, hi)


static func _quadratic_params_with_lift(start: Vector2, end: Vector2, lift: float) -> Dictionary:
	lift = _ensure_quadratic_curvature(start, end, _clamp_quadratic_lift(start, end, lift))
	var dx := end.x - start.x
	var min_a := QUAD_MIN_ABS_A
	var lift_for_a := min_a * dx * dx / 4.0
	if absf(lift) < lift_for_a:
		lift = signf(lift) * lift_for_a if lift != 0.0 else lift_for_a
		lift = _clamp_quadratic_lift(start, end, lift)
	var mid := start.lerp(end, 0.5)
	var peak := Vector2(mid.x, mid.y + lift)
	var abc := _parabola_from_three_points(start, peak, end)
	abc["mid_y_offset"] = lift
	var probe := {
		"type": FuncType.QUADRATIC,
		"start": start,
		"end": end,
		"params": abc,
	}
	if not segment_fits_domain(probe, 36):
		for _attempt in 8:
			lift *= 0.82
			peak = Vector2(mid.x, mid.y + lift)
			abc = _parabola_from_three_points(start, peak, end)
			abc["mid_y_offset"] = lift
			probe["params"] = abc
			if segment_fits_domain(probe, 36):
				break
	return abc


static func _parabola_from_three_points(p0: Vector2, pm: Vector2, p1: Vector2) -> Dictionary:
	var x0 := p0.x
	var xm := pm.x
	var x1 := p1.x
	var denom := (x0 - xm) * (x0 - x1) * (x1 - xm)
	if absf(denom) < 1e-4:
		var dx_fb := p1.x - p0.x
		var lift_fb: float = dx_fb * QUAD_MIN_LIFT_RATIO * (1.0 if p1.y >= p0.y else -1.0)
		var ctrl_fb := p0.lerp(p1, 0.5) + Vector2(0.0, lift_fb)
		var abc_fb := {"a": 0.0, "b": 0.0, "c": 0.0, "mid_y_offset": lift_fb}
		if absf(dx_fb) > 1.0:
			var fit := _parabola_from_three_points(p0, ctrl_fb, p1)
			abc_fb["a"] = fit.get("a", 0.0)
			abc_fb["b"] = fit.get("b", 0.0)
			abc_fb["c"] = fit.get("c", 0.0)
		return abc_fb
	var a := (p0.y * (xm - x1) + pm.y * (x1 - x0) + p1.y * (x0 - xm)) / denom
	var b := (
		p0.y * (x1 * x1 - xm * xm)
		+ pm.y * (x0 * x0 - x1 * x1)
		+ p1.y * (xm * xm - x0 * x0)
	) / denom
	var c := p0.y - a * x0 * x0 - b * x0
	return {"a": a, "b": b, "c": c}


static func _format_affine(slope: float, intercept: float) -> String:
	if absf(slope) < 0.0008:
		return "y = %.1f" % intercept
	return "y = %.2fx %+.1f" % [slope, intercept]


static func _format_parabola(a: float, b: float, c: float) -> String:
	if absf(a) < 0.01:
		return "y = %.4fx² %+.2fx %+.1f" % [a, b, c]
	return "y = %.3fx² %+.2fx %+.1f" % [a, b, c]


static func _format_exponential(params: Dictionary) -> String:
	var y0: float = params.get("base", 0.0)
	var amp: float = params.get("amp", 0.0)
	var k: float = params.get("k", 2.5)
	return "y = %.0f + %.0f·e^(%.1ft)" % [y0, amp, k]


static func _exponential_params(start: Vector2, end: Vector2, k: float) -> Dictionary:
	return {
		"amp": end.y - start.y,
		"k": k,
		"base": start.y,
	}


static func _sketch_quadratic_lift(start: Vector2, end: Vector2, rng: RandomNumberGenerator) -> float:
	var dx := end.x - start.x
	var dy := end.y - start.y
	var ratio := rng.randf_range(QUAD_LIFT_RATIO_MIN, QUAD_LIFT_RATIO_MAX)
	var lift := dx * ratio if dy > dx * 0.12 else -dx * ratio
	return _clamp_quadratic_lift(start, end, lift)
