extends SceneTree
## 布局边界探测：横向亮度/色相跳变找 UI 分界线
func _init() -> void:
	var names := ["DM_20261006002709_007", "DM_20261006002709_009", "DM_20261006002709_010", "DM_20261006002709_002"]
	for n in names:
		var img := Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes("res://.tmp_refs/" + n + ".png")) != OK:
			continue
		var w := img.get_width(); var h := img.get_height()
		print("=== " + n + " " + str(w) + "x" + str(h))
		# 行平均亮度跳变（横向边界）：找顶栏/底栏边界
		var prev := -1.0
		for y in range(1, h):
			var lum := _row_lum(img, y)
			if prev >= 0.0 and abs(lum - prev) > 0.09:
				print("  row-boundary y=%d (%.2f->%.2f)" % [y, prev, lum])
			prev = lum
		# 列平均亮度跳变（纵向边界）
		var prevc := -1.0
		for x in range(1, w):
			var lum := _col_lum(img, x)
			if prevc >= 0.0 and abs(lum - prevc) > 0.09:
				print("  col-boundary x=%d (%.2f->%.2f)" % [x, prevc, lum])
			prevc = lum
	quit(0)

func _row_lum(img: Image, y: int) -> float:
	var s := 0.0
	for x in range(0, img.get_width(), 4):
		var c := img.get_pixel(x, y)
		s += c.get_luminance()
	return s / (img.get_width() / 4.0)

func _col_lum(img: Image, x: int) -> float:
	var s := 0.0
	for y in range(0, img.get_height(), 4):
		var c := img.get_pixel(x, y)
		s += c.get_luminance()
	return s / (img.get_height() / 4.0)
