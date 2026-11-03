extends Node

signal oxygen_changed(value: float)
signal lives_changed(value: int)
signal heart_lost(slot_index: int)
signal game_over
signal salas_progress_changed(cleared: int, total: int)

const MAX_O2 := 500.0
const MAX_LIVES := 3
## Segundos para esvaziar o O2 do cheio ao zero.
const O2_DURATION_SEC := 150.0
const DRAIN_PER_SEC := MAX_O2 / O2_DURATION_SEC
const DASH_O2_COST := 4.0
## Alerta de O2 quando restam 15% ou menos do tanque.
const O2_ALERT_RATIO := 0.15
const SALA1_SCENE := "res://scenes/sala1.tscn"
const SALA2_SCENE := "res://scenes/sala2.tscn"
const SALA3_SCENE := "res://scenes/sala3.tscn"
const SALAS_REQUIRED := 3
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"
const VICTORY_SCENE := "res://scenes/victory_cutscene.tscn"
const HUB_LIFE_QUESTION_TIME_BONUS_SEC := 15.0

enum GameOverCause { NONE, OXYGEN, LIVES }

var oxygen: float = MAX_O2
var game_over_cause: GameOverCause = GameOverCause.NONE
var lives: int = MAX_LIVES
var is_game_over: bool = false
var _sala_cleared: Dictionary = {
	"sala1": false,
	"sala2": false,
	"sala3": false,
}
var _pending_spawn_id: String = ""
var run_active: bool = false
var run_started_at_msec: int = 0
var last_escape_time_sec: float = 0.0
var escape_completed: bool = false
var hub_life_question_solved: bool = false
var hub_life_question_failed: bool = false
var run_time_bonus_sec: float = 0.0
var hub_gameplay_frozen: bool = false


func _ready() -> void:
	_emit_all_stats()


func start_new_run() -> void:
	is_game_over = false
	game_over_cause = GameOverCause.NONE
	escape_completed = false
	hub_life_question_solved = false
	hub_life_question_failed = false
	run_time_bonus_sec = 0.0
	hub_gameplay_frozen = false
	oxygen = MAX_O2
	lives = MAX_LIVES
	_pending_spawn_id = ""
	last_escape_time_sec = 0.0
	run_started_at_msec = Time.get_ticks_msec()
	_reset_sala_flags()
	run_active = true
	_emit_all_stats()
	call_deferred("_sync_o2_audio")
	if AudioManager and AudioManager.has_method("reset_session_audio"):
		AudioManager.reset_session_audio()


func set_run_active(active: bool) -> void:
	run_active = active
	if not active and AudioManager:
		AudioManager.stop_o2_alert()


func get_o2_alert_threshold() -> float:
	return MAX_O2 * O2_ALERT_RATIO


func _emit_all_stats() -> void:
	oxygen_changed.emit(oxygen)
	lives_changed.emit(lives)
	salas_progress_changed.emit(salas_cleared_count(), SALAS_REQUIRED)


func _sync_o2_audio() -> void:
	if AudioManager:
		AudioManager.update_o2_alert(oxygen)


func _process(delta: float) -> void:
	if not run_active or is_game_over:
		return
	drain_o2(DRAIN_PER_SEC * delta)


func drain_o2(amount: float) -> void:
	if not run_active or amount <= 0.0 or is_game_over:
		return
	oxygen = maxf(0.0, oxygen - amount)
	oxygen_changed.emit(oxygen)
	if AudioManager:
		AudioManager.update_o2_alert(oxygen)
	if oxygen <= 0.0:
		_on_oxygen_empty()


func _on_oxygen_empty() -> void:
	if is_game_over:
		return
	_trigger_game_over(GameOverCause.OXYGEN)


func get_run_elapsed_seconds() -> float:
	if run_started_at_msec <= 0:
		return 0.0
	return maxf(0.0, float(Time.get_ticks_msec() - run_started_at_msec) / 1000.0)


func get_final_escape_time_sec() -> float:
	return maxf(0.0, get_run_elapsed_seconds() - run_time_bonus_sec)


func set_hub_gameplay_frozen(frozen: bool) -> void:
	hub_gameplay_frozen = frozen


func is_hub_gameplay_frozen() -> bool:
	return hub_gameplay_frozen


func can_attempt_hub_life_question() -> bool:
	return not hub_life_question_solved and not hub_life_question_failed


func mark_hub_life_question_failed() -> void:
	if hub_life_question_solved or hub_life_question_failed:
		return
	hub_life_question_failed = true


func try_solve_hub_life_question() -> bool:
	if hub_life_question_solved or hub_life_question_failed:
		return false
	hub_life_question_solved = true
	run_time_bonus_sec = HUB_LIFE_QUESTION_TIME_BONUS_SEC
	return true


func complete_escape() -> void:
	if escape_completed or is_game_over:
		return
	if not are_all_salas_cleared():
		return
	escape_completed = true
	run_active = false
	last_escape_time_sec = get_final_escape_time_sec()
	call_deferred("_load_victory_scene")


func _load_victory_scene() -> void:
	if not ResourceLoader.exists(VICTORY_SCENE):
		push_error("GameManager: cena de vitoria ausente: %s" % VICTORY_SCENE)
		return
	var tree := get_tree()
	if tree == null:
		return
	tree.change_scene_to_file(VICTORY_SCENE)


func _trigger_game_over(cause: GameOverCause = GameOverCause.OXYGEN) -> void:
	if is_game_over:
		return
	is_game_over = true
	game_over_cause = cause
	run_active = false
	hub_gameplay_frozen = false
	if MathTerminalUI and MathTerminalUI.visible:
		MathTerminalUI.force_close()
	if AudioManager:
		AudioManager.play_game_over()
	game_over.emit()
	call_deferred("_load_game_over_scene")


func _load_game_over_scene() -> void:
	if not ResourceLoader.exists(GAME_OVER_SCENE):
		push_error("GameManager: cena game over ausente: %s" % GAME_OVER_SCENE)
		return
	var tree := get_tree()
	if tree == null:
		return
	tree.change_scene_to_file(GAME_OVER_SCENE)


func spend_dash_o2() -> void:
	drain_o2(DASH_O2_COST)


func lose_life_from_enemy() -> bool:
	if not run_active or is_game_over or lives <= 0:
		return false
	var lost_slot := lives - 1
	lives -= 1
	heart_lost.emit(lost_slot)
	lives_changed.emit(lives)
	if lives <= 0:
		_trigger_game_over(GameOverCause.LIVES)
	return true


func queue_spawn(spawn_id: String) -> void:
	_pending_spawn_id = spawn_id


func consume_spawn_id() -> String:
	var id := _pending_spawn_id
	_pending_spawn_id = ""
	return id


func _reset_sala_flags() -> void:
	for k in _sala_cleared.keys():
		_sala_cleared[k] = false


func is_sala_cleared(sala_id: String) -> bool:
	return _sala_cleared.get(sala_id, false)


func can_enter_sala(sala_id: String) -> bool:
	return sala_id != "" and not is_sala_cleared(sala_id)


func sala_id_for_scene(scene_path: String) -> String:
	match scene_path:
		SALA1_SCENE:
			return "sala1"
		SALA2_SCENE:
			return "sala2"
		SALA3_SCENE:
			return "sala3"
		_:
			return ""


func mark_sala_cleared(sala_id: String) -> void:
	if not _sala_cleared.has(sala_id):
		return
	if _sala_cleared[sala_id]:
		return
	_sala_cleared[sala_id] = true
	salas_progress_changed.emit(salas_cleared_count(), SALAS_REQUIRED)
	if are_all_salas_cleared():
		_on_all_salas_cleared()


func salas_cleared_count() -> int:
	var n := 0
	for cleared in _sala_cleared.values():
		if cleared:
			n += 1
	return n


func are_all_salas_cleared() -> bool:
	return salas_cleared_count() >= SALAS_REQUIRED


func _on_all_salas_cleared() -> void:
	if AudioManager:
		AudioManager.play_door()
