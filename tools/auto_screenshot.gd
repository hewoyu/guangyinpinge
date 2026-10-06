extends SceneTree
## 自动化截图 + 玩法自测工具（v2：含自动完成拼图验证全链路）

const FLOW := [
	{"scene": "res://scenes/main.tscn", "wait": 1.6},
	{"scene": "res://scenes/level_select.tscn", "wait": 1.6},
	{"scene": "res://scenes/puzzle.tscn", "params": {"level_id": 1}, "wait": 1.0, "autowin": true},
	{"scene": "res://scenes/win_screen.tscn", "params": {"level_id": 1, "stars": 3, "hints_used": 0, "elapsed": 42.5}, "wait": 2.0},
]

var _step := 0

func _init() -> void:
	_next()

func _next() -> void:
	if _step >= FLOW.size():
		print("FLOW_COMPLETE")
		quit()
		return
	var cfg: Dictionary = FLOW[_step]
	if cfg.has("params"):
		root.set_meta("scene_params", cfg.params)
	change_scene_to_file(cfg.scene)
	await _wait_frames(30)
	if cfg.get("autowin", false):
		await _autowin()
	await _wait_frames(int(cfg.wait * 60.0))
	var img := root.get_viewport().get_texture().get_image()
	var name_: String = str(cfg.scene).get_file().replace(".tscn", "")
	img.save_png("user://shot_" + name_ + ".png")
	print("SAVED shot_" + name_ + ".png")
	_step += 1
	_next()

func _autowin() -> void:
	var scene := root.get_child(root.get_child_count() - 1) as Node
	var board := _find_board(scene)
	if board == null:
		print("AUTOWIN: board not found")
		return
	var placed := 0
	for piece in board.pieces:
		if not piece.is_locked:
			var target: Vector2 = board._board_origin + Vector2(piece.target_cell) * board._cell_size
			piece.global_position = target
			piece.is_locked = true
			piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
			placed += 1
	board.placed_count = board.total_pieces
	print("AUTOWIN placed=", placed)
	board.puzzle_completed.emit()

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

func _wait_frames(n: int) -> void:
	for i in n:
		await process_frame
