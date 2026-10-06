extends SceneTree
## QA：全部 6 关可玩性验证（先等 autoload 就位再切场景）
const LEVELS := [1, 2, 3, 4, 5, 6]
var _i := 0
var _fail := 0
const EXPECT := {
	1: [Vector2i(3, 3), 9],
	2: [Vector2i(3, 4), 12],
	3: [Vector2i(4, 4), 16],
	4: [Vector2i(4, 5), 20],
	5: [Vector2i(5, 5), 25],
	6: [Vector2i(6, 6), 36],
}

func _init() -> void:
	_next()

func _next() -> void:
	if _i >= LEVELS.size():
		print("\n========== 6 关验证 ==========")
		if _fail == 0:
			print("ALL 6 LEVELS PASS ✅")
		else:
			print("FAILURES: %d ❌" % _fail)
		quit(_fail)
		return
	var id: int = LEVELS[_i]
	# 等一帧确保 autoload（GameState/SoundManager）已进入树，场景脚本才能编译通过
	await process_frame
	root.set_meta("scene_params", {"level_id": id})
	change_scene_to_file("res://scenes/puzzle.tscn")
	await _wait_frames(45)
	var scene := root.get_child(root.get_child_count() - 1) as Node
	var board := _find_board(scene)
	if board == null:
		print("LEVEL %d: FAIL board 未找到" % id)
		_fail += 1
	else:
		var exp_grid: Vector2i = EXPECT[id][0]
		var exp_cnt: int = EXPECT[id][1]
		var grid: Vector2i = board.get("grid_size")
		var cnt: int = board.get("total_pieces")
		var pieces: Array = board.get("pieces")
		var ok_region := 0
		for p in pieces:
			var t = p.get("_texture_rect").texture
			if t is AtlasTexture and t.region.size.x > 1:
				ok_region += 1
		var tex_ok: bool = board.get("puzzle_texture") != null
		if grid == exp_grid and cnt == exp_cnt and tex_ok and ok_region == exp_cnt:
			print("LEVEL %d: PASS grid=%s pieces=%d 裁切=%d 纹理✓" % [id, str(grid), cnt, ok_region])
		else:
			print("LEVEL %d: FAIL grid=%s(期望%s) pieces=%d(期望%d) 裁切=%d/%d 纹理=%s" % [id, str(grid), str(exp_grid), cnt, exp_cnt, ok_region, exp_cnt, str(tex_ok)])
			_fail += 1
	_i += 1
	_next()

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
