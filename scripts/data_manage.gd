extends Control
## 数据管理页（task-28 f）：存档概览 + 导出/导入/清空

@onready var back_button: Button = $BackButton
@onready var overview: GridContainer = $Overview
@onready var actions: HBoxContainer = $Actions

func _ready() -> void:
	back_button.flat = true
	back_button.add_theme_color_override("font_color", GameTheme.V_TEXT_MID)
	back_button.pressed.connect(func():
		SoundManager.play("click")
		get_tree().change_scene_to_file("res://scenes/stats_page.tscn"))
	_build_overview()
	_build_actions()

func _build_overview() -> void:
	## 概览四卡（复用 real_12 统计砖样式：浅 #C5AA92/深 #997D66 棋盘交替）
	var save_path := ProjectSettings.globalize_path("user://save_v3.json")
	var save_size := 0
	if FileAccess.file_exists(save_path):
		var f := FileAccess.open(save_path, FileAccess.READ)
		save_size = f.get_length() if f else 0
		if f: f.close()
	var days := 0
	for d in GameState.history:
		if float(GameState.history[d].minutes) > 0.0:
			days += 1
	var cards := [
		[str(maxi(save_size / 1024, 0)) + " KB", "存档大小"],
		[str(days), "累计专注天数"],
		[str(GameState.journey_history.size()), "完成旅程趟数"],
		[str(GameState.scene_paper), "未使用景笺"],
	]
	for i in cards.size():
		overview.add_child(_brick(cards[i][0], cards[i][1], i % 2 == 0))

func _brick(value: String, label: String, light: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(340, 64)
	var sb := GameTheme.flat_style(Color("C5AA92") if light else Color("997D64"), 6)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var l1 := Label.new()
	l1.text = value
	l1.add_theme_font_size_override("font_size", 24)
	l1.add_theme_color_override("font_color", Color("351601") if light else Color("EADCCB"))
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l1)
	var l2 := Label.new()
	l2.text = label
	l2.add_theme_font_size_override("font_size", 14)
	l2.add_theme_color_override("font_color", Color("7B614A") if light else Color("D9C7B2"))
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l2)
	return p

func _build_actions() -> void:
	## 导出 / 导入 / 清空
	var exp := Button.new()
	exp.text = "导出存档"
	exp.theme = GameTheme.v4_cream_button(20)
	exp.pressed.connect(_on_export)
	actions.add_child(exp)
	var imp := Button.new()
	imp.text = "导入存档"
	imp.theme = GameTheme.v4_cream_button(20)
	imp.pressed.connect(_on_import)
	actions.add_child(imp)
	var wipe := Button.new()
	wipe.text = "清空存档"
	wipe.theme = GameTheme.v4_text_button(20, Color("766655"))
	wipe.pressed.connect(_on_wipe)
	actions.add_child(wipe)

func _on_export() -> void:
	SoundManager.play("click")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://export"))
	var stamp := Time.get_datetime_string_from_system().replace(":", "")
	var src := "user://save_v3.json"
	var dst := "user://export/save_%s.json" % stamp
	DirAccess.copy_absolute(ProjectSettings.globalize_path(src), ProjectSettings.globalize_path(dst))
	_notify("已导出到：export/save_%s.json" % stamp)

func _on_import() -> void:
	SoundManager.play("click")
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.json"])
	fd.current_dir = ProjectSettings.globalize_path("user://")
	fd.file_selected.connect(func(path: String):
		var target := ProjectSettings.globalize_path("user://save_v3.json")
		if DirAccess.copy_absolute(path, target) == OK:
			_notify("导入成功，重启游戏后生效")
		else:
			_notify("导入失败：文件无法读取")
	)
	add_child(fd)
	fd.popup_centered(Vector2i(600, 400))

func _on_wipe() -> void:
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "确定清空全部存档？
（拼图进度、旅程历史、景笺都将清零，且无法恢复）"
	confirm.ok_button_text = "清空"
	confirm.cancel_button_text = "再想想"
	confirm.confirmed.connect(func():
		var p := ProjectSettings.globalize_path("user://save_v3.json")
		DirAccess.remove_absolute(p)
		_notify("存档已清空，重启游戏后为全新状态")
	)
	add_child(confirm)
	confirm.popup_centered()

func _notify(text: String) -> void:
	var toast := AcceptDialog.new()
	toast.dialog_text = text
	toast.ok_button_text = "好"
	add_child(toast)
	toast.popup_centered()
