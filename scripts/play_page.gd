extends Control
## 玩法页（real_03/04 复刻 v4）：
## 布局基准 850x478 → 本页 1280x720：
##   拼图区 x18-463(52.4%) 近方形 | 计数卡+竖木托盘 x480-632 | 右栏 x660-835(23%) 两态
##   底部提示条（状态徽章：进行 #A05C2F / 结束 #7F93A2）+ 顶栏(←返回/三图标)
## 右栏状态机：
##   FOCUSING = 计时卡(任务名+25|5 RoundN+大数字+暂停/结束) + 待办卡 + 精读计数卡
##   IDLE/BREAK = 任务卡列表(开始/设置/累计N/N分钟) + 本周重点便签 + 呼吸发光球卡

const PuzzleBoardScene := preload("res://scenes/puzzle_board.tscn")
const PostcardScene := preload("res://scenes/postcard.tscn")

const LAYOUT := {
	"board_x": 0.021, "board_w": 0.524,      # 棋盘 52.4%
	"tray_x": 0.565, "tray_w": 0.180,        # 托盘
	"side_x": 0.776, "side_w": 0.207,        # 右栏
	"top_h": 0.042,                          # 顶栏
	"toast_y": 0.926,                        # 底部提示条
}

@onready var back_button: Button = $BackButton
@onready var board_holder: Control = $BoardHolder
@onready var side_panel: VBoxContainer = $SidePanel
## 右栏间距内容驱动（实测：计时态 2px / 空闲态 9px）
@onready var toast_label: Label = $Toast/ToastLabel
@onready var toast_badge: Label = $Toast/Badge

var board: Control = null
var _toast: Control

var _break_overlay: Control = null
var _break_timer_label: Label = null

func _process(_delta: float) -> void:
	## v5-23 休息态遮罩（BREAK 5 分钟可见界面）
	if FocusEngine.state == FocusEngine.STATE_BREAK:
		if _break_overlay == null or not is_instance_valid(_break_overlay):
			_show_break_overlay()
		if _break_timer_label and is_instance_valid(_break_timer_label):
			_break_timer_label.text = FocusEngine.fmt(FocusEngine.break_remaining)
	elif _break_overlay != null and is_instance_valid(_break_overlay):
		_break_overlay.queue_free()
		_break_overlay = null

func _show_break_overlay() -> void:
	_break_overlay = Control.new()
	_break_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.92, 0.84, 0.70, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_break_overlay.add_child(bg)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	v.position = Vector2(size.x / 2 - 160, size.y / 2 - 160)
	_break_overlay.add_child(v)
	var small := Label.new()
	small.text = "休息一下"
	small.add_theme_font_size_override("font_size", 24)
	small.add_theme_color_override("font_color", Color("A98C67"))
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(small)
	_break_timer_label = Label.new()
	_break_timer_label.text = "05:00"
	_break_timer_label.add_theme_font_size_override("font_size", 64)
	_break_timer_label.add_theme_color_override("font_color", Color("764E26"))
	_break_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_break_timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_break_timer_label)
	var tip := Label.new()
	tip.text = "让眼睛看看远方 · 5 分钟"
	tip.add_theme_font_size_override("font_size", 17)
	tip.add_theme_color_override("font_color", Color("9A8B78"))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(tip)
	var skip := Button.new()
	skip.text = "跳过休息"
	skip.theme = GameTheme.v4_text_button(19, Color("54452F"))
	skip.pressed.connect(func():
		SoundManager.play("click")
		FocusEngine.skip_break())
	v.add_child(skip)
	add_child(_break_overlay)

func _ready() -> void:
	back_button.flat = true
	back_button.add_theme_color_override("font_color", GameTheme.V_TEXT_MID)
	back_button.pressed.connect(_on_back)
	SoundManager.set_bgm_enabled(false)
	SoundManager.set_ambient("stream")
	_build_board()
	FocusEngine.state_changed.connect(_on_state_changed)
	FocusEngine.tick.connect(_on_tick)
	FocusEngine.piece_landed.connect(_on_piece_landed)
	FocusEngine.focus_finished.connect(_on_focus_finished)
	FocusEngine.pause_too_long.connect(_on_pause_too_long)   ## v6-34 暂停超时提醒
	_toast = $Toast   ## v6 修复：_toast 从未赋值 → _set_toast 一直空操作（掉落文案不更新的根因）
	_refresh_side()
	_set_toast("专注结束~ 快来拼拼图吧！", false)

func _build_board() -> void:
	board = PuzzleBoardScene.instantiate()
	board_holder.add_child(board)   ## 先入树：@onready（pieces_layer 等）才能就绪
	await get_tree().process_frame
	## v6 修复：棋盘按实际容器尺寸布局——否则内部兜底 1280x800 会把棋盘撑到 752px 高（窗口 720 以下被裁）
	board.size = board_holder.size
	var tex: Texture2D = load(GameState.get_current_puzzle().image)
	if board.has_method("setup"):
		board.setup(tex, GameState.GRID)
	# 同步已收集态（存档恢复 + 掉落实时刷新）
	if board.has_method("refresh_from_game_state"):
		board.refresh_from_game_state()
	GameState.piece_collected.connect(_on_piece_collected)
	# v5-20 官方承诺链路：完成拼图 → 显影 → 会动的明信片
	if board.has_signal("puzzle_completed"):
		board.puzzle_completed.connect(_on_puzzle_completed)
	# v5-21 自动拼完成 → 回收集模式（完成后 completed→明信片自动触发）
	if board.has_signal("auto_solve_finished"):
		board.auto_solve_finished.connect(_on_auto_solve_finished)
	# v6 计数卡（real_03 实测：托盘上方，两行计数）
	_build_counter_card()
	if board.has_signal("collection_changed"):
		board.collection_changed.connect(_update_counter)

var _timer_label: Label = null   ## 计时大数字引用（v5 修复：嵌套深路径 get_node 查不到导致不走秒）

func _on_tick(remaining: float) -> void:
	## 计时中刷新大数字（用引用，不再深路径查找）
	if _timer_label and is_instance_valid(_timer_label):
		_timer_label.text = FocusEngine.fmt(remaining)

func _on_state_changed(_s: int) -> void:
	## v6 修复：离开专注态时 toast 收口（放弃/暂停都不再残留掉落文案）
	if _s == FocusEngine.STATE_IDLE and FocusEngine.session_pieces > 0:
		_set_toast("专注结束~ 快来拼拼图吧！", false)
	_refresh_side()

func _on_pause_too_long(total_sec: float) -> void:
	## v6-34：暂停太久温柔提醒
	var m := int(total_sec) / 60
	_set_toast("已暂停 %d 分钟 · 碎片在等你回来" % m, false)

func _on_piece_landed(_idx: int) -> void:
	_toast_drop()

func _on_piece_collected(_i: int) -> void:
	if board and is_instance_valid(board) and board.has_method("refresh_from_game_state"):
		board.refresh_from_game_state()

func _on_auto_solve_finished() -> void:
	if _in_puzzle_mode:
		_in_puzzle_mode = false
		if board and is_instance_valid(board) and board.has_method("exit_puzzle_mode"):
			board.exit_puzzle_mode()
		## v6 体验：未集齐时明确告知差距（否则玩家疑惑为什么没完成）
		if GameState.placed_count() < GameState.TOTAL_PIECES:
			_set_toast("已拼 %d/%d 块 · 继续专注收集碎片吧" % [GameState.placed_count(), GameState.TOTAL_PIECES], false)
	_refresh_side()

func _toast_drop() -> void:
	## v5-22 官方格式："专注X分X秒~奖励拼图碎片×N"（real_03 实测）
	## v6-34：首分钟显示"专注X秒"（去"0分"前缀——玩家建议 D3）
	var e := int(FocusEngine.elapsed_sec)
	if e < 60:
		_set_toast("专注%d秒~奖励拼图碎片×%d" % [e, FocusEngine.session_pieces], true)
	else:
		_set_toast("专注%d分%d秒~奖励拼图碎片×%d" % [e / 60, e % 60, FocusEngine.session_pieces], true)

var _celebrating := false   ## 明信片链路防重入
var _in_puzzle_mode := false  ## v5-21 拼图模式态
var _counter_card: PanelContainer = null  ## v6 计数卡（real_03：已完成N/144块·托盘存量）
var _counter_l1: Label = null
var _counter_l2: Label = null

func _on_puzzle_completed() -> void:
	## v5-20：显影 → 会动的明信片 → 收图切下一幅（官方核心承诺）
	if _celebrating:
		return
	_celebrating = true
	if FocusEngine.state != FocusEngine.STATE_IDLE:
		FocusEngine.give_up_focus()
	# 1) 显影：全图淡入覆盖棋盘
	if board and is_instance_valid(board) and board.has_method("reveal_full_image"):
		board.reveal_full_image()
	SoundManager.play("win")
	await get_tree().create_timer(1.4).timeout
	# 2) 弹出会动的明信片
	var pc: Control = PostcardScene.instantiate() as Control
	add_child(pc)
	if pc.has_method("present"):
		pc.present(GameState.current_puzzle_id)
	# 3) 收图回调：切下一幅未完成拼图
	if pc.has_signal("done"):
		pc.done.connect(_next_puzzle_or_done)
	else:
		await get_tree().create_timer(6.0).timeout
		_next_puzzle_or_done()

func _next_puzzle_or_done() -> void:
	## 收下明信片后：归档当前拼图，切到下一幅未完成拼图
	GameState.mark_current_completed()
	var next_id := ""
	for p in GameState.PUZZLES:
		if not GameState.completed_album.has(p.id):
			next_id = String(p.id)
			break
	if next_id != "":
		GameState.set_current_puzzle(next_id)
		get_tree().reload_current_scene()
	else:
		## 全部完成 → 回书房（相册已满）
		get_tree().change_scene_to_file("res://scenes/bookroom.tscn")

func _on_focus_finished(minutes: float) -> void:
	## v5-22 完成结算：本轮 N 块（官方提示条语义）
	if FocusEngine.session_pieces > 0:
		var m := int(minutes)
		_set_toast("专注%d分%d秒~奖励拼图碎片×%d（本轮共获）" % [m / 60, m % 60, FocusEngine.session_pieces], false)
	else:
		_set_toast("专注结束~ 快来拼拼图吧！", false)
	_refresh_side()
	## 旅程结算信（real_06：一趟旅程结束 → 信件页）
	## 仅当本页是活动主场景时切换（避免嵌套实例/测试环境被误切）
	if get_tree().current_scene == self:
		await get_tree().create_timer(1.2).timeout
		if is_inside_tree() and FocusEngine.state != FocusEngine.STATE_FOCUSING:
			get_tree().change_scene_to_file("res://scenes/journey_letter.tscn")

func _set_toast(text: String, running: bool) -> void:
	if _toast == null:
		return
	toast_label.text = text
	toast_badge.text = str(maxi(FocusEngine.session_pieces, 0)) if running else "2"   ## v5-22 徽章=本轮碎片数
	toast_badge.add_theme_color_override("font_color", Color.WHITE)
	var sb := GameTheme.flat_style(GameTheme.V_BADGE_ON if running else GameTheme.V_BADGE_OFF, 3)
	toast_badge.add_theme_stylebox_override("normal", sb)

func _refresh_side() -> void:
	_timer_label = null   ## 右栏重建时清引用（旧节点即将 free）
	for c in side_panel.get_children():
		c.queue_free()
	side_panel.add_theme_constant_override("separation", 2 if FocusEngine.state in [FocusEngine.STATE_FOCUSING, FocusEngine.STATE_PAUSED] else 9)
	if _in_puzzle_mode:
		_build_puzzle_mode_side()
	elif FocusEngine.state in [FocusEngine.STATE_FOCUSING, FocusEngine.STATE_PAUSED]:
		_build_focus_side()   ## v6 修复：PAUSED 也保留计时卡（继续/结束按钮可用）
	else:
		_build_idle_side()

func _build_focus_side() -> void:
	## 计时中（real_03）：任务名 + 番茄钟 25|5 RoundN + 大数字 + 暂停/结束
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", GameTheme.v4_side_card())
	side_panel.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var task := Label.new()
	task.text = "拾光拼途"
	task.add_theme_font_size_override("font_size", GameTheme.V_F_BODY)
	task.add_theme_color_override("font_color", GameTheme.V_TEXT_BODY)
	v.add_child(task)
	var sub := Label.new()
	sub.text = "番茄钟 25|5 Round%d" % maxf(1, GameState.pomodoro_count + 1)
	sub.add_theme_font_size_override("font_size", GameTheme.V_F_SMALL)
	sub.add_theme_color_override("font_color", Color("A98C67"))
	v.add_child(sub)
	var big := Label.new()
	big.name = "TimerBig"
	_timer_label = big   ## v5 修复：保存引用供 _on_tick 更新
	big.text = FocusEngine.fmt(FocusEngine.remaining_sec)
	big.add_theme_font_size_override("font_size", GameTheme.V_F_TIMER)
	big.add_theme_color_override("font_color", GameTheme.V_TIMER)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 24)
	v.add_child(btns)
	var pause := Button.new()
	pause.name = "PauseButton"
	## v6：暂停/继续二合一（官方无独立 resume 入口，防误重置）
	pause.text = "继续" if FocusEngine.state == FocusEngine.STATE_PAUSED else "暂停"
	pause.theme = GameTheme.v4_text_button(GameTheme.V_F_BODY)
	pause.pressed.connect(func():
		SoundManager.play("click")
		if FocusEngine.state == FocusEngine.STATE_PAUSED:
			FocusEngine.resume_focus()
		else:
			FocusEngine.pause_focus()
		pause.text = "暂停"   ## resume 后 _refresh_side 会重建右栏，文本由状态驱动
	)   ## v6 修复：闭合 connect(func(): ...) 的括号
	btns.add_child(pause)
	var stop := Button.new()
	stop.text = "结束"
	stop.theme = GameTheme.v4_text_button(GameTheme.V_F_BODY)
	## v6-34：二次确认（防误点丢整轮——玩家建议 D1）
	stop.pressed.connect(func():
		SoundManager.play("click")
		var dlg := ConfirmationDialog.new()
		dlg.dialog_text = "确定结束本轮专注吗？\n（本轮已获碎片会保留）"
		dlg.ok_button_text = "确定结束"
		dlg.cancel_button_text = "再想想"
		dlg.confirmed.connect(func(): FocusEngine.give_up_focus())
		add_child(dlg)
		dlg.popup_centered())
	btns.add_child(stop)
	# v5-24 待办卡（real_03：隐藏+/统计 + 添加行 + 着色任务列表）
	_build_todo_card()
	# v5-25 计数器卡（real_03 第三卡：归零/设置 + 标题 + − N ＋）
	_build_counter_widget()
	# v5-25 备忘入口（纯文字，弹编辑窗）
	var memo_btn := Button.new()
	memo_btn.text = "备忘"
	memo_btn.theme = GameTheme.v4_text_button(GameTheme.V_F_SMALL, Color("A98C67"))
	memo_btn.pressed.connect(_open_memo)
	side_panel.add_child(memo_btn)

func _build_todo_card() -> void:
	var todo := PanelContainer.new()
	todo.add_theme_stylebox_override("panel", GameTheme.v4_side_card())
	side_panel.add_child(todo)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 4)
	todo.add_child(tv)
	## 卡头：隐藏+ | 统计
	var head := HBoxContainer.new()
	tv.add_child(head)
	var hide_l := Label.new()
	hide_l.text = "隐藏+"
	hide_l.add_theme_font_size_override("font_size", GameTheme.V_F_SMALL)
	hide_l.add_theme_color_override("font_color", GameTheme.V_TEXT_SUB)
	head.add_child(hide_l)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var stat := Button.new()
	stat.text = "统计"
	stat.flat = true
	stat.add_theme_font_size_override("font_size", GameTheme.V_F_SMALL)
	stat.add_theme_color_override("font_color", GameTheme.V_TEXT_SUB)
	stat.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/todo_stats.tscn"))
	head.add_child(stat)
	## 添加行：类别色点 + 输入 + ✓
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 6)
	tv.add_child(add_row)
	var cat := ColorRect.new()
	cat.name = "CatDot"
	cat.color = Color(TodoData.CATEGORY_COLORS["life"])
	cat.custom_minimum_size = Vector2(10, 10)
	add_row.add_child(cat)
	var input := LineEdit.new()
	input.name = "TodoInput"
	input.placeholder_text = "点击添加待办任务..."
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.custom_minimum_size = Vector2(0, 26)
	add_row.add_child(input)
	var ok := Button.new()
	ok.text = "✓"
	ok.flat = true
	ok.add_theme_color_override("font_color", GameTheme.V_TEXT_MID)
	ok.pressed.connect(func():
		var txt := input.text.strip_edges()
		if txt != "":
			var cat_key: String = _cat_key_of(cat.color)
			TodoData.add(txt, cat_key)
			input.text = ""
			_refresh_side())
	add_row.add_child(ok)
	## 类别切换：4 色小圆点（点输入框左侧色点循环）
	cat.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			var keys := ["life", "study", "work", "urgent"]
			var cur: int = keys.find(_cat_key_of(cat.color))
			cat.color = Color(TodoData.CATEGORY_COLORS[keys[(cur + 1) % keys.size()]])
			cat.queue_redraw())
	## 任务列表（前 4 条 active）
	var items := TodoData.items()
	var shown := 0
	for i in items.size():
		if shown >= 4:
			break
		var t: Dictionary = items[i]
		if bool(t.get("done", false)):
			continue
		shown += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		tv.add_child(row)
		var dot := ColorRect.new()
		dot.color = Color(TodoData.CATEGORY_COLORS[t.get("category", "life")])
		dot.custom_minimum_size = Vector2(8, 8)
		row.add_child(dot)
		var label := Label.new()
		label.text = "· " + String(t.get("text", ""))
		label.add_theme_font_size_override("font_size", GameTheme.V_F_SMALL)
		label.add_theme_color_override("font_color", GameTheme.V_TEXT_BODY)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(label)
		var done_b := Button.new()
		done_b.text = "✓"
		done_b.flat = true
		done_b.add_theme_color_override("font_color", Color("6E8B3D"))
		done_b.pressed.connect(func(): TodoData.toggle(i); _refresh_side())
		row.add_child(done_b)
		var del_b := Button.new()
		del_b.text = "✕"
		del_b.flat = true
		del_b.add_theme_color_override("font_color", Color("9A8B78"))
		del_b.pressed.connect(func(): TodoData.remove(i); _refresh_side())
		row.add_child(del_b)

func _cat_key_of(c: Color) -> String:
	for k in TodoData.CATEGORY_COLORS:
		if Color(TodoData.CATEGORY_COLORS[k]).is_equal_approx(c):
			return String(k)
	return "life"

func _build_counter_widget() -> void:
	## real_03 第三卡：卡头(归零/设置) + 标题 + 大数字 + (− 页 ＋)
	var data := CounterData.load_data()
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", GameTheme.v4_side_card())
	side_panel.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var zero := Button.new()
	zero.text = "归零"
	zero.flat = true
	zero.add_theme_font_size_override("font_size", 13)
	zero.add_theme_color_override("font_color", Color("A98C67"))
	zero.pressed.connect(func():
		CounterData.save_data(String(data.title), 0)
		_refresh_side())
	head.add_child(zero)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var set_b := Button.new()
	set_b.text = "设置"
	set_b.flat = true
	set_b.add_theme_font_size_override("font_size", 13)
	set_b.add_theme_color_override("font_color", Color("A98C67"))
	set_b.pressed.connect(func():
		var dlg := AcceptDialog.new()
		var edit := LineEdit.new()
		edit.text = String(data.title)
		dlg.add_child(edit)
		dlg.confirmed.connect(func():
			CounterData.save_data(edit.text, int(data.value))
			_refresh_side())
		add_child(dlg)
		dlg.popup_centered(Vector2i(260, 110)))
	head.add_child(set_b)
	var title := Label.new()
	title.text = String(data.title)
	title.add_theme_font_size_override("font_size", GameTheme.V_F_SMALL)
	title.add_theme_color_override("font_color", GameTheme.V_TEXT_SUB)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var num := Label.new()
	num.text = str(int(data.value))
	num.add_theme_font_size_override("font_size", 34)
	num.add_theme_color_override("font_color", GameTheme.V_TIMER)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(num)
	var ops := HBoxContainer.new()
	ops.alignment = BoxContainer.ALIGNMENT_CENTER
	ops.add_theme_constant_override("separation", 16)
	v.add_child(ops)
	var minus := Button.new()
	minus.text = "−"
	minus.flat = true
	minus.add_theme_font_size_override("font_size", 22)
	minus.add_theme_color_override("font_color", GameTheme.V_TEXT_MID)
	minus.pressed.connect(func():
		CounterData.save_data(String(data.title), maxi(int(data.value) - 8, 0))
		_refresh_side())
	ops.add_child(minus)
	var unit := Label.new()
	unit.text = "页"
	unit.add_theme_font_size_override("font_size", GameTheme.V_F_SMALL)
	unit.add_theme_color_override("font_color", GameTheme.V_TEXT_SUB)
	ops.add_child(unit)
	var plus := Button.new()
	plus.text = "＋"
	plus.flat = true
	plus.add_theme_font_size_override("font_size", 22)
	plus.add_theme_color_override("font_color", GameTheme.V_TEXT_MID)
	plus.pressed.connect(func():
		CounterData.save_data(String(data.title), int(data.value) + 8)
		_refresh_side())
	ops.add_child(plus)

func _open_memo() -> void:
	## v5-25 备忘录：弹窗多行编辑 + 即存
	var dlg := AcceptDialog.new()
	dlg.title = "备忘录"
	var pad := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(m, 10)
	dlg.add_child(pad)
	var te := TextEdit.new()
	te.custom_minimum_size = Vector2i(380, 220)
	te.text = CounterData.load_memo()
	pad.add_child(te)
	dlg.confirmed.connect(func(): CounterData.save_memo(te.text))
	dlg.ok_button_text = "保存"
	add_child(dlg)
	dlg.popup_centered(Vector2i(420, 300))

func _build_puzzle_mode_side() -> void:
	## v5-21 拼图模式右栏（real_03 拼图辅助：自动拼按钮 + 返回）
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", GameTheme.v4_side_card())
	side_panel.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var tip := Label.new()
	tip.text = "把碎片拖到棋盘上\n拼对位置会自动吸附"
	tip.add_theme_font_size_override("font_size", GameTheme.V_F_SMALL)
	tip.add_theme_color_override("font_color", GameTheme.V_TEXT_BODY)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tip)
	## v6-34 去重：自动拼按钮由 board 提供（棋盘区，官方 real_03 位置）——右栏不再重复放。
	## 拼图排序开关（「启用拼图排序按钮」默认开）：关=进拼图模式时隐藏 board 的按钮
	if board and is_instance_valid(board):
		board.auto_button.visible = bool(SettingsData.get_value("启用拼图排序按钮", true))
	var back_btn := Button.new()
	back_btn.text = "返回收集"
	back_btn.theme = GameTheme.v4_text_button(GameTheme.V_F_BODY)
	back_btn.pressed.connect(_exit_puzzle_mode)
	v.add_child(back_btn)

func _build_idle_side() -> void:
	## 空闲（real_04）：任务卡 + 本周重点便签 + 呼吸发光球卡
	# 任务卡（点击"开始"进入计时）
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", GameTheme.v4_side_card())
	side_panel.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var title := Label.new()
	title.text = GameState.get_current_puzzle().title
	title.add_theme_font_size_override("font_size", GameTheme.V_F_BODY)
	title.add_theme_color_override("font_color", GameTheme.V_TEXT_TITLE)
	v.add_child(title)
	var desc := Label.new()
	desc.text = "每专注25分钟，休息5分钟"
	desc.add_theme_font_size_override("font_size", GameTheme.V_F_SMALL)
	desc.add_theme_color_override("font_color", GameTheme.V_TEXT_SUB)
	v.add_child(desc)
	var prog := Label.new()
	prog.text = "已累计 %d/ %d分钟（%d/8）" % [int(GameState.journey_minutes), 200, GameState.pomodoro_count]
	prog.add_theme_font_size_override("font_size", GameTheme.V_F_SMALL)
	prog.add_theme_color_override("font_color", GameTheme.V_TEXT_SUB)
	v.add_child(prog)
	var start := Button.new()
	start.text = "开始"
	start.theme = GameTheme.v4_text_button(GameTheme.V_F_BODY)
	start.pressed.connect(func():
			SoundManager.play("click")
			FocusEngine.start_focus(25.0)
			_refresh_side())
	v.add_child(start)
	## v5-21 官方：拼图模式入口（带进度提示）
	var pmode := Button.new()
	pmode.text = "拼图模式（%d/144）" % GameState.placed_count()
	pmode.theme = GameTheme.v4_cream_button(18)
	pmode.pressed.connect(_enter_puzzle_mode)
	v.add_child(pmode)
	# v5-26 本周重点便签（real_04：米黄半透明 + 编号列表 + 记得子块）
	_build_weekly_notes_card()
	# 呼吸卡（发光球 + 轻触开始）
	var breath := PanelContainer.new()
	breath.add_theme_stylebox_override("panel", GameTheme.v4_side_card())
	side_panel.add_child(breath)
	var bv := VBoxContainer.new()
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_theme_constant_override("separation", 8)
	breath.add_child(bv)
	var glow := TextureRect.new()
	glow.texture = load("res://assets/images/deco_light_spot.svg")
	glow.custom_minimum_size = Vector2(48, 48)
	glow.modulate = Color("B1F3E2")
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bv.add_child(glow)
	var anim := create_tween().set_loops()
	anim.tween_property(glow, "modulate:a", 0.5, 2.0).set_trans(Tween.TRANS_SINE)
	anim.tween_property(glow, "modulate:a", 1.0, 2.0).set_trans(Tween.TRANS_SINE)
	var bhint := Label.new()
	bhint.text = "轻触开始，跟随花朵调整呼吸。"
	bhint.add_theme_font_size_override("font_size", GameTheme.V_F_SMALL)
	bhint.add_theme_color_override("font_color", GameTheme.V_TEXT_SUB)
	bhint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(bhint)
	var bstart := Button.new()
	bstart.text = "开始"
	bstart.theme = GameTheme.v4_text_button(GameTheme.V_F_BODY)
	bstart.pressed.connect(func():
		SoundManager.play("click")
		get_tree().change_scene_to_file("res://scenes/breath_page.tscn"))
	bv.add_child(bstart)

func _build_counter_card() -> void:
	## v6 real_03：木质计数卡（棋盘右上、两行"已完成 N/144 块""当前托盘存量 N 块"）
	if _counter_card != null:
		return
	_counter_card = PanelContainer.new()
	var sb := GameTheme.flat_style(Color("F3E4C5"), 4)
	sb.border_color = Color("C8B18B")
	sb.set_border_width_all(1)
	_counter_card.add_theme_stylebox_override("panel", sb)
	_counter_card.position = Vector2(size.x * 0.585, 44)
	_counter_card.custom_minimum_size = Vector2(188, 66)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_counter_card.add_child(v)
	_counter_l1 = Label.new()
	_counter_l1.add_theme_font_size_override("font_size", 16)
	_counter_l1.add_theme_color_override("font_color", GameTheme.V_TEXT_TITLE)
	v.add_child(_counter_l1)
	_counter_l2 = Label.new()
	_counter_l2.add_theme_font_size_override("font_size", 14)
	_counter_l2.add_theme_color_override("font_color", Color("A98C67"))
	v.add_child(_counter_l2)
	add_child(_counter_card)
	_update_counter(GameState.collected_count(), GameState.placed_count())

func _update_counter(collected: int, placed: int) -> void:
	if _counter_l1 == null:
		return
	_counter_l1.text = "已完成 %d/%d 块" % [placed, GameState.TOTAL_PIECES]
	_counter_l2.text = "当前托盘存量 %d 块" % maxi(GameState.collected_count() - placed, 0)

## ---------- v5-21 拼图模式 ----------

func _enter_puzzle_mode() -> void:
	## 官方："可以自己拼拼图"——已收集未拼碎片进托盘自由拖拽
	SoundManager.play("click")
	_in_puzzle_mode = true
	if board and board.has_method("enter_puzzle_mode"):
		board.enter_puzzle_mode()
		## v6-34：拼图排序开关（关=隐藏 board 的自动拼按钮）
		if board.auto_button != null:
			board.auto_button.visible = bool(SettingsData.get_value("启用拼图排序按钮", true))
	_refresh_side()

func _exit_puzzle_mode() -> void:
	SoundManager.play("click")
	_in_puzzle_mode = false
	if board and board.has_method("exit_puzzle_mode"):
		board.exit_puzzle_mode()
	_refresh_side()

func _auto_solve_pressed() -> void:
	## 官方："点击按钮自动拼"（real_10 可关闭的拼图辅助）
	SoundManager.play("click")
	if board and board.has_method("auto_solve"):
		## v6-34：快速拼图开关（关=慢速 0.25s/块，开=默认 0.06）
		if not bool(SettingsData.get_value("启用快速拼图按钮", true)):
			board.auto_solve_interval = 0.25
		board.auto_solve()

func _build_weekly_notes_card() -> void:
	## v5-26 real_04 第二卡：本周重点（米黄便签 + 编号列表 + 记得子块 + 底部裁切）
	var notes := CounterData.load_notes()
	var card := PanelContainer.new()
	var sb := GameTheme.flat_style(Color("E3C7A0"), 8)
	sb.content_margin_left = 12.0; sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0; sb.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", sb)
	card.modulate.a = 0.94
	side_panel.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	card.add_child(v)
	## 卡头：本周重点 | 设置
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := Label.new()
	title.text = "本周重点"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("4A3A2A"))
	head.add_child(title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var set_b := Button.new()
	set_b.text = "设置"
	set_b.flat = true
	set_b.add_theme_font_size_override("font_size", 12)
	set_b.add_theme_color_override("font_color", Color("A98C67"))
	set_b.pressed.connect(_edit_weekly_notes)
	head.add_child(set_b)
	## 编号列表
	for p in notes.get("points", []):
		var l := Label.new()
		l.text = String(p)
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Color("6B4A2E"))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(l)
	## 记得子块（次级标题 + 分隔感 + 列表）
	var rem_title := Label.new()
	rem_title.text = "记得"
	rem_title.add_theme_font_size_override("font_size", 13)
	rem_title.add_theme_color_override("font_color", Color("7A5C3A"))
	v.add_child(rem_title)
	for r in notes.get("remembers", []):
		var rl := Label.new()
		rl.text = String(r)
		rl.add_theme_font_size_override("font_size", 12)
		rl.add_theme_color_override("font_color", Color("8A6E4E"))
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(rl)

func _edit_weekly_notes() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "编辑本周计划"
	var pad := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(m, 10)
	dlg.add_child(pad)
	var v := VBoxContainer.new()
	pad.add_child(v)
	var notes := CounterData.load_notes()
	var p_edit := TextEdit.new()
	p_edit.text = "\n".join(PackedStringArray(notes.get("points", [])))
	p_edit.custom_minimum_size = Vector2i(360, 90)
	v.add_child(p_edit)
	var r_edit := TextEdit.new()
	r_edit.text = "\n".join(PackedStringArray(notes.get("remembers", [])))
	r_edit.custom_minimum_size = Vector2i(360, 70)
	v.add_child(r_edit)
	dlg.confirmed.connect(func():
		CounterData.save_notes(p_edit.text.split("\n"), r_edit.text.split("\n"))
		_refresh_side())
	dlg.ok_button_text = "保存"
	add_child(dlg)
	dlg.popup_centered(Vector2i(420, 340))

func _on_back() -> void:
	SoundManager.play("click")
	get_tree().change_scene_to_file("res://scenes/bookroom.tscn")
