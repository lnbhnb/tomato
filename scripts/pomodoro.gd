extends Node
class_name PomodoroTimer

signal focus_started
signal focus_completed
signal focus_interrupted
signal break_started(mode: String, duration: float)
signal break_completed(mode: String)
signal timer_tick(time_left: float)

const MODE_IDLE := "idle"
const MODE_FOCUS := "focus"
const MODE_SHORT := "short_break"
const MODE_LONG := "long_break"
const LONG_BREAK_EVERY := 4

var timer: Timer
var is_running: bool = false
var mode: String = MODE_IDLE
# 自上次长休以来已连续完成的专注数（达到 LONG_BREAK_EVERY 触发长休后归零）
var focus_streak: int = 0

# 默认时长（秒），由 set_durations 从 SaveManager.settings 注入
var focus_duration: float = 25.0 * 60.0
var short_break_duration: float = 5.0 * 60.0
var long_break_duration: float = 15.0 * 60.0


func _ready():
	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_on_timeout)
	add_child(timer)


func set_durations(focus_min: float, short_min: float, long_min: float) -> void:
	focus_duration = max(1.0, focus_min) * 60.0
	short_break_duration = max(1.0, short_min) * 60.0
	long_break_duration = max(1.0, long_min) * 60.0


func start_focus(duration: float = 0.0):
	if duration > 0:
		focus_duration = duration
	mode = MODE_FOCUS
	timer.start(focus_duration)
	is_running = true
	focus_started.emit()


# 根据 focus_streak 自动决定短/长休息；返回实际进入的 mode
func start_next_break() -> String:
	var is_long: bool = (focus_streak > 0 and focus_streak % LONG_BREAK_EVERY == 0)
	mode = MODE_LONG if is_long else MODE_SHORT
	var dur: float = long_break_duration if is_long else short_break_duration
	timer.start(dur)
	is_running = true
	break_started.emit(mode, dur)
	return mode


func interrupt():
	if not is_running:
		return
	timer.stop()
	is_running = false
	var was: String = mode
	mode = MODE_IDLE
	if was == MODE_FOCUS:
		focus_interrupted.emit()
	# 休息态被打断（用户主动跳过休息）不发信号，由调用方自行处理 UI


func _on_timeout():
	is_running = false
	var was: String = mode
	mode = MODE_IDLE
	match was:
		MODE_FOCUS:
			focus_streak += 1
			focus_completed.emit()
		MODE_SHORT, MODE_LONG:
			if was == MODE_LONG:
				focus_streak = 0  # 长休后归零，开启下一轮
			break_completed.emit(was)


func get_time_left() -> float:
	return timer.time_left


func get_time_left_string() -> String:
	var t = int(timer.time_left)
	var minutes = t / 60
	var seconds = t % 60
	return "%02d:%02d" % [minutes, seconds]


func get_mode() -> String:
	return mode


func is_focusing() -> bool:
	return is_running and mode == MODE_FOCUS


func is_resting() -> bool:
	return is_running and (mode == MODE_SHORT or mode == MODE_LONG)
