extends Node
## task-40 验收：TodoData 直连后 todo_stats 正常 + 窗景商店状态健康

var _pass := 0
var _fail := 0

func check(n: String, c: bool, extra: String = "") -> void:
	if c:
		_pass += 1
		print("PASS  ", n)
	else:
		_fail += 1
		print("FAIL  ", n, "  ", extra)

func _ready() -> void:
	# 1) TodoData 类全局注册（GDScript class_name 不进 ClassDB，直接引用验证）
	check("TodoData class_name 已注册", TodoData.PATH == "user://todo.json" and TodoData.add != null)
	# 2) items() 返回 Array（读 user://todo.json，可为空）
	var items: Array = TodoData.items()
	check("TodoData.items() 返回 Array", items is Array, "got %s" % typeof(items))
	# 3) 预置演示逻辑：写空文件后 items() 为空
	TodoData.save([])
	check("空文件时 items() 为空", TodoData.items().is_empty())
	# 4) todo_stats 页实例化（内部 _load_todo 直连 TodoData）
	var ps: PackedScene = load("res://scenes/todo_stats.tscn")
	check("todo_stats.tscn 加载", ps != null)
	await get_tree().process_frame
	var page: Control = ps.instantiate()
	get_tree().root.add_child(page)
	await get_tree().process_frame
	check("todo_stats 实例化进入树", is_instance_valid(page) and page.is_inside_tree())
	# 演示数据兜底后统计卡有值（content 内 GridContainer 已建）
	var grid: GridContainer = page.get_node("Content").get_child(0) as GridContainer
	check("统计卡 12 张已建", grid != null and grid.get_child_count() == 12,
		"children=%d" % (grid.get_child_count() if grid else -1))
	page.queue_free()
	await get_tree().process_frame
	# 5) 窗景商店状态健康（v5-29 遗留数据结构仍可用）
	check("窗景商店 4 景", GameState.WINDOW_VIEWS.size() == 4)
	check("图库 9 幅", GameState.PUZZLES.size() == 9, "got %d" % GameState.PUZZLES.size())
	print("== TEST E LEGACY: %d pass %d fail ==" % [_pass, _fail])
	get_tree().quit()
