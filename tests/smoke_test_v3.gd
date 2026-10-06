extends Node
## v3 拼图板冒烟测试：双模式（收集可视化/拼图模式）+ 144 块 + 自动拼 + 完成信号
## 运行：godot --headless res://tests/smoke_test_v3.tscn（quit code = 失败数）
## 注意：直接驱动 PuzzleBoard + GameState，不走 FocusEngine（间隔 2-5 分钟不可测）。

var _fails := 0
var _checks := 0
var _completed_flag := false
var _collected_signal: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	# 清档（测试隔离）
	GameState.collected.clear()
	GameState.placed.clear()
	GameState.puzzles_cache.clear()
	var scene: PuzzleBoard = (load("res://scenes/puzzle_board.tscn") as PackedScene).instantiate()
	scene.size = Vector2(1280, 800)
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	# 场景未带贴图，显式 setup（工作台/测试统一入口）
	scene.setup(load("res://assets/images/puzzle_picnic.svg"), Vector2i(12, 12))
	await get_tree().process_frame

	print("== 基础构建 ==")
	_check(scene.pieces.size() == 144, "144 块碎片生成 (got %d)" % scene.pieces.size())
	_check(scene.total_pieces == 144, "total_pieces == 144")
	_check(scene.pieces[0].piece_index == 0, "piece_index 行主序 (0,0)=0")
	_check(scene.pieces[13].piece_index == 13, "(1,1)=13")
	_check(scene.pieces[143].target_cell == Vector2i(11, 11), "(11,11) target")
	_check(scene.pieces[143].piece_index == 143, "最后一块 index=143")
	# region 尺寸 = 1200x900 / 12x12 = 100x75
	var region_ok := true
	for p in scene.pieces:
		if p.region.size != Vector2i(100, 75):
			region_ok = false
			break
	_check(region_ok, "全部 region 100x75（1200x900/12）")
	_check(scene.pieces[0].cell_state == PuzzlePiece.CELL_HIDDEN, "初始全部 HIDDEN")

	print("== 收集模式：掉落飞入 ==")
	scene.puzzle_completed.connect(func(): _completed_flag = true)
	scene.collection_changed.connect(func(c, pl): _collected_signal = Vector2i(c, pl))
	# 模拟 FocusEngine 掉落：on_piece_dropping → on_piece_landed
	scene.on_piece_dropping(5)
	scene.on_piece_dropping(80)
	scene.on_piece_landed(5)
	scene.on_piece_landed(80)
	await get_tree().create_timer(0.2).timeout
	_check(scene.pieces[5].cell_state == PuzzlePiece.CELL_COLLECTED, "掉落后 piece5 → COLLECTED")
	_check(scene.pieces[80].cell_state == PuzzlePiece.CELL_COLLECTED, "掉落后 piece80 → COLLECTED")
	_check(scene.pieces[5].is_locked == false, "COLLECTED 未锁定")
	_check(scene.collected_count == 2, "collected_count == 2 (got %d)" % scene.collected_count)
	_check(_collected_signal == Vector2i(2, 0), "collection_changed(2,0)")

	print("== 收集模式 → GameState 同步恢复 ==")
	# 直接改 GameState 再 refresh（模拟切拼图回来）
	# 注意 place_piece 前置条件：必须先 collect（拼上的一定已收集）
	GameState.collect_piece(0)
	GameState.collect_piece(1)
	GameState.collect_piece(50)
	GameState.place_piece(0)
	GameState.place_piece(1)
	scene.refresh_from_game_state()
	_check(scene.pieces[50].cell_state == PuzzlePiece.CELL_COLLECTED, "refresh: piece50 COLLECTED")
	_check(scene.pieces[0].cell_state == PuzzlePiece.CELL_PLACED, "refresh: piece0 PLACED")
	_check(scene.pieces[1].cell_state == PuzzlePiece.CELL_PLACED, "refresh: piece1 PLACED")
	_check(scene.placed_count == 2, "refresh: placed_count == 2 (got %d)" % scene.placed_count)
	_check(scene.pieces[0].is_locked == true, "PLACED 锁定")

	print("== 拼图模式：托盘 + 手动吸附 ==")
	scene.enter_puzzle_mode()
	await get_tree().process_frame
	var in_tray := true
	var tray := scene._tray_rect.grow(30)
	var dragabble := 0
	for p in scene.pieces:
		if p.cell_state == PuzzlePiece.CELL_COLLECTED and not p.is_locked:
			draggable_check(p)
			dragabble += 1
			if not tray.has_point(p.position):
				in_tray = false
	_check(scene.mode == PuzzleBoard.MODE_PUZZLE, "进入拼图模式")
	_check(in_tray, "COLLECTED 碎片全部在托盘内")
	_check(dragabble == 3, "可拖碎片 = 已收集未拼 = 3 (got %d)" % dragabble)  # piece5,50,80（0/1 已拼）
	_check(scene.auto_button.visible == true, "自动拼按钮显示")
	# 手动吸附 piece5（模拟拖到位松手）
	var piece5: PuzzlePiece = scene.pieces[5]
	piece5.global_position = piece5.target_global_pos()
	piece5._try_snap()
	await get_tree().process_frame
	_check(piece5.is_locked == true, "手动吸附锁定")
	_check(piece5.cell_state == PuzzlePiece.CELL_PLACED, "吸附后 PLACED")
	_check(GameState.is_placed(5) == true, "GameState.place_piece(5) 已上推")
	_check(scene.placed_count == 3, "placed_count == 3 (got %d)" % scene.placed_count)

	print("== 自动拼 ==")
	scene.auto_solve()
	# 等自动拼完成（2 块 × 0.06s + 余量）
	await get_tree().create_timer(0.5).timeout
	_check(scene.pieces[50].is_locked == true, "自动拼 piece50 锁定")
	_check(scene.pieces[80].is_locked == true, "自动拼 piece80 锁定")
	_check(scene.placed_count == 5, "自动拼后 placed_count == 5 (got %d)" % scene.placed_count)
	_check(GameState.placed_count() == 5, "GameState placed == 5")

	print("== 回收集模式 ==")
	scene.exit_puzzle_mode()
	await get_tree().process_frame
	_check(scene.mode == PuzzleBoard.MODE_COLLECTION, "回收集模式")
	_check(scene.auto_button.visible == false, "自动拼按钮隐藏")
	_check(scene.pieces[50].global_position == scene.pieces[50].target_global_pos(), "COLLECTED 回格位")

	print("== 全量收集 + 自动拼 → 完成 ==")
	# 一次性全收集
	for i in 144:
		GameState.collect_piece(i)
	scene.refresh_from_game_state()
	_check(scene.collected_count == 144, "全收集 144")
	scene.enter_puzzle_mode()
	_completed_flag = false
	scene.auto_solve()
	await get_tree().create_timer(144 * 0.06 + 1.0).timeout
	_check(scene.placed_count == 144, "全拼上 144 (got %d)" % scene.placed_count)
	_check(_completed_flag, "puzzle_completed 信号已发射")
	_check(GameState.is_current_puzzle_complete(), "GameState 判定完成")
	_check(scene.pieces[143].cell_state == PuzzlePiece.CELL_PLACED, "最后一块 PLACED")

	print("== RESULT: %d checks, %d failures ==" % [_checks, _fails])
	scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(_fails)

func draggable_check(p: PuzzlePiece) -> void:
	## 可拖性校验（mouse_filter STOP 才收 _gui_input）
	if p.cell_state == PuzzlePiece.CELL_COLLECTED and not p.is_locked:
		if p.mouse_filter != Control.MOUSE_FILTER_STOP:
			_fails += 1
			print("  FAIL  %s 未启用拖拽 (mouse_filter=%d)" % [p.name, p.mouse_filter])

func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if cond:
		print("  PASS  %s" % msg)
	else:
		_fails += 1
		print("  FAIL  %s" % msg)
