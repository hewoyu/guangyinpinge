extends Node
## task-9 冒烟测试 runner（以场景方式运行，autoload 可用）
## 用法：Godot --headless --path . res://tests/ui_smoke_v3.tscn --quit-after 600

var fails: Array[String] = []

func _ready() -> void:
	await _run()
	get_tree().quit(1 if not fails.is_empty() else 0)

func _run() -> void:
	await get_tree().process_frame
	# 清理测试残留存档（todo/counter），确保断言环境干净
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://todo.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://counter.json"))
	var ps: PackedScene = load("res://scenes/workspace.tscn")
	if ps == null:
		_fail("workspace.tscn 加载失败")
		return
	var ws: Control = ps.instantiate()
	get_tree().root.add_child(ws)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# 1. 番茄钟 idle 显示 + 启动
	var time_label: Label = ws.get_node("TopBar/TimerZone/Ring/TimeLabel")
	var start_btn: Button = ws.get_node("TopBar/ControlZone/StartButton")
	if not time_label.text.contains("25"):
		_fail("idle 计时显示=%s（期望含 25）" % time_label.text)
	start_btn.pressed.emit()
	await _frames(15)
	if FocusEngine.state != FocusEngine.STATE_FOCUSING:
		_fail("start_focus 后状态=%d 期望 FOCUSING(%d)" % [FocusEngine.state, FocusEngine.STATE_FOCUSING])

	# 2. 工具面板开/关
	var tool_bar: VBoxContainer = ws.get_node("Body/ToolBar")
	var todo_btn: Button = tool_bar.get_child(0)
	todo_btn.pressed.emit()
	await _frames(3)
	var panel: PanelContainer = ws.get_node("Body/ToolPanel")
	if not panel.visible:
		_fail("todo 面板未打开")
	todo_btn.pressed.emit()
	await _frames(3)
	if panel.visible:
		_fail("todo 面板未关闭")

	# 3. 白噪音切换
	var noise_btn: Button = tool_bar.get_child(4)
	noise_btn.pressed.emit()
	await _frames(3)
	if not panel.visible:
		_fail("noise 面板未打开")
	var noise_panel: VBoxContainer = ws.get_node("Body/ToolPanel/Content").get_child(0)
	var rain_btn: Button = null
	for c in noise_panel.get_node("List").get_children():
		if c is Button and "雨" in c.text:
			rain_btn = c
	if rain_btn == null:
		_fail("找不到雨声按钮")
	else:
		rain_btn.pressed.emit()
		await _frames(3)
		if SoundManager.current_ambient != "rain":
			_fail("白噪音切换后=%s 期望 rain" % SoundManager.current_ambient)

	# 4. 放弃 → idle
	var give_up: Button = ws.get_node("TopBar/ControlZone/GiveUpButton")
	if give_up.disabled:
		_fail("运行中放弃按钮应可用")
	give_up.pressed.emit()
	await _frames(3)
	if FocusEngine.state != FocusEngine.STATE_IDLE:
		_fail("give_up 后状态=%d 期望 IDLE(%d)" % [FocusEngine.state, FocusEngine.STATE_IDLE])

	# 5. 拼图切换
	var switch_row: HBoxContainer = ws.get_node("Body/CenterZone/InfoBar/SwitchRow")
	var starry_btn: Button = switch_row.get_child(1)
	starry_btn.button_pressed = true  ## toggle 按钮用状态翻转触发 toggled
	await _frames(5)
	if GameState.current_puzzle_id != "starry":
		_fail("拼图切换后=%s 期望 starry" % GameState.current_puzzle_id)

	# 6. 碎片收集联动 + 板刷新
	GameState.collect_piece(0)
	GameState.collect_piece(1)
	await _frames(3)
	if GameState.collected_count() < 1:
		_fail("collect_piece 未生效")
	var board: Control = ws.get_node("Body/CenterZone/BoardHolder")
	if board.get_child_count() < GameState.TOTAL_PIECES:
		_fail("拼图板子节点=%d 期望 %d" % [board.get_child_count(), GameState.TOTAL_PIECES])

	# 7. Todo 增加一条
	todo_btn.pressed.emit()
	await _frames(3)
	var todo_panel: VBoxContainer = ws.get_node("Body/ToolPanel/Content").get_child(0)
	var input: LineEdit = todo_panel.get_node("InputRow/Input")
	input.text = "测试条目"
	todo_panel.get_node("InputRow/AddButton").pressed.emit()
	await _frames(3)
	var list: VBoxContainer = todo_panel.get_node("Scroll/List")
	if list.get_child_count() != 1:
		_fail("todo 添加后行数=%d 期望 1" % list.get_child_count())

	ws.queue_free()
	await _frames(2)
	if fails.is_empty():
		print("SMOKE OK — 全部通过")
	else:
		for f in fails:
			print("  FAIL: ", f)
		print("SMOKE FAILURES=", fails.size())

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _fail(msg: String) -> void:
	fails.append(msg)
