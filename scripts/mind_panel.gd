extends VBoxContainer
## 正念呼吸面板：4-4 拍呼吸引导圆（吸气4s扩张 → 呼气4s收缩）

const CYCLE_SEC := 4.0

var running := false

@onready var circle: Panel = $CircleHolder/Circle
@onready var hint_label: Label = $HintLabel
@onready var toggle_btn: Button = $Toggle

func _ready() -> void:
	hint_label.add_theme_font_size_override("font_size", 20)
	hint_label.add_theme_color_override("font_color", GameTheme.INK_SOFT)
	toggle_btn.theme = GameTheme.soft_button_theme(18, GameTheme.TOMATO)
	toggle_btn.pressed.connect(_on_toggle)
	circle.custom_minimum_size = Vector2(160, 160)
	var sb := GameTheme.flat_style(GameTheme.TOMATO_LEAF, 80)
	sb.shadow_color = Color(0.5, 0.65, 0.55, 0.35)
	sb.shadow_size = 24
	circle.add_theme_stylebox_override("panel", sb)
	_set_text("点击开始，跟随圆的节奏呼吸")

func _on_toggle() -> void:
	running = not running
	SoundManager.play("click")
	if running:
		toggle_btn.text = "停 止"
		_breathe_in()
	else:
		toggle_btn.text = "开 始"
		_set_text("随时回来，慢慢来")
		var tw := create_tween()
		tw.tween_property(circle, "scale", Vector2.ONE, 0.4)

func _breathe_in() -> void:
	if not running:
		return
	_set_text("吸气… 4")
	var tw := create_tween()
	tw.tween_property(circle, "scale", Vector2(1.45, 1.45), CYCLE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.finished.connect(_breathe_out)

func _breathe_out() -> void:
	if not running:
		return
	_set_text("呼气… 4")
	var tw := create_tween()
	tw.tween_property(circle, "scale", Vector2.ONE, CYCLE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.finished.connect(_breathe_in)

func _set_text(t: String) -> void:
	hint_label.text = t
