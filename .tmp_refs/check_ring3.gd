extends SceneTree
func _init() -> void:
	var ctrl := Control.new()
	ctrl.size = Vector2(240, 240)
	root.add_child(ctrl)
	var y0 := 10
	for mode_i in range(2):
		var ring := TextureProgressBar.new()
		ring.size = Vector2(118, 118)
		ring.position = Vector2(10, y0)
		ctrl.add_child(ring)
		var size := Vector2i(118, 118)
		var fg_img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		var center := Vector2(size) / 2.0
		for y in size.y:
			for x in size.x:
				var p := Vector2(x, y)
				var d := p.distance_to(center)
				if d >= 42.0 and d <= 52.0:
					fg_img.set_pixel(x, y, Color(0.878, 0.471, 0.337, 1.0))
		ring.texture_progress = ImageTexture.create_from_image(fg_img)
		ring.fill_mode = 4 if mode_i == 0 else 4  # FILL_CLOCKWISE
		ring.radial_center_offset = Vector2.ZERO
		ring.value = 100.0 if mode_i == 0 else 50.0
		y0 += 130
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("res://.tmp_refs/ring_test2.png")
	for yi in range(2):
		var cnt := 0
		for y in range(0, 118, 1):
			for x in range(0, 118, 1):
				var px := img.get_pixel(10 + x, 10 + yi * 130 + y)
				if px.r8 > 180 and px.r8 < 250 and px.g8 > 90 and px.g8 < 160:
					cnt += 1
		print("ring", yi, " value=", 100.0 if yi == 0 else 50.0, " tomato=", cnt)
	quit(0)
