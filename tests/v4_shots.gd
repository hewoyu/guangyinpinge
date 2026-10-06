extends Node
## v4 最终截图集：书房 / 玩法页(掉落后) / 旅程信 / 音乐盒
func _ready() -> void:
	# 1) 书房
	var br: Control = load("res://scenes/bookroom.tscn").instantiate()
	add_child(br)
	await _f(90)
	_snap("user://v4_bookroom.png")
	br.queue_free()
	await _f(10)
	# 2) 玩法页（掉落几块后）
	var pg: Control = load("res://scenes/play_page.tscn").instantiate()
	add_child(pg)
	FocusEngine.debug_drop_interval = 2.0
	FocusEngine.start_focus(25.0)
	await _f(6 * 60)
	_snap("user://v4_play.png")
	pg.queue_free()
	FocusEngine.give_up_focus()
	await _f(10)
	# 3) 旅程信
	var jl: Control = load("res://scenes/journey_letter.tscn").instantiate()
	add_child(jl)
	await _f(40)
	_snap("user://v4_letter.png")
	jl.queue_free()
	await _f(10)
	# 4) 音乐盒
	var mb: Control = load("res://scenes/music_box.tscn").instantiate()
	add_child(mb)
	await _f(40)
	_snap("user://v4_music.png")
	mb.queue_free()
	await _f(10)
	get_tree().quit()

func _snap(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SNAP ", path)

func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame
