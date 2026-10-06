extends Node
## task-36 验收：起止时间 + 轮播

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
	GameState.journey_history.clear()
	var now := int(Time.get_unix_time_from_system())
	# 两趟带起止时间（间隔6小时/25分钟）
	GameState.journey_history.append({"no": 1, "date": "2026-10-05", "focus_count": 3, "minutes": 82, "start_ts": now - 8 * 3600, "end_ts": now - 2 * 3600})
	GameState.journey_history.append({"no": 2, "date": "2026-10-06", "focus_count": 1, "minutes": 25, "start_ts": now - 3600, "end_ts": now - 2100})
	var jr: Control = (load("res://scenes/journey_review.tscn") as PackedScene).instantiate() as Control
	add_child(jr)
	await get_tree().create_timer(0.5).timeout
	# 1) 默认显示最新趟（含时间范围与"—"）
	var first_card: PanelContainer = jr.get_node("Scroll/List").get_child(0)
	var range_l: Label = first_card.get_child(0).get_child(0).get_child(1)
	check("时间范围含—", range_l.text.contains("—"), range_l.text)
	check("默认最新趟=第2趟", first_card.get_child(0).get_child(0).get_child(0).text == "第2趟旅程")
	# 2) 上一趟切换
	var nav: HBoxContainer = jr.get_node("Scroll/List").get_child(1)
	var prev_btn: Button = nav.get_child(0)
	prev_btn.emit_signal("pressed")
	await get_tree().create_timer(0.3).timeout
	var card2: PanelContainer = jr.get_node("Scroll/List").get_child(0)
	check("切到第1趟", card2.get_child(0).get_child(0).get_child(0).text == "第1趟旅程")
	# 3) 边界禁用（第1趟时"上一趟"disabled）
	var nav2: HBoxContainer = jr.get_node("Scroll/List").get_child(1)
	check("边界禁用上一趟", (nav2.get_child(0) as Button).disabled)
	# 4) start_new_journey 的时间戳链
	GameState.journey_start_ts = now - 7200
	GameState.journey_count = 3
	GameState.journey_focus_count = 2
	GameState.journey_minutes = 50.0
	GameState.start_new_journey()
	var last: Dictionary = GameState.journey_history.back()
	check("新趟记录 start_ts", int(last.start_ts) == now - 7200)
	check("新趟记录 end_ts>start", int(last.end_ts) >= now - 7200)
	check("下趟起点=本趟结束", GameState.journey_start_ts >= now - 60)
	print("== A36 JOURNEY: %d pass %d fail ==" % [_pass, _fail])
	get_tree().quit()
