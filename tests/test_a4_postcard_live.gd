extends Node
## A4 验收：拼图模式真实交互路径 → 明信片链路（复验 task-20 在 v6 之后仍闭环）
## 用 PuzzlePiece 的 _try_snap（与手动拖拽同一路径）而非 GameState.place_piece 直注

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_v3.json"))
	GameState.collected.clear()
	GameState.placed.clear()
	GameState.completed_album.clear()
	GameState.current_puzzle_id = "picnic"
	GameState.puzzles_cache.clear()
	var page: Control = (load("res://scenes/play_page.tscn") as PackedScene).instantiate() as Control
	add_child(page)
	await get_tree().create_timer(1.0).timeout
	var board = page.get_node_or_null("BoardHolder/PuzzleBoard")
	check("棋盘在", board != null)
	# 全部收集（模拟长期专注后）
	for i in GameState.TOTAL_PIECES:
		GameState.collect_piece(i)
	board.refresh_from_game_state()
	# 进入拼图模式
	page._enter_puzzle_mode()
	await get_tree().create_timer(0.3).timeout
	check("拼图模式", page._in_puzzle_mode)
	# 用与手动拖拽一致的路径逐块吸附（模拟玩家拖完全部 144 块）
	var snapped := 0
	for p in board.pieces:
		if p.cell_state == PuzzlePiece.CELL_COLLECTED:
			p.global_position = p.target_global_pos()
			p._try_snap()
			if p.cell_state == PuzzlePiece.CELL_PLACED:
				snapped += 1
	check("全部吸附", snapped == 144, "snapped=%d" % snapped)
	# 明信片链路（显影1.4s+弹出）
	await get_tree().create_timer(3.0).timeout
	var pc = null
	for c in page.get_children():
		if c.name == "Postcard":
			pc = c
	check("明信片弹出", pc != null)
	if pc:
		var fx = pc.get_node_or_null("Card/VBox/PictureFrame/EffectsLayer")
		check("动效节点>0", fx != null and fx.get_child_count() > 0)
		pc._on_keep()
		await get_tree().create_timer(1.0).timeout
		check("归档+切下一幅", GameState.completed_album.has("picnic") and GameState.current_puzzle_id == "starry")
	# 检查 reload 之前 FocusEngine 状态是否被打断保护
	check("庆祝中防重入", page._celebrating)
	print("== A4 POSTCARD LIVE: %d pass %d fail ==" % [_pass, _fail])
	get_tree().quit()
