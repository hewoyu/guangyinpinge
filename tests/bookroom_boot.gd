extends Node

func _ready() -> void:
	var br: Control = load("res://scenes/bookroom.tscn").instantiate()
	add_child(br)
	await get_tree().create_timer(2.0).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shot_bookroom.png")
	print("BOOKROOM SAVED ", img.get_size())
	get_tree().quit()
