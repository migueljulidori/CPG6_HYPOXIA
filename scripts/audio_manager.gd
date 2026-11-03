extends Node
## BGM + SFX. BGM loops and persists across scenes.

const BGM_PATH := "res://assets/audio/sfx/bgm_porao.wav"
const SFX_DIR := "res://assets/audio/sfx/"

## Usa GameManager.O2_ALERT_RATIO (15% do tanque).

var _bgm: AudioStreamPlayer
var _o2_alert: AudioStreamPlayer
var _game_over_player: AudioStreamPlayer
var _bgm_stream: AudioStream
var _o2_alert_on: bool = false
var _game_over_played: bool = false
var _initialized: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_bgm = _make_player(&"Music")
	_o2_alert = _make_player(&"SFX")
	_game_over_player = _make_player(&"SFX")
	_preload_bgm()
	_initialized = true
	call_deferred("ensure_bgm_playing")
	get_tree().create_timer(0.5).timeout.connect(ensure_bgm_playing)


func _setup_buses() -> void:
	_ensure_bus(&"Music")
	_ensure_bus(&"SFX")
	var music_idx := AudioServer.get_bus_index(&"Music")
	var sfx_idx := AudioServer.get_bus_index(&"SFX")
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, -6.0)
		AudioServer.set_bus_mute(music_idx, false)
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, -2.0)
		AudioServer.set_bus_mute(sfx_idx, false)


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		if bus_name != &"Master":
			AudioServer.set_bus_send(idx, &"Master")


func _make_player(bus_name: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus_name
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	return p


func _preload_bgm() -> void:
	if not ResourceLoader.exists(BGM_PATH):
		push_error("AudioManager: BGM file missing at %s" % BGM_PATH)
		return
	_bgm_stream = load(BGM_PATH)
	if _bgm_stream == null:
		push_error("AudioManager: failed to load BGM")
		return
	if _bgm_stream is AudioStreamWAV:
		var wav := (_bgm_stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_bgm_stream = wav


func _load_sfx(file_name: String, loop: bool = false) -> AudioStream:
	var path := SFX_DIR + file_name
	if not ResourceLoader.exists(path):
		push_warning("Audio missing: %s" % path)
		return null
	var stream: AudioStream = load(path)
	if stream == null:
		return null
	if loop and stream is AudioStreamWAV:
		var dup := stream.duplicate() as AudioStreamWAV
		dup.loop_mode = AudioStreamWAV.LOOP_FORWARD
		return dup
	return stream


func ensure_bgm_playing() -> void:
	if _game_over_played or _bgm == null:
		return
	if _bgm_stream == null:
		_preload_bgm()
	if _bgm_stream == null:
		return
	if _bgm.stream != _bgm_stream:
		_bgm.stream = _bgm_stream
	_bgm.volume_db = -2.0
	_bgm.bus = &"Music"
	if not _bgm.playing:
		_bgm.play()


func start_gameplay_bgm() -> void:
	ensure_bgm_playing()


func play_sfx(file_name: String, volume_db: float = 0.0) -> void:
	var stream := _load_sfx(file_name, false)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.bus = &"SFX"
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func play_sonar() -> void:
	play_sfx("sfx_sonar.wav", -2.0)


func play_dash() -> void:
	play_sfx("sfx_dash.wav", -1.0)


func play_web() -> void:
	play_sfx("sfx_teia.wav", -4.0)


func play_key() -> void:
	play_sfx("sfx_chave.wav", 0.0)


func play_door() -> void:
	play_sfx("sfx_porta.wav", -2.0)


func play_terminal_key() -> void:
	play_sfx("sfx_teclado.wav", -6.0)


func play_terminal_success() -> void:
	play_sfx("sfx_acerto.wav", 0.0)


func play_terminal_error() -> void:
	play_sfx("sfx_erro.wav", 0.0)


func play_victory() -> void:
	play_sfx("sfx_vitoria.wav", 0.0)
	if _bgm and _bgm.playing:
		_bgm.stop()


func reset_session_audio() -> void:
	_game_over_played = false
	stop_o2_alert()


func play_game_over() -> void:
	if _game_over_played:
		return
	_game_over_played = true
	stop_o2_alert()
	var stream := _load_sfx("sfx_gameover.wav", false)
	if stream == null or _game_over_player == null:
		return
	_game_over_player.stream = stream
	_game_over_player.volume_db = 0.0
	_game_over_player.play()
	if _bgm and _bgm.playing:
		_bgm.stop()


func update_o2_alert(oxygen: float) -> void:
	if not _initialized or _o2_alert == null:
		return
	if _game_over_played:
		return
	if oxygen <= 0.0:
		stop_o2_alert()
		return
	var alert_at := GameManager.get_o2_alert_threshold() if GameManager else 75.0
	if oxygen <= alert_at:
		if not _o2_alert_on:
			_start_o2_alert()
	else:
		stop_o2_alert()


func _start_o2_alert() -> void:
	if _o2_alert == null:
		return
	var stream := _load_sfx("sfx_alerta_o2.wav", true)
	if stream == null:
		return
	_o2_alert.stream = stream
	_o2_alert.volume_db = -4.0
	if not _o2_alert.playing:
		_o2_alert.play()
	_o2_alert_on = true


func stop_o2_alert() -> void:
	_o2_alert_on = false
	if _o2_alert == null:
		return
	if _o2_alert.playing:
		_o2_alert.stop()


func setup_spider_audio(player: AudioStreamPlayer2D) -> void:
	_setup_patrol_enemy_audio(player, -10.0, 1.0, "sfx_aranha.wav")


func setup_rat_audio(player: AudioStreamPlayer2D) -> void:
	var stream := _load_sfx("sfx_rato.wav", true)
	if stream == null:
		_setup_patrol_enemy_audio(player, -12.0, 1.35, "sfx_aranha.wav")
		return
	player.stream = stream
	player.bus = &"SFX"
	player.volume_db = -8.0
	player.pitch_scale = 1.0
	player.max_distance = 540.0
	player.attenuation = 1.1
	if not player.playing:
		player.play()


func _setup_patrol_enemy_audio(
		player: AudioStreamPlayer2D,
		volume_db: float,
		pitch: float,
		file_name: String = "sfx_aranha.wav",
	) -> void:
	var stream := _load_sfx(file_name, true)
	if stream == null:
		return
	player.stream = stream
	player.bus = &"SFX"
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.max_distance = 520.0
	player.attenuation = 1.15
	if not player.playing:
		player.play()
