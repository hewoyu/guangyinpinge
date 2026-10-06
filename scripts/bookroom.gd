extends Control
## 书房主界面（real_05 复刻）：场景即菜单
## 暖木书房插画 + 手绘白色描边字入口 + 白色手绘箭头
## 布局（850x478 基准 → 1280x720，scale 1.506）：
##   关于/教程(书房左下) 成就/窗景(左墙) 统计(右墙) 拼图选择(书柜)
##   旅程回顾(桌面明信片) 音乐/白噪音(收音机) 开始旅程(主CTA 中央白纸贴纸)

const MENU := [
	{ "id": "about",   "text": "关于/教程",  "x": 0.045, "y": 0.78, "w": 0.13, "target": "res://scenes/about_page.tscn" },
	{ "id": "achieve", "text": "成就/窗景",  "x": 0.185, "y": 0.16, "w": 0.13, "target": "res://scenes/achievements_page.tscn" },
	{ "id": "stats",   "text": "统计",       "x": 0.745, "y": 0.09, "w": 0.09, "target": "res://scenes/stats_page.tscn" },
	{ "id": "puzzle",  "text": "拼图选择/DLC/创意工坊", "x": 0.88, "y": 0.24, "w": 0.115, "target": "res://scenes/puzzle_select.tscn" },
	{ "id": "journey", "text": "旅程回顾",   "x": 0.71, "y": 0.66, "w": 0.10, "target": "res://scenes/journey_review.tscn" },
	{ "id": "music",   "text": "音乐/白噪音", "x": 0.47, "y": 0.60, "w": 0.10, "target": "res://scenes/music_box.tscn" },
]

@onready var menu_layer: Control = $MenuLayer
@onready var top_icons: HBoxContainer = $TopIcons

func _ready() -> void:
	SoundManager.set_bgm_enabled(true)
	# v5-29 窗景：最新解锁的窗外风景（无解锁时默认场景图）
	var view: Dictionary = GameState.latest_unlocked_view()
	if not view.is_empty():
		var wv: TextureRect = $WindowView
		wv.texture = load(String(view.image))
		wv.visible = true
	_build_top_icons()
	_build_menu()
	_build_start_button()

func _build_top_icons() -> void:
	## 右上三细线系统图标（最小化/叠窗/齿轮）——静态装饰 + 齿轮可点开设置
	for i in 3:
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(28, 28)
		b.tooltip_text = ["最小化", "窗口", "设置"][i]
		if i == 2:
			b.pressed.connect(func():
				SoundManager.play("click")
				get_tree().change_scene_to_file("res://scenes/settings_page.tscn"))
		top_icons.add_child(b)

func _build_menu() -> void:
	for m in MENU:
		var hot := Button.new()
		hot.flat = true
		hot.text = m.text
		hot.position = Vector2(m.x * size.x, m.y * size.y)
		hot.custom_minimum_size = Vector2(m.w * size.x, 34)
		hot.add_theme_font_size_override("font_size", GameTheme.V_F_MENU * 0.7)
		## 白色手绘描边字：多重阴影模拟描边（Godot Label 无 outline 时用阴影近似）
		hot.add_theme_color_override("font_color", Color(1, 1, 1, 0.97))
		hot.add_theme_constant_override("outline_size", 4)
		hot.add_theme_color_override("font_outline_color", Color(0.28, 0.22, 0.16, 0.9))
		var target: String = m.target
		if target != "":
			hot.pressed.connect(_goto.bind(target))
		else:
			hot.disabled = true
			hot.modulate = Color(1, 1, 1, 0.85)
		menu_layer.add_child(hot)
		## 手绘箭头（小三角指向场景物件）
		_add_arrow(Vector2(m.x * size.x - 22, m.y * size.y + 12))

func _add_arrow(pos: Vector2) -> void:
	var arrow := ColorRect.new()
	arrow.color = Color(1, 1, 1, 0.85)
	arrow.size = Vector2(16, 3)
	arrow.position = pos
	arrow.rotation_degrees = 0
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(arrow)
	var tip := ColorRect.new()
	tip.color = Color(1, 1, 1, 0.85)
	tip.size = Vector2(3, 3)
	tip.position = pos + Vector2(16, -3)
	tip.rotation_degrees = 45
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(tip)

func _build_start_button() -> void:
	## 主 CTA：白色手撕纸贴纸底 + 深棕字（real_05：x428-548 / y366-400 基准）
	var btn := Button.new()
	btn.text = "开始旅程"
	btn.position = Vector2(size.x * 0.503, size.y * 0.896) - Vector2(90, 26)
	btn.custom_minimum_size = Vector2(180, 52)
	var sb := GameTheme.flat_style(Color(1, 0.98, 0.94, 0.96), 3)
	sb.border_color = Color("D8CCB4")
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0.3, 0.24, 0.16, 0.25)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(1, 3)
	btn.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = Color(1, 1, 1, 0.98)
	btn.add_theme_stylebox_override("hover", sbh)
	btn.add_theme_stylebox_override("pressed", sbh)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", Color("612D1A"))
	btn.pressed.connect(func():
		SoundManager.play("click")
		_goto("res://scenes/play_page.tscn"))
	menu_layer.add_child(btn)

func _goto(path: String) -> void:
	SoundManager.play("click")
	get_tree().change_scene_to_file(path)

func _gui_input(event: InputEvent) -> void:
	## Esc 退出全屏提示（桌面习惯）
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
