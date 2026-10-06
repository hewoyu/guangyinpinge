extends Node
## task-20 验收：完成拼图 → 显影 → 会动的明信片 → 收图 → 切下一幅
## 注意：_on_keep 触发 reload_current_scene（重载本测试）——加运行标记防循环，
## 且归档断言须在 _on_keep 后同步执行（reload 在帧末）。

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
	## 防重载循环：第二轮直接退（首轮已完整验证）
	if get_tree().root.has_meta("pc_chain_ran"):
		print("== TEST POSTCARD CHAIN (rerun suppressed): %d pass %d fail ==" % [_pass, _fail])
		get_tree().quit()
		return
	get_tree().root.set_meta("pc_chain_ran", true)
	# 清档
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_v3.json"))
	GameState.collected.clear()
	GameState.placed.clear()
	GameState.completed_album.clear()
	GameState.claimed_achievements.clear()
	GameState.scene_paper = 0
	GameState.current_puzzle_id = "picnic"
	GameState.puzzles_cache.clear()
	var page: Control = (load("res://scenes/play_page.tscn") as PackedScene).instantiate() as Control
	add_child(page)
	await get_tree().process_frame
	var board = page.get_node_or_null("BoardHolder/PuzzleBoard")
	check("board 存在", board != null)
	for i in GameState.TOTAL_PIECES:
		GameState.collect_piece(i)
		GameState.place_piece(i)
	board.refresh_from_game_state()
	await get_tree().create_timer(3.0).timeout   # 显影1.4s + 明信片弹出
	var pc = null
	for c in page.get_children():
		if c.name == "Postcard":
			pc = c
	check("明信片已弹出", pc != null)
	if pc:
		var fx = pc.get_node_or_null("Card/VBox/PictureFrame/EffectsLayer")
		check("动效运行(节点>0)", fx != null and fx.get_child_count() > 0, "fx=%d" % (fx.get_child_count() if fx else -1))
		## done 在收图动画（0.4s）后 emit → done 回调里断言（_next 同步完成、reload 帧末才执行）
		pc.done.connect(func():
			check("当前拼图已归档", GameState.completed_album.has("picnic"))
			check("切到下一幅 starry", GameState.current_puzzle_id == "starry")
			print("== TEST POSTCARD CHAIN: %d pass %d fail ==" % [_pass + 2, _fail])
			get_tree().quit())
		pc._on_keep()
	else:
		check("当前拼图已归档", false, "no postcard")
		print("== TEST POSTCARD CHAIN: %d pass %d fail ==" % [_pass, _fail])
		get_tree().quit()
