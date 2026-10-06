extends Node
## 拼图玩法冒烟测试：实例化 puzzle 场景验证构建/切图/吸附/完成检测/6x6 托盘布局
## 运行：godot --headless res://tests/smoke_test.tscn --quit-after 300（quit code = 失败数）

var _fails: int = 0
var _checks: int = 0
var _completed_flag := false

func _ready() -> void:
	await _test_level(1, Vector2i(3, 3), 9)
	await _test_level(2, Vector2i(3, 4), 12)
	await _test_level(3, Vector2i(4, 4), 16)
	await _test_level(4, Vector2i(4, 5), 20)
	await _test_level(5, Vector2i(5, 5), 25)
	await _test_level(6, Vector2i(6, 6), 36)
	print("RESULT: %d checks, %d failures" % [_checks, _fails])
	get_tree().quit(_fails)

func _set_completed() -> void:
	_completed_flag = true

func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if cond:
		print("  PASS  %s" % msg)
	else:
		_fails += 1
		print("  FAIL  %s" % msg)

func _test_level(level_id: int, grid: Vector2i, expect_pieces: int) -> void:
	print("== level %d (grid %s) ==" % [level_id, grid])
	# 清理上局 scene_params
	get_tree().root.set_meta("scene_params", {"level_id": level_id})
	var scene: Control = (load("res://scenes/puzzle.tscn") as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var board = scene.get("board")
	if board == null:
		_check(false, "board instantiated")
		scene.queue_free()
		await get_tree().process_frame
		return
	_check(true, "board instantiated")
	_check(board.grid_size == grid, "grid_size == %s" % grid)
	_check(board.pieces.size() == expect_pieces, "pieces == %d (got %d)" % [expect_pieces, board.pieces.size()])
	_check(board.total_pieces == expect_pieces, "total_pieces == %d" % expect_pieces)
	_check(board.placed_count == 0, "initial placed_count == 0")
	# 碎片切图：region 尺寸 = 原图/网格，960x720 基准
	var expect_region := Vector2i(960 / grid.x, 720 / grid.y)
	var region_ok := true
	var cells := {}
	for p in board.pieces:
		if p.region.size != expect_region:
			region_ok = false
		cells[p.target_cell] = true
	_check(region_ok, "all region sizes == %s" % expect_region)
	_check(cells.size() == expect_pieces, "target_cell 无重复覆盖 (%d)" % cells.size())
	# 暖调在层上，碎片自身无染色
	_check(board.pieces_layer.modulate == board.WARM_TINT, "PiecesLayer.modulate == WARM_TINT")
	_check(board.pieces[0].self_modulate == Color.WHITE, "piece 无自身染色（层统一暖调）")
	# 托盘布局：所有碎片起始位都在托盘区（含容差）
	var tray: Rect2 = board._tray_rect.grow(30)
	var in_tray := true
	for p in board.pieces:
		if not tray.has_point(p.position):
			in_tray = false
			print("    out-of-tray piece at %s (tray %s)" % [p.position, tray])
	_check(in_tray, "全部碎片起始位在托盘内")
	# 提示：give_hint 成功且计数
	var hints_before: int = board.hints_used
	_check(board.give_hint(), "give_hint returns true")
	_check(board.hints_used == hints_before + 1, "hints_used 递增")
	# 全部吸附 → 完成检测（lambda 局部捕获是值拷贝，用成员变量回写）
	_completed_flag = false
	board.puzzle_completed.connect(func(): _set_completed())
	for p in board.pieces:
		p.global_position = p._target_global
		p._try_snap()
	_check(board.placed_count == expect_pieces, "全部吸附后 placed_count == %d (got %d)" % [expect_pieces, board.placed_count])
	_check(_completed_flag, "puzzle_completed 信号已发射")
	var all_locked := true
	for p in board.pieces:
		if not p.is_locked:
			all_locked = false
	_check(all_locked, "全部碎片 is_locked")
	# 进度查询
	_check(board.get_progress() == Vector2i(expect_pieces, expect_pieces), "get_progress == (n, n)")
	# 清场
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
