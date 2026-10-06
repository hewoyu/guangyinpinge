extends SceneTree
## 截图布局自检：验证关键区域颜色特征
func _init() -> void:
	var checks := {
		"ws_shot_idle.png": ["topbar", "toolbar", "board", "bottom"],
		"ws_shot_todo.png": ["topbar", "toolbar", "board", "panel", "bottom"],
		"ws_shot_focus.png": ["topbar_focus", "board", "bottom"],
	}
	for fname: String in checks:
		var img := Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes("res://.tmp_refs/" + fname)) != OK:
			print(fname, ": LOAD FAIL")
			continue
		var w := img.get_width(); var h := img.get_height()
		var report: String = fname + " " + str(w) + "x" + str(h) + " | "
		# 顶栏中心（进度环位置 ~575,50）
		var ring := _avg(img, int(w * 0.42), int(h * 0.05), 40, 30)
		report += "ring=#%02X%02X%02X " % [ring.r8, ring.g8, ring.b8]
		# 左工具栏 (~55, 400)
		var tb := _avg(img, int(w * 0.035), int(h * 0.5), 30, 60)
		report += "toolbar=#%02X%02X%02X " % [tb.r8, tb.g8, tb.b8]
		# 中央拼图板 (~500, 400)
		var bd := _avg(img, int(w * 0.4), int(h * 0.5), 60, 60)
		report += "board=#%02X%02X%02X " % [bd.r8, bd.g8, bd.b8]
		# 右侧（面板开时应亮，关时为背景）(~1100, 400)
		var pn := _avg(img, int(w * 0.88), int(h * 0.5), 40, 60)
		report += "right=#%02X%02X%02X " % [pn.r8, pn.g8, pn.b8]
		# 底栏 (~640, 775)
		var bt := _avg(img, int(w * 0.5), int(h * 0.965), 60, 20)
		report += "bottom=#%02X%02X%02X" % [bt.r8, bt.g8, bt.b8]
		print(report)
	quit(0)

func _avg(img: Image, x: int, y: int, w: int, h: int) -> Color:
	var r := 0; var g := 0; var b := 0; var n := 0
	for yy in range(y, min(y + h, img.get_height())):
		for xx in range(x, min(x + w, img.get_width())):
			var c := img.get_pixel(xx, yy)
			r += c.r8; g += c.g8; b += c.b8; n += 1
	return Color(r / float(n) / 255.0, g / float(n) / 255.0, b / float(n) / 255.0)
