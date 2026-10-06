extends Control
## 成就页（real_11 复刻）：左分类竖排 + 景笺计数 + 两列成就卡 + 领取

@onready var back_button: Button = $TopBar/BackButton
@onready var paper_label: Label = $PaperLabel
@onready var unlocked_label: Label = $UnlockedLabel
@onready var side_menu: VBoxContainer = $SideMenu
@onready var card_area: GridContainer = $CardArea

const CATEGORIES := ["窗景", "拼图", "次数", "时长", "天数"]
var _category := "次数"   ## 当前实现"次数"分类（与 ACHIEVEMENTS 数据对应）

func _ready() -> void:
	back_button.flat = true
	back_button.add_theme_color_override("font_color", Color("54452F"))
	back_button.pressed.connect(_on_back)
	_build_side_menu()
	_refresh()
	GameState.stats_changed.connect(func(_a, _b): _refresh())

func _build_side_menu() -> void:
	for c in CATEGORIES:
		var b := Button.new()
		b.text = c
		b.flat = true
		b.add_theme_font_size_override("font_size", 16)
		if c == _category:
			b.add_theme_color_override("font_color", Color("54452F"))
		else:
			b.add_theme_color_override("font_color", Color("A79781"))
		b.pressed.connect(func(): _switch_category(c))
		side_menu.add_child(b)

func _switch_category(c: String) -> void:
	_category = c
	for b in side_menu.get_children():
		if b is Button:
			if b.text == c:
				b.add_theme_color_override("font_color", Color("54452F"))
			else:
				b.add_theme_color_override("font_color", Color("A79781"))
	_refresh()

func _refresh() -> void:
	paper_label.text = "未使用景笺: %d" % GameState.scene_paper
	unlocked_label.text = "已解锁成就 %d/%d" % [GameState.unlocked_achievement_count(), GameState.ACHIEVEMENTS.size()]
	for c in card_area.get_children():
		c.queue_free()
	match _category:
		"窗景":
			_show_views_placeholder()
		"次数", "拼图", "时长", "天数":
			for a in GameState.ACHIEVEMENTS:
				if String(a.get("type", "count")) == _type_of(_category):
					card_area.add_child(_make_card(a))

func _type_of(cat: String) -> String:
	## 分类名 → 成就 need_type
	match cat:
		"次数": return "count"
		"拼图": return "puzzle"
		"时长": return "hours"
		"天数": return "days"
	return "count"

func _show_views_placeholder() -> void:
	## v5-29 窗景商店（官方：景笺兑换，永久可用）
	for v in GameState.WINDOW_VIEWS:
		card_area.add_child(_make_view_card(v))

func _make_view_card(v: Dictionary) -> PanelContainer:
	var unlocked: bool = GameState.is_view_unlocked(String(v.id))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(480, 150)
	var sb := GameTheme.flat_style(Color("F2EADD"), 6)
	sb.border_color = Color("B9A488")
	sb.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	card.add_child(h)
	var img := TextureRect.new()
	img.texture = load(String(v.image))
	img.custom_minimum_size = Vector2(280, 120)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not unlocked:
		img.modulate = Color(0.5, 0.5, 0.5)
	h.add_child(img)
	var v2 := VBoxContainer.new()
	v2.alignment = BoxContainer.ALIGNMENT_CENTER
	v2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v2)
	var title := Label.new()
	title.text = String(v.title)
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", GameTheme.V_TEXT_TITLE)
	v2.add_child(title)
	var price := Label.new()
	price.text = "%d 景笺" % int(v.price)
	price.add_theme_font_size_override("font_size", 13)
	price.add_theme_color_override("font_color", GameTheme.V_TEXT_SUB)
	v2.add_child(price)
	var btn := Button.new()
	if unlocked:
		btn.text = "已拥有"
		btn.disabled = true
		btn.theme = GameTheme.v4_text_button(14, Color("6E8B3D"))
	else:
		var affordable: bool = GameState.scene_paper >= int(v.price)
		btn.text = "兑换"
		btn.disabled = not affordable
		btn.theme = GameTheme.v4_cream_button(15)
		btn.pressed.connect(func():
			if GameState.unlock_view(String(v.id)):
				SoundManager.play("star")
				_refresh())
	v2.add_child(btn)
	return card

func _make_card(a: Dictionary) -> PanelContainer:
	var achieved: bool = GameState.is_achieved(a)
	var claimed: bool = GameState.is_claimed(a)
	
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(485, 62)
	var sb := GameTheme.flat_style(Color("F2EADD"), 5)
	sb.border_color = Color("B9A488")
	sb.border_width_left = 1; sb.border_width_right = 1
	sb.border_width_top = 1; sb.border_width_bottom = 1
	card.add_theme_stylebox_override("panel", sb)
	
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	
	# 左：标题 + 条件 + 进度
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var title := Label.new()
	title.text = a.title
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color("4A3A2A"))
	v.add_child(title)
	var sub := Label.new()
	sub.text = _condition_text(a)
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color("9A8B78"))
	v.add_child(sub)
	# 进度条（两段式：浅褐底 + 深褐填充）
	var pb := ColorRect.new()
	pb.custom_minimum_size = Vector2(180, 4)
	pb.color = Color("DED2BE")
	var fill_ratio: float = clampf(GameState.achievement_progress(a) / float(a.need), 0.0, 1.0)
	var fill := ColorRect.new()
	fill.color = Color("8B5E3C")
	fill.anchor_right = fill_ratio
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.add_child(fill)
	pb.clip_contents = true
	v.add_child(pb)
	
	# 右：奖励 + 领取/未达成
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 4)
	h.add_child(right)
	var reward := Label.new()
	reward.text = "奖励 %d 景笺" % a.reward
	reward.add_theme_font_size_override("font_size", 11)
	reward.add_theme_color_override("font_color", Color("7B614A"))
	right.add_child(reward)
	var action := Button.new()
	action.flat = true
	action.add_theme_font_size_override("font_size", 13)
	if claimed:
		action.text = "已领取"
		action.disabled = true
		action.add_theme_color_override("font_color", Color("B6A894"))
	elif achieved:
		action.text = "领取"
		action.add_theme_color_override("font_color", Color("54452F"))
		action.pressed.connect(func():
			if GameState.claim_achievement(a):
				SoundManager.play("star")
				_refresh()
		)
	else:
		action.text = "未达成"
		action.disabled = true
		action.add_theme_color_override("font_color", Color("B6A894"))
	right.add_child(action)
	return card

func _condition_text(a: Dictionary) -> String:
	## 按类型的达成条件文案
	match String(a.get("type", "count")):
		"puzzle": return "累计完成 %d 幅拼图" % a.need
		"hours": return "累计专注 %d 小时" % a.need
		"days": return "连续专注 %d 天" % a.need
		_: return "累计完成 %d 次专注" % a.need

func _on_back() -> void:
	SoundManager.play("click")
	get_tree().change_scene_to_file("res://scenes/bookroom.tscn")
