class_name SettingsData
## 设置键值存取（v5-27）：user://settings.json
## 键约定：nickname 昵称 / bgm_vol / ambient_vol / sfx_vol (0.0~1.0)
##         auto_sort / fast_puzzle (bool) / hyper_focus (bool) / module_count (1/2/3)

const PATH := "user://settings.json"

static func get_value(key: String, default_val = null):
	## 注意：不能叫 get（与 Object.get 冲突）
	var all := _load_all()
	return all.get(key, default_val) if all.has(key) else default_val

static func set_value(key: String, value) -> void:
	var all := _load_all()
	all[key] = value
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(all))
		f.close()

static func _load_all() -> Dictionary:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}
