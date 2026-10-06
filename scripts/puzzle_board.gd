class_name PuzzleBoard
extends Control
## 拼图板（v3）：144 块收集可视化 + 拼图模式（手动/自动）
## 双模式：
##   MODE_COLLECTION 收集模式（主界面常驻）：12×12 板，未收集格=暗纹理+微问号，
##     已收集未拼格=低亮度画面，已拼格=全亮；碎片掉落时飞入动画。
##   MODE_PUZZLE 拼图模式（专注结束后进入）：已收集未拼碎片进托盘自由拖拽，
##     吸附正确格位点亮；格位画低亮度 region 作目标提示；提供自动拼按钮。
## piece_index = row*12+col 行主序（GameState/FocusEngine 掉落索引语义）。
## 拖拽内核复用 v2：_gui_input 拾起 + _input 全局跟踪 + 吸附阈值。

signal piece_snapped(piece: PuzzlePiece)   ## 碎片吸附成功（手动/自动共用）
signal piece_picked(piece: PuzzlePiece)    ## 碎片被拾起
signal puzzle_completed                    ## 144 块全部拼上
signal collection_changed(collected: int, placed: int)  ## 收集/拼装计数变化
signal auto_solve_started
signal auto_solve_finished

enum { MODE_COLLECTION, MODE_PUZZLE }

@export var grid_size: Vector2i = Vector2i(12, 12)  ## (cols, rows)
@export var puzzle_texture: Texture2D
@export var mode: int = MODE_COLLECTION
@export var auto_solve_interval := 0.06  ## 自动拼：每块吸附间隔（秒）

const PIECE_SCENE := preload("res://scenes/puzzle_piece.tscn")
const TOTAL_PIECES := 144
const CELL_MARGIN := 8.0        ## 棋盘与托盘之间的间距
const HIDDEN_CELL_COLOR := Color(0.30, 0.26, 0.22, 0.55)   ## 未收集格暗底
const HIDDEN_CELL_LINE := Color(0.30, 0.26, 0.22, 0.85)
const QUESTION_MARK_COLOR := Color(0.62, 0.55, 0.46, 0.55)  ## 微问号
const DIM_ALPHA_IN_COLLECTION := 0.45   ## 收集模式格位上已收集未拼的亮度
const TRAY_BG_COLOR := Color(0.24, 0.21, 0.18, 0.35)

var pieces: Array[PuzzlePiece] = []
var placed_count := 0
var collected_count := 0
var total_pieces := TOTAL_PIECES
var _placed_idx: Dictionary = {}   ## piece_index -> true（本地镜像，幂等判定）
var _auto_solving := false
var _auto_solve_token := 0

var _board_rect := Rect2()
var _cell_size := Vector2.ZERO
var _tray_rect := Rect2()
var _rng := RandomNumberGenerator.new()
var _built := false
var _question_font: Font = null
var _jigsaw_edges: Dictionary = {}   ## v4 整板咬合边表（seed 确定性）
const SLOT_FILL := Color("F3E6C8")   ## 空位米白（实测精修）
const SLOT_LINE := Color("CBB994")   ## 空位描边=接缝色（实测 1-1.5px）

@onready var pieces_layer: Control = $PiecesLayer
@onready var auto_button: Button = $AutoButton

func _ready() -> void:
	_rng.randomize()
	pieces_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_question_font = ThemeDB.fallback_font
	if auto_button:
		auto_button.visible = false
		auto_button.pressed.connect(_on_auto_button)
	if puzzle_texture != null:
		setup(puzzle_texture, grid_size)

func setup(tex: Texture2D, grid: Vector2i) -> void:
	_jigsaw_edges = Jigsaw.make_edges(grid.x, grid.y, 20260422)
	## 初始化/重建（幂等）
	puzzle_texture = tex
	grid_size = grid
	if puzzle_texture == null:
		push_error("PuzzleBoard: puzzle_texture is null")
		return
	if _built:
		for p in pieces:
			p.queue_free()
		pieces.clear()
		placed_count = 0
		collected_count = 0
		_placed_idx.clear()
	_built = false
	_layout()
	_build_pieces()
	_sync_from_game_state(false)
	_built = true
	queue_redraw()

func _layout() -> void:
	## 自适应布局：横版（宽>高）左棋盘右托盘；竖版上棋盘下托盘
	var area := Rect2(Vector2.ZERO, size)
	if area.size.x <= 1.0 or area.size.y <= 1.0:
		area.size = Vector2(1280, 800)  # 未入树兜底（工作台横版基准）
	var landscape := area.size.x >= area.size.y
	var board_size: Vector2
	var board_pos: Vector2
	var tray_pos: Vector2
	var tray_size: Vector2
	if landscape:
		# 横版：棋盘在左（高度撑满留边），托盘在右侧
		var margin := 24.0
		var avail_h := area.size.y - margin * 2
		var avail_w := area.size.x * 0.60
		var side := minf(avail_w, avail_h)
		board_size = Vector2(side, side)
		board_pos = Vector2(margin, margin + (area.size.y - margin * 2 - side) / 2.0)
		tray_pos = Vector2(board_pos.x + board_size.x + CELL_MARGIN, margin)
		tray_size = Vector2(area.size.x - tray_pos.x - margin, avail_h)
	else:
		# 竖版：棋盘在上，托盘在下
		var margin := 16.0
		var avail_w := area.size.x - margin * 2
		var board_h := area.size.y * 0.55
		var side := minf(avail_w, board_h)
		board_size = Vector2(side, side)
		board_pos = Vector2(margin + (avail_w - side) / 2.0, margin)
		tray_pos = Vector2(margin, board_pos.y + board_size.y + CELL_MARGIN)
		tray_size = Vector2(avail_w, area.size.y - tray_pos.y - margin)
	_board_rect = Rect2(board_pos, board_size)
	_cell_size = board_size / Vector2(grid_size)
	_tray_rect = Rect2(tray_pos, tray_size)

func _build_pieces() -> void:
	## 生成 144 块碎片（索引 = 行主序），初始全部 HIDDEN
	var img_w := puzzle_texture.get_width()
	var img_h := puzzle_texture.get_height()
	var region_size := Vector2i(img_w / grid_size.x, img_h / grid_size.y)
	total_pieces = grid_size.x * grid_size.y
	for r in grid_size.y:
		for c in grid_size.x:
			var index := r * grid_size.x + c
			var cell := Vector2i(c, r)
			var region := Rect2i(c * region_size.x, r * region_size.y, region_size.x, region_size.y)
			var piece: PuzzlePiece = PIECE_SCENE.instantiate()
			pieces_layer.add_child(piece)
			var target_local := _board_rect.position + Vector2(cell) * _cell_size
			# v4 咬合形：顶点（本地含凸头）+ UV（原图像素坐标）
			var poly := Jigsaw.piece_polygon(c, r, grid_size.x, grid_size.y, _jigsaw_edges, _cell_size)
			var uvs := PackedVector2Array()
			for pt in poly:
				uvs.append(Vector2(region.position) + pt * (Vector2(region.size) / _cell_size))
			piece.setup_jigsaw(puzzle_texture, region, cell, _cell_size, board_to_global(target_local), index, poly, uvs)
			piece.picked_up.connect(_on_piece_picked)
			piece.snapped_in.connect(_on_piece_snapped)
			piece.dropped.connect(_on_piece_dropped)
			pieces.append(piece)

func board_to_global(local: Vector2) -> Vector2:
	return pieces_layer.get_global_transform() * local

func _draw() -> void:
	## 自绘层：托盘底 / 棋盘底 / 格线 / 未收集暗格 + 微问号 / 已收集低亮度提示
	if not _built and _board_rect.size == Vector2.ZERO:
		return
	# 托盘底
	if mode == MODE_PUZZLE:
		draw_rect(_tray_rect, TRAY_BG_COLOR)
	# 棋盘底
	draw_rect(_board_rect.grow(6), Color(0.20, 0.17, 0.14, 0.30))
	# 12x12 = 169 条线，一次 draw 循环
	var line_col := Color(1, 1, 1, 0.08)
	for r in grid_size.y + 1:
		var y := _board_rect.position.y + r * _cell_size.y
		draw_line(Vector2(_board_rect.position.x, y), Vector2(_board_rect.end.x, y), line_col, 1.0)
	for c in grid_size.x + 1:
		var x := _board_rect.position.x + c * _cell_size.x
		draw_line(Vector2(x, _board_rect.position.y), Vector2(x, _board_rect.end.y), line_col, 1.0)
	# v4 收集模式：未收集格 = 米白空白咬合块（real_04 实测 #F0E4BF，无问号）
	if mode == MODE_COLLECTION:
		for r in grid_size.y:
			for c in grid_size.x:
				var idx := r * grid_size.x + c
				var p: PuzzlePiece = pieces[idx]
				if p.cell_state == PuzzlePiece.CELL_HIDDEN:
					var cell_pos := _board_rect.position + Vector2(c, r) * _cell_size
					var poly := Jigsaw.piece_polygon(c, r, grid_size.x, grid_size.y, _jigsaw_edges, _cell_size)
					var local := PackedVector2Array()
					for pt in poly:
						local.append(pt + cell_pos)
					var cols := PackedColorArray()
					for i in local.size():
						cols.append(SLOT_FILL)
					draw_polygon(local, cols)
					var line_pts := local.duplicate()
					line_pts.append(local[0])
					draw_polyline(line_pts, SLOT_LINE, 1.0, true)

func _on_piece_picked(piece: PuzzlePiece) -> void:
	piece_picked.emit(piece)

func _on_piece_snapped(piece: PuzzlePiece) -> void:
	## 手动/自动吸附统一入口：状态上推 GameState + 计数 + 完成检测
	if _placed_idx.has(piece.piece_index):
		return  # 幂等（重复 snap 不重复计数）
	_placed_idx[piece.piece_index] = true
	GameState.place_piece(piece.piece_index)
	placed_count = GameState.placed_count()
	piece_snapped.emit(piece)
	_emit_progress()
	if placed_count >= total_pieces:
		puzzle_completed.emit()

func _emit_progress() -> void:
	## 计数统一从 GameState 派生（唯一权威数据源，杜绝视觉/数据双算）
	collected_count = GameState.collected_count()
	placed_count = GameState.placed_count()
	collection_changed.emit(collected_count, placed_count)

func _on_piece_dropped(piece: PuzzlePiece) -> void:
	if piece.is_locked:
		return
	# 落点既不在托盘也不在棋盘附近 → 弹回归属位
	var p := piece.position
	if not _tray_rect.grow(60).has_point(p) and not _board_rect.grow(60).has_point(p):
		piece.go_home()

func get_progress() -> Vector2i:
	return Vector2i(placed_count, total_pieces)

func get_collection_progress() -> Vector2i:
	## (已收集, 已拼)
	return Vector2i(collected_count, placed_count)

## ---------- 收集模式接口（对接 FocusEngine 掉落） ----------

func on_piece_dropping(index: int) -> void:
	## 掉落开始（FocusEngine.piece_dropping）：收集上推 GameState（幂等）+ 飞入动画
	if index < 0 or index >= pieces.size():
		return
	var piece := pieces[index]
	if piece.cell_state == PuzzlePiece.CELL_PLACED:
		return  # 已拼上，不再重复掉落
	# GameState 为唯一权威：FocusEngine 的 landed 侧 collect 是幂等 no-op
	GameState.collect_piece(index)
	_emit_progress()
	if piece.cell_state == PuzzlePiece.CELL_HIDDEN:
		piece.fly_to(piece.target_global_pos(), PuzzlePiece.CELL_COLLECTED, DIM_ALPHA_IN_COLLECTION)
	queue_redraw()

func on_piece_landed(index: int) -> void:
	## 掉落完成（FocusEngine.piece_landed）：落定到最终态（兜底 finish_flight）
	if index < 0 or index >= pieces.size():
		return
	var piece := pieces[index]
	GameState.collect_piece(index)  # 幂等
	piece.finish_flight()
	_emit_progress()
	queue_redraw()

## ---------- 拼图模式 ----------

func enter_puzzle_mode() -> void:
	## 进入拼图模式：已收集未拼的碎片进托盘（随机散布），启用拖拽
	mode = MODE_PUZZLE
	_sync_from_game_state(false)
	var unplaced: Array[PuzzlePiece] = []
	for p in pieces:
		if p.cell_state == PuzzlePiece.CELL_COLLECTED:
			unplaced.append(p)
	_scatter_in_tray(unplaced)
	for p in unplaced:
		p.set_visual_alpha(0.9)  # 托盘内稍亮便于辨认
		p.enable_drag()
	if auto_button:
		auto_button.visible = true
	queue_redraw()

func exit_puzzle_mode() -> void:
	## 回到收集模式：托盘碎片清空回格位低亮度态，重新同步状态
	mode = MODE_COLLECTION
	for p in pieces:
		if p.cell_state == PuzzlePiece.CELL_COLLECTED:
			p.global_position = p.target_global_pos()
			p.apply_state(PuzzlePiece.CELL_COLLECTED, DIM_ALPHA_IN_COLLECTION)
	if auto_button:
		auto_button.visible = false
	_auto_solving = false
	queue_redraw()

func _scatter_in_tray(list: Array[PuzzlePiece]) -> void:
	## 托盘网格化散布（144 块全量场景：行列均分 + 随机扰动）
	if list.is_empty():
		return
	var margin := 14.0
	var avail := _tray_rect.size - Vector2(margin * 2, margin * 2)
	var cols := maxi(3, ceili(sqrt(float(list.size()))))
	var rows := ceili(float(list.size()) / cols)
	var slot_w := avail.x / cols
	var slot_h := avail.y / maxf(1.0, rows)
	var piece_h := _cell_size.y
	for i in list.size():
		var p: PuzzlePiece = list[i]
		var col := i % cols
		var row := i / cols
		var px := _tray_rect.position.x + margin + col * slot_w + _rng.randf_range(0.0, maxf(0.0, slot_w - _cell_size.x) * 0.7)
		var py: float
		if rows > 1:
			py = _tray_rect.position.y + margin + row * slot_h + _rng.randf_range(0.0, maxf(0.0, slot_h - piece_h) * 0.5)
		else:
			py = _tray_rect.position.y + margin
		var home := Vector2(px, py)
		p.position = home
		p.set_home(home)

func _on_auto_button() -> void:
	auto_solve()

func auto_solve() -> void:
	## 自动拼：按序（行主序）吸附所有已收集未拼碎片，间隔 auto_solve_interval
	if _auto_solving:
		return
	var pending: Array[PuzzlePiece] = []
	for p in pieces:
		if p.cell_state == PuzzlePiece.CELL_COLLECTED and not p.is_locked:
			pending.append(p)
	if pending.is_empty():
		return
	_auto_solving = true
	_auto_solve_token += 1
	var token := _auto_solve_token
	if auto_button:
		auto_button.disabled = true
	auto_solve_started.emit()
	for p in pending:
		await get_tree().create_timer(auto_solve_interval).timeout
		if token != _auto_solve_token or not is_instance_valid(self):
			return  # 模式切换/重建中断
		if p.cell_state == PuzzlePiece.CELL_COLLECTED and not p.is_locked:
			p.snap_to_target()
	_auto_solving = false
	if auto_button:
		auto_button.disabled = false
	auto_solve_finished.emit()

func stop_auto_solve() -> void:
	## 中断自动拼（模式切换/外部调用）
	_auto_solve_token += 1
	_auto_solving = false
	if auto_button:
		auto_button.disabled = false

## ---------- 状态同步 ----------

func _sync_from_game_state(animate: bool) -> void:
	## 从 GameState 恢复 collected/placed → 碎片三态（存档恢复/外部变更）
	var any_change := false
	for i in pieces.size():
		var p: PuzzlePiece = pieces[i]
		if GameState.is_placed(i):
			_placed_idx[i] = true
			if p.cell_state != PuzzlePiece.CELL_PLACED:
				p.global_position = p.target_global_pos()
				p.apply_state(PuzzlePiece.CELL_PLACED)
				any_change = true
		elif GameState.is_collected(i):
			if p.cell_state != PuzzlePiece.CELL_COLLECTED:
				p.global_position = p.target_global_pos()
				p.apply_state(PuzzlePiece.CELL_COLLECTED, DIM_ALPHA_IN_COLLECTION)
				any_change = true
		else:
			if p.cell_state != PuzzlePiece.CELL_HIDDEN:
				p.apply_state(PuzzlePiece.CELL_HIDDEN)
				any_change = true
	collected_count = GameState.collected_count()
	placed_count = GameState.placed_count()
	if any_change:
		collection_changed.emit(collected_count, placed_count)
	## v5-20：同步路径的完成检测（外部注入 144 块/存档恢复完成态也要发信号）
	if placed_count >= total_pieces and total_pieces > 0:
		puzzle_completed.emit()
	queue_redraw()

func refresh_from_game_state() -> void:
	## 公开同步入口（UI 可在切拼图后调用）
	_sync_from_game_state(false)

func reveal_full_image() -> TextureRect:
	## 完成时显影：完整图淡入盖住棋盘
	var full := TextureRect.new()
	full.texture = puzzle_texture
	full.stretch_mode = TextureRect.STRETCH_SCALE
	full.position = _board_rect.position
	full.size = _board_rect.size
	full.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full.modulate.a = 0.0
	pieces_layer.add_child(full)
	var tw := create_tween()
	tw.tween_property(full, "modulate:a", 1.0, 0.6)
	return full
