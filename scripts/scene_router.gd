extends Node
## 场景路由（autoload: SceneRouter）
## 契约：SceneRouter.go(path, params) / SceneRouter.get_param(key)
## 带全屏转场渐变（ColorRect alpha 动画），参数存 root meta（旧代码直接读 root meta 也兼容）

const FADE_SEC := 0.22

var _params: Dictionary = {}
var _fader: ColorRect = null
var _locked := false

func _ready() -> void:
	_fader = ColorRect.new()
	_fader.color = Color(0.16, 0.13, 0.10, 0.0)
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fader.layer = 100
	var layer := CanvasLayer.new()
	layer.name = "SceneRouterFade"
	layer.add_child(_fader)
	get_tree().root.add_child.call_deferred(layer)

func go(path: String, params: Dictionary = {}) -> void:
	if _locked:
		return
	_locked = true
	_params = params
	get_tree().root.set_meta("scene_params", params)  ## 兼容旧读法
	var tw := _fader.create_tween()
	tw.tween_property(_fader, "color:a", 0.55, FADE_SEC)
	await tw.finished
	get_tree().change_scene_to_file(path)
	# 新场景就绪后淡出
	var tw2 := _fader.create_tween()
	tw2.tween_interval(0.05)
	tw2.tween_property(_fader, "color:a", 0.0, FADE_SEC)
	_locked = false

func get_param(key: String, default = null):
	return _params.get(key, default)

func has_param(key: String) -> bool:
	return _params.has(key)
