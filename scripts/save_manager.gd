extends Node
class_name SaveManagerSingleton

signal data_changed
signal realm_changed(new_realm: String)
signal tribulation_started(target_realm: String)
signal tribulation_failed(stay_realm: String)
signal achievement_unlocked(id: String, title: String)

const REALMS = ["练气", "筑基", "金丹", "元婴", "化神", "炼虚", "合体", "大乘", "渡劫"]
const REALM_THRESHOLDS = [0, 100, 300, 600, 1000, 1500, 2200, 3000, 4000]
const TRIBULATION_FROM_IDX = 2  # 金丹及以上需渡劫
const SAVE_PATH = "user://save_data.json"

const CYCLE_DAILY := "daily"
const CYCLE_WEEKLY := "weekly"
const CYCLE_ONCE := "once"
const EXP_MIN := 1
const EXP_MAX := 200

# 成就定义：id → {title, desc}
const ACHIEVEMENTS := {
	"first_focus":      {"title": "初入修仙",   "desc": "首次完成一次闭关"},
	"streak_7":         {"title": "道心初坚",   "desc": "连续打卡 7 天"},
	"streak_30":        {"title": "道心通玄",   "desc": "连续打卡 30 天"},
	"day_8_focus":      {"title": "一日筑基",   "desc": "单日完成 8 个番茄"},
	"first_realm_up":   {"title": "首次破境",   "desc": "首次提升境界"},
	"first_interrupt":  {"title": "走火入魔",   "desc": "首次中断专注"},
	"focus_3day_4":     {"title": "闭关三日",   "desc": "连续 3 天每天 ≥4 番茄"},
	"collector":        {"title": "收集癖",     "desc": "解锁全部内置形象"},
}

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
		"character": "",
		"tribulation_pending": false,
		"task_defs": [
			{"id": "gongfa", "name": "功法修炼 (CET-4)", "exp": 15, "is_body": false, "cycle": CYCLE_DAILY},
			{"id": "zhenfa", "name": "阵法推演 (编程)", "exp": 20, "is_body": false, "cycle": CYCLE_DAILY},
			{"id": "like",   "name": "理科悟性 (数学)", "exp": 15, "is_body": false, "cycle": CYCLE_DAILY},
			{"id": "routi",  "name": "肉体横练 (运动)", "exp": 30, "is_body": true,  "cycle": CYCLE_DAILY},
		],
		"tasks_done_today": [],
		"tasks_done_week": [],
		"last_active_date": "",
		"last_active_week": "",
		"history": {},
		"history_focus": {},
		"focus_today": 0,
		"streak_days": 0,
		"achievements": {},
		"settings": {
			"focus_min": 25,
			"short_break_min": 5,
			"long_break_min": 15,
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
				_migrate_legacy_tasks()
				# Fill missing keys
				var defaults = get_default_data()
				for key in defaults:
					if not data.has(key):
						data[key] = defaults[key]
				return
	# Fallback: use defaults
	data = get_default_data()
	save_data()


func _migrate_legacy_tasks():
	# 旧版: tasks_today 是 bool 字典; 新版: task_defs[] + tasks_done_today[]
	if data.has("tasks_today") and not data.has("task_defs"):
		var defaults = get_default_data()
		data["task_defs"] = defaults["task_defs"]
		var done: Array = []
		for d in data["task_defs"]:
			if data["tasks_today"].get(d["id"], false):
				done.append(d["id"])
		data["tasks_done_today"] = done
		data.erase("tasks_today")
	# R-03 补全 cycle 字段
	if data.has("task_defs"):
		for d in data["task_defs"]:
			if typeof(d) == TYPE_DICTIONARY and not d.has("cycle"):
				d["cycle"] = CYCLE_DAILY


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


func get_task_def(task_id: String) -> Dictionary:
	for d in data["task_defs"]:
		if d["id"] == task_id:
			return d
	return {}


func is_task_done(task_id: String) -> bool:
	var def := get_task_def(task_id)
	var cyc: String = def.get("cycle", CYCLE_DAILY) if not def.is_empty() else CYCLE_DAILY
	if cyc == CYCLE_WEEKLY:
		return task_id in data.get("tasks_done_week", [])
	return task_id in data["tasks_done_today"]


func add_task_def(task_name: String, exp: int, is_body: bool, cycle: String = CYCLE_DAILY) -> String:
	var id = "t_%d_%d" % [Time.get_ticks_msec(), randi() % 1000]
	var safe_exp: int = clamp(exp, EXP_MIN, EXP_MAX)
	var safe_cycle: String = cycle if cycle in [CYCLE_DAILY, CYCLE_WEEKLY, CYCLE_ONCE] else CYCLE_DAILY
	data["task_defs"].append({
		"id": id, "name": task_name, "exp": safe_exp, "is_body": is_body, "cycle": safe_cycle,
	})
	save_data()
	data_changed.emit()
	return id


func remove_task_def(task_id: String) -> bool:
	var defs: Array = data["task_defs"]
	for i in range(defs.size()):
		if defs[i]["id"] == task_id:
			defs.remove_at(i)
			var done: Array = data["tasks_done_today"]
			if task_id in done:
				done.erase(task_id)
			save_data()
			data_changed.emit()
			return true
	return false


func complete_task(task_id: String) -> bool:
	if is_task_done(task_id):
		return false
	var def = get_task_def(task_id)
	if def.is_empty():
		return false
	var cyc: String = def.get("cycle", CYCLE_DAILY)
	match cyc:
		CYCLE_WEEKLY:
			if not data.has("tasks_done_week") or typeof(data["tasks_done_week"]) != TYPE_ARRAY:
				data["tasks_done_week"] = []
			data["tasks_done_week"].append(task_id)
			# 同时计入当日，避免今日重复点
			data["tasks_done_today"].append(task_id)
		CYCLE_ONCE:
			data["tasks_done_today"].append(task_id)
		_:
			data["tasks_done_today"].append(task_id)
	if def["is_body"]:
		add_body_strength(int(def["exp"]))
	add_exp(int(def["exp"]))
	# once: 完成后自动删除
	if cyc == CYCLE_ONCE:
		remove_task_def(task_id)
	return true


func focus_completed():
	data["focus_count"] += 1
	data["focus_today"] = int(data.get("focus_today", 0)) + 1
	add_exp(25)
	# R-05 成就触发
	unlock_achievement("first_focus")
	if int(data.get("focus_today", 0)) >= 8:
		unlock_achievement("day_8_focus")


func _check_realm_upgrade():
	var current_idx: int = data["realm_index"]
	# 渡劫未完成期间不再进一步升阶
	if data.get("tribulation_pending", false):
		return
	for i in range(REALM_THRESHOLDS.size() - 1, -1, -1):
		if data["total_exp"] >= REALM_THRESHOLDS[i] and i > current_idx:
			if i >= TRIBULATION_FROM_IDX:
				# 进入渡劫态：暂不提阶，等待 confirm_breakthrough
				data["tribulation_pending"] = true
				tribulation_started.emit(REALMS[i])
			else:
				data["realm_index"] = i
				data["realm"] = REALMS[i]
				realm_changed.emit(REALMS[i])
				unlock_achievement("first_realm_up")
			break


func is_in_tribulation() -> bool:
	return data.get("tribulation_pending", false)


# 渡劫成功：把阶位推到 total_exp 所匹配的最高阶
func confirm_breakthrough() -> String:
	var new_idx: int = data["realm_index"]
	for i in range(REALM_THRESHOLDS.size() - 1, -1, -1):
		if data["total_exp"] >= REALM_THRESHOLDS[i]:
			new_idx = i
			break
	data["tribulation_pending"] = false
	if new_idx > data["realm_index"]:
		data["realm_index"] = new_idx
		data["realm"] = REALMS[new_idx]
		save_data()
		realm_changed.emit(REALMS[new_idx])
		unlock_achievement("first_realm_up")
		return REALMS[new_idx]
	save_data()
	return data["realm"]


# 渡劫失败：保留当前阶位、当前阶位经验清零
func fail_tribulation() -> String:
	var idx: int = data["realm_index"]
	data["total_exp"] = REALM_THRESHOLDS[idx]
	data["tribulation_pending"] = false
	save_data()
	tribulation_failed.emit(data["realm"])
	data_changed.emit()
	return data["realm"]


func get_exp_to_next_realm() -> int:
	var idx = data["realm_index"]
	if idx >= REALMS.size() - 1:
		return 0
	return REALM_THRESHOLDS[idx + 1] - data["total_exp"]


func get_setting(key: String, default_value = null):
	var s: Dictionary = data.get("settings", {})
	return s.get(key, default_value)


func set_setting(key: String, value) -> void:
	if not data.has("settings") or typeof(data["settings"]) != TYPE_DICTIONARY:
		data["settings"] = {}
	data["settings"][key] = value
	save_data()
	data_changed.emit()


func reset_daily_tasks():
	data["tasks_done_today"] = []
	save_data()
	data_changed.emit()


func _today_str() -> String:
	var d = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


# 检测跨天：跨天则把昨日完成数归档到 history、重置 tasks_done_today。
# 返回 {rolled: bool, prev_date: String, prev_done: int}
func check_daily_rollover() -> Dictionary:
	var today := _today_str()
	var prev: String = data.get("last_active_date", "")
	if prev == "":
		# 旧存档迁移：从 last_save 取日期部分；空则视为今天
		var ls: String = data.get("last_save", "")
		prev = ls.substr(0, 10) if ls.length() >= 10 else today
	if prev == today:
		# 同一天，只补 last_active_date
		if data.get("last_active_date", "") == "":
			data["last_active_date"] = today
			save_data()
		return {"rolled": false, "prev_date": "", "prev_done": 0}
	# 已跨天
	var prev_done: int = (data["tasks_done_today"] as Array).size()
	var prev_focus: int = int(data.get("focus_today", 0))
	if prev_done > 0:
		(data["history"] as Dictionary)[prev] = prev_done
	if prev_focus > 0:
		if not data.has("history_focus") or typeof(data["history_focus"]) != TYPE_DICTIONARY:
			data["history_focus"] = {}
		(data["history_focus"] as Dictionary)[prev] = prev_focus
	data["tasks_done_today"] = []
	data["focus_today"] = 0
	data["last_active_date"] = today
	# R-05 重算连续打卡天数
	_recompute_streak()
	_check_focus_3day_achievement()
	save_data()
	data_changed.emit()
	return {"rolled": true, "prev_date": prev, "prev_done": prev_done}


# 返回当前周的 ISO key (YYYY-W##)。用与 Date 联动的近似算法（周一为周首）。
func _week_str() -> String:
	var dd := Time.get_date_dict_from_system()
	var weekday: int = int(dd.get("weekday", 0))  # 0=Sunday
	# 调整为 ISO：周一=0、周日=6
	var iso_w: int = (weekday + 6) % 7
	var unix: int = int(Time.get_unix_time_from_system())
	# 周一零点的 unix
	var mon_unix: int = unix - iso_w * 86400
	var mon_dict: Dictionary = Time.get_date_dict_from_unix_time(mon_unix)
	# 粗略 ISO 周号：以当年第几周表达
	var jan1_unix: int = int(Time.get_unix_time_from_datetime_dict({
		"year": int(mon_dict.year), "month": 1, "day": 1,
		"hour": 0, "minute": 0, "second": 0,
	}))
	var days_diff: int = (mon_unix - jan1_unix) / 86400
	var week_no: int = days_diff / 7 + 1
	return "%04d-W%02d" % [int(mon_dict.year), week_no]


# 检测跨周：跨周重置 weekly tasks
func check_weekly_rollover() -> bool:
	var wk := _week_str()
	var prev: String = data.get("last_active_week", "")
	if prev == wk:
		return false
	data["tasks_done_week"] = []
	data["last_active_week"] = wk
	save_data()
	data_changed.emit()
	return prev != ""


# 重算连续打卡天数：以昨日为错位起点向前数连续不为 0 的天数
func _recompute_streak() -> void:
	var hist: Dictionary = data.get("history", {})
	var focus_hist: Dictionary = data.get("history_focus", {})
	var streak: int = 0
	var unix: int = int(Time.get_unix_time_from_system()) - 86400  # 从昨天开始
	for _i in range(60):
		var d: Dictionary = Time.get_date_dict_from_unix_time(unix)
		var k: String = "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]
		var tasks: int = int(hist.get(k, 0))
		var focus: int = int(focus_hist.get(k, 0))
		if tasks > 0 or focus > 0:
			streak += 1
			unix -= 86400
		else:
			break
	data["streak_days"] = streak
	if streak >= 7:
		unlock_achievement("streak_7")
	if streak >= 30:
		unlock_achievement("streak_30")


func _check_focus_3day_achievement() -> void:
	var focus_hist: Dictionary = data.get("history_focus", {})
	var unix: int = int(Time.get_unix_time_from_system()) - 86400
	var ok: bool = true
	for _i in range(3):
		var d: Dictionary = Time.get_date_dict_from_unix_time(unix)
		var k: String = "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]
		if int(focus_hist.get(k, 0)) < 4:
			ok = false
			break
		unix -= 86400
	if ok:
		unlock_achievement("focus_3day_4")


# 中断专注 → 首次划火入魔成就
func on_focus_interrupted() -> void:
	unlock_achievement("first_interrupt")


# 解锁成就；已解锁返 false
func unlock_achievement(id: String) -> bool:
	if not ACHIEVEMENTS.has(id):
		return false
	if not data.has("achievements") or typeof(data["achievements"]) != TYPE_DICTIONARY:
		data["achievements"] = {}
	var ach: Dictionary = data["achievements"]
	if ach.has(id):
		return false
	ach[id] = {"unlocked_at": _today_str()}
	save_data()
	achievement_unlocked.emit(id, str(ACHIEVEMENTS[id]["title"]))
	return true


func is_achievement_unlocked(id: String) -> bool:
	return data.get("achievements", {}).has(id)
