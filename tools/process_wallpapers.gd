extends SceneTree
## 壁纸加工：1:1 中心裁切 1080x1080 + 拼图友好度分析（色彩分区/对比度）
## godot --headless --script tools/process_wallpapers.gd

func _init() -> void:
	var dir_path := "res://assets/images/wallpapers"
	var meta_file := FileAccess.open(dir_path + "/_meta.json", FileAccess.READ)
	var meta = JSON.parse_string(meta_file.get_as_text())
	meta_file.close()
	var keep: Array[Dictionary] = []
	if meta is Array:
		for entry_raw in meta:
			var entry: Dictionary = entry_raw
			var fn: String = String(entry.file)
			var path := dir_path + "/" + fn
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img == null:
				print("LOAD FAIL ", fn)
				continue
			# 1:1 中心裁切到 1080x1080
			var side: int = mini(img.get_width(), img.get_height())
			var cx: int = img.get_width() / 2
			var cy: int = img.get_height() / 2
			var rect := Rect2i(cx - side / 2, cy - side / 2, side, side)
			var crop := img.get_region(rect)
			if side > 1080:
				crop.resize(1080, 1080, Image.INTERPOLATE_LANCZOS)
			var out := ProjectSettings.globalize_path(dir_path + "/sq_" + fn.replace(".jpg", ".png"))
			crop.save_png(out)
			# 拼图友好度：8x8 采样的色相方差 + 亮度对比
			var score := _puzzle_score(crop)
			print("SQ ", fn, " ", crop.get_width(), "x", crop.get_height(), " score=", score, " | ", String(entry.title))
			keep.append({ "file": "sq_" + fn.replace(".jpg", ".png"), "title": entry.title, "copyright": entry.copyright, "score": score })
	# 按分数排序输出推荐
	keep.sort_custom(func(a, b): return float(a.score) > float(b.score))
	var f := FileAccess.open(ProjectSettings.globalize_path(dir_path + "/_processed.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(keep))
	f.close()
	print("PROCESSED ", keep.size())
	quit()

func _puzzle_score(img: Image) -> float:
	## 拼图友好度 = 色彩多样性(0-40) + 明暗分区(0-30) + 边缘结构(0-30)
	var colors := {}
	var lums: Array[float] = []
	var step: int = maxi(img.get_width() / 24, 1)
	for x in range(0, img.get_width(), step):
		for y in range(0, img.get_height(), step):
			var c := img.get_pixel(x, y)
			lums.append(c.r * 0.3 + c.g * 0.59 + c.b * 0.11)
			var key: String = "%d-%d-%d" % [int(c.r * 6), int(c.g * 6), int(c.b * 6)]
			colors[key] = true
	var color_div: float = clampf(float(colors.size()) / 2.5, 0.0, 40.0)
	var max_l: float = 0.0
	var min_l: float = 1.0
	for l in lums:
		max_l = maxf(max_l, l)
		min_l = minf(min_l, l)
	var contrast: float = clampf((max_l - min_l) * 40.0, 0.0, 30.0)
	var l_var := 0.0
	var l_mean := 0.0
	for l in lums:
		l_mean += l
	l_mean /= float(lums.size())
	for l in lums:
		l_var += (l - l_mean) * (l - l_mean)
	l_var = sqrt(l_var / float(lums.size()))
	var structure: float = clampf(l_var * 120.0, 0.0, 30.0)
	return color_div + contrast + structure
