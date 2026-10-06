extends Control
## 《拾光拼途》工作台主界面（task-9）
## 横版 1280x800：顶栏番茄钟 / 左工具栏 / 中央 144 块拼图板 / 右侧工具面板 / 底部今日统计
## 数据源：GameState（v3 拼图集）+ FocusEngine（番茄钟状态机）

const PANELS := {
	"todo": {"tscn": "res://scenes/todo_panel.tscn", "icon": "res://assets/images/icon_todo.svg", "name": "清单"},
	"memo": {"tscn": "res://scenes/memo_panel.tscn", "icon": "res://assets/images/icon_memo.svg", "name": "备忘"},
	"counter": {"tscn": "res://scenes/counter_panel.tscn", "icon": "res://assets/images/icon_counter.svg", "name": "计数"},
	"mind": {"tscn": "res://scenes/mind_panel.tscn", "icon": "res://assets/images/icon_zen.svg", "name": "正念"},
	"noise": {"tscn": "res://scenes/noise_panel.tscn", "icon": "res://assets/images/icon_sound.svg", "name": "白噪"},
}
const FOCUS_OPTIONS := [15.0, 25.0, 45.0]

## ---- 节点引用 ----
@onready var background: Panel = $Background
@onready var app_title: Label = $TopBar/TitleZone/AppTitle
@onready var ring: TextureProgressBar = $TopBar/TimerZone/Ring
@onready var time_label: Label = $TopBar/TimerZone/Ring/TimeLabel
@onready var state_label: Label = $TopBar/TimerZone/StateLabel
@onready var option_row: HBoxContainer = $TopBar/TimerZone/OptionRow
@onready var start_btn: Button = $TopBar/ControlZone/StartButton
@onready var pause_btn: Button = $TopBar/ControlZone/PauseButton
@onready var give_up_btn: Button = $TopBar/ControlZone/GiveUpButton
@onready var tool_bar: VBoxContainer = $Body/ToolBar
@onready var board_holder: Control = $Body/CenterZone/BoardHolder
@onready var puzzle_title: Label = $Body/CenterZone/InfoBar/PuzzleTitle
@onready var piece_count: Label = $Body/CenterZone/InfoBar/PieceCount
@onready var switch_row: HBoxContainer = $Body/CenterZone/InfoBar/SwitchRow
@onready var panel_holder: PanelContainer = $Body/ToolPanel
@onready var panel_title: Label = $Body/ToolPanel/PanelHead/Title
@onready var panel_close: Button = $Body/ToolPanel/PanelHead/CloseButton
@onready var panel_content: VBoxContainer = $Body/ToolPanel/Content
@onready var stats_label: Label = $BottomBar/StatsLabel

## ---- 运行时 ----
var _tool_buttons: Dictionary = {}     ## key -> Button
var _active_panel_key := ""
var _panel_instance: Control = null
var _focus_option_idx := 1             ## 默认 25 分钟
var _ring_tex_bg: ImageTexture
var _ring_tex_fg: ImageTexture

func _ready() -> void:
	background.add_theme_stylebox_override("panel", GameTheme.flat_style(GameTheme.PAPER, 0))
	_build_ring_textures()
	_build_option_buttons()
	_build_tool_bar()
	_build_switch_row()
	_bind_timer()
	_bind_board()
	_refresh_stats()
	_refresh_timer_ui()

# ---------------- 番茄钟 ----------------

func _build_ring_textures() -> void:
	# 程序化画两个圆环贴图（底环/进度环），避免依赖美术资源
	var size := Vector2i(118, 118)
	var bg_img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var fg_img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var center := Vector2(size) / 2.0
	var outer_r := 52.0
	var inner_r := 42.0
	for y in size.y:
		for x in size.x:
			var p := Vector2(x, y)
			var d := p.distance_to(center)
			if d >= inner_r and d <= outer_r:
				var edge := 1.0 - absf((d - (outer_r + inner_r) / 2.0) / ((outer_r - inner_r) / 2.0))
				var a := clampf(edge * 3.0, 0.0, 1.0)
				bg_img.set_pixel(x, y, Color(GameTheme.PAPER_DEEP.r, GameTheme.PAPER_DEEP.g, GameTheme.PAPER_DEEP.b, 0.9 * a))
				fg_img.set_pixel(x, y, Color(GameTheme.TOMATO.r, GameTheme.TOMATO.g, GameTheme.TOMATO.b, a))
	_ring_tex_bg = ImageTexture.create_from_image(bg_img)
	_ring_tex_fg = ImageTexture.create_from_image(fg_img)
	ring.texture_under = _ring_tex_bg
	ring.texture_progress = _ring_tex_fg
	ring.nine_patch_stretch = true
	ring.stretch_margin_left = 0
	ring.stretch_margin_right = 0
	ring.stretch_margin_top = 0
	ring.stretch_margin_bottom = 0
	ring.fill_mode = TextureProgressBar.FILL_CLOCKWISE

func _build_option_buttons() -> void:
	for i in FOCUS_OPTIONS.size():
		var btn := Button.new()
		btn.text = "%d 分" % int(FOCUS_OPTIONS[i])
		btn.toggle_mode = true
		btn.button_pressed = i == _focus_option_idx
		btn.custom_minimum_size = Vector2(64, 34)
		btn.theme = GameTheme.soft_button_theme(15, GameTheme.INK)
		btn.toggled.connect(func(pressed: bool):
			if pressed:
				_focus_option_idx = i
				SoundManager.play("click")
				for j in option_row.get_child_count():
					var b: Button = option_row.get_child(j)
					b.set_pressed_no_signal(j == i)
				_refresh_timer_ui())
		option_row.add_child(btn)

func _bind_timer() -> void:
	start_btn.theme = GameTheme.action_button_theme(22)
	pause_btn.theme = GameTheme.soft_button_theme(18, GameTheme.INK)
	give_up_btn.theme = GameTheme.soft_button_theme(18, GameTheme.INK_SOFT)
	start_btn.pressed.connect(_on_start)
	pause_btn.pressed.connect(_on_pause)
	give_up_btn.pressed.connect(_on_give_up)
	panel_close.pressed.connect(_on_panel_close)
	FocusEngine.state_changed.connect(_on_state_changed)
	FocusEngine.tick.connect(_on_tick)
	FocusEngine.focus_finished.connect(func(_m): _refresh_stats())
	GameState.stats_changed.connect(func(_m, _p): _refresh_stats())

func _on_start() -> void:
	SoundManager.play("click")
	FocusEngine.start_focus(FOCUS_OPTIONS[_focus_option_idx])

func _on_pause() -> void:
	SoundManager.play("click")
	if FocusEngine.state == FocusEngine.STATE_FOCUSING:
		FocusEngine.pause_focus()
	elif FocusEngine.state == FocusEngine.STATE_BREAK and FocusEngine.break_remaining < FocusEngine.focus_duration_sec:
		FocusEngine.resume_focus()

func _on_give_up() -> void:
	SoundManager.play("click")
	FocusEngine.give_up_focus()

func _on_state_changed(state: int) -> void:
	_refresh_timer_ui()

func _on_tick(remaining: float) -> void:
	time_label.text = FocusEngine.fmt(remaining)
	match FocusEngine.state:
		FocusEngine.STATE_FOCUSING:
			ring.value = 1.0 - clampf(remaining / FocusEngine.focus_duration_sec, 0.0, 1.0)
			state_label.text = "专注中"
		FocusEngine.STATE_BREAK:
			ring.value = clampf(remaining / maxf(1.0, FocusEngine.break_remaining + 1.0), 0.0, 1.0)
			state_label.text = "休息一下"

func _refresh_timer_ui() -> void:
	match FocusEngine.state:
		FocusEngine.STATE_IDLE:
			time_label.text = FocusEngine.fmt(FOCUS_OPTIONS[_focus_option_idx] * 60.0)
			state_label.text = "准备专注"
			ring.value = 0.0
			start_btn.text = "开始专注"
			start_btn.disabled = false
			pause_btn.text = "暂停"
			give_up_btn.disabled = true
		FocusEngine.STATE_FOCUSING:
			time_label.text = FocusEngine.fmt(FocusEngine.remaining_sec)
			state_label.text = "专注中"
			start_btn.text = "专注中…"
			start_btn.disabled = true
			pause_btn.text = "暂停"
			give_up_btn.disabled = false
		FocusEngine.STATE_BREAK:
			time_label.text = FocusEngine.fmt(FocusEngine.break_remaining)
			state_label.text = "休息一下"
			start_btn.text = "继续专注"
			start_btn.disabled = false
			pause_btn.text = "恢复"
			give_up_btn.disabled = false
	# 时长选项在运行中禁用
	var running: bool = FocusEngine.state != FocusEngine.STATE_IDLE
	for b in option_row.get_children():
		b.disabled = running

# ---------------- 左工具栏 + 右面板 ----------------

func _build_tool_bar() -> void:
	for key in PANELS:
		var info: Dictionary = PANELS[key]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(72, 72)
		btn.tooltip_text = str(info.name)
		var icon := TextureRect.new()
		icon.texture = load(str(info.icon))
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(34, 34)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_lbl := Label.new()
		name_lbl.text = str(info.name)
		name_lbl.add_theme_font_size_override("font_size", GameTheme.FONT_TOOL)
		name_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vb := VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 2)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(icon)
		vb.add_child(name_lbl)
		btn.add_child(vb)
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.pressed.connect(func(): _toggle_panel(str(key)))
		tool_bar.add_child(btn)
		_tool_buttons[key] = btn
	_update_tool_button_styles()

func _update_tool_button_styles() -> void:
	for key in _tool_buttons:
		var btn: Button = _tool_buttons[key]
		var active: bool = key == _active_panel_key
		btn.add_theme_stylebox_override("normal", GameTheme.tool_button_style(active))
		btn.add_theme_stylebox_override("hover", GameTheme.tool_button_style(true))
		btn.add_theme_stylebox_override("pressed", GameTheme.tool_button_style(active))

func _toggle_panel(key: String) -> void:
	SoundManager.play("click")
	if _active_panel_key == key:
		_close_panel()
		return
	_open_panel(key)

func _open_panel(key: String) -> void:
	_close_panel()
	panel_holder.add_theme_stylebox_override("panel", GameTheme.panel_style(GameTheme.PAPER_LIGHT, 14))
	_active_panel_key = key
	panel_title.text = str(PANELS[key]["name"])
	var scene: PackedScene = load(str(PANELS[key]["tscn"]))
	_panel_instance = scene.instantiate()
	panel_content.add_child(_panel_instance)
	panel_holder.visible = true
	_update_tool_button_styles()
	var tw := create_tween()
	tw.tween_property(panel_holder, "modulate:a", 1.0, 0.18)

func _close_panel() -> void:
	_active_panel_key = ""
	if _panel_instance:
		_panel_instance.queue_free()
		_panel_instance = null
	panel_holder.visible = false
	_update_tool_button_styles()

func _on_panel_close() -> void:
	SoundManager.play("click")
	_close_panel()

# ---------------- 中央拼图板 ----------------

func _bind_board() -> void:
	GameState.current_puzzle_changed.connect(func(_id): _refresh_board())
	GameState.piece_collected.connect(func(_idx): _refresh_board())
	GameState.piece_collected.connect(func(idx): _fly_piece_anim(idx))
	board_holder.resized.connect(_refresh_board)
	# 首帧布局未完成，等一帧再建板
	_first_board_build.call_deferred()

func _first_board_build() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_refresh_board()

func _refresh_board() -> void:
	# 清空重建（144 块规模可接受；掉落动画单独叠加在格子坐标上）
	for c in board_holder.get_children():
		c.queue_free()
	var puzzle := GameState.get_current_puzzle()
	puzzle_title.text = str(puzzle.title)
	piece_count.text = "%d / %d" % [GameState.collected_count(), GameState.TOTAL_PIECES]
	var tex: Texture2D = load(str(puzzle.image))
	var area: Vector2 = board_holder.size
	# 12x12 板，正方形格子，适配中央区域（保持正方形，居中）
	var cell := minf(area.x, area.y) / 12.0
	var board_size := Vector2(cell * 12.0, cell * 12.0)
	var origin := (area - board_size) / 2.0
	var cols := GameState.GRID.x
	for idx in GameState.TOTAL_PIECES:
		var cell_rect := TextureRect.new()
		var col := idx % cols
		var row := idx / cols
		# region 切图：以整图为 atlas
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		var region := Rect2(
			Vector2(tex.get_width() * col / float(cols), tex.get_height() * row / float(cols)),
			Vector2(tex.get_width() / float(cols), tex.get_height() / float(cols)))
		atlas.region = region
		cell_rect.texture = atlas
		cell_rect.position = origin + Vector2(col * cell, row * cell)
		cell_rect.size = Vector2(cell, cell)
		if GameState.is_placed(idx):
			pass  ## 完全点亮
		elif GameState.is_collected(idx):
			cell_rect.modulate = Color(0.55, 0.52, 0.47)  ## 已收集未拼：低亮度
		else:
			cell_rect.modulate = Color(0.30, 0.27, 0.23, 0.85)  ## 未收集：暗色
		board_holder.add_child(cell_rect)

func _fly_piece_anim(idx: int) -> void:
	# 碎片掉落点亮动画：从顶部飞入到对应格子
	var cols := GameState.GRID.x
	var area: Vector2 = board_holder.size
	var cell := minf(area.x, area.y) / 12.0
	var origin := (area - Vector2(cell * 12.0, cell * 12.0)) / 2.0
	var col := idx % cols
	var row := idx / cols
	var target := origin + Vector2(col * cell, row * cell)
	# 高亮闪一下
	var flash := ColorRect.new()
	flash.color = Color(GameTheme.GOLD.r, GameTheme.GOLD.g, GameTheme.GOLD.b, 0.55)
	flash.position = target
	flash.size = Vector2(cell, cell)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_holder.add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.6)
	tw.tween_callback(flash.queue_free)

func _build_switch_row() -> void:
	for p in GameState.PUZZLES:
		var btn := Button.new()
		btn.text = str(p.title)
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(96, 40)
		btn.theme = GameTheme.soft_button_theme(15, GameTheme.INK)
		btn.toggled.connect(func(pressed: bool):
			if pressed:
				SoundManager.play("click")
				GameState.set_current_puzzle(str(p.id))
				_refresh_switch_row()
				_refresh_board())
		switch_row.add_child(btn)
	_refresh_switch_row()

func _refresh_switch_row() -> void:
	for i in switch_row.get_child_count():
		var btn: Button = switch_row.get_child(i)
		btn.set_pressed_no_signal(GameState.PUZZLES[i].id == GameState.current_puzzle_id)

# ---------------- 底部统计 ----------------

func _refresh_stats() -> void:
	stats_label.text = "今日专注 %d 分钟 · 番茄 ×%d · 拼图 %d/%d" % [
		int(GameState.today_minutes), GameState.pomodoro_count,
		GameState.collected_count(), GameState.TOTAL_PIECES]