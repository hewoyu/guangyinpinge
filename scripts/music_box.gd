extends Control
## 音乐盒（real_08 复刻）：标签页(音乐盒/白噪音/设置) + 木框曲目表 + 底部四圆钮
## 曲目 = 我们的程序化音频（bgm 变奏 pitch + 白噪音三轨）

const TRACKS := [
	{ "name": "微光落纸",       "dur": "03:52" },
	{ "name": "夜色慢慢舒展",   "dur": "04:58" },
	{ "name": "静",             "dur": "04:40" },
	{ "name": "木纹里的静流",   "dur": "04:59" },
	{ "name": "炉影余温",       "dur": "04:29" },
	{ "name": "晨光",           "dur": "04:17" },
	{ "name": "微澜的湖",       "dur": "04:43" },
]

const AMBIENTS := [
	{ "name": "雨声（檐下细雨）", "key": "rain" },
	{ "name": "溪流（山涧慢淌）", "key": "stream" },
	{ "name": "森林（晨光鸟语）", "key": "forest" },
	{ "name": "关闭白噪音",      "key": "off" },
]

@onready var back_button: Button = $BackButton
@onready var tabs: HBoxContainer = $Tabs
@onready var track_list: VBoxContainer = $WoodFrame/PaperInner/TrackList
@onready var controls: HBoxContainer = $Controls

var _tab := "music"     ## music / noise
var _current := 0       ## 当前曲目/当前白噪
var _playing := false

func _ready() -> void:
	back_button.flat = true
	back_button.add_theme_color_override("font_color", GameTheme.V_TEXT_MID)
	back_button.pressed.connect(func(): _goto("res://scenes/bookroom.tscn"))
	_build_tabs()
	_rebuild()
	## 木框样式
	$WoodFrame.add_theme_stylebox_override("panel", GameTheme.v4_wood_frame(14))
	var inner := GameTheme.flat_style(Color("F6EFE4"), 4)
	$WoodFrame/PaperInner.add_theme_stylebox_override("panel", inner)

func _build_tabs() -> void:
	for pair in [["音乐盒", "music"], ["白噪音", "noise"], ["设置", "settings"]]:
		var b := Button.new()
		b.text = pair[0]
		b.flat = true
		b.pressed.connect(func(): _switch_tab(pair[1]))
		tabs.add_child(b)
	## v5-27 右上操作行：「本地添加」「移除」「复原」
	var ops := HBoxContainer.new()
	ops.alignment = BoxContainer.ALIGNMENT_END
	ops.position = Vector2(size.x - 300, 88)
	ops.size = Vector2(280, 26)
	add_child(ops)
	for pair in [["「本地添加」", "add"], ["「移除」", "remove"], ["「复原」", "reset"]]:
		var op := Button.new()
		op.text = String(pair[0])
		op.flat = true
		op.add_theme_font_size_override("font_size", 15)
		op.add_theme_color_override("font_color", Color("7A5A3A"))
		var act: String = String(pair[1])
		op.pressed.connect(func(): _on_local_op(act))
		ops.add_child(op)

func _on_local_op(action: String) -> void:
	SoundManager.play("click")
	match action:
		"add":
			var fd := FileDialog.new()
			fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			fd.access = FileDialog.ACCESS_FILESYSTEM
			fd.filters = PackedStringArray(["*.wav"])
			fd.file_selected.connect(func(path: String):
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://music"))
				var name_ := path.get_file()
				var dst := ProjectSettings.globalize_path("user://music/" + name_)
				if DirAccess.copy_absolute(path, dst) == OK:
					var list := _custom_list()
					list.append({"name": name_.replace(".wav", ""), "path": "user://music/" + name_, "builtin": false})
					_save_custom_list(list)
					_rebuild())
			add_child(fd)
			fd.popup_centered(Vector2i(640, 420))
		"remove":
			## v6-39：按选中行删（内置曲目不可删）
			var all_r := _all_tracks()
			var sel_ok: bool = _selected_index >= 0 and _selected_index < all_r.size()
			if sel_ok and not bool(all_r[_selected_index].get("builtin", true)):
				var list := _custom_list()
				var rm_idx: int = _selected_index - TRACKS.size()
				if rm_idx >= 0 and rm_idx < list.size():
					list.remove_at(rm_idx)
					_save_custom_list(list)
					_selected_index = -1
					_rebuild()
			elif sel_ok:
				push_warning("内置曲目不可移除")
			else:
				push_warning("请先选中要移除的本地曲目")
		"reset":
			_save_custom_list([])
			_rebuild()

var _selected_index := -1    ## v6-39：选中行（内置曲目不可删）
var _custom_player: AudioStreamPlayer = null   ## v6-39：自定义 wav 独立播放器

func _all_tracks() -> Array:
	## v6-39：内置 + 自定义合并视图
	var out: Array = []
	for t in TRACKS:
		out.append({"name": t.name, "dur": String(t.dur), "composer": "拾光工作室", "builtin": true, "path": ""})
	for c in _custom_list():
		var wav_path := String(c.get("path", ""))
		var gpath := ProjectSettings.globalize_path(wav_path)
		var mins := "--:--"
		if FileAccess.file_exists(gpath):
			var f := FileAccess.open(gpath, FileAccess.READ)
			if f:
				var bytes: int = f.get_length()
				f.close()
				var sec: int = bytes / 176400
				mins = "%02d:%02d" % [sec / 60, sec % 60]
		out.append({"name": String(c.get("name", "本地曲目")), "dur": mins, "composer": "本地", "builtin": false, "path": wav_path})
	return out

func _play_custom(path: String) -> void:
	## v6-39：自定义 wav 真播放（独立 player，不动 SoundManager）
	if _custom_player == null:
		_custom_player = AudioStreamPlayer.new()
		add_child(_custom_player)
	_custom_player.stop()
	SoundManager.set_bgm_enabled(false)
	var gpath := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(gpath):
		push_warning("本地曲目文件缺失：" + path)
		return
	var fb := FileAccess.open(gpath, FileAccess.READ)
	if fb == null:
		push_warning("本地曲目无法读取：" + path)
		return
	var buf := fb.get_buffer(fb.get_length())
	fb.close()
	var wav := AudioStreamWAV.load_from_buffer(buf)
	if wav:
		_custom_player.stream = wav
		_custom_player.play()
	else:
		push_warning("本地曲目格式不支持：" + path)

func _custom_list() -> Array:
	var f := FileAccess.open("user://music_list.json", FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Array else []

func _save_custom_list(list: Array) -> void:
	var f := FileAccess.open("user://music_list.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(list))
		f.close()

func _switch_tab(t: String) -> void:
	SoundManager.play("click")
	if t == "settings":
		_goto("res://scenes/settings_page.tscn")
		return
	_tab = t
	_rebuild()

func _rebuild() -> void:
	## 标签高亮
	for i in tabs.get_child_count():
		var b: Button = tabs.get_child(i)
		var active := (i == 0 and _tab == "music") or (i == 1 and _tab == "noise")
		b.add_theme_font_size_override("font_size", GameTheme.V_F_TAB if active else GameTheme.V_F_TAB_OFF)
		b.add_theme_color_override("font_color", Color("7A5D40") if active else Color("B2A595"))
	## 列表重建
	for c in track_list.get_children():
		c.queue_free()
	for c in controls.get_children():
		c.queue_free()
	if _tab == "music":
		_build_tracks()
	else:
		_build_noises()

func _build_tracks() -> void:
	## 表头
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	track_list.add_child(head)
	for pair in [["旋律名称", 2.2], ["作曲者", 1.0], ["时长", 0.7], ["播放/暂停", 0.9]]:
		var h := Label.new()
		h.text = pair[0]
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.custom_minimum_size = Vector2(0, 30)
		h.add_theme_font_size_override("font_size", 19)
		h.add_theme_color_override("font_color", Color("6B4A23"))
		head.add_child(h)
	var sep := ColorRect.new()
	sep.color = GameTheme.V_SEPARATOR
	sep.custom_minimum_size = Vector2(0, 1)
	track_list.add_child(sep)
	## 曲目行（v6-39：内置+自定义合并，点击选中）
	var all := _all_tracks()
	for i in all.size():
		var t: Dictionary = all[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		row.add_theme_constant_override("separation", 20)
		row.modulate = Color(1, 1, 0.82) if i == _selected_index else Color.WHITE
		row.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed:
				_selected_index = i
			_rebuild())
		track_list.add_child(row)
		var name_ := Label.new()
		name_.text = String(t.name)
		name_.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_.add_theme_font_size_override("font_size", 18)
		name_.add_theme_color_override("font_color", Color("7A5230") if i != _current else Color("B5643A"))
		row.add_child(name_)
		var composer := Label.new()
		composer.text = String(t.composer)
		composer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		composer.add_theme_font_size_override("font_size", 18)
		composer.add_theme_color_override("font_color", Color("7A5A3A"))
		row.add_child(composer)
		var dur := Label.new()
		dur.text = ("00:15/%s" % String(t.dur)) if i == _current and _playing else String(t.dur)
		dur.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dur.add_theme_font_size_override("font_size", 18)
		dur.add_theme_color_override("font_color", Color("7A4C23"))
		row.add_child(dur)
		var btn := Button.new()
		btn.text = ("⏸" if i == _current and _playing else "▶")
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 20)
		if i == _current and _playing:
			btn.add_theme_color_override("font_color", Color("B5643A"))
		btn.pressed.connect(func(): _play_track(i))
		row.add_child(btn)
	## 底部控制条（⏮ ⏸ ⏭ ≡）
	var prev := _round_btn("⏮", func(): _play_track((_current - 1 + TRACKS.size()) % TRACKS.size()))
	controls.add_child(prev)
	var pp := _round_btn("⏸" if _playing else "▶", func(): _play_track(_current), true)
	controls.add_child(pp)
	var next := _round_btn("⏭", func(): _play_track((_current + 1) % TRACKS.size()))
	controls.add_child(next)
	var list := _round_btn("≡", func(): pass)
	controls.add_child(list)

func _build_noises() -> void:
	var head := Label.new()
	head.text = "白噪音 · 专注时的背景氛围"
	head.add_theme_font_size_override("font_size", GameTheme.V_F_SECTION)
	head.add_theme_color_override("font_color", Color("6B4A23"))
	track_list.add_child(head)
	var sep := ColorRect.new()
	sep.color = GameTheme.V_SEPARATOR
	sep.custom_minimum_size = Vector2(0, 1)
	track_list.add_child(sep)
	for i in AMBIENTS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		track_list.add_child(row)
		var name_ := Label.new()
		name_.text = AMBIENTS[i].name
		name_.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_.add_theme_font_size_override("font_size", 19)
		name_.add_theme_color_override("font_color", Color("7A5230"))
		row.add_child(name_)
		var btn := Button.new()
		var active: bool = String(SoundManager.current_ambient) == String(AMBIENTS[i].key)
		btn.text = "⏸" if active else "▶"
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 20)
		if active:
			btn.add_theme_color_override("font_color", Color("B5643A"))
		btn.pressed.connect(func(): _toggle_noise(i))
		row.add_child(btn)

func _round_btn(glyph: String, cb: Callable, main: bool = false) -> Button:
	var b := Button.new()
	b.text = glyph
	var d := 52 if main else 44
	var sb := GameTheme.flat_style(Color("B28259") if main else Color("C99864"), d / 2)
	sb.border_color = Color("8A6A45")
	sb.set_border_width_all(1)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := GameTheme.flat_style(Color("C09068") if main else Color("D4A87A"), d / 2)
	sbh.border_color = Color("8A6A45")
	sbh.set_border_width_all(1)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_color_override("font_color", Color("F1E6D8"))
	b.add_theme_font_size_override("font_size", 24 if main else 20)
	b.custom_minimum_size = Vector2(d, d)
	b.pressed.connect(cb)
	return b

func _play_track(i: int) -> void:
	_playing = not _playing or i != _current
	_current = i
	SoundManager.play("click")
	var all := _all_tracks()
	if _playing:
		if i >= 0 and i < all.size() and not bool(all[i].get("builtin", true)):
			_play_custom(String(all[i].get("path", "")))   ## v6-39：自定义 wav
		else:
			if _custom_player:
				_custom_player.stop()
			SoundManager.set_bgm_enabled(true)   ## 内置=bgm 变奏
	else:
		if _custom_player:
			_custom_player.stop()
		SoundManager.set_bgm_enabled(false)
	_rebuild()

func _toggle_noise(i: int) -> void:
	SoundManager.play("click")
	SoundManager.set_ambient(AMBIENTS[i].key)
	_rebuild()

func _goto(path: String) -> void:
	SoundManager.play("click")
	get_tree().change_scene_to_file(path)
