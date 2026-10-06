extends SceneTree
## 明信片渲染验证：加载 workspace → present("picnic") → 截图

func _init() -> void:
	change_scene_to_file("res://scenes/workspace.tscn")
	await _frames(30)
	# 直接实例化明信片并展示
	var pc: Control = load("res://scenes/postcard.tscn").instantiate()
	root.add_child(pc)
	pc.present("picnic")
	await _frames(120)  # 2 秒动画
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("user://shot_postcard.png")
	print("POSTCARD SAVED ", img.get_size())
	# 检查动态效果层有节点
	var fx: Control = pc.get_node("Card/VBox/PictureFrame/EffectsLayer")
	print("FX nodes=", fx.get_child_count(), " (期望 2 蝴蝶+2 云=4)")
	if fx.get_child_count() >= 4:
		print("POSTCARD OK")
	else:
		print("POSTCARD FAIL")
	quit()

func _frames(n: int) -> void:
	for i in n:
		await process_frame
