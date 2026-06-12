extends Node
## 虚空矢量 - 音频管理器 (Autoload)
## 管理 BGM、SFX、音量控制，支持程序化占位音效

# ==================== 音量设置 ====================
var master_volume: float = 1.0: set = _set_master_volume
var bgm_volume: float = 0.8: set = _set_bgm_volume
var sfx_volume: float = 1.0: set = _set_sfx_volume
var bgm_muted: bool = false
var sfx_muted: bool = false

# ==================== 内部节点 ====================
var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_pool_size: int = 8
var _sfx_index: int = 0

# ==================== 程序化音频生成器 ====================
var _sfx_gen: AudioStreamGenerator

# ==================== 音频总线索引 ====================
const BGM_BUS: String = "BGM"
const SFX_BUS: String = "SFX"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_buses()
	_setup_bgm_player()
	_setup_sfx_pool()
	_load_volume_settings()

# ==================== 音频总线设置 ====================

func _setup_audio_buses() -> void:
	# 确保 BGM 和 SFX 总线存在
	var bus_count = AudioServer.bus_count
	for i in range(bus_count):
		var bus_name = AudioServer.get_bus_name(i)
		if bus_name == BGM_BUS or bus_name == SFX_BUS:
			continue

	# 如果没找到 BGM 总线，创建它
	if AudioServer.get_bus_index(BGM_BUS) == -1:
		var bgm_idx = AudioServer.bus_count
		AudioServer.add_bus(bgm_idx)
		AudioServer.set_bus_name(bgm_idx, BGM_BUS)

	# 如果没找到 SFX 总线，创建它
	if AudioServer.get_bus_index(SFX_BUS) == -1:
		var sfx_idx = AudioServer.bus_count
		AudioServer.add_bus(sfx_idx)
		AudioServer.set_bus_name(sfx_idx, SFX_BUS)

# ==================== BGM 播放器 ====================

func _setup_bgm_player() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = BGM_BUS
	add_child(_bgm_player)

func play_bgm(stream: AudioStream = null, fade_in: float = 1.0) -> void:
	## 播放 / 切换 BGM，支持淡入效果
	if stream == null:
		return
	if _bgm_player.playing and _bgm_player.stream == stream:
		return

	_bgm_player.stream = stream
	_bgm_player.play()

	if fade_in > 0:
		_bgm_player.volume_db = linear_to_db(0.01)
		var tween: Tween = create_tween()
		tween.tween_property(_bgm_player, "volume_db", linear_to_db(bgm_volume), fade_in)

func stop_bgm(fade_out: float = 0.5) -> void:
	## 停止 BGM，支持淡出
	if fade_out > 0:
		var tween: Tween = create_tween()
		var target_db = linear_to_db(0.01)
		tween.tween_property(_bgm_player, "volume_db", target_db, fade_out)
		tween.tween_callback(_bgm_player.stop)
	else:
		_bgm_player.stop()

# ==================== SFX 音效池 ====================

func _setup_sfx_pool() -> void:
	for i in range(_sfx_pool_size):
		var player = AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		player.bus = SFX_BUS
		add_child(player)
		_sfx_players.append(player)

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	## 播放音效（自动轮询音效池）
	if sfx_muted or stream == null:
		return

	var player = _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool_size

	if player.playing:
		player.stop()

	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale + randf_range(-0.05, 0.05)  # 微调音高避免重复感
	player.play()

# ==================== 程序化音效生成（占位音频） ====================

func generate_sfx_tone(frequency: float, duration: float, wave_type: int = 0) -> AudioStream:
	## 生成简单的程序化音效（用于占位）
	var mix_rate: int = 44100
	var sample_count: int = int(mix_rate * duration)

	# 使用 AudioStreamWAV 直接存储 PCM 数据
	var stream = AudioStreamWAV.new()
	stream.mix_rate = mix_rate
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.stereo = false

	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count)

	var phase: float = 0.0

	for i in range(sample_count):
		var t = float(i) / sample_count
		# 简单的 ADSR 包络
		var envelope: float
		if t < 0.05:
			envelope = t / 0.05  # Attack
		elif t > 0.7:
			envelope = 1.0 - (t - 0.7) / 0.3  # Release
		else:
			envelope = 1.0  # Sustain

		var sample: float
		match wave_type:
			0:  # Sine
				sample = sin(phase * TAU)
			1:  # Square
				sample = 1.0 if sin(phase * TAU) > 0 else -1.0
			2:  # Saw
				sample = 2.0 * (phase - floor(phase + 0.5))
			_:  # Triangle
				sample = 4.0 * abs(phase - floor(phase + 0.5)) - 1.0

		sample *= envelope * 0.3
		data[i] = int((sample * 0.5 + 0.5) * 255.0)  # 映射到 8-bit [0, 255]

		phase += frequency / float(mix_rate)
		if phase >= 1.0:
			phase -= 1.0

	stream.data = data
	return stream

# ==================== 预定义音效快捷方式 ====================

var _cached_sfx: Dictionary = {}

func _get_or_create_sfx(key: String, freq: float, dur: float, wave: int = 0) -> AudioStream:
	if not _cached_sfx.has(key):
		_cached_sfx[key] = generate_sfx_tone(freq, dur, wave)
	return _cached_sfx[key]

func play_shoot() -> void:
	play_sfx(_get_or_create_sfx("shoot", 800, 0.08, 0), -6.0)

func play_hit() -> void:
	play_sfx(_get_or_create_sfx("hit", 200, 0.1, 1), -3.0)

func play_kill() -> void:
	play_sfx(_get_or_create_sfx("kill", 600, 0.15, 2), -3.0, 0.8)

func play_level_up() -> void:
	play_sfx(_get_or_create_sfx("levelup", 1200, 0.3, 0), -3.0, 1.5)

func play_pickup() -> void:
	play_sfx(_get_or_create_sfx("pickup", 1000, 0.12, 0), -6.0, 1.2)

func play_explosion() -> void:
	play_sfx(_get_or_create_sfx("explosion", 80, 0.4, 1), -3.0, 0.6)

func play_boss_warning() -> void:
	play_sfx(_get_or_create_sfx("boss_warn", 300, 0.5, 2), -3.0, 0.5)

# ==================== 音量控制 ====================

func _set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))
	_save_volume_settings()

func _set_bgm_volume(value: float) -> void:
	bgm_volume = clampf(value, 0.0, 1.0)
	var idx = AudioServer.get_bus_index(BGM_BUS)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(bgm_volume))
	_save_volume_settings()

func _set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	var idx = AudioServer.get_bus_index(SFX_BUS)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(sfx_volume))
	_save_volume_settings()

func toggle_bgm_mute() -> void:
	bgm_muted = not bgm_muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index(BGM_BUS), bgm_muted)
	_save_volume_settings()

func toggle_sfx_mute() -> void:
	sfx_muted = not sfx_muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index(SFX_BUS), sfx_muted)
	_save_volume_settings()

# ==================== 公共音量接口 ====================

func set_bgm_volume(value: float) -> void:
	bgm_volume = value
	if _bgm_player:
		_bgm_player.volume_db = linear_to_db(value)
	_save_volume_settings()

func set_sfx_volume(value: float) -> void:
	sfx_volume = value
	_save_volume_settings()

# ==================== 音量设置持久化 ====================

func _save_volume_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "bgm_volume", bgm_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "bgm_muted", bgm_muted)
	config.set_value("audio", "sfx_muted", sfx_muted)
	config.save("user://audio_settings.cfg")

func _load_volume_settings() -> void:
	var config = ConfigFile.new()
	if config.load("user://audio_settings.cfg") != OK:
		return
	master_volume = config.get_value("audio", "master_volume", 1.0)
	bgm_volume = config.get_value("audio", "bgm_volume", 0.8)
	sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
	bgm_muted = config.get_value("audio", "bgm_muted", false)
	sfx_muted = config.get_value("audio", "sfx_muted", false)
	# 应用加载的设置
	_set_master_volume(master_volume)
	_set_bgm_volume(bgm_volume)
	_set_sfx_volume(sfx_volume)
	if bgm_muted:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(BGM_BUS), true)
	if sfx_muted:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(SFX_BUS), true)
