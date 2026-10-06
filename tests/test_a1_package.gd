extends Node
## task-34 验收（修正版）：拼图辅助开关/结束确认/首分钟文案/暂停提醒

var _pass := 0
var _fail := 0

func check(n: String, c: bool, extra: String = "") -> void:
	if c:
		_pass += 1
		print("PASS  ", n)
	else:
		_fail += 1
		print("FAIL  ", n, " ", extra)

func _count_btns(root: Node, label: String) -> int:
	var cnt := 0
	for c in root.get_children():
		if c is Button and not c.is_queued_for_deletion() and c.visible and String(c.text).contains(label):
			cnt += 1
		cnt += _count_btns(c, label)
	return cnt

func _find_stop(root: Node) -> Button:
	for c in root.get_children():
		if c is Button and not c.is_queued_for_deletion() and String(c.text) == "结束":
			return c
		var r := _find_stop(c)
		if r != null:
			return r
	return null

func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_v3.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.json"))
	GameState.collected.clear()
	GameState.placed.clear()
	var page: Control = (load("res://scenes/play_page.tscn") as PackedScene).instantiate() as Control
	add_child(page)
	await get_tree().create_timer(1.0).timeout
	var board = page.get_node_or_null("BoardHolder/PuzzleBoard")
	# 1) 排序开关
	for i in 5:
		GameState.collect_piece(i)
	board.refresh_from_game_state()
	page._enter_puzzle_mode()
	await get_tree().create_timer(0.3).timeout
	await get_tree().process_frame   # 让 queue_free 的旧卡真正删除
	check("默认开关开·自动拼按钮=1", _count_btns(page, "自动拼") == 1, "got %d" % _count_btns(page, "自动拼"))
	SettingsData.set_value("启用拼图排序按钮", false)
	page._exit_puzzle_mode()
	await get_tree().create_timer(0.2).timeout
	page._enter_puzzle_mode()
	await get_tree().create_timer(0.2).timeout
	await get_tree().process_frame
	check("开关关·自动拼按钮=0", _count_btns(page, "自动拼") == 0, "got %d" % _count_btns(page, "自动拼"))
	SettingsData.set_value("启用拼图排序按钮", true)
	page._exit_puzzle_mode()
	await get_tree().create_timer(0.2).timeout
	# 2) 首分钟文案
	FocusEngine.debug_drop_interval = 1.2
	FocusEngine.start_focus(25.0)
	await get_tree().create_timer(2.5).timeout
	var toast: Label = page.get_node("Toast/ToastLabel")
	check("首分钟文案（X秒无分字）", toast.text.match("专注*秒~奖励拼图碎片×*") and not toast.text.contains("分"), toast.text)
	FocusEngine.give_up_focus()
	await get_tree().create_timer(0.3).timeout
	# 3) 结束确认弹窗（先进入专注态才有"结束"按钮）
	FocusEngine.start_focus(25.0)
	await get_tree().create_timer(0.3).timeout
	var found := _find_stop(page)
	if found != null:
		found.emit_signal("pressed")
		await get_tree().create_timer(0.3).timeout
		var dlg := false
		for c in page.get_children():
			if c is ConfirmationDialog:
				dlg = true
		check("结束弹确认框", dlg)
		for c in page.get_children():
			if c is ConfirmationDialog:
				c.emit_signal("confirmed")
		await get_tree().create_timer(0.3).timeout
		check("确认后结束", FocusEngine.state == FocusEngine.STATE_IDLE)
	else:
		check("结束弹确认框", false, "no stop btn")
	# 4) 暂停提醒（lambda 捕获用数组——GDScript 值捕获坑）
	var fired: Array = []
	FocusEngine.start_focus(25.0)
	FocusEngine.pause_focus()
	FocusEngine.pause_too_long.connect(func(_t: float): fired.append(1))
	FocusEngine.pause_elapsed = 350.0
	FocusEngine._pause_reminded_sec = 0.0
	await get_tree().create_timer(0.5).timeout
	check("暂停超时提醒触发", fired.size() > 0)
	FocusEngine.give_up_focus()
	print("== A1 PACKAGE: %d pass %d fail ==" % [_pass, _fail])
	get_tree().quit()
