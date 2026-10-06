extends SceneTree
## 一次性工具：WEBP → PNG（转换 .tmp_refs 下截图供 UI 参考）
func _init() -> void:
	var dir := DirAccess.open("res://.tmp_refs")
	if dir == null:
		print("no .tmp_refs")
		quit(1)
		return
	var img := Image.new()
	var converted := 0
	for f in dir.get_files():
		if not f.to_lower().ends_with(".webp"):
			continue
		var err := img.load_webp_from_buffer(FileAccess.get_file_as_bytes("res://.tmp_refs/" + f))
		if err != OK:
			print("FAIL ", f, " err=", err)
			continue
		var png := f.get_basename() + ".png"
		img.save_png("res://.tmp_refs/" + png)
		converted += 1
		print("OK ", png, " ", img.get_size())
	print("converted=", converted)
	quit(0)
