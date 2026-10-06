extends Control
## 待办管理页（task-28 b-e，real_12 复刻）：
## 左栏：待办管理(选中)/统计/列表/归档 · 搜索框 · 统计段 12 卡棋盘交替 · 清除数据
## 数据源：TodoData（class_name 已全局注册，持久化 user://todo.json）

@onready var back_button: Button = $BackButton
@onready var tabs: HBoxContainer = $Tabs
@onready var side_menu: VBoxContainer = $SideMenu
@onready var search: LineEdit = $Search
@onready var content: Control = $Content
@onready var clear_link: Button = $ClearLink

const SECTIONS := ["统计", "列表", "归档"]
var _section := "统计"
var _todo_items: Array = []

func _ready() -> void:
	back_button.flat = true
	back_button.add_theme_color_override("font_color", GameTheme.V_TEXT_MID)
	back_button.pressed.connect(func():
		SoundManager.play("click")
		get_tree().change_scene_to_file("res://scenes/stats_page.tscn"))
	## 顶部标签（与统计页同款骨架）
	for pair in [["专注概览", "overview"], ["热力图", "heatmap"], ["数据管理", "data"], ["待办管理", "todo"]]:
		var b := Button.new()
		b.text = pair[0]
		b.flat = true
		var key: String = String(pair[1])
		b.add_theme_font_size_override("font_size", GameTheme.V_F_TAB if key == "todo" else GameTheme.V_F_TAB_OFF)
		b.add_theme_color_override("font_color", Color("5E3F21") if key == "todo" else Color("A79781"))
		if key == "overview" or key == "heatmap":
			b.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/stats_page.tscn"))
		elif key == "data":
			b.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/data_manage.tscn"))
		tabs.add_child(b)
	## 左栏
	var head := Label.new()
	head.text = "待办管理"
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", Color("54452F"))
	side_menu.add_child(head)
	for s in SECTIONS:
		var b := Button.new()
		b.text = s
		b.flat = true
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_color_override("font_color", Color("54452F") if s == _section else Color("8B755F"))
		b.pressed.connect(func(): _switch(s))
		side_menu.add_child(b)
	search.text_changed.connect(func(_t): _refresh())
	clear_link.theme = GameTheme.v4_text_button(17, Color("766655"))
	clear_link.pressed.connect(_on_clear)
	_load_todo()
	_refresh()

func _load_todo() -> void:
	## 数据源：TodoData（class_name 已全局注册，持久化 user://todo.json）
	_todo_items = TodoData.items()
	if _todo_items.is_empty():
		## 无数据时预置演示任务（贴近官方截图气质）
		_todo_items = [
			{"text": "把统计方法作业第4题做完", "done": false, "category": "study", "created_at": 0, "done_at": 0},
			{"text": "给导师回邮件确认汇报时间", "done": false, "category": "work", "created_at": 0, "done_at": 0},
			{"text": "图书馆的书周五到期，记得续借", "done": true, "category": "life", "created_at": 0, "done_at": 1791200000},
			{"text": "整理第一轮访谈开放式编码", "done": false, "category": "study", "created_at": 0, "done_at": 0},
		]

func _switch(s: String) -> void:
	SoundManager.play("click")
	_section = s
	for b in side_menu.get_children():
		if b is Button:
			var active: bool = b.text == s
			b.add_theme_color_override("font_color", Color("54452F") if active else Color("8B755F"))
	_refresh()

func _refresh() -> void:
	for c in content.get_children():
		c.queue_free()
	match _section:
		"统计":
			_build_stats()
		"列表":
			_build_list(false)
		"归档":
			_build_list(true)

func _filtered(done_want: bool) -> Array:
	var kw := search.text.strip_edges()
	var out: Array = []
	for t in _todo_items:
		var ok_done: bool = bool(t.get("done", false)) == done_want
		var ok_kw: bool = kw == "" or String(t.get("text", "")).find(kw) >= 0
		if ok_done and ok_kw:
			out.append(t)
	return out

## ---- 统计段（12 卡，real_12 棋盘交替）----

func _build_stats() -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 22)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(grid)
	var total := _todo_items.size()
	var active := _filtered(false).size()
	var done := _filtered(true).size()
	## 时长统计（从 done_at - created_at 算，无时间则 0）
	var durations: Array[float] = []
	for t in _todo_items:
		if bool(t.get("done", false)):
			var d := float(t.get("done_at", 0)) - float(t.get("created_at", 0))
			if d > 0.0:
				durations.append(d)
	durations.sort()
	var med: float = durations[int(durations.size() / 2)] if durations.size() > 0 else 0.0
	var fastest: float = durations[0] if durations.size() > 0 else 0.0
	var slowest: float = durations.back() if durations.size() > 0 else 0.0
	var avg: float = 0.0
	for d in durations:
		avg += d
	avg = avg / durations.size() if durations.size() > 0 else 0.0
	var backlog_max := 0.0
	for t in _filtered(false):
		backlog_max = maxf(backlog_max, float(Time.get_unix_time_from_system()) - float(t.get("created_at", 0)) if float(t.get("created_at", 0)) > 0 else 0.0)
	var cards := [
		[str(total), "当前任务总数"],
		[str(TodoData.high_count()), "高优先级待办"],
		[str(done), "已完成待归档"],
		[_fmt_days(backlog_max), "最久积压时长"],
		[str(active), "积压超1天"],
		[str(done), "已归档任务数"],
		["0", "今日已归档"],
		[str(done), "近7天归档"],
		[_fmt_dur(med), "归档耗时中位"],
		[_fmt_dur(fastest), "最快完成用时"],
		[_fmt_dur(avg), "平均完成用时"],
		[_fmt_dur(slowest), "最久完成用时"],
	]
	for i in cards.size():
		grid.add_child(_brick(cards[i][0], cards[i][1], i % 2 == (i / 3) % 2))

func _brick(value: String, label: String, light: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 64)
	var sb := GameTheme.flat_style(Color("C5AA92") if light else Color("997D64"), 6)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var l1 := Label.new()
	l1.text = value
	l1.add_theme_font_size_override("font_size", 24)
	l1.add_theme_color_override("font_color", Color("351601") if light else Color("EADCCB"))
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l1)
	var l2 := Label.new()
	l2.text = label
	l2.add_theme_font_size_override("font_size", 15)
	l2.add_theme_color_override("font_color", Color("7B614A") if light else Color("D9C7B2"))
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l2)
	return p

func _fmt_days(sec: float) -> String:
	if sec <= 0.0:
		return "0"
	var d := int(sec) / 86400
	var h := (int(sec) % 86400) / 3600
	return "%d天%d时" % [d, h] if d > 0 else "%d时" % h

func _fmt_dur(sec: float) -> String:
	if sec <= 0.0:
		return "—"
	var m := int(sec) / 60
	return "%d分" % m if m < 60 else "%d小时%d分" % [m / 60, m % 60]

## ---- 列表/归档段 ----

func _build_list(done_want: bool) -> void:
	var rows := _filtered(done_want)
	if rows.is_empty():
		var empty := Label.new()
		empty.text = "搜索任务名..." if _section == "列表" else "暂无归档任务"
		empty.add_theme_font_size_override("font_size", 15)
		empty.add_theme_color_override("font_color", Color("AFA9A2"))
		empty.position = Vector2(20, 20)
		content.add_child(empty)
		return
	var i := 0
	for t in rows:
		var row := HBoxContainer.new()
		row.position = Vector2(20, 20 + i * 42)
		row.add_theme_constant_override("separation", 14)
		content.add_child(row)
		var mark := Label.new()
		mark.text = "✓" if done_want else "·"
		mark.add_theme_font_size_override("font_size", 17)
		mark.add_theme_color_override("font_color", Color("6E8B3D") if done_want else Color("8B7261"))
		row.add_child(mark)
		var txt := Label.new()
		## v6-38：高优先级任务 ★ 前缀（砖红）
		var is_high: bool = bool(t.get("high", false)) and not done_want
		txt.text = ("★ " if is_high else "") + String(t.get("text", ""))
		txt.add_theme_font_size_override("font_size", 17)
		txt.add_theme_color_override("font_color", Color("9E4A3A") if is_high else (Color("8A8578") if done_want else Color("54452F")))
		row.add_child(txt)
		var cat := Label.new()
		cat.text = {"study": "学习", "work": "工作", "life": "生活", "urgent": "紧急"}.get(String(t.get("category", "life")), "生活")
		cat.add_theme_font_size_override("font_size", 13)
		cat.add_theme_color_override("font_color", Color("9A8B78"))
		cat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cat.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(cat)
		i += 1

func _on_clear() -> void:
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "清除所有任务数据？"
	confirm.ok_button_text = "清除"
	confirm.cancel_button_text = "取消"
	confirm.confirmed.connect(func():
		TodoData.clear_all()
		_todo_items.clear()
		_notify("任务数据已清除")
		_refresh()
	)
	add_child(confirm)
	confirm.popup_centered()

func _notify(text: String) -> void:
	var toast := AcceptDialog.new()
	toast.dialog_text = text
	toast.ok_button_text = "好"
	add_child(toast)
	toast.popup_centered()
