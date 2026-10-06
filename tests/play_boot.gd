extends Node
## v4 玩法页功能验证：咬合碎片 + 掉落 + 收集可视化 + 右栏两态

func _ready() -> void:
	# 清档保证初始状态
	var save_path := ProjectSettings.globalize_path("user://save_v3.json")
	DirAccess.remove_absolute(save_path)
	GameState.collected.clear()
	GameState.placed.clear()
	GameState.completed_album.clear()
	GameState.puzzles_cache.clear()
	var page: Control = load("res://scenes/play_page.tscn").instantiate()
	add_child(page)
	await get_tree().create_timer(1.5).timeout
	var board = page.get_node_or_null("BoardHolder/PuzzleBoard")
	if board == null:
		print("V4 FAIL: no board")
		_finish()
		return
	# 1) 咬合形验证：碎片有 polygon 且顶点数 > 8（方形只有 4）
	var poly_piece = null
	for p in board.pieces:
		if p._poly.size() > 8:
			poly_piece = p
			break
	print("JIGSAW POLY: ", poly_piece != null, " pts=", poly_piece._poly.size() if poly_piece else 0)
	# 2) 掉落 3 块
	FocusEngine.debug_drop_interval = 1.5
	FocusEngine.start_focus(25.0)
	await get_tree().create_timer(5.5).timeout
	print("COLLECTED: ", GameState.collected_count(), "/144 (期望 >=3)")
	# 3) 空位渲染：收集模式下空位米白
	var visible_states := 0
	for p in board.pieces:
		if p.cell_state == PuzzlePiece.CELL_HIDDEN:
			visible_states += 1
	print("HIDDEN slots: ", visible_states, " (期望 144-已收集)")
	# 4) 截图
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shot_play_v4.png")
	print("PLAY V4 SAVED")
	_finish()

func _finish() -> void:
	FocusEngine.give_up_focus()
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()
