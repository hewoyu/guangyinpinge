extends VBoxContainer
## 白噪音面板：雨/溪流/森林/关闭 四选一，接 SoundManager.set_ambient

const OPTIONS := [
	{"key": "off", "name": "关 闭", "icon": ""},
	{"key": "rain", "name": "雨 声", "icon": "res://assets/images/icon_sound.svg"},
	{"key": "stream", "name": "溪 流", "icon": "res://assets/images/icon_sound.svg"},
	{"key": "forest", "name": "森 林", "icon": "res://assets/images/icon_sound.svg"},
]

var _buttons: Dictionary = {}   ## key -> Button

@onready var list: VBoxContainer = $List

func _ready() -> void:
	for opt in OPTIONS:
		var btn := Button.new()
		btn.text = str(opt.name)
		btn.custom_minimum_size = Vector2(0, 52)
		btn.theme = GameTheme.soft_button_theme(20, GameTheme.INK)
		btn.pressed.connect(func(): _select(str(opt.key)))
		list.add_child(btn)
		_buttons[str(opt.key)] = btn
	_select(SoundManager.current_ambient)

func _select(key: String) -> void:
	SoundManager.set_ambient(key)
	SoundManager.play("click")
	_refresh()

func _refresh() -> void:
	var cur: String = SoundManager.current_ambient
	for key in _buttons:
		var active: bool = key == cur
		var btn: Button = _buttons[key]
		btn.theme = GameTheme.soft_button_theme(
			20, GameTheme.TOMATO if active else GameTheme.INK)
