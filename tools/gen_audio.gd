extends SceneTree
# 程序化音效生成器 - headless 运行: godot --headless --script tools/gen_audio.gd
# 生成《拾光拼图》全部音效与背景音乐（WAV 格式）

const SAMPLE_RATE := 44100

func _init() -> void:
	var dir := "res://assets/audio/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var out_path := ProjectSettings.globalize_path(dir)
	
	# --- 1. 拼图归位"咔哒"声（短促、木质感）---
	_save_wav(out_path + "snap.wav", _gen_snap())
	# --- 2. 拾取碎片（轻扫声）---
	_save_wav(out_path + "pickup.wav", _gen_pickup())
	# --- 3. 错误放置（低沉噗声）---
	_save_wav(out_path + "wrong.wav", _gen_wrong())
	# --- 4. 关卡完成（上行琶音 C-E-G-C）---
	_save_wav(out_path + "win.wav", _gen_win())
	# --- 5. 按钮点击 ---
	_save_wav(out_path + "click.wav", _gen_click())
	# --- 6. 提示使用（闪亮铃声）---
	_save_wav(out_path + "hint.wav", _gen_hint())
	# --- 7. 星星弹出（3连音）---
	_save_wav(out_path + "star.wav", _gen_star())
	# --- 8. 背景音乐（温暖循环琶音 ~24s）---
	_save_wav(out_path + "bgm.wav", _gen_bgm())
	
	print("AUDIO GENERATED OK")
	quit()

func _save_wav(path: String, samples: PackedFloat32Array) -> void:
	var bytes := PackedByteArray()
	var n := samples.size()
	# WAV header
	bytes.append(0x52); bytes.append(0x49); bytes.append(0x46); bytes.append(0x46)  # RIFF
	var data_size := n * 2
	var riff_size := 36 + data_size
	bytes.append(riff_size & 0xFF); bytes.append((riff_size >> 8) & 0xFF); bytes.append((riff_size >> 16) & 0xFF); bytes.append((riff_size >> 24) & 0xFF)
	bytes.append(0x57); bytes.append(0x41); bytes.append(0x56); bytes.append(0x45)  # WAVE
	bytes.append(0x66); bytes.append(0x6D); bytes.append(0x74); bytes.append(0x20)  # fmt
	bytes.append(16); bytes.append(0); bytes.append(0); bytes.append(0)             # chunk size
	bytes.append(1); bytes.append(0)                                                # PCM
	bytes.append(1); bytes.append(0)                                                # mono
	var sr := SAMPLE_RATE
	bytes.append(sr & 0xFF); bytes.append((sr >> 8) & 0xFF); bytes.append((sr >> 16) & 0xFF); bytes.append((sr >> 24) & 0xFF)
	var byte_rate := sr * 2
	bytes.append(byte_rate & 0xFF); bytes.append((byte_rate >> 8) & 0xFF); bytes.append((byte_rate >> 16) & 0xFF); bytes.append((byte_rate >> 24) & 0xFF)
	bytes.append(2); bytes.append(0)                                                # block align
	bytes.append(16); bytes.append(0)                                               # bits
	bytes.append(0x64); bytes.append(0x61); bytes.append(0x74); bytes.append(0x61)  # data
	bytes.append(data_size & 0xFF); bytes.append((data_size >> 8) & 0xFF); bytes.append((data_size >> 16) & 0xFF); bytes.append((data_size >> 24) & 0xFF)
	for i in n:
		var v := int(clamp(samples[i], -1.0, 1.0) * 32767.0)
		bytes.append(v & 0xFF); bytes.append((v >> 8) & 0xFF)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
	print("saved: ", path, " (", n, " samples, ", data_size, " bytes)")

func _env(i: int, total: int, attack: float, decay_to: float) -> float:
	# 简单 AD 包络
	var t := float(i) / float(total)
	if t < attack:
		return t / attack
	return 1.0 - (1.0 - decay_to) * ((t - attack) / (1.0 - attack))

func _gen_snap() -> PackedFloat32Array:
	# 咔哒：正弦快速下滑 + 噪声瞬态
	var n := int(0.08 * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var freq := 1800.0 * exp(-t * 30.0) + 300.0
		phase += TAU * freq / SAMPLE_RATE
		var noise := (randf() * 2.0 - 1.0) * 0.3 * exp(-t * 80.0)
		var s := sin(phase) * 0.7 + noise
		out[i] = s * _env(i, n, 0.002, 0.0)
	return out

func _gen_pickup() -> PackedFloat32Array:
	var n := int(0.12 * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var freq := 500.0 + 400.0 * t / 0.12
		phase += TAU * freq / SAMPLE_RATE
		out[i] = sin(phase) * 0.35 * _env(i, n, 0.01, 0.0)
	return out

func _gen_wrong() -> PackedFloat32Array:
	var n := int(0.2 * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var freq := 180.0 - 60.0 * t / 0.2
		phase += TAU * freq / SAMPLE_RATE
		out[i] = sin(phase) * 0.5 * _env(i, n, 0.005, 0.0)
	return out

func _gen_click() -> PackedFloat32Array:
	var n := int(0.06 * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var freq := 900.0 * exp(-t * 25.0) + 200.0
		phase += TAU * freq / SAMPLE_RATE
		out[i] = sin(phase) * 0.5 * _env(i, n, 0.001, 0.0)
	return out

func _gen_win() -> PackedFloat32Array:
	# C5-E5-G5-C6 琶音
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var note_len := 0.18
	var n := int((note_len * 4 + 0.5) * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var idx := int(t / note_len)
		if idx >= 4: idx = 3
		var nt := t - idx * note_len
		var freq: float = notes[idx]
		var s := sin(TAU * freq * t) * 0.4 * exp(-nt * 3.0)
		s += sin(TAU * freq * 2.0 * t) * 0.15 * exp(-nt * 4.0)
		out[i] = s
	# 尾音渐出
	for i in range(n - int(0.4 * SAMPLE_RATE), n):
		out[i] *= 1.0 - float(i - (n - int(0.4 * SAMPLE_RATE))) / (0.4 * SAMPLE_RATE)
	return out

func _gen_hint() -> PackedFloat32Array:
	# 闪亮铃声：高频正弦 + 泛音
	var n := int(0.5 * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var s := sin(TAU * 1318.5 * t) * 0.3 * exp(-t * 5.0)
		s += sin(TAU * 1760.0 * t) * 0.2 * exp(-t * 6.0)
		s += sin(TAU * 2637.0 * t) * 0.1 * exp(-t * 8.0)
		out[i] = s
	return out

func _gen_star() -> PackedFloat32Array:
	# 三连上行短音
	var notes := [784.0, 988.0, 1319.0]
	var n := int(0.45 * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var idx := int(t / 0.12)
		if idx >= 3: idx = 2
		var nt := t - idx * 0.12
		var freq: float = notes[idx]
		out[i] = sin(TAU * freq * t) * 0.35 * exp(-nt * 8.0)
	return out

func _gen_bgm() -> PackedFloat32Array:
	# 温暖琶音循环：C大调分解和弦进行 C-G-Am-F，24秒
	var chords := [
		[261.63, 329.63, 392.0, 523.25],   # C
		[196.0, 246.94, 392.0, 493.88],    # G
		[220.0, 261.63, 329.63, 440.0],    # Am
		[174.61, 220.0, 261.63, 349.23],   # F
	]
	var chord_len := 1.5
	var total := chord_len * 4 * 4  # 4轮 = 24s
	var n := int(total * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var chord_idx := int(t / chord_len) % 4
		var round_idx := int(t / (chord_len * 4))
		var chord: Array = chords[chord_idx]
		var s := 0.0
		# 琶音：每0.1875s触发一个音（chord_len/8）
		var arp_step := chord_len / 8.0
		var step_in_chord := fmod(t, chord_len)
		var note_idx := int(step_in_chord / arp_step)
		# 音符模式：0,1,2,3,2,1,0,1
		var pattern := [0, 1, 2, 3, 2, 1, 0, 1]
		var pn: int = pattern[note_idx]
		var freq: float = chord[pn]
		var note_t := fmod(step_in_chord, arp_step)
		s += sin(TAU * freq * t) * 0.18 * exp(-note_t * 6.0)
		# 低音铺底（每和弦一个低八度音）
		var bass: float = chord[0] / 2.0
		s += sin(TAU * bass * t) * 0.10 * (0.6 + 0.4 * sin(TAU * 0.5 * t))
		# 轻微立体声感（单声道模拟：加相位差的第二层）
		s += sin(TAU * freq * t + 0.5) * 0.06 * exp(-note_t * 6.0)
		out[i] = s * 0.8
	# 首尾交叉淡化以无缝循环
	var xf := int(1.0 * SAMPLE_RATE)
	for i in xf:
		var fade := float(i) / xf
		out[i] = out[i] * fade + out[n - xf + i] * (1.0 - fade)
	out.resize(n - xf)
	return out
