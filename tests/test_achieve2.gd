extends Node
## task-31 验收：四分类成就 + streak

var _pass := 0
var _fail := 0

func check(n: String, c: bool, extra: String = "") -> void:
	if c:
		_pass += 1
		print("PASS  ", n)
	else:
		_fail += 1
		print("FAIL  ", n)

func _ready() -> void:
	# 清基线
	GameState.claimed_achievements.clear()
	GameState.total_focus_count = 1
	GameState.total_focus_minutes = 0.0
	GameState.completed_album.clear()
	GameState.history.clear()
	# 1) 次数：开机测试(need=1)可达成
	var boot := GameState.ACHIEVEMENTS[0]
	check("次数·开机测试达成", GameState.is_achieved(boot))
	# 2) streak：造连续 3 天历史
	var now := Time.get_unix_time_from_system()
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	for i in 3:
		var d := Time.get_date_string_from_unix_time(now - i * 86400.0 + float(bias) * 60.0)
		GameState.history[d] = { "minutes": 30.0, "pieces": 3 }
	check("streak 计算=3", GameState.focus_streak() == 3, "got %d" % GameState.focus_streak())
	var d3: Dictionary = GameState.ACHIEVEMENTS.filter(func(a): return a.id == "ach_d_three")[0]
	check("天数·三日之约达成", GameState.is_achieved(d3))
	var d7: Dictionary = GameState.ACHIEVEMENTS.filter(func(a): return a.id == "ach_d_seven")[0]
	check("天数·七日未达成(3<7)", not GameState.is_achieved(d7))
	# 3) 拼图：完成 1 幅
	GameState.completed_album.append("picnic")
	var p1: Dictionary = GameState.ACHIEVEMENTS.filter(func(a): return a.id == "ach_puz_first")[0]
	check("拼图·初见全景达成", GameState.is_achieved(p1))
	# 4) 时长：0.5 小时未达 1 小时
	GameState.total_focus_minutes = 30.0
	var h1: Dictionary = GameState.ACHIEVEMENTS.filter(func(a): return a.id == "ach_h_one")[0]
	check("时长·一小时未达成(0.5h)", not GameState.is_achieved(h1))
	GameState.total_focus_minutes = 65.0
	check("时长·一小时达成(65min)", GameState.is_achieved(h1))
	# 5) 领取联动
	GameState.scene_paper = 0
	check("领取三日之约得 1 景笺", GameState.claim_achievement(d3) and GameState.scene_paper == 1)
	print("== TEST ACHIEVE2: %d pass %d fail ==" % [_pass, _fail])
	get_tree().quit()
