extends VBoxContainer
## 计数器面板：+/- 步进、重置、保存 user://counter.json

const SAVE_PATH := "user://counter.json"

var count := 0
var step := 1

@onready var num_label: Label = $NumLabel
@onready var plus_btn: Button = $Row/PlusButton
@onready var minus_btn: Button = $Row/MinusButton
@onready var reset_btn: Button = $ResetRow/ResetButton
@onready var step_input: SpinBox = $ResetRow/StepInput

func _ready() -> void:
	num_label.add_theme_font_size_override("font_size", 72)
	num_label.add_theme_color_override("font_color", GameTheme.INK)
	plus_btn.theme = GameTheme.soft_button_theme(34, GameTheme.TOMATO)
	minus_btn.theme = GameTheme.soft_button_theme(34, GameTheme.INK)
	reset_btn.theme = GameTheme.soft_button_theme(16, GameTheme.INK_SOFT)
	step_input.theme = GameTheme.line_edit_theme(16)
	_load()
	plus_btn.pressed.connect(func(): _change(step))
	minus_btn.pressed.connect(func(): _change(-step))
	reset_btn.pressed.connect(func():
		count = 0
		SoundManager.play("click")
		_save())
	step_input.value_changed.connect(func(v: float):
		step = int(v)
		_save())
	_refresh()

func _change(delta: int) -> void:
	count += delta
	SoundManager.play("click")
	_save()
	_refresh()

func _refresh() -> void:
	num_label.text = str(count)

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"count": count, "step": step}))
		f.close()
	_refresh()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is Dictionary:
		count = int(parsed.get("count", 0))
		step = int(parsed.get("step", 1))
