class_name PuzzlePiece
extends Control
## 拼图碎片（v3）：拖拽内核复用 v2 全局跟踪方案，叠加收集状态层
## 三态（由 PuzzleBoard 驱动）：
##   CELL_HIDDEN     未收集——不显示纹理（格子由 board 绘制暗底+问号）
##   CELL_COLLECTED  已收集未拼——低亮度显示（收集模式在格位/拼图模式在托盘）
##   CELL_PLACED     已拼上——全亮锁定在正确格位
## 拖拽实现：pressed 由 _gui_input 捕获，拖动/松手由 _input 全局跟踪，
## 快速甩出碎片矩形也不丢事件、不粘手（v2 验证过的内核）。
## piece_index = row*12+col（行主序，与 GameState/FocusEngine 掉落索引对齐）。

signal picked_up(piece: PuzzlePiece)
signal dropped(piece: PuzzlePiece)
signal snapped_in(piece: PuzzlePiece)
signal clicked(piece: PuzzlePiece)          ## 点击（未拖动即松手）——收集模式预览

enum { CELL_HIDDEN, CELL_COLLECTED, CELL_PLACED }

@export var snap_threshold_ratio := 0.35  ## 吸附距离 = min(格宽,格高) * 此比例

const DIM_ALPHA := 0.45                     ## 收集模式格位上的低亮度
const CLICK_SLOP := 6.0                     ## 位移小于此值视为点击而非拖动

var region: Rect2i = Rect2i()          ## 在原图上的裁切区域
var target_cell: Vector2i = Vector2i()  ## 正确格位 (col, row)
var piece_index := 0                   ## 0..143（行主序，GameState 掉落索引）
var cell_state: int = CELL_HIDDEN
var is_locked := false                 ## 拼上后 true

var _texture: Texture2D
var _cell_size := Vector2.ZERO
var _target_global := Vector2.ZERO
var _drag_offset := Vector2.ZERO
var _dragging := false
var _press_screen := Vector2.ZERO
var _home_pos := Vector2.ZERO
var _home_tw: Tween = null
var _fly_tw: Tween = null
var _fly_dest := Vector2.ZERO
var _fly_state := CELL_HIDDEN
var _fly_alpha := 0.0

## v4 咬合形渲染：多边形顶点（本地）与对应 UV（原图像素坐标）
var _poly := PackedVector2Array()
var _uvs := PackedVector2Array()
var _tint := Color(1, 1, 1, 1)   ## 三态亮度（低亮/全亮/提亮）
const SEAM := Color("CBB994")   ## 已放块接缝 1-1.5px（实测精修）

@onready var _texture_rect: TextureRect = $TextureRect
@onready var _shadow: ColorRect = $Shadow

func setup(tex: Texture2D, region_: Rect2i, cell: Vector2i, cell_size: Vector2, target_global: Vector2, index: int) -> void:
	setup_jigsaw(tex, region_, cell, cell_size, target_global, index, PackedVector2Array(), PackedVector2Array())

## v4 咬合形 setup：poly = 本地顶点（含凸头外扩），uvs = 顶点对应原图坐标
func setup_jigsaw(tex: Texture2D, region_: Rect2i, cell: Vector2i, cell_size: Vector2, target_global: Vector2, index: int, poly: PackedVector2Array, uvs: PackedVector2Array) -> void:
	_texture = tex
	region = region_
	target_cell = cell
	piece_index = index
	_cell_size = cell_size
	_target_global = target_global
	size = cell_size
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if poly.size() > 0:
		_poly = poly
		_uvs = uvs
	if _texture_rect:
		_texture_rect.visible = false   ## v4 弃用矩形渲染，改 _draw 多边形

func _ready() -> void:
	if _shadow:
		_shadow.visible = false

func _gui_input(event: InputEvent) -> void:
	## 拾起判定：必须点到碎片本体，且仅"已收集未拼"态可拖
	if is_locked or cell_state != CELL_COLLECTED:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		_start_drag()

func _input(event: InputEvent) -> void:
	## 拖动中全局跟踪，不受碎片矩形限制（修复快速拖动丢帧/粘手）
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		global_position = get_global_mouse_position() - _drag_offset
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		get_viewport().set_input_as_handled()
		_end_drag()

func _start_drag() -> void:
	_dragging = true
	if _home_tw != null and _home_tw.is_valid():
		_home_tw.kill()
	_drag_offset = get_global_mouse_position() - global_position
	_press_screen = get_global_mouse_position()
	var par := get_parent()
	if par is Control:
		par.move_child(self, par.get_child_count() - 1)
	if _shadow:
		_shadow.visible = true
	picked_up.emit(self)

func _end_drag() -> void:
	_dragging = false
	if _shadow:
		_shadow.visible = false
	dropped.emit(self)
	# 位移极小 → 视为点击（收集模式预览入口）
	if (get_global_mouse_position() - _press_screen).length() < CLICK_SLOP:
		clicked.emit(self)
	_try_snap()

func _try_snap() -> void:
	## 靠近正确格位则吸附（吸附距离取格宽高的较小边）
	if is_locked or cell_state != CELL_COLLECTED:
		return
	var dist := (global_position - _target_global).length()
	if dist <= min(_cell_size.x, _cell_size.y) * snap_threshold_ratio:
		snap_to_target()

func snap_to_target() -> void:
	## 吸附到正确格位并锁定（手动拼 & 自动拼 & 存档恢复共用；幂等）
	if is_locked:
		return
	global_position = _target_global
	is_locked = true
	cell_state = CELL_PLACED
	z_index = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.modulate.a = 1.0
	var tw := create_tween().bind_node(self)
	tw.tween_property(self, "scale", Vector2(0.93, 0.93), 0.05)
	tw.tween_property(self, "scale", Vector2.ONE, 0.08)
	snapped_in.emit(self)

func apply_state(state: int, alpha := -1.0) -> void:
	## 三态切换（board 驱动）；alpha=-1 用状态默认亮度
	cell_state = state
	var a := alpha
	match state:
		CELL_HIDDEN:
			if alpha < 0.0: a = 0.0
			is_locked = false
			mouse_filter = Control.MOUSE_FILTER_IGNORE
		CELL_COLLECTED:
			if alpha < 0.0: a = DIM_ALPHA
			is_locked = false
			mouse_filter = Control.MOUSE_FILTER_IGNORE
		CELL_PLACED:
			if alpha < 0.0: a = 1.0
			is_locked = true
			mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _texture_rect:
		_texture_rect.modulate.a = maxf(0.0, a)
	if _shadow:
		_shadow.visible = false

func set_visual_alpha(a: float) -> void:
	if _texture_rect:
		_texture_rect.modulate.a = a

func enable_drag() -> void:
	## 进入拼图模式：已收集未拼的碎片允许拖拽
	if cell_state == CELL_COLLECTED and not is_locked:
		mouse_filter = Control.MOUSE_FILTER_STOP

func disable_interaction() -> void:
	_dragging = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func fly_to(dest_global: Vector2, final_state: int, final_alpha: float, duration := 0.9, on_landed: Callable = Callable()) -> void:
	## 掉落飞行动画：飞到 dest_global 并落定到 final_state（on_landed 落定回调）
	if _fly_tw != null and _fly_tw.is_valid():
		_fly_tw.kill()
	if _home_tw != null and _home_tw.is_valid():
		_home_tw.kill()
	_fly_dest = dest_global
	_fly_state = final_state
	_fly_alpha = final_alpha
	_dragging = false
	global_position = dest_global + Vector2(0.0, -_fly_height(dest_global))
	z_index = 50  # 飞行期间置顶
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _texture_rect:
		_texture_rect.modulate.a = 0.0
	var tw := create_tween().bind_node(self)
	tw.set_parallel(true)
	tw.tween_property(self, "global_position", dest_global, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_texture_rect, "modulate:a", final_alpha, duration).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(func():
		finish_flight()
		if on_landed.is_valid():
			on_landed.call()
	)
	_fly_tw = tw

func _fly_height(dest: Vector2) -> float:
	## 飞行起始高度（从格位上方飞入）
	return maxf(120.0, dest.y * 0.35)

func finish_flight() -> void:
	## 立即结束飞行（落定信号兜底）：杀 tween、落位、应用目标态
	if _fly_tw != null and _fly_tw.is_valid():
		_fly_tw.kill()
	_fly_tw = null
	global_position = _fly_dest
	z_index = 0
	apply_state(_fly_state, _fly_alpha)

func update_target(target_global: Vector2, cell_size: Vector2) -> void:
	## 布局变化后刷新吸附目标（锁定碎片跟随重新归位）
	_cell_size = cell_size
	_target_global = target_global
	if is_locked:
		global_position = target_global

func target_global_pos() -> Vector2:
	return _target_global

func go_home() -> void:
	## 弹回托盘归属位
	if _home_tw != null and _home_tw.is_valid():
		_home_tw.kill()
	_home_tw = create_tween().bind_node(self)
	_home_tw.tween_property(self, "position", _home_pos, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func set_home(pos: Vector2) -> void:
	_home_pos = pos


# ---------------- v4 咬合形绘制 ----------------

func _draw() -> void:
	if _poly.size() < 3 or _texture == null:
		return
	if cell_state == CELL_HIDDEN:
		return   ## 未收集格由 board 绘制空位
	var colors := PackedColorArray()
	for i in _poly.size():
		colors.append(_tint)
	draw_polygon(_poly, colors, _uvs, _texture)
	var line_pts := _poly.duplicate()
	line_pts.append(_poly[0])
	draw_polyline(line_pts, Color(SEAM.r, SEAM.g, SEAM.b, _tint.a), 1.0, true)

func apply_tint(t: Color) -> void:
	_tint = t
	queue_redraw()

func set_polygon(poly: PackedVector2Array, uvs: PackedVector2Array) -> void:
	_poly = poly
	_uvs = uvs
	queue_redraw()
