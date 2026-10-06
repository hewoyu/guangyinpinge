extends Node
## 玩家模拟器：以真实按钮信号驱动完整游玩流，记录每步体验
## 命令行窗口模式运行，观察 stdout

var _step := 0
var _fails: Array[String] = []
var _notes: Array[String] = []

func note(text: String) -> void:
	_notes.append(text)
	print("[", _step, "]", text)

func ok(cond: bool, fail_text: String = "") -> void:
	if not cond and fail_text != "":
		_fails.append(fail_text)
		print("   !!FAIL: ", fail_text)

func _press(root: Node, label: String) -> bool:
	## 递归找按钮并触发 pressed（玩家点击路径）
	return _press_rec(root, label)

func _press_rec(n: Node, label: String) -> bool:
	for c in n.get_children():
		if c is Button and String(c.text).contains(label):
			c.emit_signal("pressed")
			return true
		if _press_rec(c, label):
			return true
	return false

func _ready() -> void:
	# 清档（新玩家）
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_v3.json"))
	GameState.collected.clear()
	GameState.placed.clear()
	GameState.completed_album.clear()
	GameState.current_puzzle_id = "picnic"
	GameState.puzzles_cache.clear()
	GameState.scene_paper = 0
	GameState.claimed_achievements.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://todo.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.json"))

	note("[探针] 清档后内存 unlocked=" + str(GameState.unlocked_views))
	# ===== 旅程开始：书房 =====
	_step = 1
	var br: Control = (load("res://scenes/bookroom.tscn") as PackedScene).instantiate() as Control
	note("[探针] add_child 前 unlocked=" + str(GameState.unlocked_views))
	add_child(br)
	note("[探针] br._ready 后 unlocked=" + str(GameState.unlocked_views))
	await _f(60)
	note("书房：菜单入口可见=" + str(br.get_node("MenuLayer").get_child_count() >= 6))
	ok(br.get_node("MenuLayer").get_child_count() >= 6, "菜单不足")
	note("窗景层(未解锁=隐藏)正确=" + str(not br.get_node("WindowView").visible))

	# 验证开始旅程按钮存在（不真点：change_scene 会销毁测试树）
	_step = 2
	var cta_exists := false
	for c in br.get_node("MenuLayer").get_children():
		if c is Button and String(c.text) == "开始旅程":
			cta_exists = true
	note("开始旅程按钮存在=" + str(cta_exists))
	# 窗景调试：为何未解锁却显示
	note("[窗景调试] unlocked=" + str(GameState.unlocked_views) + " latest=" + str(GameState.latest_unlocked_view()))
	var wv = br.get_node("WindowView")
	note("[窗景调试] wv.visible=" + str(wv.visible) + " tex=" + str(wv.texture != null))

	# ===== 玩法页（直接实例化保持链路） =====
	br.queue_free()
	await _f(10)
	var page: Control = (load("res://scenes/play_page.tscn") as PackedScene).instantiate() as Control
	add_child(page)
	await _f(60)
	_step = 3
	note("玩法页空闲态：任务卡标题=" + str(GameState.get_current_puzzle().title))
	note("底部初始提示=" + page.get_node("Toast/ToastLabel").text)
	var board = page.get_node_or_null("BoardHolder/PuzzleBoard")
	ok(board != null, "棋盘缺失")
	note("空棋盘观感：全部空位米白=" + str(page._counter_l1.text == "已完成 0/144 块"))

	# ===== 开始专注 =====
	_step = 4
	FocusEngine.debug_drop_interval = 2.0   # QA快进：2秒掉落（真实=2-5分钟）
	ok(_press(page, "开始"), "开始按钮找不到")
	await _f(40)
	note("专注中：计时=" + str(page._timer_label.text) + " 右栏走秒=" + str(page._timer_label.text != "25:00"))
	note("番茄钟副题=" + str(page._timer_label.text != ""))

	# 等掉落 3 块
	_step = 5
	await _f(6 * 60)
	note("掉落后：collected=" + str(GameState.collected_count()) + " toast=" + str(page.get_node("Toast/ToastLabel").text))
	ok(GameState.collected_count() >= 2, "没掉落")

	# ===== 暂停/恢复 =====
	_step = 6
	ok(_press(page, "暂停"), "暂停按钮")
	await _f(30)
	var paused_sec: float = FocusEngine.remaining_sec
	await _f(30)
	note("暂停冻结计时=" + str(absf(FocusEngine.remaining_sec - paused_sec) < 0.01))
	ok(absf(FocusEngine.remaining_sec - paused_sec) < 0.01, "暂停仍计时")
	# 恢复无按钮（bug 调查点）：paused 态下点"开始"？
	var start_again = _press(page, "开始")
	note("暂停态点开始是否可用(官方无resume按钮)=" + str(start_again))

	# ===== 结束专注 =====
	_step = 7
	ok(_press(page, "结束"), "结束按钮")
	await _f(30)
	note("结束态=" + str(FocusEngine.state == FocusEngine.STATE_IDLE) + " 结算文案=" + str(page.get_node("Toast/ToastLabel").text))

	# ===== 拼图模式 =====
	_step = 8
	ok(_press(page, "拼图模式"), "拼图模式按钮")
	await _f(30)
	note("拼图模式态=" + str(page._in_puzzle_mode))
	var drag := 0
	for p in board.pieces:
		if p.cell_state == PuzzlePiece.CELL_COLLECTED:
			drag += 1
	note("托盘可拖碎片=" + str(drag))

	# 手动拼 1 块（玩家拖拽模拟：直接位移+触发吸附）
	_step = 9
	for p in board.pieces:
		if p.cell_state == PuzzlePiece.CELL_COLLECTED:
			p.global_position = p.target_global_pos()
			p._try_snap()
			break
	await _f(10)
	note("手动拼1块后 placed=" + str(GameState.placed_count()))
	ok(GameState.placed_count() == 1, "手动拼未计")

	# ===== 自动拼 =====
	_step = 10
	ok(_press(page, "自动拼"), "自动拼按钮")
	var auto_wait := int(drag * 0.08 * 60) + 90
	await _f(auto_wait)
	note("自动拼完成 placed=" + str(GameState.placed_count()) + " 退出拼图模式=" + str(not page._in_puzzle_mode))

	# ===== 明信片 =====
	_step = 11
	await _f(120)
	var pc = null
	for c in page.get_children():
		if c.name == "Postcard":
			pc = c
	note("明信片弹出=" + str(pc != null))
	if pc:
		note("明信片文案含旅程数=" + str(String(pc.get_node("Card/VBox/BlessingLabel").text).length() > 5))
		pc._on_keep()
		await _f(30)
		note("收图后归档=" + str(GameState.completed_album.has("picnic")) + " 切换到=" + GameState.current_puzzle_id)
	page.queue_free()
	await _f(20)

	# ===== 全页面巡游 =====
	_step = 12
	for pair in [
		["统计页", "res://scenes/stats_page.tscn", "stats_page"],
		["成就页", "res://scenes/achievements_page.tscn", "achievements_page"],
		["音乐盒", "res://scenes/music_box.tscn", "music_box"],
		["设置页", "res://scenes/settings_page.tscn", "settings_page"],
		["拼图选择", "res://scenes/puzzle_select.tscn", "puzzle_select"],
		["旅程回顾", "res://scenes/journey_review.tscn", "journey_review"],
		["关于教程", "res://scenes/about_page.tscn", "about_page"],
	]:
		var scn: Control = (load(String(pair[1])) as PackedScene).instantiate() as Control
		add_child(scn)
		await _f(40)
		var alive: bool = is_instance_valid(scn) and scn.is_inside_tree()
		note(pair[0] + " 打开" + ("" if alive else "（异常）"))
		ok(alive, pair[0] + " 崩溃")
		if not alive:
			continue
		# 页内交互抽查
		match String(pair[2]):
			"stats_page":
				var tabs_n: int = scn.get_node("Tabs").get_child_count()
				note("  统计标签数=" + str(tabs_n))
			"achievements_page":
				note("  成就景笺=0（新玩家）=" + str(GameState.scene_paper == 0))
			"music_box":
				var op_row = _find_text(scn, "本地添加")
				note("  音乐盒操作行存在=" + str(op_row))
			"settings_page":
				note("  设置音量初值读取=" + str(float(SettingsData.get_value("sfx_vol", 0.7))))
		scn.queue_free()
		await _f(20)

	# ===== 设置操作：音量+昵称 =====
	_step = 13
	var sp2: Control = (load("res://scenes/settings_page.tscn") as PackedScene).instantiate() as Control
	add_child(sp2)
	await _f(30)
	SettingsData.set_value("nickname", "拾光者")
	SettingsData.set_value("bgm_vol", 0.35)
	SoundManager.set_bgm_volume(0.35)
	note("设置写入昵称/音量 OK")
	sp2.queue_free()
	await _f(10)

	# ===== 旅程信昵称联动 =====
	_step = 14
	var jl: Control = (load("res://scenes/journey_letter.tscn") as PackedScene).instantiate() as Control
	add_child(jl)
	await _f(40)
	var greet: String = String(jl.get_node("LetterCard/InnerPad/H/TextCol").get_child(0).get_child(0).text)
	note("旅程信称呼=" + greet)
	ok(greet.contains("拾光者"), "昵称未联动: " + greet)
	jl.queue_free()
	await _f(10)

	# ===== 存档恢复（玩家关游戏再开） =====
	_step = 15
	GameState.save_game()
	var saved_p: int = GameState.placed_count()
	GameState.placed.clear()
	GameState.collected.clear()
	GameState.load_game()
	note("重开进度恢复 placed=" + str(GameState.placed_count()) + "/" + str(saved_p))
	ok(GameState.placed_count() == saved_p, "进度丢失")

	# ===== 总结 =====
	print("")
	print("========== 玩家模拟总结 ==========")
	print("发现 FAIL 数: ", _fails.size())
	for f in _fails:
		print("  - ", f)
	print("观察笔记数: ", _notes.size())
	get_tree().quit()

func _find_text(root: Node, text: String) -> bool:
	for c in root.get_children():
		if c is Button and String(c.text).contains(text):
			return true
		if _find_text(c, text):
			return true
	return false

func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame
