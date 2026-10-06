extends Control
## 拼图选择页（task-30 g-h）：3 幅卡（图/标题/进度/完成标记）+ DLC 占位

@onready var back_button: Button = $BackButton
@onready var cards: GridContainer = $Scroll/Cards

func _ready() -> void:
	back_button.flat = true
	back_button.add_theme_color_override("font_color", GameTheme.V_TEXT_MID)
	back_button.pressed.connect(_on_back)
	_build()

func _build() -> void:
	for c in cards.get_children():
		c.queue_free()
	for p in GameState.PUZZLES:
		cards.add_child(_make_card(p))

func _make_card(p: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(310, 340)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add_theme_stylebox_override("panel", GameTheme.v4_side_card())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var pad := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(m, 14)
	pad.add_child(v)
	card.add_child(pad)
	## 图
	var img := TextureRect.new()
	img.texture = load(p.image)
	img.custom_minimum_size = Vector2(280, 190)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(img)
	## 标题 + 完成标记
	var title_row := HBoxContainer.new()
	v.add_child(title_row)
	var title := Label.new()
	title.text = String(p.title)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", GameTheme.V_TEXT_TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var done := GameState.completed_album.has(p.id)
	if done:
		var badge := Label.new()
		badge.text = "✓"
		badge.add_theme_font_size_override("font_size", 22)
		badge.add_theme_color_override("font_color", Color("6E8B3D"))
		title_row.add_child(badge)
	## 进度（若为当前拼图）
	if p.id == GameState.current_puzzle_id:
		var cur := Label.new()
		cur.text = "进行中 · %d/144" % GameState.collected_count()
		cur.add_theme_font_size_override("font_size", 15)
		cur.add_theme_color_override("font_color", Color("A98C67"))
		v.add_child(cur)
	## 点击卡：切拼图 → 回书房
	var btn := Button.new()
	btn.text = "选择这幅" if not done else "重新拼"
	btn.theme = GameTheme.v4_cream_button(18)
	btn.pressed.connect(func():
		SoundManager.play("click")
		GameState.set_current_puzzle(String(p.id))
		get_tree().change_scene_to_file("res://scenes/bookroom.tscn"))
	v.add_child(btn)
	return card

func _on_back() -> void:
	SoundManager.play("click")
	get_tree().change_scene_to_file("res://scenes/bookroom.tscn")
