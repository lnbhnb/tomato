extends Node
class_name SaveManagerSingleton

signal data_changed
signal realm_changed(new_realm: String)

const REALMS = ["练气", "筑基", "金丹", "元婴", "化神", "炼虚", "合体", "大乘", "渡劫"]
const REALM_THRESHOLDS = [0, 100, 300, 600, 1000, 1500, 2200, 3000, 4000]
const SAVE_PATH = "user://save_data.json"

var data: Dictionary = {}


func _ready():
	load_data()


func get_default_data() -> Dictionary:
	return {
		"realm_index": 0,
		"realm": "练气",
		"total_exp": 0,
		"body_strength": 0,
		"focus_count": 0,
		"tasks_today": {
			"gongfa": false,
			"zhenfa": false,
			"like": false,
			"routi": false,
		},
		"last_save": "",
	}


func load_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var json = JSON.new()
			var err = json.parse(file.get_as_text())
			file.close()
			if err == OK:
				data = json.data
				# Fill missing keys
				var defaults = get_default_data()
				for key in defaults:
					if not data.has(key):
						data[key] = defaults[key]
				return
	# Fallback: use defaults
	data = get_default_data()
	save_data()


func save_data():
	data["last_save"] = Time.get_datetime_string_from_system()
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "  "))
		file.close()


func add_exp(amount: int):
	data["total_exp"] += amount
	_check_realm_upgrade()
	save_data()
	data_changed.emit()


func add_body_strength(amount: int):
	data["body_strength"] = min(data["body_strength"] + amount, 100)
	save_data()
	data_changed.emit()


func complete_task(task_key: String, exp: int, is_body: bool = false):
	if data["tasks_today"].has(task_key) and data["tasks_today"][task_key]:
		return false  # Already done today
	data["tasks_today"][task_key] = true
	if is_body:
		add_body_strength(exp)
	add_exp(exp)
	return true


func focus_completed():
	data["focus_count"] += 1
	add_exp(25)


func _check_realm_upgrade():
	var current_idx = data["realm_index"]
	for i in range(REALM_THRESHOLDS.size() - 1, -1, -1):
		if data["total_exp"] >= REALM_THRESHOLDS[i] and i > current_idx:
			data["realm_index"] = i
			data["realm"] = REALMS[i]
			realm_changed.emit(REALMS[i])
			break


func get_exp_to_next_realm() -> int:
	var idx = data["realm_index"]
	if idx >= REALMS.size() - 1:
		return 0
	return REALM_THRESHOLDS[idx + 1] - data["total_exp"]


func reset_daily_tasks():
	for key in data["tasks_today"]:
		data["tasks_today"][key] = false
	save_data()
