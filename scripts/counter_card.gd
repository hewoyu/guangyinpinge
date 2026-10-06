class_name CounterData
## 精读页数计数器（v5-25，real_03 第三卡）：持久化 user://counter.json

const PATH := "user://counter.json"

static func load_data() -> Dictionary:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return { "title": "精读页数", "value": 0 }
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		return {
			"title": String(parsed.get("title", "精读页数")),
			"value": int(parsed.get("value", 0)),
		}
	return { "title": "精读页数", "value": 0 }

static func save_data(title: String, value: int) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({ "title": title, "value": value }))
		f.close()

## 备忘录（v5-25 d）
const MEMO_PATH := "user://memo.txt"

static func load_memo() -> String:
	var f := FileAccess.open(MEMO_PATH, FileAccess.READ)
	if f == null:
		return ""
	var text_ := f.get_as_text()
	f.close()
	return text_

static func save_memo(text: String) -> void:
	var f := FileAccess.open(MEMO_PATH, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()

## 本周重点便签（v5-26）
const NOTES_PATH := "user://weekly_notes.json"

static func load_notes() -> Dictionary:
	var f := FileAccess.open(NOTES_PATH, FileAccess.READ)
	if f == null:
		return {
			"points": ["1. 把手头的事拆小，先做 25 分钟再说", "2. 难啃的部分放在状态最好的时段", "3. 完成的就划掉，攒着不如做完"],
			"remembers": ["- 记得保存进度", "- 番茄结束起来接杯水", "- 睡前把明信片收进相册"],
		}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary and parsed.has("points"):
		return parsed
	return { "points": [], "remembers": [] }

static func save_notes(points: Array, remembers: Array) -> void:
	var f := FileAccess.open(NOTES_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({ "points": points, "remembers": remembers }))
		f.close()
