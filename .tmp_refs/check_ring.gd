extends SceneTree
func _init() -> void:
	var img := Image.new()
	img.load_png_from_buffer(FileAccess.get_file_as_bytes("res://.tmp_refs/ws_shot_focus.png"))
	# 环中心约 (405, 59)，半径 47 上的四个点
	for p in [Vector2i(405, 13), Vector2i(405, 105), Vector2i(359, 59), Vector2i(451, 59)]:
		var c := img.get_pixel(p.x, p.y)
		print("ring(%d,%d)=#%02X%02X%02X" % [p.x, p.y, c.r8, c.g8, c.b8])
	# 番茄色检测：TOMATO #E07856
	var cnt := 0
	for y in range(0, 118, 2):
		for x in range(346, 465, 2):
			var c := img.get_pixel(x, y)
			if absi(c.r8 - 0xE0) < 24 and absi(c.g8 - 0x78) < 24 and absi(c.b8 - 0x56) < 24:
				cnt += 1
	print("tomato_pixels=", cnt)
	# 大数字（暗色 INK 文字）
	var ink := 0
	for y in range(33, 86):
		for x in range(346, 465):
			var c := img.get_pixel(x, y)
			if c.r8 < 120 and c.g8 < 110 and c.b8 < 100:
				ink += 1
	print("ink_pixels(timer digits)=", ink)
	quit(0)
