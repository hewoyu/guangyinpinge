extends Node
## task-37 验收：霞鹜文楷全局字体系统
## headless 运行：断言 fallback 字体已注册且为 WenKai
## 窗口模式运行：等待 20 帧后截图保存到 user://shot_font.png

var _frames := 0
var _bookroom: Node = null
var _shot_done := false


func _ready() -> void:
	print("=== test_c1_font start ===")
	print("DISPLAY_SERVER=", DisplayServer.get_name())
	var fail: Array[String] = []

	# 触发 GameTheme 静态初始化（引用任意成员即可）
	var _touch := GameTheme.V_TEXT_TITLE

	var font := ThemeDB.fallback_font
	if font == null:
		fail.append("ThemeDB.fallback_font is null")
	else:
		var fname := font.get_font_name()
		print("FONT_CLASS=", font.get_class())
		print("FONT_NAME=", fname)
		if not (fname.contains("WenKai") or fname.contains("LXGW") or fname.contains("文楷")):
			fail.append("fallback_font is not WenKai, got: " + fname)

	# 探针：新建 Label 的主题解析字体应为 WenKai（证明全站控件默认字体生效）
	var probe := Label.new()
	probe.text = "拾光拼途 25:00"
	var probe_font := probe.get_theme_font("font")
	if probe_font == null:
		fail.append("Label default theme font is null")
	else:
		print("PROBE_FONT=", probe_font.get_font_name())
		if not (probe_font.get_font_name().contains("WenKai") or probe_font.get_font_name().contains("文楷")):
			fail.append("Label default font is not WenKai: " + probe_font.get_font_name())

	# 实例化书房主场景，确认真实页面在楷体兜底下可正常构建
	var ps := load("res://scenes/bookroom.tscn") as PackedScene
	if ps == null:
		fail.append("bookroom.tscn load failed")
	else:
		_bookroom = ps.instantiate()
		add_child(_bookroom)
		print("BOOKROOM_INSTANTIATED=true")

	if fail.is_empty():
		print("TEST_OK task-37 font assertions passed")
	else:
		for m in fail:
			push_error("TEST_FAIL: " + m)
		print("TEST_FAIL count=", fail.size())


func _process(_delta: float) -> void:
	_frames += 1
	if _shot_done or _bookroom == null:
		return
	# 窗口模式（非 headless）才截图；等书页渲染稳定
	if _frames >= 20 and DisplayServer.get_name() != "headless":
		_shot_done = true
		var img := get_viewport().get_texture().get_image()
		if img != null and not img.is_empty():
			img.save_png("user://shot_font.png")
			print("SHOT_SAVED=", OS.get_user_data_dir(), "/shot_font.png")
		else:
			print("SHOT_SKIPPED empty viewport image")
