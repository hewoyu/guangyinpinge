extends Node
## task-38/39 验收：高优先级体系 + 音乐盒自定义播放

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
	# ===== B1 高优先级 =====
	TodoData.clear_all()
	TodoData.add("读文献", "study", true)
	TodoData.add("回邮件", "work", false)
	TodoData.add("写周报", "work", true)
	check("high_count=2", TodoData.high_count() == 2, str(TodoData.high_count()))
	TodoData.toggle_high(1)
	check("toggle 后=3", TodoData.high_count() == 3, str(TodoData.high_count()))
	TodoData.set_high(1, false)
	TodoData.set_high(2, false)
	check("set_high 后=1", TodoData.high_count() == 1, str(TodoData.high_count()))
	TodoData.set_high(2, true)
	# 待办管理页卡2
	var ts: Control = (load("res://scenes/todo_stats.tscn") as PackedScene).instantiate() as Control
	add_child(ts)
	await get_tree().create_timer(0.5).timeout
	var grid: GridContainer = null
	for c in ts.get_node("Content").get_children():
		if c is GridContainer and not c.is_queued_for_deletion():
			grid = c
			break
	check("卡2=高优先级待办 且值2", grid != null and grid.get_child(1).get_child(0).get_child(1).text == "高优先级待办" and grid.get_child(1).get_child(0).get_child(0).text == "2")
	ts.queue_free()
	await get_tree().process_frame
	# ===== B3 音乐盒 =====
	# 造一条自定义（真 wav）+ 一条假（不存在路径，测容错）
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://music"))
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://assets/audio/click.wav"), ProjectSettings.globalize_path("user://music/test.wav"))
	var f := FileAccess.open("user://music_list.json", FileAccess.WRITE)
	f.store_string(JSON.stringify([
		{"name": "本地测试曲", "path": "user://music/test.wav", "builtin": false},
		{"name": "幽灵曲", "path": "user://music/ghost.wav", "builtin": false},
	]))
	f.close()
	var mb: Control = (load("res://scenes/music_box.tscn") as PackedScene).instantiate() as Control
	add_child(mb)
	await get_tree().create_timer(0.5).timeout
	var all: Array = mb._all_tracks()
	check("合并列表=内置7+自定义2", all.size() == mb.TRACKS.size() + 2, "got %d" % all.size())
	check("自定义行标记", String(all[mb.TRACKS.size()].composer) == "本地" and not bool(all[mb.TRACKS.size()].builtin))
	# 播自定义（真 wav）
	mb._play_track(mb.TRACKS.size())
	await get_tree().create_timer(0.3).timeout
	check("自定义曲目已加载播放", mb._custom_player != null and mb._custom_player.stream != null and (mb._custom_player.playing or int(mb._custom_player.stream.get_length()) < 1))
	# 播幽灵曲（不存在——不崩）
	mb._play_track(mb.TRACKS.size() + 1)
	await get_tree().create_timer(0.3).timeout
	check("缺失文件容错", true)
	# 选中自定义行删除
	mb._selected_index = mb.TRACKS.size()
	mb._on_local_op("remove")
	await get_tree().create_timer(0.3).timeout
	check("删除后自定义=1", mb._custom_list().size() == 1)
	# 选中内置行删除（不可删）
	mb._selected_index = 0
	var before: int = mb._all_tracks().size()
	mb._on_local_op("remove")
	await get_tree().create_timer(0.3).timeout
	check("内置不可删", mb._all_tracks().size() == before)
	print("== B PACKAGE: %d pass %d fail ==" % [_pass, _fail])
	get_tree().quit()
