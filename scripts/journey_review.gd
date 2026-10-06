extends Control
## 旅程回顾页（task-36 v6：起止时间 + 前后趟轮播）

@onready var back_button: Button = $BackButton
@onready var list: VBoxContainer = $Scroll/List

var _current_index := 0   ## v6-36：轮播索引（默认最新一趟）

func _ready() -> void:
	back_button.flat = true
	back_button.add_theme_color_override("font_color", GameTheme.V_TEXT_MID)
	back_button.pressed.connect(_on_back)
	_current_index = maxi(GameState.journey_history.size() - 1, 0)
	_build()

func _build() -> void:
	for c in list.get_children():
		c.queue_free()
	var hist: Array[Dictionary] = GameState.journey_history
	if hist.is_empty():
		var empty := Label.new()
		empty.text = "还没有完成的旅程，先专注一次吧"
		empty.add_theme_font_size_override("font_size", 19)
		empty.add_theme_color_override("font_color", GameTheme.V_TEXT_SUB)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(empty)
		return
	## v6-36：单卡轮播（当前趟大卡 + 上一趟/下一趟按钮）
	list.add_child(_make_row(hist[_current_index]))
	list.add_child(_make_nav())

func _make_nav() -> HBoxContainer:
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 60)
	var prev := Button.new()
	prev.text = "◀ 上一趟"
	prev.theme = GameTheme.v4_text_button(18)
	prev.disabled = _current_index <= 0
	prev.pressed.connect(func():
		SoundManager.play("click")
		_current_index -= 1
		_build())
	nav.add_child(prev)
	var indicator := Label.new()
	indicator.text = "第 %d / %d 趟" % [_current_index + 1, GameState.journey_history.size()]
	indicator.add_theme_font_size_override("font_size", 15)
	indicator.add_theme_color_override("font_color", GameTheme.V_TEXT_SUB)
	indicator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nav.add_child(indicator)
	var next := Button.new()
	next.text = "下一趟 ▶"
	next.theme = GameTheme.v4_text_button(18)
	next.disabled = _current_index >= GameState.journey_history.size() - 1
	next.pressed.connect(func():
		SoundManager.play("click")
		_current_index += 1
		_build())
	nav.add_child(next)
	return nav

func _fmt_range(j: Dictionary) -> String:
	## v6-36：起止时间"MM.dd HH:mm — MM.dd HH:mm"（官方 real_02 格式）
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var s: int = int(j.get("start_ts", 0))
	var e: int = int(j.get("end_ts", 0))
	if s <= 0 or e - s < 60:
		return String(j.get("date", ""))
	var sd := Time.get_datetime_dict_from_unix_time(s + float(bias) * 60.0)
	var ed := Time.get_datetime_dict_from_unix_time(e + float(bias) * 60.0)
	return "%02d.%02d %02d:%02d — %02d.%02d %02d:%02d" % [
		int(sd.month), int(sd.day), int(sd.hour), int(sd.minute),
		int(ed.month), int(ed.day), int(ed.hour), int(ed.minute),
	]

func _make_row(j: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 84)
	card.add_theme_stylebox_override("panel", GameTheme.v4_side_card())
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	## 第一行：趟数 + 时间范围（v6-36）
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 24)
	v.add_child(top)
	var title := Label.new()
	title.text = "第%d趟旅程" % int(j.get("no", 1))
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", GameTheme.V_TEXT_TITLE)
	top.add_child(title)
	var range_l := Label.new()
	range_l.text = _fmt_range(j)
	range_l.add_theme_font_size_override("font_size", 16)
	range_l.add_theme_color_override("font_color", GameTheme.V_TEXT_SUB)
	top.add_child(range_l)
	## 第二行：专注次数 + 时长 + 邮戳
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 40)
	v.add_child(bottom)
	var cnt := Label.new()
	cnt.text = "%d次专注" % int(j.get("focus_count", 0))
	cnt.add_theme_font_size_override("font_size", 17)
	cnt.add_theme_color_override("font_color", GameTheme.V_TEXT_BODY)
	bottom.add_child(cnt)
	var mins := int(j.get("minutes", 0.0))
	var dur := Label.new()
	dur.text = "%d小时%d分钟" % [mins / 60, mins % 60]
	dur.add_theme_font_size_override("font_size", 17)
	dur.add_theme_color_override("font_color", GameTheme.V_TEXT_BODY)
	bottom.add_child(dur)
	var stamp := Panel.new()
	var sb := GameTheme.flat_style(Color("96874C"), 14)
	sb.border_color = Color("7A6E3E")
	sb.set_border_width_all(1)
	stamp.custom_minimum_size = Vector2(28, 28)
	stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stamp.add_theme_stylebox_override("panel", sb)
	bottom.add_child(stamp)
	return card

func _on_back() -> void:
	SoundManager.play("click")
	get_tree().change_scene_to_file("res://scenes/bookroom.tscn")
