extends Node
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://music"))
	var cerr := DirAccess.copy_absolute(ProjectSettings.globalize_path("res://assets/audio/click.wav"), ProjectSettings.globalize_path("user://music/test.wav"))
	print("COPY_ERR=", cerr)
	var f := FileAccess.open("user://music_list.json", FileAccess.WRITE)
	f.store_string(JSON.stringify([{"name": "本地测试曲", "path": "user://music/test.wav", "builtin": false}]))
	f.close()
	var mb: Control = (load("res://scenes/music_box.tscn") as PackedScene).instantiate() as Control
	add_child(mb)
	await get_tree().create_timer(0.5).timeout
	print("ALL=", mb._all_tracks().size(), " first_custom_idx=", mb.TRACKS.size())
	mb._play_track(mb.TRACKS.size())
	await get_tree().create_timer(0.4).timeout
	print("PLAYER=", mb._custom_player != null, " PLAYING=", mb._custom_player != null and mb._custom_player.playing)
	get_tree().quit()
