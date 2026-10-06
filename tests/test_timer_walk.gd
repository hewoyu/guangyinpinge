extends Node
## 倒计时走秒验证（v5 用户报告 bug 的修复验证）
## 开始专注 → 取 T0 文本 → 等 3 秒 → 取 T1 文本 → 断言不同且减少

func _ready() -> void:
	var page: Control = (load("res://scenes/play_page.tscn") as PackedScene).instantiate() as Control
	add_child(page)
	await get_tree().process_frame
	# 开始专注（25 分钟）
	FocusEngine.start_focus(25.0)
	await get_tree().create_timer(0.8).timeout
	var t0 := String(page._timer_label.text)
	await get_tree().create_timer(3.0).timeout
	var t1 := String(page._timer_label.text)
	print("T0=", t0, " T1=", t1)
	if t0 != t1 and t1 < t0:
		print("TIMER WALKING: PASS")
	else:
		print("TIMER STUCK: FAIL")
	FocusEngine.give_up_focus()
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()
