extends Control
## 呼吸冥想页（real_04 呼吸卡进入）：湖绿发光球呼吸引导
## 花朵开合节奏：4 秒膨胀（吸气）→ 4 秒收缩（呼气）循环
## 色彩：核心 #BFEDE9 → 外沿 #7FD8D0（呼吸中同步变化）

const INHALE_SEC := 4.0
const EXHALE_SEC := 4.0
const CORE := Color("BFEDE9")
const EDGE := Color("7FD8D0")

@onready var sphere: ColorRect = $BreathSphere/Sphere
@onready var phase_label: Label = $PhaseLabel
@onready var timer_label: Label = $TimerLabel
@onready var start_button: Button = $StartButton
@onready var back_button: Button = $BackButton

var _running := false
var _elapsed := 0.0
var _breath_tween: Tween = null

func _ready() -> void:
	back_button.flat = true
	back_button.add_theme_color_override("font_color", GameTheme.V_TEXT_MID)
	back_button.pressed.connect(_on_back)
	## 圆形球体（ColorRect 圆角 = 直径/2）+ 初始辉光
	sphere.size = Vector2(128, 128)
	sphere.pivot_offset = sphere.size / 2.0
	sphere.color = CORE
	start_button.theme = GameTheme.v4_text_button(28)
	start_button.pressed.connect(_on_start)
	## 待机呼吸（慢速轻柔）
	_idle_breath()

func _idle_breath() -> void:
	_breath_tween = create_tween().set_loops()
	_breath_tween.tween_property(sphere, "scale", Vector2(1.08, 1.08), 2.4).set_trans(Tween.TRANS_SINE)
	_breath_tween.tween_property(sphere, "scale", Vector2.ONE, 2.4).set_trans(Tween.TRANS_SINE)

func _on_start() -> void:
	SoundManager.play("click")
	if _breath_tween:
		_breath_tween.kill()
	if _running:
		_running = false
		start_button.text = "开始"
		phase_label.text = "轻触开始，跟随花朵调整呼吸。"
		_idle_breath()
		return
	_running = true
	_elapsed = 0.0
	start_button.text = "停止"
	_breath_loop()

func _breath_loop() -> void:
	## 花朵开合引导：膨胀=吸气，收缩=呼气
	while _running:
		phase_label.text = "吸气… 让光慢慢变大"
		_breath_tween = create_tween()
		_breath_tween.tween_property(sphere, "scale", Vector2(1.45, 1.45), INHALE_SEC).set_trans(Tween.TRANS_SINE)
		_breath_tween.parallel().tween_property(sphere, "color", EDGE, INHALE_SEC)
		await _breath_tween.finished
		if not _running:
			return
		phase_label.text = "呼气… 把时间轻轻放下"
		_breath_tween = create_tween()
		_breath_tween.tween_property(sphere, "scale", Vector2.ONE, EXHALE_SEC).set_trans(Tween.TRANS_SINE)
		_breath_tween.parallel().tween_property(sphere, "color", CORE, EXHALE_SEC)
		await _breath_tween.finished

func _process(delta: float) -> void:
	if _running:
		_elapsed += delta
		timer_label.text = "%02d:%02d" % [int(_elapsed) / 60, int(_elapsed) % 60]

func _on_back() -> void:
	SoundManager.play("click")
	_running = false
	get_tree().change_scene_to_file("res://scenes/play_page.tscn")
