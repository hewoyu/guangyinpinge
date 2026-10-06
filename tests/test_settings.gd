extends Node
## task-27 验收

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.json"))
	# 1) 设置页实例化（滑条/开关/昵称全部构建）
	var sp: Control = (load("res://scenes/settings_page.tscn") as PackedScene).instantiate() as Control
	add_child(sp)
	await get_tree().process_frame
	check("设置页构建", sp != null)
	# 2) 键值读写
	SettingsData.set_value("sfx_vol", 0.45)
	check("音量存档", is_equal_approx(float(SettingsData.get_value("sfx_vol", 0.0)), 0.45))
	SettingsData.set_value("nickname", "小明")
	check("昵称存档", String(SettingsData.get_value("nickname", "")) == "小明")
	SettingsData.set_value("启用快速拼图按钮", true)
	check("开关存档", bool(SettingsData.get_value("启用快速拼图按钮", false)))
	sp.queue_free()
	await get_tree().process_frame
	# 3) 旅程信读昵称
	var jl: Control = (load("res://scenes/journey_letter.tscn") as PackedScene).instantiate() as Control
	add_child(jl)
	await get_tree().process_frame
	var col: VBoxContainer = jl.get_node("LetterCard/InnerPad/H/TextCol")
	var first: Label = col.get_child(0).get_child(0)
	check("旅程信昵称生效", first.text == "嗨，小明：", first.text)
	jl.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.json"))
	print("== TEST SETTINGS: %d pass %d fail ==" % [_pass, _fail])
	get_tree().quit()
