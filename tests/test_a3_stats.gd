extends Node
## task-35 验收：粒度竖轨 + 年月切换 + 聚合

var _pass := 0
var _fail := 0

func check(n: String, c: bool, extra: String = "") -> void:
	if c:
		_pass += 1
		print("PASS  ", n)
	else:
		_fail += 1
		print("FAIL  ", n, " ", extra)

func _ready() -> void:
	# 造历史：本月 3 天 + 上月 2 天
	var now := Time.get_unix_time_from_system()
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	GameState.history.clear()
	for i in 3:
		var key := Time.get_date_string_from_unix_time(now + float(bias) * 60.0 - i * 86400.0)
		GameState.history[key] = {"minutes": 25.0, "pieces": 2}
	for i in [31, 33]:
		var key2 := Time.get_date_string_from_unix_time(now + float(bias) * 60.0 - i * 86400.0)
		GameState.history[key2] = {"minutes": 50.0, "pieces": 4}
	var sp: Control = (load("res://scenes/stats_page.tscn") as PackedScene).instantiate() as Control
	add_child(sp)
	await get_tree().create_timer(0.5).timeout
	# 1) 默认 day：30 行
	var day_rows: int = sp._aggregate_window().size()
	check("day 默认 30 行", day_rows == 30, "got %d" % day_rows)
	# 2) month：12 行（近12月）
	sp._set_granularity("month")
	await get_tree().create_timer(0.2).timeout
	var month_rows: int = sp._aggregate_window().size()
	check("month 12 行", month_rows == 12, "got %d" % month_rows)
	# 3) year：1 行（2026）
	var year_rows: int = sp._years().size()
	check("year 聚合 1 年", year_rows == 1, "got %d" % year_rows)
	# 4) total：单行且值=175
	var tot: Array = sp._total_row()
	check("total 单行", tot.size() == 1)
	check("total 总时长 175", is_equal_approx(float(tot[0].minutes), 175.0), str(tot[0].minutes))
	# 5) 年月切换：◀ 步进到上月 → _month_days=当月天数行
	sp._set_granularity("day")
	sp._ov_month_offset = -1
	var md: int = sp._month_days().size()
	check("上月天数行", md >= 28 and md <= 31, "got %d" % md)
	# 6) 竖轨 UI 存在
	check("竖轨 5 按钮", sp._gran_panel.get_child_count() == 5)
	sp._ov_month_offset = 0
	print("== A3 STATS: %d pass %d fail ==" % [_pass, _fail])
	get_tree().quit()
