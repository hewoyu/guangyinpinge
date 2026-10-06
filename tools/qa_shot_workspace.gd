extends Node
## 工作台截图工具（需带窗口运行：Godot --path . res://tools/qa_shot_workspace.tscn）
var _frames := 0
var ws: Control

func _ready() -> void:
	var ps: PackedScene = load("res://scenes/workspace.tscn")
	ws = ps.instantiate()
	await get_tree().process_frame
	get_tree().root.add_child.call_deferred(ws)

func _process(_d: float) -> void:
	_frames += 1
	if ws == null or not is_instance_valid(ws) or not ws.is_inside_tree():
		return
	if _frames == 60:
		_shot("ws_shot_idle.png")
		var tb: VBoxContainer = ws.get_node("Body/ToolBar")
		(tb.get_child(0) as Button).pressed.emit()
	elif _frames == 100:
		_shot("ws_shot_todo.png")
		var tb: VBoxContainer = ws.get_node("Body/ToolBar")
		(tb.get_child(1) as Button).pressed.emit()
	elif _frames == 140:
		_shot("ws_shot_memo.png")
		(ws.get_node("TopBar/ControlZone/StartButton") as Button).pressed.emit()
	elif _frames == 180:
		_shot("ws_shot_focus.png")
	elif _frames == 200:
		get_tree().quit()

func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://.tmp_refs/" + name)
	print("saved ", name)
