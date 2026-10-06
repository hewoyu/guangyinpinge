extends Control
## 旅程结算信（real_06 复刻）：
## "嗨，旅人：/这是你的第N趟旅程/旅程中，你完成了N次专注/专注共计 N小时N分钟/谢谢你在旅途中的陪伴，辛苦啦"
## 每行下手绘棕横线 #8B6A4A（横格信笺），字 13-14px 居中
## 点纸飞机 → 飞出动画 → 开启下一段旅程

const LINE_COLOR := Color("8B6A4A")
const TEXT_COLOR := Color("3B2F27")

var _lines: Array[Label] = []

func _ready() -> void:
	$PlaneButton.theme = GameTheme.v4_text_button(19, Color("5A3A1E"))
	$PlaneButton.pressed.connect(_on_plane)
	_fill_letter()

func _fill_letter() -> void:
	## 旅程数据（GameState journey 统计）
	var journey_no := maxi(1, GameState.journey_count)
	var focus_count := GameState.journey_focus_count
	var total_min := GameState.journey_minutes
	var hours := int(total_min) / 60
	var mins := int(total_min) % 60
	var nickname := String(SettingsData.get_value("nickname", "旅人"))
	var texts := [
		"嗨，%s：" % nickname,
		"这是你的第%d趟旅程" % journey_no,
		"旅程中，你完成了%d次专注" % maxi(focus_count, 1),
		"专注共计 %d小时%d分钟" % [hours, mins],
		"谢谢你在旅途中的陪伴，辛苦啦",
	]
	var col: VBoxContainer = $LetterCard/InnerPad/H/TextCol
	for c in col.get_children():
		c.queue_free()
	for t in texts:
		## 每行 = 字 + 手绘横线（VBox 内嵌一个行容器）
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		col.add_child(row)
		var l := Label.new()
		l.text = t
		l.add_theme_font_size_override("font_size", 21)
		l.add_theme_color_override("font_color", TEXT_COLOR)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(l)
		var line := ColorRect.new()
		line.color = LINE_COLOR
		line.custom_minimum_size = Vector2(0, 1.4)
		var tw := create_tween().set_loops()
		tw.tween_property(line, "modulate:a", 0.75, 1.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(line, "modulate:a", 1.0, 1.6).set_trans(Tween.TRANS_SINE)
		row.add_child(line)

func _on_plane() -> void:
	## 纸飞机飞出动画 → 下一趟旅程（重置本轮计数回主页）
	SoundManager.play("click")
	GameState.start_new_journey()
	## 飞行动画：PlaneButton 文字飞出 + 花瓣效果（简洁版）
	var btn: Button = $PlaneButton
	var tw := create_tween()
	tw.tween_property(btn, "modulate:a", 0.0, 0.5)
	tw.tween_property(btn, "position:x", btn.position.x - 260.0, 0.6).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.parallel()
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/bookroom.tscn")
