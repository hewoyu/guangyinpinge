extends Control
## 设置页（real_10 三栏复刻）：模块设置 / 拼图辅助+音量 / 昵称语言+印章+退出
## 各栏卡片动态构建（_make_card 统一奶油卡样式）

@onready var back_button: Button = $TopBar/BackButton
@onready var left_col: VBoxContainer = $Columns/LeftCol
@onready var mid_col: VBoxContainer = $Columns/MidCol
@onready var right_col: VBoxContainer = $Columns/RightCol

const TITLE_SIZE := 14
const BODY_SIZE := 13

func _ready() -> void:
	back_button.flat = true
	back_button.add_theme_color_override("font_color", Color("54452F"))
	back_button.pressed.connect(_on_back)
	_build()

func _build() -> void:
	# 左栏：模块设置
	var module_card := _make_card("模块设置")
	_add_label(module_card, "模块数量：", BODY_SIZE, Color("4A3A2A"))
	var count_row := HBoxContainer.new()
	module_card.add_child(count_row)
	for n in 3:
		var b := _make_option_button(str(n + 1), n == 2)  ## 默认 3（截图选中态）
		count_row.add_child(b)
	_add_gap(module_card)
	var focus_card := _make_card("专注模块")
	_add_check(focus_card, "极简计时", true)
	_add_check(focus_card, "任务计时", false)
	var eff_card := _make_card("效率模块")
	_add_check(eff_card, "任务待办", true)
	_add_check(eff_card, "便利贴", false)
	var aux_card := _make_card("辅助模块")
	_add_check(aux_card, "时钟", true)
	_add_check(aux_card, "正念", true)
	_add_check(aux_card, "计数", false)
	_add_check(aux_card, "便签", false)
	var danger1 := _make_text_button("重置布局")
	var danger2 := _make_text_button("重置窗口")
	var danger3 := _make_text_button("清空存档")
	danger3.pressed.connect(_on_clear_save)
	var danger4 := _make_text_button("清空专注记录")
	left_col.add_child(module_card)
	left_col.add_child(focus_card)
	left_col.add_child(eff_card)
	left_col.add_child(aux_card)
	var db := HBoxContainer.new(); db.add_theme_constant_override("separation", 10)
	db.add_child(danger1); db.add_child(danger2)
	left_col.add_child(db)
	var db2 := HBoxContainer.new(); db2.add_theme_constant_override("separation", 10)
	db2.add_child(danger3); db2.add_child(danger4)
	left_col.add_child(db2)
	
	# 中栏：拼图辅助 + 音量
	var puzzle_card := _make_card("拼图辅助设置")
	_add_check(puzzle_card, "启用拼图排序按钮", true)
	_add_check(puzzle_card, "启用快速拼图按钮", true)
	var hyper_card := _make_card("超专注模式")
	_add_label(hyper_card, "专注模块仅在全屏状态下启用", BODY_SIZE, Color("9A8B78"))
	var vol_card := _make_card("音量")
	_add_slider(vol_card, "专注计时音量")
	_add_slider(vol_card, "音效音量")
	_add_slider(vol_card, "音乐音量")
	mid_col.add_child(puzzle_card)
	mid_col.add_child(hyper_card)
	mid_col.add_child(vol_card)
	
	# 右栏：昵称 + 语言 + 印章 + 退出
	var name_card := _make_card("昵称设置")
	var name_edit := LineEdit.new()
	name_edit.text = String(SettingsData.get_value("nickname", "旅人"))
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.custom_minimum_size = Vector2(0, 30)
	_style_input(name_edit)
	name_edit.text_changed.connect(func(t: String): SettingsData.set_value("nickname", t))
	name_card.add_child(name_edit)
	var lang_card := _make_card("语言设置")
	var lang_opt := OptionButton.new()
	lang_opt.add_item("简体中文")
	lang_opt.add_item("English")
	lang_opt.custom_minimum_size = Vector2(0, 30)
	_style_input(lang_opt)
	lang_card.add_child(lang_opt)
	var seal_box := VBoxContainer.new()
	seal_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var seal := ColorRect.new()
	seal.color = Color("A93226")
	seal.custom_minimum_size = Vector2(64, 64)
	var seal_inner := VBoxContainer.new()
	seal_inner.alignment = BoxContainer.ALIGNMENT_CENTER
	var seal_cn := Label.new()
	seal_cn.text = "止焉"
	seal_cn.add_theme_font_size_override("font_size", 22)
	seal_cn.add_theme_color_override("font_color", Color.WHITE)
	var seal_en := Label.new()
	seal_en.text = "ZHIYAN STUDIO"
	seal_en.add_theme_font_size_override("font_size", 7)
	seal_en.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	seal_inner.add_child(seal_cn); seal_inner.add_child(seal_en)
	seal.add_child(seal_inner)
	var seal_spacer := Control.new()
	seal_spacer.custom_minimum_size = Vector2(0, 12)
	right_col.add_child(name_card)
	right_col.add_child(lang_card)
	right_col.add_child(seal_box)
	seal_box.add_child(seal)
	seal_box.add_child(seal_spacer)
	var quit := Button.new()
	quit.text = "退出游戏"
	quit.add_theme_font_size_override("font_size", 21)
	_style_main_button(quit)
	quit.pressed.connect(_on_quit)
	right_col.add_child(quit)

func _apply_volume(key: String, val: float) -> void:
	## 音量通道调度（lambda 内 match 解析受限，外置方法）
	if key == "bgm_vol":
		SoundManager.set_bgm_volume(val)
	elif key == "sfx_vol":
		SoundManager.set_sfx_volume(val)
	elif key == "ambient_vol":
		SoundManager.set_ambient_volume(val)

func _make_card(title: String) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := GameTheme.flat_style(Color("F3EBDD"), 6)
	sb.border_color = Color("C4B49A")
	sb.set_border_width_all(1)
	sb.content_margin_left = 14.0; sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0; sb.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", sb)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", TITLE_SIZE)
	t.add_theme_color_override("font_color", Color("4A3A2A"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sep := ColorRect.new()
	sep.color = Color("DED2BE")
	sep.custom_minimum_size = Vector2(0, 1)
	v.add_child(sep)
	var wrap := VBoxContainer.new()
	wrap.name = "Content"
	v.add_child(wrap)
	# 返回包装层，后续添加控件进 wrap
	card.set_meta("wrap", wrap)
	return card

func _add_label(card: PanelContainer, text: String, size: int, color: Color) -> void:
	var wrap: VBoxContainer = card.get_meta("wrap")
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	wrap.add_child(l)

func _add_check(card: PanelContainer, text: String, checked: bool) -> void:
	var wrap: VBoxContainer = card.get_meta("wrap")
	var b := CheckBox.new()
	b.text = text
	## v5-27：开关持久化（键名=文本；超专注接全屏）
	if SettingsData.get_value(text, null) != null:
		checked = bool(SettingsData.get_value(text, checked))
	b.button_pressed = checked
	b.toggled.connect(func(on: bool):
		SettingsData.set_value(text, on)
		if text == "超专注模式":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	b.add_theme_font_size_override("font_size", BODY_SIZE)
	b.add_theme_color_override("font_color", Color("4A3A2A"))
	b.add_theme_color_override("font_pressed_color", Color("4A3A2A"))
	b.add_theme_color_override("font_hover_color", Color("4A3A2A"))
	# 复选框 14x14 样式（选中深褐底白✓）
	var cb := GameTheme.flat_style(Color("8B5E3C"), 3)
	var cu := GameTheme.flat_style(Color.WHITE, 3)
	cu.border_color = Color("C4B49A")
	cu.set_border_width_all(1)
	b.add_theme_stylebox_override("checked", cb)
	b.add_theme_stylebox_override("unchecked", cu)
	wrap.add_child(b)

func _add_slider(card: PanelContainer, label: String) -> void:
	var wrap: VBoxContainer = card.get_meta("wrap")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	wrap.add_child(v)
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", BODY_SIZE)
	l.add_theme_color_override("font_color", Color("4A3A2A"))
	v.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	## v5-27：读存档初值 + 变更即存即生效（映射音量通道）
	var key: String = {"专注计时音量": "bgm_vol", "音效音量": "sfx_vol", "音乐音量": "ambient_vol"}.get(label, "sfx_vol")
	s.value = float(SettingsData.get_value(key, 0.7))
	s.custom_minimum_size = Vector2(0, 16)
	s.value_changed.connect(func(val: float):
		SettingsData.set_value(key, val)
		_apply_volume(key, val))
	s.add_theme_stylebox_override("slider", GameTheme.flat_style(Color("8B5E3C"), 8))
	s.add_theme_stylebox_override("grabber_area", GameTheme.flat_style(Color("8B5E3C"), 8))
	v.add_child(s)
	var ends := HBoxContainer.new()
	var e0 := Label.new(); e0.text = "0"; e0.add_theme_font_size_override("font_size", 10)
	e0.add_theme_color_override("font_color", Color("9A8B78"))
	var em := Label.new(); em.text = "Max"; em.add_theme_font_size_override("font_size", 10)
	em.add_theme_color_override("font_color", Color("9A8B78"))
	ends.add_child(e0)
	ends.add_child(_spacer())
	ends.add_child(em)
	ends.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(ends)

func _make_option_button(text: String, selected: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(34, 26)
	if selected:
		var sb := GameTheme.flat_style(Color("6E8B3D"), 4)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_color_override("font_color", Color.WHITE)
	else:
		var sb := GameTheme.flat_style(Color("EDE0CC"), 4)
		sb.border_color = Color("C4B49A")
		sb.set_border_width_all(1)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_color_override("font_color", Color("4A3A2A"))
	return b

func _make_text_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_font_size_override("font_size", BODY_SIZE)
	b.add_theme_color_override("font_color", Color("766655"))
	return b

func _style_main_button(b: Button) -> void:
	var sb := GameTheme.flat_style(Color("EDE0CC"), 8)
	sb.border_color = Color("8B5E3C")
	sb.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := GameTheme.flat_style(Color("F0E6D0"), 8)
	sbh.border_color = Color("8B5E3C")
	sbh.set_border_width_all(2)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_color_override("font_color", Color("4A3A2A"))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _style_input(ctrl: Control) -> void:
	ctrl.add_theme_stylebox_override("normal", GameTheme.flat_style(Color.WHITE, 4))
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s

func _add_gap(card: PanelContainer) -> void:
	var wrap: VBoxContainer = card.get_meta("wrap")
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, 6)
	wrap.add_child(s)

func _on_clear_save() -> void:
	var ud := ProjectSettings.globalize_path("user://").path_join("save_v3.json")
	DirAccess.remove_absolute(ud)
	SoundManager.play("click")

func _on_quit() -> void:
	get_tree().quit()

func _on_back() -> void:
	SoundManager.play("click")
	get_tree().change_scene_to_file("res://scenes/bookroom.tscn")
