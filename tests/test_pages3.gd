extends Node
## task-30 验收：旅程回顾/关于教程/拼图选择三页

var _pass := 0
var _fail := 0

func check(n: String, c: bool) -> void:
	if c:
		_pass += 1
		print("PASS  ", n)
	else:
		_fail += 1
		print("FAIL  ", n)

func _ready() -> void:
	# 1) 旅程回顾
	GameState.journey_history.clear()
	GameState.journey_history.append({"no": 1, "date": "2026-10-05", "focus_count": 3, "minutes": 82.0})
	GameState.journey_history.append({"no": 2, "date": "2026-10-06", "focus_count": 1, "minutes": 25.0})
	var jr: Control = load("res://scenes/journey_review.tscn").instantiate()
	add_child(jr)
	await get_tree().process_frame
	check("旅程回顾 2 条历史", jr.get_node("Scroll/List").get_child_count() == 2)
	jr.queue_free()
	await get_tree().process_frame
	# 2) 关于页四步
	var ab: Control = load("res://scenes/about_page.tscn").instantiate()
	add_child(ab)
	await get_tree().process_frame
	check("关于页四步卡", ab.get_node("Steps").get_child_count() == 4)
	ab.queue_free()
	await get_tree().process_frame
	# 3) 拼图选择切换
	var ps: Control = load("res://scenes/puzzle_select.tscn").instantiate()
	add_child(ps)
	await get_tree().process_frame
	check("拼图选择 9 幅卡", ps.get_node("Scroll/Cards").get_child_count() == 9)
	GameState.set_current_puzzle("starry")
	check("切换到第二幅", GameState.current_puzzle_id == "starry")
	ps.queue_free()
	await get_tree().process_frame
	GameState.set_current_puzzle("picnic")
	print("== TEST PAGES3: %d pass %d fail ==" % [_pass, _fail])
	get_tree().quit()
