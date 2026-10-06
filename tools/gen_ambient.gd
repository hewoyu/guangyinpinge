extends SceneTree
## 环境白噪音生成器 - headless: godot --headless --script tools/gen_ambient.gd
## 生成：ambient_rain.wav（雨声）、ambient_stream.wav（溪流）、ambient_forest.wav（森林）
## 全部 30 秒 mono 44.1kHz，首尾交叉淡化实现无缝循环

const SR := 44100
const DUR := 30.0

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/audio/"))
	var base := ProjectSettings.globalize_path("res://assets/audio/")
	_save_wav(base + "ambient_rain.wav", _gen_rain())
	_save_wav(base + "ambient_stream.wav", _gen_stream())
	_save_wav(base + "ambient_forest.wav", _gen_forest())
	print("AMBIENT GENERATED OK")
	quit()

func _save_wav(path: String, samples: PackedFloat32Array) -> void:
	var bytes := PackedByteArray()
	var n := samples.size()
	var data_size := n * 2
	var riff_size := 36 + data_size
	bytes.append(0x52); bytes.append(0x49); bytes.append(0x46); bytes.append(0x46)
	bytes.append(riff_size & 0xFF); bytes.append((riff_size >> 8) & 0xFF); bytes.append((riff_size >> 16) & 0xFF); bytes.append((riff_size >> 24) & 0xFF)
	bytes.append(0x57); bytes.append(0x41); bytes.append(0x56); bytes.append(0x45)
	bytes.append(0x66); bytes.append(0x6D); bytes.append(0x74); bytes.append(0x20)
	bytes.append(16); bytes.append(0); bytes.append(0); bytes.append(0)
	bytes.append(1); bytes.append(0)
	bytes.append(1); bytes.append(0)
	bytes.append(SR & 0xFF); bytes.append((SR >> 8) & 0xFF); bytes.append((SR >> 16) & 0xFF); bytes.append((SR >> 24) & 0xFF)
	var br := SR * 2
	bytes.append(br & 0xFF); bytes.append((br >> 8) & 0xFF); bytes.append((br >> 16) & 0xFF); bytes.append((br >> 24) & 0xFF)
	bytes.append(2); bytes.append(0)
	bytes.append(16); bytes.append(0)
	bytes.append(0x64); bytes.append(0x61); bytes.append(0x74); bytes.append(0x61)
	bytes.append(data_size & 0xFF); bytes.append((data_size >> 8) & 0xFF); bytes.append((data_size >> 16) & 0xFF); bytes.append((data_size >> 24) & 0xFF)
	for i in n:
		var v := int(clamp(samples[i], -1.0, 1.0) * 32000.0)
		bytes.append(v & 0xFF); bytes.append((v >> 8) & 0xFF)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
	print("saved: ", path, " (", n, " samples)")

func _pink_gen() -> Array:
	## Pink noise Voss-McCartney 状态
	return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

func _pink_next(state: Array) -> float:
	state[6] = 0.979 * state[6] + randf() * 0.02
	state[5] = 0.976 * state[5] + randf() * 0.04
	state[4] = 0.973 * state[4] + randf() * 0.06
	state[3] = 0.97 * state[3] + randf() * 0.08
	state[2] = 0.965 * state[2] + randf() * 0.1
	state[1] = 0.96 * state[1] + randf() * 0.12
	state[0] = 0.95 * state[0] + randf() * 0.14
	var white := randf() * 0.5
	return (state[0] + state[1] + state[2] + state[3] + state[4] + state[5] + state[6] + white) * 0.11

func _gen_rain() -> PackedFloat32Array:
	## 雨声：粉噪声底 + 随机雨点脉冲（高频短衰减）
	var n := int(DUR * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var state := _pink_gen()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# 雨点事件：每秒约 25 个，随机时刻与强度
	var drops: Array[Dictionary] = []
	var total_drops := int(DUR * 25.0)
	for i in total_drops:
		drops.append({
			"t": rng.randf() * DUR,
			"amp": rng.randf_range(0.08, 0.3),
			"freq": rng.randf_range(1800.0, 3800.0),
			"decay": rng.randf_range(80.0, 160.0),
		})
	drops.sort_custom(func(a, b): return a.t < b.t)
	var di := 0
	for i in n:
		var t := float(i) / SR
		var s := _pink_next(state) * 0.5
		# 叠加当前时刻附近所有雨点
		while di < drops.size() and drops[di].t <= t:
			di += 1
		var j := di - 1
		var scan := 0
		while j >= 0 and scan < 60:
			var d: Dictionary = drops[j]
			var dt: float = t - float(d.t)
			if dt >= 0.0 and dt < 0.06:
				var p: float = sin(TAU * d.freq * dt) * d.amp * exp(-dt * d.decay)
				s += p
			j -= 1
			scan += 1
		out[i] = s * 0.8
	return _xfade(out)

func _gen_stream() -> PackedFloat32Array:
	## 溪流：多频带噪声 sin 调幅（模拟水流波动）
	var n := int(DUR * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var state := _pink_gen()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# 6 条"水波"：不同速率调制不同幅度
	var waves: Array[Dictionary] = []
	for k in 6:
		waves.append({
			"rate": rng.randf_range(0.3, 1.4),
			"phase": rng.randf() * TAU,
			"depth": rng.randf_range(0.3, 0.7),
			"lowpass": rng.randf_range(0.5, 1.0),
		})
	for i in n:
		var t := float(i) / SR
		var pink := _pink_next(state)
		var s := 0.0
		for w in waves:
			var mod_: float = 0.5 + 0.5 * sin(TAU * w.rate * t + w.phase)
			var band: float = pink * (1.0 - w.lowpass * 0.5)
			s += band * mod_ * w.depth
		out[i] = s * 0.42
	return _xfade(out)

func _gen_forest() -> PackedFloat32Array:
	## 森林：低频噪声底（风）+ 偶发鸟鸣（FM 正弦短句）
	var n := int(DUR * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var state := _pink_gen()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	# 鸟鸣：约 12 声，每声 2-5 个音符
	var birds: Array[Dictionary] = []
	var t_cursor := 1.0
	while t_cursor < DUR - 3.0:
		var notes: Array[Dictionary] = []
		var note_t := 0.0
		var note_count := rng.randi_range(2, 5)
		for k in note_count:
			notes.append({
				"t": note_t,
				"f0": rng.randf_range(2200.0, 4200.0),
				"f1": rng.randf_range(1800.0, 4800.0),
				"dur": rng.randf_range(0.06, 0.16),
			})
			note_t += rng.randf_range(0.08, 0.2)
		birds.append({ "t": t_cursor, "notes": notes })
		t_cursor += rng.randf_range(1.5, 4.5)
	for i in n:
		var t := float(i) / SR
		# 风底：慢速调幅的深粉噪声
		var wind_mod: float = 0.5 + 0.5 * sin(TAU * 0.11 * t) * sin(TAU * 0.047 * t + 1.3)
		var s := _pink_next(state) * 0.55 * wind_mod
		# 鸟鸣
		for b in birds:
			var bt: float = t - b.t
			if bt >= 0.0 and bt < 1.2:
				for note in b.notes:
					var nt: float = bt - note.t
					if nt >= 0.0 and nt < note.dur:
						var env: float = sin(PI * nt / note.dur)
						var f: float = lerp(note.f0, note.f1, nt / note.dur)
						s += sin(TAU * f * nt) * 0.22 * env
		out[i] = s * 0.8
	return _xfade(out)

func _xfade(samples: PackedFloat32Array) -> PackedFloat32Array:
	## 首尾 1 秒交叉淡化（无缝循环）
	var n := samples.size()
	var xf := SR  # 1 秒
	var out := samples.duplicate()
	for i in xf:
		var fade := float(i) / xf
		out[i] = out[i] * fade + out[n - xf + i] * (1.0 - fade)
	out.resize(n - xf)
	return out
