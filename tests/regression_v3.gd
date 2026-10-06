extends Node
## v3 最终回归：番茄钟状态机流转 + 掉落 + 存档恢复 + 旧文件处置断言
## 运行：godot --path . --headless --fixed-fps 60 res://tests/regression_v3_boot.tscn --quit-after 4000

var _pass := 0
var _fail := 0

func check(name: String, cond: bool, extra: String = "") -> void:
	if cond:
		_pass += 1
		print("PASS  ", name)
	else:
		_fail += 1
		print("FAIL  ", name, " ", extra)

func _ready() -> void:
	# ---- 0. 旧 v2 文件处置 ----
	check("旧 v2 场景已删除", not ResourceLoader.exists("res://scenes/main.tscn") and not FileAccess.file_exists("res://scripts/main_menu.gd"))

	# ---- 1. 番茄钟状态流转 ----
	check("初始 IDLE", FocusEngine.state == FocusEngine.STATE_IDLE)
	FocusEngine.start_focus(0.75)  # 45 秒（缩短便于测试）
	check("start 后 FOCUSING", FocusEngine.state == FocusEngine.STATE_FOCUSING)
	await _frames(30)
	FocusEngine.pause_focus()
	check("pause 后 PAUSED", FocusEngine.state == FocusEngine.STATE_PAUSED)
	var frozen := FocusEngine.remaining_sec
	await _frames(60)
	check("PAUSED 完全冻结计时", absf(FocusEngine.remaining_sec - frozen) < 0.001, "rem=%.3f frozen=%.3f" % [FocusEngine.remaining_sec, frozen])
	FocusEngine.resume_focus()
	check("resume 回 FOCUSING", FocusEngine.state == FocusEngine.STATE_FOCUSING)

	# ---- 2. 掉落（2 秒一掉，等 7 秒收集 ~3 块） ----
	FocusEngine.give_up_focus()  # 结束 resume 后的原轮（guard 会挡 start，须先归零）
	await _frames(10)
	FocusEngine.debug_drop_interval = 2.0
	FocusEngine.start_focus(0.75)
	await _frames(7 * 60)
	var c1: int = GameState.collected_count()
	check("掉落发生 collected>=2", c1 >= 2, "got %d" % c1)

	# ---- 3. 完成流转 FOCUSING→BREAK→IDLE ----
	FocusEngine.give_up_focus()  # 结束掉落轮（含其统计数据）
	await _frames(10)
	FocusEngine.debug_drop_interval = 0.0
	var pomo_before: int = GameState.pomodoro_count
	FocusEngine.start_focus(1.0 / 60.0)  # 1 秒完成
	await _frames(90)
	check("完成进入 BREAK", FocusEngine.state == FocusEngine.STATE_BREAK)
	check("休息倒计时 5 分钟", absf(FocusEngine.break_remaining - 300.0) < 1.0, "rem=%.1f" % FocusEngine.break_remaining)
	check("番茄计数+1", GameState.pomodoro_count > pomo_before, "pomo=%d before=%d" % [GameState.pomodoro_count, pomo_before])
	var mins: float = GameState.today_minutes
	check("今日专注分钟累计>0", mins > 0.0, "%.2f" % mins)
	# 跳过休息
	FocusEngine.give_up_focus()
	check("give_up 回 IDLE", FocusEngine.state == FocusEngine.STATE_IDLE)

	# ---- 4. 存档恢复 ----
	var collected_before: int = GameState.collected_count()
	var placed_before: int = GameState.placed_count()
	GameState.save_game()
	# 模拟重启：清内存后重新加载
	GameState.collected.clear()
	GameState.placed.clear()
	GameState.load_game()
	check("存档恢复 collected 数量一致", GameState.collected_count() == collected_before, "%d vs %d" % [GameState.collected_count(), collected_before])
	check("存档恢复 placed 数量一致", GameState.placed_count() == placed_before)
	check("统计恢复（番茄数）", GameState.pomodoro_count >= 1)
	check("当前拼图 id 恢复", GameState.current_puzzle_id != "")

	# ---- 5. 拼图完成链路（自动拼到完成信号） ----
	var board = load("res://scenes/puzzle_board.tscn").instantiate()
	add_child(board)
	board.setup(load(GameState.get_current_puzzle().image), Vector2i(12, 12))
	var done_fired := false
	board.puzzle_completed.connect(func(): done_fired = true)
	# 全收集 + 全拼
	for i in GameState.TOTAL_PIECES:
		GameState.collect_piece(i)
		GameState.place_piece(i)
	board.exit_puzzle_mode()
	check("收集模式切换 OK", board.mode == board.MODE_COLLECTION)
	check("GameState 完成判定", GameState.is_current_puzzle_complete())

	# ---- 6. 明信片场景可用 ----
	var pc: Control = load("res://scenes/postcard.tscn").instantiate()
	add_child(pc)
	check("明信片实例化", pc != null and is_instance_valid(pc))
	pc.queue_free()
	board.queue_free()

	print("== REGRESSION RESULT: %d pass, %d fail ==" % [_pass, _fail])
	if _fail == 0:
		print("REGRESSION ALL PASS")
	get_tree().quit()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
