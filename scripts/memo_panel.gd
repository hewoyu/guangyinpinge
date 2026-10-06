extends VBoxContainer
## 备忘录面板：TextEdit，user://memo.txt 持久化（防抖保存）

const SAVE_PATH := "user://memo.txt"
const SAVE_DEBOUNCE := 0.8

var _dirty := false
var _timer := 0.0

@onready var edit: TextEdit = $Edit

func _ready() -> void:
	edit.theme = GameTheme.text_edit_theme(17)
	if FileAccess.file_exists(SAVE_PATH):
		edit.text = FileAccess.get_file_as_string(SAVE_PATH)
	edit.text_changed.connect(func(): _dirty = true)

func _process(delta: float) -> void:
	if _dirty:
		_timer += delta
		if _timer >= SAVE_DEBOUNCE:
			_save_now()

func _save_now() -> void:
	_dirty = false
	_timer = 0.0
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(edit.text)
		f.close()

func _exit_tree() -> void:
	_save_now()
