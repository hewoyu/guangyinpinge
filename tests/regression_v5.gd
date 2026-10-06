extends Node
## v5 全量回归 = v4 基线 + v5 官方承诺全链路

var _pass := 0
var _fail := 0

func check(n: String, c: bool, extra: String = "") -> void:
	if c:
		_pass += 1
		print("PASS  ", n)
	else:
		_fail += 1
		print("FAIL  ", n, " ", extra)

func _reset() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_v3.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://todo.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.json"))
	GameState.collected.clear()
	GameState.placed.clear()
	GameState.history.clear()
	GameState.completed_album.clear()
	GameState.journey_history.clear()
	GameState.unlocked_views.clear()
	GameState.claimed_achievements.clear()
	GameState.scene_paper = 0
	GameState.total_focus_count = 0
	GameState.total_focus_minutes = 0.0
	GameState.total_pieces_dropped = 0
	GameState.pomodoro_count = 0
	GameState.today_minutes = 0.0
	GameState.current_puzzle_id = "picnic"
	GameState.puzzles_cache.clear()

func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	_reset()
	# ===== v4 基线 =====
	var br: Control = (load("res://scenes/bookroom.tscn") as PackedScene).instantiate() as Control
	add_child(br)
	await _f(30)
	check("书房场景", br.get_node("Scene").texture != null)
	check("菜单热区>=6", br.get_node("MenuLayer").get_child_count() >= 6)
	br.queue_free()
	await _f(10)
	var page: Control = (load("res://scenes/play_page.tscn") as PackedScene).instantiate() as Control
	add_child(page)
	await _f(30)
	var board = page.get_node_or_null("BoardHolder/PuzzleBoard")
	check("拼图板", board != null)
	var poly_n := 0
	for p in board.pieces:
		if p._poly.size() > 8:
			poly_n = p._poly.size()
			break
	check("咬合碎片", poly_n >= 18)
	check("边表确定性", Jigsaw.make_edges(12, 12, 1).h.size() == 156)
	FocusEngine.debug_drop_interval = 1.5
	FocusEngine.start_focus(25.0)
	await _f(8 * 60)
	var c1: int = GameState.collected_count()
	check("掉落>=3", c1 >= 3, "got %d" % c1)
	var hidden := 0
	for p in board.pieces:
		if p.cell_state == PuzzlePiece.CELL_HIDDEN:
			hidden += 1
	check("收集同步", hidden == 144 - c1)
	check("按日记录", GameState.history.has(Time.get_date_string_from_system()))
	check("计时走秒", page._timer_label != null and page._timer_label.text != "25:00")
	## v6-34：首分钟文案"专注X秒"（无"分"字）——断言兼容两种格式
	check("结算文案", page.get_node("Toast/ToastLabel").text.match("专注*秒~奖励拼图碎片×*"), page.get_node("Toast/ToastLabel").text)
	check("计数卡", page._counter_l1.text.begins_with("已完成"))
	FocusEngine.give_up_focus()
	await _f(10)
	FocusEngine.debug_drop_interval = 0.0
	FocusEngine.start_focus(1.0 / 60.0)
	await _f(90)
	check("番茄完成", GameState.journey_focus_count >= 1)
	check("休息遮罩", page._break_overlay != null and is_instance_valid(page._break_overlay))
	FocusEngine.skip_break()
	await _f(10)
	check("跳过休息", FocusEngine.state == FocusEngine.STATE_IDLE)
	page.queue_free()
	await _f(10)
	# ===== v5 官方承诺链路 =====
	_reset()
	var page2: Control = (load("res://scenes/play_page.tscn") as PackedScene).instantiate() as Control
	add_child(page2)
	await _f(30)
	var board2 = page2.get_node_or_null("BoardHolder/PuzzleBoard")
	for i in 20:
		GameState.collect_piece(i)
	board2.refresh_from_game_state()
	page2._enter_puzzle_mode()
	await _f(5)
	check("拼图模式", page2._in_puzzle_mode)
	var drag := 0
	for p in board2.pieces:
		if p.cell_state == PuzzlePiece.CELL_COLLECTED:
			drag += 1
	check("托盘可拖=20", drag == 20, "got %d" % drag)
	page2._auto_solve_pressed()
	await _f(int(20 * 0.08 * 60) + 90)
	check("自动拼=20", GameState.placed_count() == 20, "got %d" % GameState.placed_count())
	page2.queue_free()
	await _f(10)
	# 工具与窗景
	_reset()
	TodoData.clear_all()
	TodoData.add("测试A", "study")
	check("Todo 1 条", TodoData.items().size() == 1)
	CounterData.save_data("页数", 32)
	check("计数器", int(CounterData.load_data().value) == 32)
	SettingsData.set_value("nickname", "旅人2")
	check("设置昵称", String(SettingsData.get_value("nickname", "")) == "旅人2")
	GameState.scene_paper = 5
	check("窗景兑换", GameState.unlock_view("snow"))
	check("窗景解锁", GameState.is_view_unlocked("snow"))
	# 成就多分类
	GameState.total_focus_count = 3
	GameState.completed_album.append("picnic")
	var ach_n := 0
	for a in GameState.ACHIEVEMENTS:
		if GameState.is_achieved(a):
			ach_n += 1
	check("成就多分类", ach_n >= 3, "got %d" % ach_n)
	# 存档总恢复
	GameState.save_game()
	var saved_c: int = GameState.collected_count()
	GameState.collected.clear()
	GameState.load_game()
	check("存档恢复", GameState.collected_count() == saved_c)
	var jl: Control = (load("res://scenes/journey_letter.tscn") as PackedScene).instantiate() as Control
	add_child(jl)
	await _f(20)
	check("旅程信昵称", String(jl.get_node("LetterCard/InnerPad/H/TextCol").get_child(0).get_child(0).text).begins_with("嗨，"))
	jl.queue_free()
	await _f(10)
	print("== V5 REGRESSION: %d pass %d fail ==" % [_pass, _fail])
	if _fail == 0:
		print("V5 ALL PASS")
	get_tree().quit()
