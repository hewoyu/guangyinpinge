extends Node
## task-24/25/26 验收：Todo 完整版 / 计数器+备忘 / 周便签

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://todo.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://counter.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://weekly_notes.json"))
	var page: Control = (load("res://scenes/play_page.tscn") as PackedScene).instantiate() as Control
	add_child(page)
	await get_tree().process_frame
	# ---- 24 Todo ----
	TodoData.add("读30页书", "study")
	TodoData.add("回导师邮件", "work")
	TodoData.add("买猫粮", "life")
	check("Todo 持久化 3 条", TodoData.items().size() == 3)
	page._refresh_side()
	await get_tree().process_frame
	## 计时态右栏才显示待办卡 → 先验证 FOCUSING 态
	FocusEngine.start_focus(25.0)
	await get_tree().process_frame
	## 找到 TodoInput（证明完整卡在计时态渲染）
	var found_input := false
	for c in page.get_node("SidePanel").get_children():
		if c is PanelContainer:
			var input := c.find_child("TodoInput", true, false)
			if input != null:
				found_input = true
				break
	check("计时态待办卡渲染（输入行）", found_input)
	TodoData.toggle(0)
	check("勾选完成", bool(TodoData.items()[0].done))
	TodoData.remove(1)
	check("删除后 2 条", TodoData.items().size() == 2)
	# ---- 25 计数器 ----
	var cd := CounterData.load_data()
	check("计数器默认标题", cd.title == "精读页数")
	CounterData.save_data("单词数", 24)
	var cd2 := CounterData.load_data()
	check("计数器改标题+值", cd2.title == "单词数" and cd2.value == 24)
	CounterData.save_memo("测试备忘内容")
	check("备忘持久化", CounterData.load_memo() == "测试备忘内容")
	# ---- 26 周便签 ----
	var notes := CounterData.load_notes()
	check("周便签默认 3 点", notes.points.size() == 3)
	CounterData.save_notes(["1. 自定义重点"], ["- 自定义记得"])
	var notes2 := CounterData.load_notes()
	check("周便签自定义持久化", notes2.points[0] == "1. 自定义重点" and notes2.remembers[0] == "- 自定义记得")
	FocusEngine.give_up_focus()
	print("== TEST TOOLS: %d pass %d fail ==" % [_pass, _fail])
	get_tree().quit()
