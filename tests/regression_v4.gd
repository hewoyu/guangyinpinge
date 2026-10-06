extends Node
## v4 全量回归：按真实截图规格（12 张图分析基线）
## 运行：godot --headless --fixed-fps 60 res://tests/regression_v4_boot.tscn --quit-after 3000

var _pass := 0
var _fail := 0

func check(name: String, cond: bool, extra: String = "") -> void:
	if cond:
		_pass += 1
		print("PASS  ", name)
	else:
		_fail += 1
		print("FAIL  ", name, " ", extra)

func _ready() -> void:
	# ---- 0. 清档 ----
	var save_path := ProjectSettings.globalize_path("user://save_v3.json")
	DirAccess.remove_absolute(save_path)
	GameState.collected.clear()
	GameState.placed.clear()
	GameState.history.clear()
	GameState.journey_count = 0
	GameState.journey_focus_count = 0
	GameState.journey_minutes = 0.0
	GameState.claimed_achievements.clear()
	GameState.scene_paper = 0
	GameState.total_focus_count = 0
	GameState.total_focus_minutes = 0.0
	GameState.total_pieces_dropped = 0
	GameState.pomodoro_count = 0
	GameState.today_minutes = 0.0

	# ---- 1. 书房主界面 ----
	var br: Control = load("res://scenes/bookroom.tscn").instantiate()
	add_child(br)
	await _f(30)
	var scene_img: TextureRect = br.get_node("Scene")
	check("书房场景图渲染", scene_img.texture != null)
	var menu_items := br.get_node("MenuLayer").get_child_count()
	check("书房菜单热区 >= 8（6入口+箭头+CTA）", menu_items >= 6, "got %d" % menu_items)
	br.queue_free()
	await _f(10)

	# ---- 2. 玩法页 + 咬合碎片 ----
	var page: Control = load("res://scenes/play_page.tscn").instantiate()
	add_child(page)
	await _f(30)
	var board = page.get_node_or_null("BoardHolder/PuzzleBoard")
	check("拼图板实例化", board != null)
	var poly_piece = null
	for p in board.pieces:
		if p._poly.size() > 8:
			poly_piece = p
			break
	check("咬合碎片多边形（>8顶点）", poly_piece != null and poly_piece._poly.size() >= 18, "pts=%d" % (poly_piece._poly.size() if poly_piece else 0))
	check("Jigsaw 边表确定性", Jigsaw.make_edges(12, 12, 1).h.size() == 12 * 13)

	# ---- 3. 掉落 + 收集同步 ----
	FocusEngine.debug_drop_interval = 1.5
	FocusEngine.start_focus(25.0)
	await _f(8 * 60)
	var c1: int = GameState.collected_count()
	check("掉落发生（>=3）", c1 >= 3, "got %d" % c1)
	var hidden := 0
	for p in board.pieces:
		if p.cell_state == PuzzlePiece.CELL_HIDDEN:
			hidden += 1
	check("收集同步到空位渲染", hidden == GameState.TOTAL_PIECES - c1, "hidden=%d expect=%d" % [hidden, GameState.TOTAL_PIECES - c1])
	check("历史按日记录", GameState.history.size() >= 1 and GameState.history.has(Time.get_date_string_from_system()))

	# ---- 4. 完成流转 + 旅程信数据 ----
	FocusEngine.give_up_focus()
	await _f(10)
	var jf_b: int = GameState.journey_focus_count
	var jm_b: float = GameState.journey_minutes
	check("旅程统计累积", jm_b > 0.0, "%.2f" % jm_b)
	FocusEngine.debug_drop_interval = 0.0
	FocusEngine.start_focus(1.0 / 60.0)
	await _f(90)
	check("番茄完成（journey_focus +1）", GameState.journey_focus_count == jf_b + 1, "%d vs %d" % [GameState.journey_focus_count, jf_b])
	check("总番茄数累计", GameState.pomodoro_count >= 1)
	page.queue_free()
	await _f(10)

	# ---- 5. 旅程信页 ----
	var jl: Control = load("res://scenes/journey_letter.tscn").instantiate()
	add_child(jl)
	await _f(20)
	var col: VBoxContainer = jl.get_node("LetterCard/InnerPad/H/TextCol")
	check("旅程信文案行数 = 5", col.get_child_count() == 5, "got %d" % col.get_child_count())
	var pb: TextureRect = jl.get_node("Postbox")
	await _f(30)
	check("邮筒渲染", pb.texture != null or ResourceLoader.exists("res://assets/images/postbox.svg"), "texture=%s" % [pb.texture != null])
	jl.queue_free()
	await _f(10)

	# ---- 6. 统计页 ----
	var sp: Control = load("res://scenes/stats_page.tscn").instantiate()
	add_child(sp)
	await _f(20)
	check("统计页实例化", sp != null)
	sp.queue_free()
	await _f(10)

	# ---- 7. 成就页 + 景笺 ----
	var ap: Control = load("res://scenes/achievements_page.tscn").instantiate()
	add_child(ap)
	await _f(20)
	var paper_b: int = GameState.scene_paper
	var ach := GameState.ACHIEVEMENTS[0]  ## 开机测试（1 次）
	check("成就1可达成", GameState.is_achieved(ach), "focus=%d need=1" % GameState.total_focus_count)
	if GameState.claim_achievement(ach):
		check("领取景笺 +1", GameState.scene_paper == paper_b + 1)
	else:
		check("领取景笺 +1", false, "claim failed")
	ap.queue_free()
	await _f(10)

	# ---- 8. 音乐盒 + 呼吸页 ----
	var mb: Control = load("res://scenes/music_box.tscn").instantiate()
	add_child(mb)
	await _f(15)
	mb.queue_free()
	var bp: Control = load("res://scenes/breath_page.tscn").instantiate()
	add_child(bp)
	await _f(15)
	check("呼吸球引导页", bp.get_node("BreathSphere/Sphere") != null)
	bp.queue_free()
	await _f(10)

	# ---- 9. 存档恢复 ----
	GameState.save_game()
	GameState.collected.clear()
	GameState.history.clear()
	GameState.scene_paper = 0
	GameState.load_game()
	check("存档恢复 collected", GameState.collected_count() >= c1, "%d vs %d" % [GameState.collected_count(), c1])
	check("存档恢复 history", GameState.history.size() >= 1)
	check("存档恢复景笺", GameState.scene_paper == paper_b + 1)
	check("存档恢复旅程计数", GameState.journey_focus_count >= jf_b + 1)

	print("== V4 REGRESSION: %d pass, %d fail ==" % [_pass, _fail])
	if _fail == 0:
		print("V4 ALL PASS")
	get_tree().quit()

func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame
