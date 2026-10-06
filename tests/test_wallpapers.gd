extends Node
## 壁纸图库验收：9 幅图库 + 壁纸可加载 + 拼图选择网格

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
	check("图库 9 幅", GameState.PUZZLES.size() == 9, "got %d" % GameState.PUZZLES.size())
	# 全部图可加载
	var all_load := true
	for p in GameState.PUZZLES:
		var tex := load(String(p.image))
		if tex == null:
			all_load = false
			print("  load fail:", p.id)
	check("9 幅纹理全部可加载", all_load)
	# 壁纸纹理尺寸方形
	var wtex: Texture2D = load("res://assets/images/wallpapers/sq_wall_08.png")
	check("壁纸方形 1080", wtex != null and wtex.get_width() == wtex.get_height(), "%dx%d" % [wtex.get_width() if wtex else 0, wtex.get_height() if wtex else 0])
	# 选择页网格 9 卡
	var ps: Control = (load("res://scenes/puzzle_select.tscn") as PackedScene).instantiate() as Control
	add_child(ps)
	await get_tree().process_frame
	check("选择页 9 卡", ps.get_node("Scroll/Cards").get_child_count() == 9, "got %d" % ps.get_node("Scroll/Cards").get_child_count())
	ps.queue_free()
	await get_tree().process_frame
	# 切到壁纸拼图可进玩法页
	GameState.set_current_puzzle("w8")
	var page: Control = (load("res://scenes/play_page.tscn") as PackedScene).instantiate() as Control
	add_child(page)
	await get_tree().create_timer(0.8).timeout
	var board = page.get_node_or_null("BoardHolder/PuzzleBoard")
	check("壁纸拼图板构建", board != null and board.puzzle_texture != null)
	page.queue_free()
	GameState.set_current_puzzle("picnic")
	print("== TEST WALLPAPERS: %d pass %d fail ==" % [_pass, _fail])
	get_tree().quit()
