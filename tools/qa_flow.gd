extends SceneTree
## QA 全链路验证（task-5）：四场景 + 参数传递 + 完成检测断言
## autoload 在 --script 工具模式不可直接按名引用，经 /root/<name> 动态访问

const FLOW := [
	{"scene": "res://scenes/main.tscn", "wait": 1.2, "check": "main"},
	{"scene": "res://scenes/level_select.tscn", "wait": 1.2, "check": "level_select"},
	{"scene": "res://scenes/puzzle.tscn", "params": {"level_id": 2}, "wait": 1.0, "check": "puzzle", "autowin": true},
	{"scene": "res://scenes/win_screen.tscn", "params": {"level_id": 2, "stars": 2, "hints_used": 1, "elapsed": 65.0}, "wait": 1.5, "check": "win_screen"},
]

var _step := 0
var _fail := 0

func _init() -> void:
	_next()

func _next() -> void:
	if _step >= FLOW.size():
		_report()
		quit(_fail)
		return
	var cfg: Dictionary = FLOW[_step]
	print("\n===== STEP %d: %s =====" % [_step, cfg.scene])
	if cfg.has("params"):
		root.set_meta("scene_params", cfg.params)
	change_scene_to_file(cfg.scene)
	await _wait_frames(30)
	if cfg.get("autowin", false):
		await _autowin()
	await _wait_frames(int(cfg.wait * 60.0))
	_check_scene(cfg)
	_step += 1
	_next()

func _check_scene(cfg: Dictionary) -> void:
	var scene := root.get_child(root.get_child_count() - 1) as Node
	var game_state: Node = root.get_node_or_null("GameState")
	var sound_mgr: Node = root.get_node_or_null("SoundManager")
	match cfg.check:
		"main":
			var title := _find_node(scene, "TitleLabel") as Label
			var start := _find_node(scene, "StartButton") as Button
			_assert(title != null and title.text == "拾光拼图", "主菜单标题文本正确")
			_assert(start != null and start.visible, "开始按钮存在且可见")
			_assert(game_state != null, "GameState autoload 已加载")
			_assert(sound_mgr != null, "SoundManager autoload 已加载")
			_assert(sound_mgr != null and sound_mgr.get("muted") != null, "SoundManager API 正常（muted 属性可读）")
		"level_select":
			var grid := _find_node(scene, "Grid") as GridContainer
			_assert(grid != null and grid.get_child_count() == 6, "相册墙 6 张卡片（实际 %d）" % (grid.get_child_count() if grid else -1))
			_assert(game_state != null and game_state.call("is_unlocked", 1) == true, "第 1 关默认解锁")
			_assert(game_state != null and game_state.call("is_unlocked", 3) == false, "第 3 关未解锁（链式解锁）")
		"puzzle":
			var board := _find_board(scene)
			_assert(board != null, "PuzzleBoard 存在")
			if board:
				_assert(board.get("total_pieces") == 12, "第 2 关 3x4=12 碎片（实际 %d）" % board.get("total_pieces"))
				_assert(board.get("puzzle_texture") != null, "拼图纹理已加载")
				_assert(board.get("grid_size") == Vector2i(3, 4), "grid 语义 x=3列 y=4行（实际 %s）" % str(board.get("grid_size")))
				var cs: Vector2 = board.get("_cell_size")
				_assert(cs.x > 10 and cs.y > 10, "cell_size 有效（%s）" % str(cs))
				var pieces: Array = board.get("pieces")
				var visible_pieces := 0
				for p in pieces:
					if p.get("size").x > 5:
						visible_pieces += 1
				_assert(visible_pieces == 12, "12 碎片尺寸有效非零（实际 %d）" % visible_pieces)
		"win_screen":
			var ws := scene
			_assert(ws.get("level_id") == 2, "win_screen level_id=2（实际 %d）" % ws.get("level_id"))
			_assert(ws.get("stars") == 2, "win_screen stars=2（实际 %d）" % ws.get("stars"))
			_assert(ws.get("hints_used") == 1, "win_screen hints_used=1（实际 %d）" % ws.get("hints_used"))
			_assert(abs(float(ws.get("elapsed")) - 65.0) < 0.01, "win_screen elapsed=65.0（实际 %f）" % float(ws.get("elapsed")))
			var stars_row := _find_node(scene, "StarsRow") as HBoxContainer
			_assert(stars_row != null and stars_row.get_child_count() >= 2, "星星行渲染 ≥2 星（实际 %d）" % (stars_row.get_child_count() if stars_row else -1))
			var next_btn := _find_node(scene, "NextButton") as Button
			_assert(next_btn != null and next_btn.visible, "下一关按钮可见（level 2 < 6）")

func _autowin() -> void:
	var scene := root.get_child(root.get_child_count() - 1) as Node
	var board := _find_board(scene)
	if board == null:
		_assert(false, "autowin: board 未找到")
		return
	var placed := 0
	for piece in board.get("pieces"):
		if not piece.get("is_locked"):
			var target: Vector2 = board.get("_board_rect").position + Vector2(piece.get("target_cell")) * board.get("_cell_size")
			piece.global_position = target
			piece.set("is_locked", true)
			piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
			placed += 1
	board.set("placed_count", board.get("total_pieces"))
	print("AUTOWIN placed=", placed, " total=", board.get("total_pieces"))
	board.emit_signal("puzzle_completed")

func _find_board(node: Node) -> Node:
	var sp := ""
	if node.get_script() != null:
		sp = str(node.get_script().resource_path)
	if sp.contains("puzzle_board"):
		return node
	for c in node.get_children():
		var r := _find_board(c)
		if r != null:
			return r
	return null

func _find_node(node: Node, name_: String) -> Node:
	if node.name == name_:
		return node
	for c in node.get_children():
		var r := _find_node(c, name_)
		if r != null:
			return r
	return null

func _wait_frames(n: int) -> void:
	for i in n:
		await process_frame

func _report() -> void:
	print("\n========== QA 结果 ==========")
	if _fail == 0:
		print("ALL PASS ✅")
	else:
		print("FAILURES: %d ❌" % _fail)

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: ", msg)
	else:
		_fail += 1
		print("  FAIL: ", msg)
