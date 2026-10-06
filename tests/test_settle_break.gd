extends Node
## task-22/23 验收：结算文案格式 + 休息遮罩

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_v3.json"))
	GameState.collected.clear()
	GameState.placed.clear()
	GameState.current_puzzle_id = "picnic"
	GameState.puzzles_cache.clear()
	var page: Control = (load("res://scenes/play_page.tscn") as PackedScene).instantiate() as Control
	add_child(page)
	await get_tree().process_frame
	# 1) 掉落结算文案（官方格式）
	FocusEngine.debug_drop_interval = 1.5
	FocusEngine.start_focus(25.0)
	await get_tree().create_timer(5.0).timeout
	var toast: Label = page.get_node("Toast/ToastLabel")
	var ok1: bool = toast.text.match("专注*分*秒~奖励拼图碎片×*")
	check("掉落文案官方格式", ok1 and FocusEngine.session_pieces >= 2, toast.text + " | pieces=" + str(FocusEngine.session_pieces))
	# 2) 徽章=碎片数
	var badge: Label = page.get_node("Toast/Badge")
	check("徽章=本轮碎片数", badge.text == str(FocusEngine.session_pieces), badge.text)
	FocusEngine.give_up_focus()
	await get_tree().process_frame
	# 3) 休息遮罩：快速完成一轮 → BREAK
	FocusEngine.debug_drop_interval = 0.0
	FocusEngine.start_focus(1.0 / 60.0)
	await get_tree().create_timer(2.0).timeout
	check("进入 BREAK", FocusEngine.state == FocusEngine.STATE_BREAK)
	await get_tree().create_timer(0.5).timeout
	check("遮罩出现", page._break_overlay != null and is_instance_valid(page._break_overlay))
	check("遮罩倒计时显示", page._break_timer_label != null and page._break_timer_label.text != "05:00", page._break_timer_label.text if page._break_timer_label else "null")
	# 4) 跳过
	FocusEngine.skip_break()
	await get_tree().create_timer(0.5).timeout
	check("跳过回 IDLE", FocusEngine.state == FocusEngine.STATE_IDLE)
	check("遮罩移除", page._break_overlay == null or not is_instance_valid(page._break_overlay))
	print("== TEST SETTLE/BREAK: %d pass %d fail ==" % [_pass, _fail])
	get_tree().quit()
