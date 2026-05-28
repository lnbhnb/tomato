extends Node
class_name PomodoroTimer

signal focus_started
signal focus_completed
signal focus_interrupted
signal timer_tick(time_left: float)

var timer: Timer
var is_running: bool = false
var focus_duration: float = 25.0 * 60.0  # 25 minutes in seconds


func _ready():
	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_on_timeout)
	add_child(timer)


func start_focus(duration: float = 0.0):
	if duration > 0:
		focus_duration = duration
	timer.start(focus_duration)
	is_running = true
	focus_started.emit()


func interrupt():
	if not is_running:
		return
	timer.stop()
	is_running = false
	focus_interrupted.emit()


func _on_timeout():
	is_running = false
	focus_completed.emit()


func get_time_left() -> float:
	return timer.time_left


func get_time_left_string() -> String:
	var t = int(timer.time_left)
	var minutes = t / 60
	var seconds = t % 60
	return "%02d:%02d" % [minutes, seconds]
