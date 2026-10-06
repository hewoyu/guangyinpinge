extends Node
## task-21 验收：拼图模式入口 + 托盘 + 自动拼 → 明信片

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
	if get_tree().root.has_meta("pm_ran"):
		get_tree().quit()
		return
	get_tree().root.set_meta("pm_ran", true)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_v3.json"))
	GameState.collected.clear()
	GameState.placed.clear()
	GameState.completed_album.clear()
	GameState.current_puzzle_id = "picnic"
	GameState.puzzles_cache.clear()
	var page: Control = (load("res://scenes/play_page.tscn") as PackedScene).instantiate() as Control
	add_child(page)
	await get_tree().process_frame
	var board = page.get_node_or_null("BoardHolder/PuzzleBoard")
	# 收集 20 块（不拼）
	for i in 20:
		GameState.collect_piece(i)
	board.refresh_from_game_state()
	await get_tree().process_frame
	# 计数卡断言（v6）
	check("计数卡文本", page._counter_l1 != null and page._counter_l1.text.begins_with("已完成 0/144"), page._counter_l1.text if page._counter_l1 else "null")
	check("托盘存量=20", page._counter_l2 != null and page._counter_l2.text == "当前托盘存量 20 块", page._counter_l2.text if page._counter_l2 else "null")
	# 进拼图模式
	page._enter_puzzle_mode()
	await get_tree().process_frame
	check("拼图模式态开启", page._in_puzzle_mode)
	var in_tray := 0
	for p in board.pieces:
		if p.cell_state == 0: pass  # HIDDEN 枚举
	for p in board.pieces:
		if p.is_locked:
			in_tray += 1
	# board 的 enter_puzzle_mode 语义：collected 未拼 → 应在托盘可拖。检查可拖块数=20
	var draggable := 0
	for p in board.pieces:
		if p.cell_state == 1:   # CELL_COLLECTED
			draggable += 1
	check("可拖碎片=20", draggable == 20, "got %d" % draggable)
	# 自动拼
	page._auto_solve_pressed()
	await get_tree().create_timer(20 * 0.08 + 1.5).timeout
	check("自动拼后 placed=20", GameState.placed_count() == 20, "got %d" % GameState.placed_count())
	check("退出拼图模式", not page._in_puzzle_mode)
	print("== TEST PUZZLE MODE: %d pass %d fail ==" % [_pass, _fail])
	get_tree().quit()
