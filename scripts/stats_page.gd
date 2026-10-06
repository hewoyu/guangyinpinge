extends Control
## 统计页（real_07/09 复刻）：标签"专注概览 | 热力图 | 数据管理 | 待办管理"
## 专注概览：KPI 三胶囊 + 通栏数据条 + 成对柱状图 + 莫兰迪饼图 + 图例
## 热力图：月历 7 列网格（5 级色）+ 右侧月统计 + 图例
## 全部程序化绘制（_draw）

const HEAT_LEVELS := [
	Color("E8DECD"), Color("D9C3A4"), Color("C39C74"), Color("A0764E"), Color("6B4529"),
]

@onready var back_button: Button = $BackButton
@onready var tabs: HBoxContainer = $Tabs
@onready var body: Control = $Body

var _tab := "overview"   ## overview / heatmap
var _granularity := "day"   ## v6-35：day/week/month/year/total（左竖轨粒度）
var _ov_month_offset := 0    ## v6-35：overview 年月切换（0=本月）
var _gran_panel: VBoxContainer = null
var _month_bar: HBoxContainer = null

func _ready() -> void:
	back_button.flat = true
	back_button.add_theme_color_override("font_color", GameTheme.V_TEXT_MID)
	back_button.pressed.connect(func(): _goto("res://scenes/bookroom.tscn"))
	for pair in [["专注概览", "overview"], ["热力图", "heatmap"], ["数据管理", "data"], ["待办管理", "todo"]]:
		var b := Button.new()
		b.text = pair[0]
		b.flat = true
		var key: String = String(pair[1])
		b.pressed.connect(func(): _switch(key))
		tabs.add_child(b)
	body.draw.connect(_draw_body)
	_build_granularity_rail()   ## v6-35 左竖轨
	_build_month_bar()           ## v6-35 年月切换

func _build_granularity_rail() -> void:
	## v6-35：左竖轨 日/周/月/年/总（real_07 实测：选中深棕，未选灰）
	if _gran_panel:
		return
	_gran_panel = VBoxContainer.new()
	_gran_panel.position = Vector2(18, 150)
	_gran_panel.add_theme_constant_override("separation", 22)
	add_child(_gran_panel)
	for pair in [["日", "day"], ["周", "week"], ["月", "month"], ["年", "year"], ["总", "total"]]:
		var b := Button.new()
		b.text = String(pair[0])
		b.flat = true
		var g: String = String(pair[1])
		b.pressed.connect(func(): _set_granularity(g))
		_gran_panel.add_child(b)
	_refresh_gran_rail()

func _refresh_gran_rail() -> void:
	var i := 0
	for pair in [["日", "day"], ["周", "week"], ["月", "month"], ["年", "year"], ["总", "total"]]:
		if i < _gran_panel.get_child_count():
			var b: Button = _gran_panel.get_child(i)
			var sel: bool = String(pair[1]) == _granularity
			b.add_theme_font_size_override("font_size", 20 if sel else 14)
			b.add_theme_color_override("font_color", Color("5E3F21") if sel else Color("A79781"))
		i += 1
	_gran_panel.visible = _tab == "overview"

func _set_granularity(g: String) -> void:
	SoundManager.play("click")
	_granularity = g
	_refresh_gran_rail()
	body.queue_redraw()

func _build_month_bar() -> void:
	## v6-35：overview 年月条（2026年10月 ◀ ▶）
	if _month_bar:
		return
	_month_bar = HBoxContainer.new()
	_month_bar.position = Vector2(560, 52)
	_month_bar.add_theme_constant_override("separation", 18)
	add_child(_month_bar)
	var prev := Button.new()
	prev.text = "◀"
	prev.flat = true
	prev.add_theme_color_override("font_color", Color("A79781"))
	prev.pressed.connect(func():
		_ov_month_offset -= 1
		body.queue_redraw())
	_month_bar.add_child(prev)
	var label := Label.new()
	label.name = "MonthLabel"
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("5E3F21"))
	_month_bar.add_child(label)
	var next := Button.new()
	next.text = "▶"
	next.flat = true
	next.add_theme_color_override("font_color", Color("A79781"))
	next.pressed.connect(func():
		if _ov_month_offset < 0:
			_ov_month_offset += 1
			body.queue_redraw())
	_month_bar.add_child(next)
	_refresh_month_bar()

func _refresh_month_bar() -> void:
	## 月份标签（跟随 _ov_month_offset；总粒度隐藏整条）
	_month_bar.visible = _tab == "overview" and _granularity != "total"
	var ml: Label = _month_bar.get_node_or_null("MonthLabel")
	if ml == null:
		return
	var d := Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_system() + _ov_month_offset * 86400.0 * 30.4)
	ml.text = "%d年%d月" % [int(d.year), int(d.month)]
	_refresh_tabs()

func _switch(key: String) -> void:
	SoundManager.play("click")
	if key == "todo":
		get_tree().change_scene_to_file("res://scenes/todo_stats.tscn")
		return
	if key == "data":
		get_tree().change_scene_to_file("res://scenes/data_manage.tscn")
		return
	_tab = key
	_refresh_tabs()
	body.queue_redraw()

func _refresh_tabs() -> void:
	for i in tabs.get_child_count():
		var b: Button = tabs.get_child(i)
		var key: String = ["overview", "heatmap", "data", "todo"][i]
		var active: bool = key == _tab
		b.add_theme_font_size_override("font_size", GameTheme.V_F_TAB if active else GameTheme.V_F_TAB_OFF)
		b.add_theme_color_override("font_color", Color("5E3F21") if active else Color("A79781"))

func _draw_body() -> void:
	if _tab == "overview":
		_draw_overview()
	else:
		_draw_heatmap()

# ============ 专注概览（real_07） ============

func _draw_overview() -> void:
	var area := body.size
	var days: Array = _aggregate_window()   ## v6-35：按粒度聚合（含年月偏移）
	_refresh_month_bar()
	var total_min: float = 0.0
	var count := 0
	for d in days:
		total_min += d.minutes
		count += d.count
	var avg := total_min / maxf(1.0, float(days.size()))
	## v6-35：day 粒度+月份偏移时 KPI 只算所选月
	if _granularity == "day" and _ov_month_offset < 0:
		var md := _month_days()
		total_min = 0.0
		count = 0
		for d in md:
			total_min += d.minutes
			count += d.count
		avg = total_min / maxf(1.0, float(md.size()))
	## KPI 三胶囊（y 30-95）
	var pill_y := 24.0
	var pill_h := 52.0
	_pill(Rect2(60, pill_y, 200, pill_h), GameTheme.V_PILL_L, str(maxi(count, 0)), "专注次数")
	_pill(Rect2(276, pill_y, 240, pill_h), GameTheme.V_PILL_M, "%d分钟" % int(avg), "平均专注时长")
	_pill(Rect2(532, pill_y, 300, pill_h), GameTheme.V_PILL_L, _fmt_hm(total_min), "总专注时长")
	## 通栏数据条（y 110-165）
	_bar(Rect2(60, 108, 772, 52), GameTheme.V_PILL_D, str(GameState.total_pieces_dropped), "累计掉落拼图数量")
	## 柱状图（左下，y 200-460）
	_section_title(Vector2(60, 190), "柱状图 · " + {"day": "按日（近30天/所选月）", "week": "按周（近12周）", "month": "按月（近12月）", "year": "按年", "total": "总计"}.get(_granularity, "近30天"))
	_draw_bars(days, Rect2(60, 216, 460, 240))
	## 饼图（右，real_07 莫兰迪）
	_section_title(Vector2(560, 190), "饼状图 · 任务分布")
	_draw_pie(Vector2(720, 340), 105.0)

## ============ v6-35 粒度聚合 ============

func _aggregate_window() -> Array:
	## 按粒度返回 [{label, minutes, count}]（day 含年月偏移窗口）
	match _granularity:
		"day":
			if _ov_month_offset < 0:
				return _month_days()
			return _last_days(30)
		"week":
			return _weeks(12)
		"month":
			return _months(12)
		"year":
			return _years()
		"total":
			return _total_row()
	return _last_days(30)

func _month_days() -> Array:
	## 所选月的每日记录（含当月已过天数）
	var out: Array = []
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var now := Time.get_unix_time_from_system() + float(bias) * 60.0
	var dd := Time.get_datetime_dict_from_unix_time(now)
	var y: int = int(dd.year)
	var m: int = int(dd.month)
	for off in range(-_ov_month_offset):
		m -= 1
		if m < 1:
			m = 12
			y -= 1
	var month_str := "%04d-%02d" % [y, m]
	var dim := 31
	match m:
		1, 3, 5, 7, 8, 10, 12: dim = 31
		4, 6, 9, 11: dim = 30
		2: dim = 29 if y % 4 == 0 and (y % 100 != 0 or y % 400 == 0) else 28
	for day in range(1, dim + 1):
		var key := "%s-%02d" % [month_str, day]
		if GameState.history.has(key):
			var h: Dictionary = GameState.history[key]
			out.append({"label": "%02d日" % day, "minutes": float(h.minutes), "count": int(h.pieces)})
		else:
			out.append({"label": "%02d日" % day, "minutes": 0.0, "count": 0})
	return out

func _weeks(n: int) -> Array:
	var out: Array = []
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var now := Time.get_unix_time_from_system() + float(bias) * 60.0
	for w in range(n - 1, -1, -1):
		var total := 0.0
		var cnt := 0
		for d in 7:
			var t := now - (w * 7 + d) * 86400.0
			var key := Time.get_date_string_from_unix_time(t)
			if GameState.history.has(key):
				total += float(GameState.history[key].minutes)
			cnt += int(GameState.history[key].pieces)
		var dt := Time.get_datetime_dict_from_unix_time(now - w * 7 * 86400.0)
		out.append({"label": "%d.%02d" % [int(dt.month), int(dt.day)], "minutes": total, "count": cnt})
	return out

func _months(n: int) -> Array:
	var out: Array = []
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var now := Time.get_unix_time_from_system() + float(bias) * 60.0
	var dd := Time.get_datetime_dict_from_unix_time(now)
	var y: int = int(dd.year)
	var m: int = int(dd.month)
	for i in range(n):
		var total := 0.0
		var cnt := 0
		var month_str := "%04d-%02d" % [y, m]
		for key in GameState.history:
			if String(key).begins_with(month_str):
				total += float(GameState.history[key].minutes)
			cnt += int(GameState.history[key].pieces)
		out.append({"label": "%d月" % m, "minutes": total, "count": cnt})
		m -= 1
		if m < 1:
			m = 12
			y -= 1
	out.reverse()
	return out

func _years() -> Array:
	var by_year := {}
	for key in GameState.history:
		var y := String(key).substr(0, 4)
		if not by_year.has(y):
			by_year[y] = {"label": "%s年" % y, "minutes": 0.0, "count": 0}
		by_year[y].minutes += float(GameState.history[key].minutes)
		by_year[y].count += int(GameState.history[key].pieces)
	var out: Array = by_year.values()
	out.sort_custom(func(a, b): return String(a.label) < String(b.label))
	return out

func _total_row() -> Array:
	var total := 0.0
	var cnt := 0
	for key in GameState.history:
		total += float(GameState.history[key].minutes)
		cnt += int(GameState.history[key].pieces)
	return [{"label": "全部", "minutes": total, "count": cnt}]

func _last_days(n: int) -> Array:
	## 最近 n 天的记录（当天开始倒推）
	var out: Array = []
	var today := Time.get_date_string_from_system()
	for i in range(n - 1, -1, -1):
		var d := Time.get_date_string_from_unix_time(Time.get_unix_time_from_system() - i * 86400.0)
		var rec: Dictionary = GameState.history.get(d, {})
		var mins: float = float(rec.get("minutes", 0.0))
		var cnt: int = 1 if mins > 0.0 else 0
		if rec.has("count"):
			cnt = int(rec.count)
		elif mins > 0.0:
			cnt = 1
		out.append({ "date": d, "minutes": mins, "count": cnt })
	return out

func _fmt_hm(mins: float) -> String:
	return "%d小时%d分钟" % [int(mins) / 60, int(mins) % 60]

func _pill(rect: Rect2, fill: Color, value: String, label: String) -> void:
	body.draw_style_box(GameTheme.v4_pill(fill), rect)
	var f := ThemeDB.fallback_font
	var vs := f.get_string_size(value, HORIZONTAL_ALIGNMENT_CENTER, -1, 26)
	body.draw_string(f, rect.position + Vector2((rect.size.x - vs.x) / 2.0, 30), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	var ls := f.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 15)
	body.draw_string(f, rect.position + Vector2((rect.size.x - ls.x) / 2.0, 46), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.72))

func _bar(rect: Rect2, fill: Color, value: String, label: String) -> void:
	body.draw_style_box(GameTheme.v4_pill(fill), rect)
	var f := ThemeDB.fallback_font
	var vs := f.get_string_size(value, HORIZONTAL_ALIGNMENT_CENTER, -1, 26)
	body.draw_string(f, rect.position + Vector2((rect.size.x - vs.x) / 2.0, 32), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	var ls := f.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 15)
	body.draw_string(f, rect.position + Vector2((rect.size.x - ls.x) / 2.0, 48), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.72))

func _section_title(pos: Vector2, text: String) -> void:
	## "| 板块标题" 竖杠前缀（3x14 竖线）
	body.draw_rect(Rect2(pos, Vector2(4, 20)), Color("6B4A2A"))
	var f := ThemeDB.fallback_font
	body.draw_string(f, pos + Vector2(12, 17), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("6B4A2A"))

func _draw_bars(days: Array, rect: Rect2) -> void:
	## 成对柱：深 #2E2016 浅 #C6AE95；网格 #D8C6B4；Y 轴刻度
	var max_min := 1.0
	for d in days:
		max_min = maxf(max_min, d.minutes)
	var step_lines := 4
	var f := ThemeDB.fallback_font
	for i in range(step_lines + 1):
		var y := rect.position.y + rect.size.y * float(i) / step_lines
		body.draw_line(Vector2(rect.position.x + 40, y), Vector2(rect.end.x, y), GameTheme.V_GRID, 1.0)
		var label := "%d分钟" % int(max_min * (step_lines - i) / step_lines)
		body.draw_string(f, Vector2(rect.position.x, y - 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8A7563"))
	## 柱（每天一组两根：专注分钟 + 掉落碎片比例）
	var n := days.size()
	var group_w := rect.size.x / float(n)
	for i in n:
		var d: Dictionary = days[i]
		var h1: float = rect.size.y * (d.minutes / max_min)
		var x := rect.position.x + 40 + i * group_w
		var w := maxf(4.0, group_w * 0.3)
		if h1 > 0.5:
			body.draw_rect(Rect2(x, rect.end.y - h1, w, h1), GameTheme.V_CHART_DARK)
		## 浅柱（碎片数可视近似）
		var pieces: int = GameState.history.get(d.date, {}).get("pieces", 0) if d.minutes > 0.0 else 0
		var h2: float = rect.size.y * clampf(float(pieces) / 40.0, 0.0, 1.0)
		if h2 > 0.5:
			body.draw_rect(Rect2(x + w + 2, rect.end.y - h2, w, h2), GameTheme.V_CHART_LIGHT)
	## X 轴日期标注（每 6 天）
	for i in range(0, n, 6):
		var x := rect.position.x + 40 + i * group_w
		var day_str: String = String(days[i].date)
		body.draw_string(f, Vector2(x, rect.end.y + 16), day_str.substr(8), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8A7563"))

func _draw_pie(center: Vector2, radius: float) -> void:
	## 莫兰迪饼图（任务分布近似：由历史数据轮转分布）+ 图例
	var f := ThemeDB.fallback_font
	var total := GameState.total_pieces_dropped + GameState.total_focus_count
	if total <= 0:
		body.draw_string(f, center + Vector2(-60, 0), "暂无数据", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("9A8B78"))
		return
	var segments := [
		{ "name": "专注时段", "val": maxi(GameState.total_focus_count, 1) },
		{ "name": "碎片收集", "val": maxi(GameState.total_pieces_dropped, 1) },
		{ "name": "拼图完成", "val": GameState.completed_album.size() * 10 },
	]
	var sum := 0
	for s in segments:
		sum += s.val
	var angle_from := -PI / 2.0
	var colors := GameTheme.V_PIE
	var pts := PackedVector2Array([center])
	var cols := PackedColorArray()
	for i in segments.size():
		var sweep := TAU * float(segments[i].val) / sum
		var points := PackedVector2Array()
		var pcols := PackedColorArray()
		points.append(center)
		pcols.append(colors[i % colors.size()])
		var steps := 32
		for j in steps + 1:
			var a := angle_from + sweep * float(j) / steps
			points.append(center + Vector2(cos(a), sin(a)) * radius)
			pcols.append(colors[i % colors.size()])
		body.draw_polygon(points, pcols)
		## 引出标签
		var mid_a := angle_from + sweep / 2.0
		var p1 := center + Vector2(cos(mid_a), sin(mid_a)) * (radius + 8)
		var p2 := p1 + Vector2(28, 0) if cos(mid_a) >= 0 else p1 + Vector2(-28, 0)
		body.draw_line(p1, p2, Color("6B5A44"), 1.0)
		var pct := int(100.0 * segments[i].val / sum)
		var label: String = "%s %d%%" % [segments[i].name, pct]
		var lp := p2 + Vector2(4, 4) if cos(mid_a) >= 0 else p2 + Vector2(-f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x - 4, 4)
		body.draw_string(f, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("6B5A44"))
		angle_from += sweep

# ============ 热力图（real_09） ============

func _draw_heatmap() -> void:
	var f := ThemeDB.fallback_font
	var area := body.size
	## 月份标题 + 切换
	_month_title(Vector2(60, 30))
	## 星期表头（周一~周日）
	var grid_x := 150.0
	var grid_y := 100.0
	var cell_w := 84.0
	var cell_h := 56.0
	for i in 7:
		var wd: String = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"][i]
		body.draw_string(f, Vector2(grid_x + i * cell_w + 12, grid_y - 10), wd, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("6B4A23"))
	## 5 行日历格
	var first_day := _month_first_weekday()
	var days_count := _days_in_month()
	var max_min := 1.0
	for d in GameState.history:
		max_min = maxf(max_min, float(GameState.history[d].minutes))
	for day in range(1, days_count + 1):
		var col := (day - 1 + first_day) % 7
		var roww := (day - 1 + first_day) / 7
		var x := grid_x + col * cell_w
		var y := grid_y + roww * cell_h
		var date_str := "%s-%02d" % [_current_month_key(), day]
		var rec: Dictionary = GameState.history.get(date_str, {})
		var mins: float = float(rec.get("minutes", 0.0))
		var level := 0
		if mins > 0.0:
			level = clampi(int(ceil(mins / max_min * 4.0)), 1, 4)
		body.draw_style_box(GameTheme.flat_style(HEAT_LEVELS[level], 5), Rect2(x, y, cell_w - 10, cell_h - 14))
		body.draw_string(f, Vector2(x + 8, y + 18), str(day), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("4A3A2A") if level < 3 else Color.WHITE)
		if mins > 0.0:
			body.draw_string(f, Vector2(x + 8, y + 36), "%d分" % int(mins), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("5C3A22") if level < 3 else Color(1, 1, 1, 0.85))
	## 右侧月统计（x 760+）
	var month_min := 0.0
	var month_days := 0
	var month_pieces := 0
	for day in range(1, days_count + 1):
		var date_str := "%s-%02d" % [_current_month_key(), day]
		if GameState.history.has(date_str):
			var rec: Dictionary = GameState.history[date_str]
			if float(rec.minutes) > 0.0:
				month_days += 1
				month_min += float(rec.minutes)
				month_pieces += int(rec.get("pieces", 0))
	var stats_x := grid_x + 7 * cell_w + 30
	var stats := [
		"本月累计", "专注 %d 天" % month_days, "专注 %d 次" % month_days,
		"专注 %s" % _fmt_hm(month_min), "收获拼图 %d 块" % month_pieces,
		"完成拼图 %d 幅" % GameState.completed_album.size(),
	]
	for i in stats.size():
		var sz := 20 if i == 0 else 17
		var col := Color("4A3A2A") if i == 0 else Color("6B5A44")
		body.draw_string(f, Vector2(stats_x, 130 + i * 40), stats[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
		if i == 0:
			body.draw_line(Vector2(stats_x, 138), Vector2(stats_x + 160, 138), GameTheme.V_SEPARATOR, 1.0)
	## 底部图例：少 □□□□□ 多
	var ly := body.size.y - 30.0
	body.draw_string(f, Vector2(grid_x + 100, ly + 12), "少", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("6B5A44"))
	for i in 5:
		var sb := GameTheme.flat_style(HEAT_LEVELS[i], 3)
		body.draw_style_box(sb, Rect2(grid_x + 130 + i * 26, ly, 22, 16))
	body.draw_string(f, Vector2(grid_x + 268, ly + 12), "多", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("6B5A44"))

var _month_offset := 0

func _month_title(pos: Vector2) -> void:
	var f := ThemeDB.fallback_font
	var now := Time.get_datetime_dict_from_system()
	var m := int(now.month) + _month_offset
	var y := int(now.year)
	while m < 1:
		m += 12; y -= 1
	while m > 12:
		m -= 12; y += 1
	## ◀ 四月 2026 ▶
	body.draw_string(f, pos + Vector2(0, 22), "◀", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("8B5A2B"))
	body.draw_string(f, pos + Vector2(40, 26), "%d年%d月" % [y, m], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("4A3A2A"))
	body.draw_string(f, pos + Vector2(150, 22), "▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("8B5A2B"))

func _current_month_key() -> String:
	var now := Time.get_datetime_dict_from_system()
	var m := int(now.month) + _month_offset
	var y := int(now.year)
	while m < 1: m += 12; y -= 1
	while m > 12: m -= 12; y += 1
	return "%04d-%02d" % [y, m]

func _month_first_weekday() -> int:
	var key := _current_month_key() + "-01"
	var t := Time.get_unix_time_from_datetime_string(key + " 00:00:00")
	var d := Time.get_datetime_dict_from_unix_time(t)
	return (int(d.weekday) + 6) % 7   ## 周一=0

func _days_in_month() -> int:
	var key := _current_month_key()
	var parts := key.split("-")
	var y := int(parts[0])
	var m := int(parts[1])
	if m == 2:
		return 29 if (y % 4 == 0 and y % 100 != 0) or y % 400 == 0 else 28
	return [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1]

func _goto(path: String) -> void:
	SoundManager.play("click")
	get_tree().change_scene_to_file(path)
