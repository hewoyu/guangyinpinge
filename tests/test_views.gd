extends Node
## task-29 验收：景笺兑换 → unlocked_views → 书房窗替换

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
	GameState.unlocked_views.clear()
	GameState.scene_paper = 5
	GameState.claimed_achievements.clear()
	check("兑换 sakura(2价)", GameState.unlock_view("sakura"))
	check("景笺 5-2=3", GameState.scene_paper == 3)
	check("已解锁记录", GameState.is_view_unlocked("sakura"))
	GameState.scene_paper = 1
	check("不足拒绝 aurora(5价)", not GameState.unlock_view("aurora"))
	var latest := GameState.latest_unlocked_view()
	check("最新窗景 sakura", String(latest.get("id", "")) == "sakura")
	GameState.save_game()
	GameState.unlocked_views.clear()
	GameState.load_game()
	check("存档恢复解锁", GameState.is_view_unlocked("sakura"))
	var br: Control = (load("res://scenes/bookroom.tscn") as PackedScene).instantiate() as Control
	add_child(br)
	await get_tree().process_frame
	var wv: TextureRect = br.get_node_or_null("WindowView")
	check("书房窗显示窗景", wv != null and wv.visible and wv.texture != null)
	print("== TEST VIEWS: %d pass %d fail ==" % [_pass, _fail])
	get_tree().quit()
