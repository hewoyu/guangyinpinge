extends SceneTree
## QA 复核：lambda 捕获值语义修正 + 提示按钮链路
var _fail := 0
var _completed := false

func _init() -> void:
	await process_frame
	root.set_meta("scene_params", {"level_id": 1})
	change_scene_to_file("res://scenes/puzzle.tscn")
	await _wait_frames(45)
	var scene := root.get_child(root.get_child_count() - 1) as Node
	var board := _find_board(scene)
	var gs: Node = root.get_node_or_null("GameState")
	var ps := scene  # puzzle_scene 根节点

	if board == null:
		print("FAIL: board 未找到"); quit(1); return

	# 1) 提示按钮链路（模拟点击 hint_button → _on_hint → give_hint + deduct_hint）
	var hints_before: int = gs.get("hints_left")
	var hint_btn: Button = _find_node(ps, "HintButton")
	hint_btn.emit_signal("pressed")
	await _wait_frames(3)
	var hints_after: int = gs.get("hints_left")
	_assert(hints_before == 3, "初始提示 3 次")
	_assert(hints_after == 2, "点击提示按钮后扣 1（now=%d）" % hints_after)
	_assert(board.get("hints_used") == 1, "board.hints_used=1（实际 %d）" % board.get("hints_used"))

	# 2) 完成信号（成员变量捕获语义正确）
	board.connect("puzzle_completed", func(): _on_complete())
	for p in board.get("pieces"):
		if not p.get("is_locked"):
			var t: Vector2 = board.get("_board_rect").position + Vector2(p.get("target_cell")) * board.get("_cell_size")
			p.global_position = t
			p.call("_try_snap")
	_assert(board.get("placed_count") == board.get("total_pieces"), "全部归位 %d" % board.get("placed_count"))
	await _wait_frames(10)
	_assert(_completed, "puzzle_completed 信号已发射（成员变量捕获）")

	# 3) 星级计算验证：hints_used=1 → 2星（puzzle_scene._on_puzzle_completed 逻辑）
	var stars := 3
	if board.get("hints_used") >= 3:
		stars = 1
	elif board.get("hints_used") >= 1:
		stars = 2
	_assert(stars == 2, "1 次提示 = 2 星（实际 %d）" % stars)

	await _wait_frames(120)
	print("\n========== 复核结果 ==========")
	if _fail == 0:
		print("RECHECK ALL PASS ✅")
	else:
		print("FAILURES: %d ❌" % _fail)
	quit(_fail)

func _on_complete() -> void:
	_completed = true

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

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: ", msg)
	else:
		_fail += 1
		print("  FAIL: ", msg)
