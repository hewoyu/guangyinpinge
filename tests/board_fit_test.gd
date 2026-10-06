extends Node
## 棋盘适配验收：完整显示在 1280x720 视口内
func _ready() -> void:
	var page: Control = (load("res://scenes/play_page.tscn") as PackedScene).instantiate() as Control
	add_child(page)
	await get_tree().create_timer(1.2).timeout
	var board = page.get_node_or_null("BoardHolder/PuzzleBoard")
	var fit: bool = board != null and board.size.y <= 720 - 42 - 10  # 顶栏42 + 余量10
	var bottom: float = board.global_position.y + board.size.y if board else 0
	var board_rect_bottom: float = 0
	if board:
		# 实际拼图区域（_board_rect 是内部区）
		board_rect_bottom = board.global_position.y + board._board_rect.position.y + board._board_rect.size.y
	print("board.size=", board.size if board else "?")
	print("棋盘区底边 y=", board_rect_bottom, " 视口底 y=720")
	print("FIT=", board_rect_bottom <= 720)
	# 截图存证
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shot_board_fit.png")
	print("SAVED")
	get_tree().quit()
