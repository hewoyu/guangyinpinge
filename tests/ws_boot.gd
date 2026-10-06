extends Node
## 工作台截图：窗口模式运行 workspace 并截图

func _ready() -> void:
	var ws: Control = load("res://scenes/workspace.tscn").instantiate()
	add_child(ws)
	await get_tree().create_timer(2.5).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shot_workspace.png")
	print("WS SAVED ", img.get_size())
	# 再开一个工具面板截图（Todo）
	if ws.has_method("_toggle_panel"):
		ws._toggle_panel("todo")
		await get_tree().create_timer(1.2).timeout
		var img2 := get_viewport().get_texture().get_image()
		img2.save_png("user://shot_workspace_todo.png")
		print("WS TODO SAVED")
	get_tree().quit()
