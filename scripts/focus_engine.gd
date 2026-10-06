extends Node
## 专注引擎（autoload: FocusEngine）
## 《光阴拼阁》核心机制：番茄钟状态机 + 碎片随机掉落
## 真实规则（用户提供的官方资料）：
##   "开始专注后，每隔 2-5 分钟，就会随机掉落一块拼图作为奖励"

signal state_changed(state: int)            ## STATE_*
signal tick(remaining_seconds: float)        ## 每秒发射
signal piece_dropping(piece_index: int)      ## 掉落开始（UI 播放飞入动画）
signal piece_landed(piece_index: int)       ## 掉落完成（进入收集状态）
signal focus_finished(typed_minutes: float)  ## 一轮专注完成
signal break_finished()

enum { STATE_IDLE, STATE_FOCUSING, STATE_PAUSED, STATE_BREAK }

const DROP_MIN_INTERVAL := 120.0   ## 2 分钟（真实设定）
const DROP_MAX_INTERVAL := 300.0   ## 5 分钟（真实设定）
const BREAK_MINUTES := 5.0

## 测试钩子：非零时覆盖掉落间隔（如 2.0 = 2 秒一掉，用于回归测试）
@export var debug_drop_interval := 0.0

var state: int = STATE_IDLE
var session_pieces := 0              ## 本轮专注累计掉落碎片数（v5-22 结算文案用）
var pause_elapsed := 0.0             ## 暂停累计时长（v6-34 超时提醒用）
var _pause_reminded_sec := 0.0      ## 上次提醒时的暂停时长

signal pause_too_long(total_sec: float)   ## v6-34：暂停超 5 分钟每 60 秒提醒
var focus_duration_sec := 1500.0    ## 25 分钟标准番茄
var elapsed_sec := 0.0
var remaining_sec := 0.0
var break_remaining := 0.0
var _drop_timer := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func _process(delta: float) -> void:
	match state:
		STATE_FOCUSING:
			elapsed_sec += delta
			remaining_sec = focus_duration_sec - elapsed_sec
			tick.emit(maxf(0.0, remaining_sec))
			_drop_timer -= delta
			if _drop_timer <= 0.0:
				_schedule_next_piece()
			if remaining_sec <= 0.0:
				_finish_focus()
		STATE_PAUSED:
			## v6-34：暂停计时 + 超5分钟每60秒提醒（玩家建议 D2）
			pause_elapsed += delta
			if pause_elapsed >= 300.0 and pause_elapsed - _pause_reminded_sec >= 60.0:
				_pause_reminded_sec = pause_elapsed
				pause_too_long.emit(pause_elapsed)
		STATE_BREAK:
			break_remaining -= delta
			tick.emit(maxf(0.0, break_remaining))
			if break_remaining <= 0.0:
				break_finished.emit()
				_to_idle()

func start_focus(minutes: float = 25.0) -> void:
	## v6 修复：PAUSED 态禁止重开（防误触把暂停变重置）——恢复必须走 resume_focus
	if state == STATE_FOCUSING or state == STATE_PAUSED:
		return
	session_pieces = 0   ## v5-22：新一轮清零
	focus_duration_sec = minutes * 60.0
	elapsed_sec = 0.0
	remaining_sec = focus_duration_sec
	_reset_drop_timer()
	state = STATE_FOCUSING
	state_changed.emit(state)

func pause_focus() -> void:
	if state != STATE_FOCUSING:
		return
	state = STATE_PAUSED
	pause_elapsed = 0.0
	_pause_reminded_sec = 0.0   ## v6-34
	state_changed.emit(state)

func resume_focus() -> void:
	if state != STATE_PAUSED:
		return
	state = STATE_FOCUSING
	state_changed.emit(state)

func give_up_focus() -> void:
	if state != STATE_IDLE:
		var done_min: float = elapsed_sec / 60.0
		if done_min > 0.0:
			GameState.add_focus_minutes(done_min)
		_to_idle()

func _finish_focus() -> void:
	var done_min: float = focus_duration_sec / 60.0
	GameState.add_focus_minutes(done_min)
	GameState.focus_minutes_cache = done_min
	GameState.add_pomodoro()
	state = STATE_BREAK
	break_remaining = BREAK_MINUTES * 60.0
	state_changed.emit(state)
	focus_finished.emit(done_min)
	SoundManager.play("win")

func skip_break() -> void:
	## v5-23 跳过休息（休息界面按钮）
	if state == STATE_BREAK:
		break_remaining = 0.0
		break_finished.emit()
		_to_idle()

func _to_idle() -> void:
	state = STATE_IDLE
	state_changed.emit(state)

func _reset_drop_timer() -> void:
	if debug_drop_interval > 0.0:
		_drop_timer = debug_drop_interval
	else:
		_drop_timer = _rng.randf_range(DROP_MIN_INTERVAL, DROP_MAX_INTERVAL)

func _schedule_next_piece() -> void:
	_try_drop_piece()
	_reset_drop_timer()

func _try_drop_piece() -> void:
	## 随机选一块未收集的碎片掉落
	if GameState.collected_count() >= GameState.TOTAL_PIECES:
		return
	var candidates: Array[int] = []
	for i in GameState.TOTAL_PIECES:
		if not GameState.is_collected(i):
			candidates.append(i)
	if candidates.is_empty():
		return
	var pick: int = candidates[_rng.randi_range(0, candidates.size() - 1)]
	piece_dropping.emit(pick)
	await get_tree().create_timer(0.9).timeout  ## 飞行动画时间
	GameState.collect_piece(pick)
	GameState.add_piece_dropped()
	session_pieces += 1   ## v5-22
	piece_landed.emit(pick)
	SoundManager.play("pickup")

## 掉落间隔（用于 UI 显示"下一块碎片"进度）
func next_drop_in() -> float:
	return maxf(0.0, _drop_timer)

func drop_interval_estimate() -> float:
	return DROP_MAX_INTERVAL

## 格式化 mm:ss
static func fmt(sec: float) -> String:
	var s := int(sec)
	return "%02d:%02d" % [s / 60, s % 60]
