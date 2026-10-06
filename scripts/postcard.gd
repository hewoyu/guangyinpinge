extends Control
## 动态明信片：完成整幅拼图后弹出——画面从静态变为动态（真实机制）
## 每幅拼图配不同的动效编排 + 祝福文案；收图入相册

signal done   ## v5-20：收图完成信号（play_page 据此切下一幅）

const LIGHT_SPOT := preload("res://assets/images/deco_light_spot.svg")

const BLESSINGS := {
	"picnic": "风把春天的味道，寄给了认真专注的你",
	"starry": "熬过的每个夜晚，都在替你收藏星光",
	"ocean": "潮起潮落，时光会带你去温柔的远方",
}

@onready var dim: TextureRect = $DimLayer
@onready var card: PanelContainer = $Card
@onready var picture: TextureRect = $Card/VBox/PictureFrame/Picture
@onready var fx: Control = $Card/VBox/PictureFrame/EffectsLayer
@onready var title_label: Label = $Card/VBox/TitleLabel
@onready var blessing: Label = $Card/VBox/BlessingLabel
@onready var keep_button: Button = $Card/VBox/KeepButton

var _tweens: Array[Tween] = []
var _closed := SignalAwaiter.new()

class SignalAwaiter:
	signal done

func _ready() -> void:
	visible = false
	card.add_theme_stylebox_override("panel", GameTheme.flat_style(GameTheme.CREAM, 14))
	keep_button.theme = GameTheme.button_theme(GameTheme.ORANGE, GameTheme.TERRA, 24)
	keep_button.pressed.connect(_on_keep)

## 由工作台调用：展示拼图完成庆祝
func present(puzzle_id: String) -> void:
	var p := GameState.get_current_puzzle()
	picture.texture = load(p.image)
	title_label.text = "%s · 会动的明信片" % p.title
	blessing.text = BLESSINGS.get(puzzle_id, "这段时光，已经完整地属于你了")
	visible = true
	dim.modulate.a = 0.0
	card.scale = Vector2(0.86, 0.86)
	card.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dim, "modulate:a", 1.0, 0.4)
	tw.tween_property(card, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.45)
	await tw.finished
	_start_effects(puzzle_id)
	SoundManager.play("star")

func _start_effects(puzzle_id: String) -> void:
	_clear_effects()
	match puzzle_id:
		"picnic":
			_fx_butterfly(Vector2(150, 380), Color(0.94, 0.72, 0.38))
			_fx_butterfly(Vector2(480, 300), Color(0.88, 0.56, 0.47))
			_fx_drift_cloud(Vector2(60, 70), 1.0)
			_fx_drift_cloud(Vector2(420, 120), 0.7)
		"starry":
			_fx_twinkle(8, Vector2(20, 20), Vector2(660, 220))
			_fx_firefly(Vector2(200, 420))
			_fx_firefly(Vector2(520, 460))
			_fx_glow_breath(Vector2(560, 90), 90.0, Color(1.0, 0.95, 0.8))
		"ocean":
			_fx_seagull(Vector2(80, 130))
			_fx_glow_breath(Vector2(490, 160), 120.0, Color(1.0, 0.9, 0.7))
			_fx_wave_shimmer(Vector2(60, 430))

## —— 动效实现（全部 Tween 驱动，零外部资源）——

func _fx_node(tex: Texture2D, pos: Vector2, size: Vector2) -> TextureRect:
	var n := TextureRect.new()
	n.texture = tex
	n.position = pos
	n.size = size
	n.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	n.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.add_child(n)
	return n

func _fx_butterfly(start: Vector2, color: Color) -> void:
	## 蝴蝶 = 两个小椭圆光点交替张合 + 8 字飘移
	var body := ColorRect.new()
	body.color = color
	body.size = Vector2(14, 10)
	body.position = start
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.add_child(body)
	var path_x := 60.0
	var tw := create_tween().set_loops()
	tw.tween_property(body, "position:x", start.x + path_x, 2.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(body, "position:x", start.x, 2.2).set_trans(Tween.TRANS_SINE)
	var tw2 := create_tween().set_loops()
	tw2.tween_property(body, "position:y", start.y + 26.0, 1.1).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(body, "position:y", start.y, 1.1).set_trans(Tween.TRANS_SINE)
	var tw3 := create_tween().set_loops()
	tw3.tween_property(body, "size:x", 8.0, 0.18)
	tw3.tween_property(body, "size:x", 14.0, 0.18)
	_tweens.append(tw); _tweens.append(tw2); _tweens.append(tw3)

func _fx_drift_cloud(start: Vector2, scale_: float) -> void:
	## 云 = 柔光斑缓慢平移循环
	var n := _fx_node(LIGHT_SPOT, start, Vector2(140 * scale_, 60 * scale_))
	n.modulate = Color(1, 1, 1, 0.5)
	var tw := create_tween().set_loops()
	tw.tween_property(n, "position:x", start.x + 90.0, 6.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "position:x", start.x, 6.0).set_trans(Tween.TRANS_SINE)
	_tweens.append(tw)

func _fx_twinkle(count: int, area_pos: Vector2, area_size: Vector2) -> void:
	## 星光闪烁：随机分布的小光点呼吸
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in count:
		var pos := Vector2(
			area_pos.x + rng.randf() * area_size.x,
			area_pos.y + rng.randf() * area_size.y
		)
		var n := _fx_node(LIGHT_SPOT, pos, Vector2(18, 18))
		var period := rng.randf_range(0.8, 1.8)
		var delay := rng.randf_range(0.0, 1.5)
		var tw := create_tween().set_loops()
		tw.tween_interval(delay)
		tw.tween_property(n, "modulate:a", 1.0, period * 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(n, "modulate:a", 0.15, period * 0.5).set_trans(Tween.TRANS_SINE)
		_tweens.append(tw)

func _fx_firefly(start: Vector2) -> void:
	## 萤火虫：暖光点小范围游走 + 呼吸
	var n := _fx_node(LIGHT_SPOT, start, Vector2(22, 22))
	n.modulate = Color(1.0, 0.95, 0.6)
	var tw := create_tween().set_loops()
	tw.tween_property(n, "position:x", start.x + 40.0, 2.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "position:x", start.x - 20.0, 3.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "position:x", start.x, 2.0).set_trans(Tween.TRANS_SINE)
	var tw2 := create_tween().set_loops()
	tw2.tween_property(n, "modulate:a", 1.0, 1.2)
	tw2.tween_property(n, "modulate:a", 0.3, 1.2)
	_tweens.append(tw); _tweens.append(tw2)

func _fx_glow_breath(pos: Vector2, size_: float, color: Color) -> void:
	## 光晕呼吸（月亮/灯塔）
	var n := _fx_node(LIGHT_SPOT, pos, Vector2(size_, size_))
	n.modulate = Color(color.r, color.g, color.b, 0.5)
	var tw := create_tween().set_loops()
	tw.tween_property(n, "modulate:a", 0.85, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "modulate:a", 0.4, 1.6).set_trans(Tween.TRANS_SINE)
	var tw2 := create_tween().set_loops()
	tw2.tween_property(n, "scale", Vector2(1.12, 1.12), 1.6).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(n, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE)
	_tweens.append(tw); _tweens.append(tw2)

func _fx_seagull(start: Vector2) -> void:
	## 海鸥 = 两道弧线小形状横越天空
	var body := ColorRect.new()
	body.color = Color(0.35, 0.25, 0.2)
	body.size = Vector2(18, 4)
	body.position = start
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.add_child(body)
	var tw := create_tween().set_loops()
	tw.tween_property(body, "position:x", start.x + 520.0, 9.0)
	tw.tween_callback(func(): body.position.x = start.x)
	var tw2 := create_tween().set_loops()
	tw2.tween_property(body, "position:y", start.y + 18.0, 2.4).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(body, "position:y", start.y, 2.4).set_trans(Tween.TRANS_SINE)
	_tweens.append(tw); _tweens.append(tw2)

func _fx_wave_shimmer(start: Vector2) -> void:
	## 水面波光：横条光带左右流动
	var n := _fx_node(LIGHT_SPOT, start, Vector2(180, 26))
	n.modulate = Color(1.0, 0.95, 0.8, 0.4)
	var tw := create_tween().set_loops()
	tw.tween_property(n, "position:x", start.x + 320.0, 5.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "position:x", start.x, 5.0).set_trans(Tween.TRANS_SINE)
	var tw2 := create_tween().set_loops()
	tw2.tween_property(n, "modulate:a", 0.55, 2.2)
	tw2.tween_property(n, "modulate:a", 0.25, 2.2)
	_tweens.append(tw); _tweens.append(tw2)

func _clear_effects() -> void:
	for t in _tweens:
		if t is Tween and t.is_valid():
			t.kill()
	_tweens.clear()
	for c in fx.get_children():
		c.queue_free()

func _on_keep() -> void:
	SoundManager.play("click")
	GameState.mark_current_completed()
	# 收图动画后关闭
	_clear_effects()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(card, "modulate:a", 0.0, 0.35)
	tw.tween_property(dim, "modulate:a", 0.0, 0.4)
	await tw.finished
	visible = false
	_closed.done.emit()
	done.emit()   ## v5-20 转发给 play_page

## 等待关闭（供工作台流程 await）
func await_closed() -> void:
	await _closed.done
