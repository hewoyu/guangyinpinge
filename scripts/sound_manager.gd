extends Node
## 音效管理器（autoload: SoundManager）
## 预加载音效池，零延迟播放；负责 BGM 循环与静音控制。
## 契约：res://assets/audio/{snap,pickup,wrong,win,click,hint,star,bgm}.wav

const SFX := {
	"snap": "res://assets/audio/snap.wav",
	"pickup": "res://assets/audio/pickup.wav",
	"wrong": "res://assets/audio/wrong.wav",
	"win": "res://assets/audio/win.wav",
	"click": "res://assets/audio/click.wav",
	"hint": "res://assets/audio/hint.wav",
	"star": "res://assets/audio/star.wav",
}
const BGM_PATH := "res://assets/audio/bgm.wav"

const AMBIENT := {
	"rain": "res://assets/audio/ambient_rain.wav",
	"stream": "res://assets/audio/ambient_stream.wav",
	"forest": "res://assets/audio/ambient_forest.wav",
}

var _sfx_players: Array[AudioStreamPlayer] = []
var _bgm_player: AudioStreamPlayer = null
var _ambient_player: AudioStreamPlayer = null
var _streams: Dictionary = {}
var muted := false
var current_ambient := "off"

func _ready() -> void:
	randomize()
	for key in SFX:
		_streams[key] = load(SFX[key])
	_setup_bgm()
	_setup_ambient()
	if not _bgm_player.playing:
		_bgm_player.play()

func _setup_ambient() -> void:
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.volume_db = -6.0
	add_child(_ambient_player)

## 白噪音：name ∈ {"rain","stream","forest","off"}
func set_ambient(name: String) -> void:
	if name == "off":
		current_ambient = "off"
		if _ambient_player.playing:
			_ambient_player.stop()
		return
	if not AMBIENT.has(name):
		push_warning("SoundManager: unknown ambient '%s'" % name)
		return
	if not _streams.has("ambient_" + name):
		var wav := load(AMBIENT[name]) as AudioStreamWAV
		if wav:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			var bpf := 4 if wav.stereo else 2
			wav.loop_end = wav.data.size() / bpf
		_streams["ambient_" + name] = wav
	_ambient_player.stream = _streams["ambient_" + name]
	if muted:
		return
	_ambient_player.play()
	current_ambient = name

func _setup_bgm() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.stream = load(BGM_PATH)
	_bgm_player.volume_db = -14.0
	# WAV 循环需要开 Loop Mode（24s 无缝循环由 Lead 已烘焙进文件）
	var wav := _bgm_player.stream as AudioStreamWAV
	if wav:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		# loop_end 单位是"帧"：字节数 / 每帧字节数（16bit 单声道=2，双声道=4）
		var bytes_per_frame := 4 if wav.stereo else 2
		wav.loop_end = wav.data.size() / bytes_per_frame
	add_child(_bgm_player)

func play(key: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if muted or not _streams.has(key):
		return
	var player := _get_free_player()
	player.stream = _streams[key]
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()

func set_bgm_enabled(enabled: bool) -> void:
	if _bgm_player == null:
		return
	if enabled and not _bgm_player.playing:
		_bgm_player.play()
	elif not enabled and _bgm_player.playing:
		_bgm_player.stop()

func set_muted(value: bool) -> void:
	muted = value
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), value)

func _get_free_player() -> AudioStreamPlayer:
	for p in _sfx_players:
		if not p.playing:
			return p
	var p := AudioStreamPlayer.new()
	_sfx_players.append(p)
	add_child(p)
	return p

## ---- v5-27 音量 API（0.0~1.0 线性 → db）----

func _lin_to_db(v: float) -> float:
	return linear_to_db(clampf(v, 0.0001, 1.0))

func set_bgm_volume(v: float) -> void:
	if _bgm_player:
		_bgm_player.volume_db = _lin_to_db(v)

func set_ambient_volume(v: float) -> void:
	if _ambient_player:
		_ambient_player.volume_db = _lin_to_db(v)

func set_sfx_volume(v: float) -> void:
	for p in _sfx_players:
		p.volume_db = _lin_to_db(v)
