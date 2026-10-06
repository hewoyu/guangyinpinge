extends Node
var _frames := 0
func _ready() -> void:
	var ps: PackedScene = load("res://scenes/workspace.tscn")
	var ws = ps.instantiate()
	await get_tree().process_frame
	get_tree().root.add_child.call_deferred(ws)

func _process(_d: float) -> void:
	_frames += 1
	if _frames == 50:
		print("window_size=", DisplayServer.window_get_size())
		print("viewport_size=", get_viewport().get_visible_rect())
		var ws := get_tree().root.get_node("Workspace")
		print("workspace_size=", ws.size)
		get_tree().quit()
