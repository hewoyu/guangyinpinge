extends Control
## 关于/教程页（task-30 d-f）：玩法四步 + 操作说明 + 版本 + 致敬印章

const STEPS := [
	"① 在右侧任务卡点「开始」，启动番茄钟（25 分钟专注 · 5 分钟休息）",
	"② 专注时，每隔 2~5 分钟会随机掉落一块拼图碎片",
	"③ 休息后，把碎片拖到棋盘拼上，或者点「自动拼」轻松完成",
	"④ 集齐 144 块，拼图会变成一张会动的明信片——收下这段时光",
]

@onready var back_button: Button = $BackButton
@onready var steps: VBoxContainer = $Steps
@onready var footer: HBoxContainer = $Footer

func _ready() -> void:
	back_button.flat = true
	back_button.add_theme_color_override("font_color", GameTheme.V_TEXT_MID)
	back_button.pressed.connect(_on_back)
	## 四步卡片
	for s in STEPS:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", GameTheme.v4_side_card())
		var inner := MarginContainer.new()
		for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			inner.add_theme_constant_override(m, 12)
		card.add_child(inner)
		var l := Label.new()
		l.text = s
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", GameTheme.V_TEXT_BODY)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(l)
		steps.add_child(card)
	## 底部：操作说明 + 版本 + 印章
	var tip := Label.new()
	tip.text = "拖拽碎片吸附归位 · 右栏随时记待办 · 统计在书房墙上的挂图里"
	tip.add_theme_font_size_override("font_size", 15)
	tip.add_theme_color_override("font_color", GameTheme.V_TEXT_SUB)
	footer.add_child(tip)
	var ver := Label.new()
	ver.text = "拾光拼途 v5.0 · Demo"
	ver.add_theme_font_size_override("font_size", 15)
	ver.add_theme_color_override("font_color", GameTheme.V_TEXT_SUB)
	footer.add_child(ver)
	## 致敬印章（朱红方块风——致敬原作 止焉 ZHIYAN STUDIO）
	var seal := ColorRect.new()
	seal.color = Color("A93226")
	seal.custom_minimum_size = Vector2(40, 40)
	var sv := VBoxContainer.new()
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	var s1 := Label.new()
	s1.text = "拾光"
	s1.add_theme_font_size_override("font_size", 12)
	s1.add_theme_color_override("font_color", Color.WHITE)
	var s2 := Label.new()
	s2.text = "致敬止焉"
	s2.add_theme_font_size_override("font_size", 7)
	s2.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	sv.add_child(s1); sv.add_child(s2)
	seal.add_child(sv)
	footer.add_child(seal)

func _on_back() -> void:
	SoundManager.play("click")
	get_tree().change_scene_to_file("res://scenes/bookroom.tscn")
