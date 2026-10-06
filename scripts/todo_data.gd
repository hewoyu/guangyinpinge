class_name TodoData
## 待办数据层（v5-24）：持久化 user://todo.json
## 字段：{text, done, category(study|work|life|urgent), created_at, done_at}
## 消费方：play_page 计时态右栏待办卡 / todo_stats 待办管理页

const PATH := "user://todo.json"

const CATEGORY_COLORS := {
	"study": Color("4A6E9E"),
	"work": Color("7A5A9E"),
	"life": Color("6B4A2E"),
	"urgent": Color("9E4A3A"),
}
const CATEGORY_NAMES := { "study": "学习", "work": "工作", "life": "生活", "urgent": "紧急" }

static func items() -> Array:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Array else []

static func save(list: Array) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(list))
		f.close()

static func add(text: String, category: String = "life", high: bool = false) -> void:
	var list := items()
	list.append({
		"text": text, "done": false, "category": category, "high": high,
		"created_at": int(Time.get_unix_time_from_system()), "done_at": 0,
	})
	save(list)

static func set_high(index: int, on: bool) -> void:
	var list := items()
	if index >= 0 and index < list.size():
		var t: Dictionary = list[index]
		t["high"] = on
		list[index] = t
		save(list)

static func toggle_high(index: int) -> void:
	var list := items()
	if index >= 0 and index < list.size():
		var t: Dictionary = list[index]
		t["high"] = not bool(t.get("high", false))
		list[index] = t
		save(list)

static func high_count() -> int:
	## v6-38：未完成且高优先级的数量（待办管理页卡2）
	var n := 0
	for t in items():
		if not bool(t.get("done", false)) and bool(t.get("high", false)):
			n += 1
	return n

static func toggle(index: int) -> void:
	var list := items()
	if index >= 0 and index < list.size():
		var t: Dictionary = list[index]
		t.done = not bool(t.get("done", false))
		t.done_at = int(Time.get_unix_time_from_system()) if t.done else 0
		list[index] = t
		save(list)

static func remove(index: int) -> void:
	var list := items()
	if index >= 0 and index < list.size():
		list.remove_at(index)
		save(list)

static func clear_all() -> void:
	save([])

static func active_count() -> int:
	var n := 0
	for t in items():
		if not bool(t.get("done", false)):
			n += 1
	return n
