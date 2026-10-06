extends SceneTree

func _init() -> void:
	var src_dir := "D:/deepseek/拾光拼图"
	var dst_dir := "D:/deepseek/shiguang_screens/real"
	DirAccess.make_dir_recursive_absolute(dst_dir)
	var dir := DirAccess.open(src_dir)
	var count := 0
	if dir:
		dir.list_dir_begin()
		var name_ := dir.get_next()
		while name_ != "":
			if name_.to_lower().ends_with(".webp"):
				var bytes_ := FileAccess.get_file_as_bytes(src_dir + "/" + name_)
				var img := Image.new()
				var status: int = img.load_webp_from_buffer(bytes_)
				if status == OK:
					var tag := name_.substr(name_.length() - 7, 3)
					var out_path := dst_dir + "/real_" + tag + ".png"
					img.save_png(out_path)
					print("OK ", name_, " -> ", img.get_width(), "x", img.get_height())
					count += 1
				else:
					print("DECODE_FAIL ", name_)
			name_ = dir.get_next()
	print("TOTAL ", count)
	quit()
