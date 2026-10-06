extends SceneTree
func _init() -> void:
	# 直接构造 TextureProgressBar 验证贴图+fill 模式渲染
	var ctrl := Control.new()
	ctrl.size = Vector2(200, 200)
	root.add_child(ctrl)
	var ring := TextureProgressBar.new()
	ring.size = Vector2(118, 118)
	ring.position = Vector2(41, 41)
	ctrl.add_child(ring)
	var size := Vector2i(118, 118)
	var bg_img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var fg_img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var center := Vector2(size) / 2.0
	for y in size.y:
		for x in size.x:
			var p := Vector2(x, y)
			var d := p.distance_to(center)
			if d >= 42.0 and d <= 52.0:
				var edge := 1.0 - absf((d - 47.0) / 5.0)
				var a := clampf(edge * 3.0, 0.0, 1.0)
				bg_img.set_pixel(x, y, Color(0.89, 0.85, 0.78, 0.9 * a))
				fg_img.set_pixel(x, y, Color(0.878, 0.471, 0.337, a))
	ring.texture_under = ImageTexture.create_from_image(bg_img)
	ring.texture_progress = ImageTexture.create_from_image(fg_img)
	ring.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	ring.value = 0.5
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("res://.tmp_refs/ring_test.png")
	# 检查右侧弧（clockwise 50% 从顶部开始 → 右半有番茄色）
	var cnt := 0
	for y in range(0, 118, 2):
		for x in range(60, 118, 2):
			var c := img.get_pixel(41 + x, 41 + y)
			if c.r8 > 180 and c.g8 > 90 and c.g8 < 160:
				cnt += 1
	print("right_arc_tomato=", cnt)
	quit(0)
