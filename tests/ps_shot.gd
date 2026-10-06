extends Node
func _ready() -> void:
	var ps: Control = (load("res://scenes/puzzle_select.tscn") as PackedScene).instantiate() as Control
	add_child(ps)
	await get_tree().create_timer(1.5).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shot_puzzle_select.png")
	print("PS SAVED")
	get_tree().quit()
