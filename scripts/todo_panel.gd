extends VBoxContainer
## Todo 面板：增删勾选，user://todo.json 持久化

const SAVE_PATH := "user://todo.json"

var _items: Array[Dictionary] = []   ## {text: String, done: bool}
var _rows: Array[HBoxContainer] = []

@onready var input: LineEdit = $InputRow/Input
@onready var add_btn: Button = $InputRow/AddButton
@onready var list_box: VBoxContainer = $Scroll/List

func _ready() -> void:
	input.theme = GameTheme.line_edit_theme(18)
	add_btn.theme = GameTheme.soft_button_theme(18, GameTheme.TOMATO)
	add_btn.pressed.connect(_on_add)
	input.text_submitted.connect(func(_t): _on_add())
	_load()
	_rebuild()

func _on_add() -> void:
	var t := input.text.strip_edges()
	if t.is_empty():
		return
	_items.append({"text": t, "done": false})
	input.clear()
	SoundManager.play("click")
	_save()
	_rebuild()

func _rebuild() -> void:
	for r in _rows:
		r.queue_free()
	_rows.clear()
	for i in _items.size():
		var row := _make_row(i)
		list_box.add_child(row)
		_rows.append(row)

func _make_row(i: int) -> HBoxContainer:
	var item: Dictionary = _items[i]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var cb := CheckBox.new()
	cb.text = str(item.text)
	cb.button_pressed = bool(item.done)
	if item.done:
		cb.add_theme_color_override("font_color", GameTheme.INK_SOFT)
	cb.theme = GameTheme.checkbox_theme()
	cb.toggled.connect(func(pressed: bool):
		_items[i]["done"] = pressed
		SoundManager.play("click")
		_save()
		_rebuild())
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cb)
	var del := Button.new()
	del.text = "×"
	del.flat = true
	del.add_theme_font_size_override("font_size", 18)
	del.add_theme_color_override("font_color", GameTheme.INK_SOFT)
	del.add_theme_color_override("font_hover_color", GameTheme.TOMATO)
	del.pressed.connect(func():
		_items.remove_at(i)
		SoundManager.play("click")
		_save()
		_rebuild())
	row.add_child(del)
	return row

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_items))
		f.close()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	_items.clear()
	if parsed is Array:
		for it in parsed:
			_items.append({"text": String(it.get("text", "")), "done": bool(it.get("done", false))})
