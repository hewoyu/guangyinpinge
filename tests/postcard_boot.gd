extends Node
## 明信片启动测试（场景模式运行，autoload 可用）
## godot --path . res://tests/postcard_boot.tscn --quit-after 300

var _shot_done := false

func _ready() -> void:
	var pc: Control = load("res://scenes/postcard.tscn").instantiate()
	add_child(pc)
	pc.present("picnic")
	# 2.5 秒后截图并自检
	await get_tree().create_timer(2.5).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shot_postcard.png")
	var fx: Control = pc.get_node("Card/VBox/PictureFrame/EffectsLayer")
	print("POSTCARD FX nodes=", fx.get_child_count())
	print("POSTCARD SAVED")
	_shot_done = true
	get_tree().quit()

func _process(_d: float) -> void:
	pass
