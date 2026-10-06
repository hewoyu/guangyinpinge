extends Node
## 全局状态（autoload: GameState）
## 《拾光拼途》v3：拼图集 + 专注统计 + 存档
## 真实机制：每幅拼图 144 块（12×12），番茄钟专注掉落碎片

signal piece_collected(piece_index: int)
signal puzzle_unlocked_progress(piece_index: int)   ## 与 piece_collected 同步，语义别名
signal current_puzzle_changed(puzzle_id: String)
signal stats_changed(today_minutes: float, pomodoro_count: int)

const GRID := Vector2i(12, 12)
const TOTAL_PIECES := 144
const SAVE_PATH := "user://save_v3.json"

## 拼图集：{ id: {title, image, completed} }
const PUZZLES: Array[Dictionary] = [
	{ "id": "picnic",  "title": "春日野餐", "image": "res://assets/images/puzzle_picnic.svg" },
	{ "id": "starry",  "title": "星空下的家", "image": "res://assets/images/puzzle_starry.svg" },
	{ "id": "ocean",   "title": "海边灯塔", "image": "res://assets/images/puzzle_ocean.svg" },
	## 精选壁纸图库（必应每日精选风光 · 1:1 裁切，拼图友好度 Top6）
	{ "id": "w8",  "title": "冰川孕育之河",     "image": "res://assets/images/wallpapers/sq_wall_08.png" },
	{ "id": "w1",  "title": "条纹中的地球故事", "image": "res://assets/images/wallpapers/sq_wall_01.png" },
	{ "id": "w4",  "title": "捕捉、进食、重复", "image": "res://assets/images/wallpapers/sq_wall_04.png" },
	{ "id": "w6",  "title": "在花岗岩中读懂时间", "image": "res://assets/images/wallpapers/sq_wall_06.png" },
	{ "id": "w5",  "title": "一条值得保护的河流", "image": "res://assets/images/wallpapers/sq_wall_05.png" },
	{ "id": "w3",  "title": "宇宙在召唤",       "image": "res://assets/images/wallpapers/sq_wall_03.png" },
]

var current_puzzle_id := "picnic"
var collected: Dictionary = {}    ## piece_index(0..143) -> true（按当前拼图）
var placed: Dictionary = {}       ## piece_index -> true（已拼装）
var completed_album: Array[String] = []  ## 已完成拼图 id

## 统计
var today_minutes := 0.0         ## 今日累计专注分钟（会话内存，按天重置）
var today_date := ""
var pomodoro_count := 0
var total_focus_count := 0        ## 历史累计专注次数
var total_focus_minutes := 0.0    ## 历史累计专注分钟
var total_pieces_dropped := 0     ## 历史累计掉落碎片
var journey_count := 0             ## 旅程趟数（结算信用）
var journey_focus_count := 0      ## 本趟旅程专注次数（结算信用）
var journey_minutes := 0.0        ## 本趟旅程专注时长
var journey_history: Array[Dictionary] = []   ## 已完成旅程历史：{no,date,focus_count,minutes,start_ts,end_ts}（旅程回顾页）
var journey_start_ts: int = 0   ## v6-36：本趟开始时刻（上趟结束时刻）

## 窗景商店（景笺兑换，task-29）
const WINDOW_VIEWS: Array[Dictionary] = [
	{ "id": "sakura", "title": "春樱雨",   "image": "res://assets/images/view_sakura.svg", "price": 2 },
	{ "id": "snow",   "title": "冬雪原",   "image": "res://assets/images/view_snow.svg",   "price": 3 },
	{ "id": "harbor", "title": "黄昏海港", "image": "res://assets/images/view_harbor.svg", "price": 3 },
	{ "id": "aurora", "title": "极夜极光", "image": "res://assets/images/view_aurora.svg", "price": 5 },
]
var unlocked_views: Array[String] = []   ## 已解锁窗景 id

func is_view_unlocked(id: String) -> bool:
	return unlocked_views.has(id)

func unlock_view(id: String) -> bool:
	## 景笺兑换窗景（官方：窗景兑换后永久可用）
	for v in WINDOW_VIEWS:
		if v.id == id:
			if is_view_unlocked(id) or scene_paper < v.price:
				return false
			scene_paper -= v.price
			unlocked_views.append(id)
			save_game()
			return true
	return false

func latest_unlocked_view() -> Dictionary:
	## 书房窗景显示：最新解锁的（无则返回空=默认景）
	if unlocked_views.is_empty():
		return {}
	var last: String = unlocked_views.back()
	for v in WINDOW_VIEWS:
		if v.id == last:
			return v
	return {}

## 连续专注天数（task-31 成就天数分类）
func _local_date_from_unix(u: float) -> String:
	## unix 秒 → 本地日期字符串（get_date_string_from_unix_time 是 UTC，需加时区 bias）
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	return Time.get_date_string_from_unix_time(u + float(bias) * 60.0)

func focus_streak() -> int:
	## 从今天（或昨天，今天还没记录时）倒推连续专注天数
	var streak := 0
	var offset := 0
	## 若今天无记录，从昨天起算（当日未专注不中断 streak 判定窗口）
	if not history.has(Time.get_date_string_from_system()):
		offset = 1
	var now := Time.get_unix_time_from_system()
	for i in range(offset, 400):
		var d := _local_date_from_unix(now - i * 86400.0)
		if history.has(d) and float(history[d].minutes) > 0.0:
			streak += 1
		else:
			break
	return streak

## 景笺（成就货币，real_11 实锤）
var scene_paper := 0               ## 未使用景笺
var claimed_achievements: Array[String] = []  ## 已领取成就 id

## 成就定义（real_11 逐字抄录：次数分类，按专注次数解锁）
const ACHIEVEMENTS: Array[Dictionary] = [
	## 次数分类（官方 8 个）
	{ "id": "ach_boot", "title": "开机测试", "need": 1, "reward": 1, "type": "count" },
	{ "id": "ach_three", "title": "三次不是巧合", "need": 3, "reward": 1, "type": "count" },
	{ "id": "ach_giveup", "title": "居然没半途而废", "need": 7, "reward": 1, "type": "count" },
	{ "id": "ach_regular", "title": "注意力已转正", "need": 18, "reward": 2, "type": "count" },
	{ "id": "ach_n30", "title": "n>30：具有统计显著性", "need": 36, "reward": 2, "type": "count" },
	{ "id": "ach_sisyphus", "title": "西西弗斯请求换班", "need": 72, "reward": 3, "type": "count" },
	{ "id": "ach_skinner", "title": "斯金纳箱的模范样本", "need": 100, "reward": 3, "type": "count" },
	{ "id": "ach_mystery", "title": "???", "need": 200, "reward": 3, "type": "count" },
	## 拼图分类
	{ "id": "ach_puz_first", "title": "初见全景", "need": 1, "reward": 2, "type": "puzzle" },
	{ "id": "ach_puz_three", "title": "收集控", "need": 2, "reward": 3, "type": "puzzle" },
	{ "id": "ach_puz_all", "title": "拾光收藏家", "need": 9, "reward": 5, "type": "puzzle" },
	## 时长分类
	{ "id": "ach_h_one", "title": "一小时俱乐部", "need": 1, "reward": 1, "type": "hours" },
	{ "id": "ach_h_ten", "title": "半日修习", "need": 10, "reward": 2, "type": "hours" },
	{ "id": "ach_h_fifty", "title": "百时拾光", "need": 50, "reward": 3, "type": "hours" },
	## 天数分类（连续专注）
	{ "id": "ach_d_three", "title": "三日之约", "need": 3, "reward": 1, "type": "days" },
	{ "id": "ach_d_seven", "title": "七日不辍", "need": 7, "reward": 2, "type": "days" },
	{ "id": "ach_d_habit", "title": "廿一日habit", "need": 21, "reward": 3, "type": "days" },
]

func achievement_progress(a: Dictionary) -> float:
	## 成就进度值（按 need_type 取对应统计）
	match String(a.get("type", "count")):
		"count": return float(total_focus_count)
		"puzzle": return float(completed_album.size())
		"hours": return total_focus_minutes / 60.0
		"days": return float(focus_streak())
	return 0.0

func is_achieved(a: Dictionary) -> bool:
	return achievement_progress(a) >= float(a.need)

func is_claimed(a: Dictionary) -> bool:
	return claimed_achievements.has(a.id)

func claim_achievement(a: Dictionary) -> bool:
	if not is_achieved(a) or is_claimed(a):
		return false
	claimed_achievements.append(a.id)
	scene_paper += a.reward
	save_game()
	return true

func unlocked_achievement_count() -> int:
	var n := 0
	for a in ACHIEVEMENTS:
		if is_achieved(a):
			n += 1
	return n

func _ready() -> void:
	var d := Time.get_date_string_from_system()
	if today_date != d:
		today_date = d
	load_game()
	current_puzzle_changed.emit(current_puzzle_id)

## 当前拼图定义
func get_current_puzzle() -> Dictionary:
	for p in PUZZLES:
		if p.id == current_puzzle_id:
			return p
	return PUZZLES[0]

func set_current_puzzle(id: String) -> void:
	if id == current_puzzle_id:
		return
	# 先归档当前拼图进度（防数据丢失：QA 报告的 BUG）
	puzzles_cache[current_puzzle_id] = {
		"collected": collected.keys(),
		"placed": placed.keys(),
		"completed": completed_album.has(current_puzzle_id),
	}
	current_puzzle_id = id
	collected.clear()
	placed.clear()
	# 恢复该拼图的存档进度
	var saved: Dictionary = puzzles_cache.get(id, {})
	for k in saved.get("collected", []):
		collected[int(k)] = true
	for k in saved.get("placed", []):
		placed[int(k)] = true
	current_puzzle_changed.emit(id)
	save_game()

func is_collected(idx: int) -> bool:
	return collected.has(idx)

func is_placed(idx: int) -> bool:
	return placed.has(idx)

func collect_piece(idx: int) -> void:
	if idx < 0 or idx >= TOTAL_PIECES or collected.has(idx):
		return
	collected[idx] = true
	piece_collected.emit(idx)
	save_game()

func place_piece(idx: int) -> void:
	if collected.has(idx) and not placed.has(idx):
		placed[idx] = true
		save_game()

func collected_count() -> int:
	return collected.size()

func placed_count() -> int:
	return placed.size()

func is_current_puzzle_complete() -> bool:
	return placed.size() >= TOTAL_PIECES

func mark_current_completed() -> void:
	if not completed_album.has(current_puzzle_id):
		completed_album.append(current_puzzle_id)
	save_game()

func add_focus_minutes(mins: float) -> void:
	var d := Time.get_date_string_from_system()
	if today_date != d:
		today_date = d
		today_minutes = 0.0
		pomodoro_count = 0
	today_minutes += mins
	total_focus_minutes += mins
	journey_minutes += mins
	## 按日记录（统计页热力图/柱状图数据源）
	if not history.has(d):
		history[d] = { "minutes": 0.0, "pieces": 0 }
	var day: Dictionary = history[d]
	day.minutes = float(day.minutes) + mins
	stats_changed.emit(today_minutes, pomodoro_count)
	save_game()

## 按日专注历史（date -> {minutes, pieces}）
var history: Dictionary = {}

func add_piece_dropped() -> void:
	total_pieces_dropped += 1
	var d := Time.get_date_string_from_system()
	if not history.has(d):
		history[d] = { "minutes": 0.0, "pieces": 0 }
	var day: Dictionary = history[d]
	day.pieces = int(day.pieces) + 1

func add_pomodoro() -> void:
	pomodoro_count += 1
	total_focus_count += 1
	total_focus_minutes += focus_minutes_cache
	journey_focus_count += 1
	journey_minutes += focus_minutes_cache
	stats_changed.emit(today_minutes, pomodoro_count)

var focus_minutes_cache := 0.0  ## 最近一轮专注分钟（FocusEngine 结算时 set）

func start_new_journey() -> void:
	## 归档本趟旅程 → 开启下一趟（journey_letter 纸飞机调用）
	var now := int(Time.get_unix_time_from_system())
	journey_history.append({
		"no": maxi(1, journey_count + 1),   ## v6 修复：journey_count 从 0 起，本趟序号 = 已完成数 + 1
		"date": Time.get_date_string_from_system(),
		"focus_count": maxi(journey_focus_count, 1),
		"minutes": journey_minutes,
		"start_ts": journey_start_ts if journey_start_ts > 0 else now,
		"end_ts": now,
	})
	journey_start_ts = now   ## v6-36：下趟从这趟结束开始计
	journey_count += 1
	journey_focus_count = 0
	journey_minutes = 0.0
	save_game()

## ---- 存档 ----

func save_game() -> void:
	var puzzles_data := {}
	for p in PUZZLES:
		var entry := {}
		if p.id == current_puzzle_id:
			entry = {
				"collected": collected.keys(),
				"placed": placed.keys(),
				"completed": completed_album.has(p.id),
			}
		else:
			# 其他拼图进度保留（首次为空）
			entry = puzzles_cache.get(p.id, {})
		puzzles_data[p.id] = entry
	var data := {
		"current": current_puzzle_id,
		"puzzles": puzzles_data,
		"album": completed_album,
		"today_date": today_date,
		"today_minutes": today_minutes,
		"pomodoro": pomodoro_count,
		"total_focus": total_focus_count,
		"total_minutes": total_focus_minutes,
		"total_pieces": total_pieces_dropped,
		"journey": journey_count,
		"journey_focus": journey_focus_count,
		"journey_minutes": journey_minutes,
		"journey_start_ts": journey_start_ts,
		"scene_paper": scene_paper,
		"claimed": claimed_achievements,
		"history": history,
		"journey_history": journey_history,
		"unlocked_views": unlocked_views,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()
	# cache 与磁盘同源同步（QA BUG 修复：save 后 cache 即最新）
	puzzles_cache = puzzles_data.duplicate(true)

var puzzles_cache: Dictionary = {}  ## id -> {collected:[], placed:[], completed:bool}

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is not Dictionary:
		return
	completed_album.clear()
	for id in parsed.get("album", []):
		completed_album.append(String(id))
	today_date = String(parsed.get("today_date", ""))
	today_minutes = float(parsed.get("today_minutes", 0.0))
	pomodoro_count = int(parsed.get("pomodoro", 0))
	current_puzzle_id = String(parsed.get("current", "picnic"))
	total_focus_count = int(parsed.get("total_focus", 0))
	total_focus_minutes = float(parsed.get("total_minutes", 0.0))
	total_pieces_dropped = int(parsed.get("total_pieces", 0))
	journey_count = int(parsed.get("journey", 0))
	journey_focus_count = int(parsed.get("journey_focus", 0))
	journey_minutes = float(parsed.get("journey_minutes", 0.0))
	journey_start_ts = int(parsed.get("journey_start_ts", 0))
	scene_paper = int(parsed.get("scene_paper", 0))
	claimed_achievements.clear()
	for id_ in parsed.get("claimed", []):
		claimed_achievements.append(String(id_))
	var h = parsed.get("history", {})
	if h is Dictionary:
		history = h
	journey_history.clear()
	for j in parsed.get("journey_history", []):
		if j is Dictionary:
			## v6-36：旧档兼容（无 start_ts 的补 0→回退显示 date）
			if not j.has("start_ts"):
				j["start_ts"] = 0
			if not j.has("end_ts"):
				j["end_ts"] = 0
			journey_history.append(j)
	unlocked_views.clear()
	for vid in parsed.get("unlocked_views", []):
		unlocked_views.append(String(vid))
	var puzzles = parsed.get("puzzles", {})
	puzzles_cache.clear()
	if puzzles is Dictionary:
		for id in puzzles:
			puzzles_cache[String(id)] = puzzles[id]
	# 热载当前拼图进度
	var cur = puzzles_cache.get(current_puzzle_id, {}) as Dictionary
	collected.clear()
	placed.clear()
	for k in cur.get("collected", []):
		collected[int(k)] = true
	for k in cur.get("placed", []):
		placed[int(k)] = true
