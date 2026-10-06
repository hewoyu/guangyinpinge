extends SceneTree
## WEBP -> PNG（用 FileAccess + load_webp_from_buffer）

func _init() -> void:
	var src := "D:/deepseek/拾光拼图"
	var dst := "D:/deepseek/shiguang_screens/real"
	DirAccess.make_dir_recursive_absolute(dst)
	var dir := DirAccess.open(src)
	var idx := 0
	if dir:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f.to_lower().ends_with(".webp"):
				var fa := FileAccess.open(src + "/" + f, FileAccess.READ)
				if fa:
					var buf := fa.get_buffer(fa.get_length())
					fa.close()
					var img := Image.new()
					var err: int = img.load_webp_from_buffer(buf)
					if err == OK:
						var num := f.substr(f.length() - 7, 3)
						var out := dst + "/real_" + num + ".png"
						img.save_png(out)
						print("OK ", f, " ", img.get_width(), "x", img.get_height())
						idx += 1
					else:
						print("FAIL ", f, " err=", err)
			f = dir.get_next()
	print("CONVERTED ", idx)
	quit()
