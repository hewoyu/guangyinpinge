extends Node
## task-28 验收：待办管理 12 卡 + 列表/归档 + 数据页

var _pass := 0
var _fail := 0

func check(n: String, c: bool, extra: String = "") -> void:
	if c:
		_pass += 1
		print("PASS  ", n)
	else:
		_fail += 1
		print("FAIL  ", n, " ", extra)

func _live_children(parent: Control) -> int:
	var n := 0
	for c in parent.get_children():
		if not c.is_queued_for_deletion():
			n += 1
	return n

func _ready() -> void:
	var demo := [
		{"text": "任务A", "done": false, "category": "study", "created_at": 1791100000, "done_at": 0},
		{"text": "任务B", "done": false, "category": "work", "created_at": 1791200000, "done_at": 0},
		{"text": "任务C", "done": false, "category": "life", "created_at": 1791210000, "done_at": 0},
		{"text": "任务D", "done": true, "category": "study", "created_at": 1791000000, "done_at": 1791003600},
		{"text": "任务E", "done": true, "category": "urgent", "created_at": 1791010000, "done_at": 1791020000},
	]
	var f := FileAccess.open("user://todo.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(demo))
	f.close()
	var ts: Node = (load("res://scenes/todo_stats.tscn") as PackedScene).instantiate()
	add_child(ts)
	await get_tree().process_frame
	var content: Control = ts.get_node("Content") as Control
	# 统计段：找 GridContainer
	var grid: GridContainer = null
	for c in content.get_children():
		if c is GridContainer and not c.is_queued_for_deletion():
			grid = c as GridContainer
			break
	check("统计段 12 卡", grid != null and grid.get_child_count() == 12, "got %d" % (grid.get_child_count() if grid else -1))
	if grid:
		check("卡1 总数=5", grid.get_child(0).get_child(0).get_child(0).text == "5")
		check("卡3 完成=2", grid.get_child(2).get_child(0).get_child(0).text == "2")
	# 列表段
	ts.call("_switch", "列表")
	await get_tree().process_frame
	check("列表段 3 行", _live_children(content) == 3, "got %d" % _live_children(content))
	# 归档段
	ts.call("_switch", "归档")
	await get_tree().process_frame
	check("归档段 2 行", _live_children(content) == 2, "got %d" % _live_children(content))
	ts.queue_free()
	await get_tree().process_frame
	# 数据管理页
	var dm: Control = (load("res://scenes/data_manage.tscn") as PackedScene).instantiate() as Control
	add_child(dm)
	await get_tree().process_frame
	check("数据页概览 4 卡", dm.get_node("Overview").get_child_count() == 4)
	dm.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://todo.json"))
	print("== TEST TODO_STATS: %d pass %d fail ==" % [_pass, _fail])
	get_tree().quit()
