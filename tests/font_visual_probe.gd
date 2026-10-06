extends Node
## C1 视觉验证：同场景两次截图（字体开/关）像素差必须显著不同
func _ready() -> void:
	# 1) 默认（文楷已注册）截图
	var a := await _shot()
	# 2) 临时还原默认字体再截图
	var saved: Font = ThemeDB.fallback_font
	ThemeDB.fallback_font = null
	var b := await _shot()
	ThemeDB.fallback_font = saved
	# 差异像素计数
	var diff := 0
	for y in range(0, 720, 4):
		for x in range(0, 1280, 4):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				diff += 1
	print("DIFF_PIXELS=", diff, " SAMPLED=", (1280 / 4) * (720 / 4))
	print("FONT_APPLIED=", diff > 500)
	get_tree().quit()

func _shot() -> Image:
	await get_tree().create_timer(0.5).timeout
	var img := get_viewport().get_texture().get_image()
	return img
