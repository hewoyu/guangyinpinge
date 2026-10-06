extends SceneTree
func _init() -> void:
	var names := [
		"DM_20261006002709_002", "DM_20261006002709_003", "DM_20261006002709_004",
		"DM_20261006002709_005", "DM_20261006002709_006", "DM_20261006002709_007",
		"DM_20261006002709_008", "DM_20261006002709_009", "DM_20261006002709_010",
		"DM_20261006002709_011", "DM_20261006002709_012",
	]
	for n in names:
		var img := Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes("res://.tmp_refs/" + n + ".png")) != OK:
			continue
		var w := img.get_width()
		var h := img.get_height()
		var out := "%s %dx%d | " % [n.substr(-3), w, h]
		for gy in 3:
			for gx in 3:
				var c := _avg(img, int(w * gx / 3.0), int(h * gy / 3.0), int(w / 3), int(h / 3))
				out += "[%d,%d]=#%02X%02X%02X " % [gx, gy, c.r8, c.g8, c.b8]
		print(out)
	quit(0)

func _avg(img: Image, x: int, y: int, w: int, h: int) -> Color:
	var r := 0; var g := 0; var b := 0; var n := 0
	for yy in range(y, min(y + h, img.get_height())):
		for xx in range(x, min(x + w, img.get_width())):
			var c := img.get_pixel(xx, yy)
			r += c.r8; g += c.g8; b += c.b8; n += 1
	return Color(r / float(n) / 255.0, g / float(n) / 255.0, b / float(n) / 255.0)
