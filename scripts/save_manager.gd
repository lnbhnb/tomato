extends Node
class_name SaveManagerSingleton

signal data_changed
signal realm_changed(new_realm: String)
signal tribulation_started(target_realm: String)
signal tribulation_failed(stay_realm: String)
signal achievement_unlocked(id: String, title: String)
signal pill_dropped(id: String, name: String)
signal pill_used(id: String, name: String)
signal save_imported()
signal custom_realms_changed(character: String)

const REALMS = ["练气", "筑基", "金丹", "元婴", "化神", "炼虚", "合体", "大乘", "渡劫"]
const REALM_THRESHOLDS = [0, 100, 300, 600, 1000, 1500, 2200, 3000, 4000]
const TRIBULATION_FROM_IDX = 2  # 金丹及以上需渡劫
const SAVE_PATH = "user://save_data.json"
const BACKUP_DIR = "user://backups"
const BACKUP_KEEP_DAYS = 7

# R-08 丹药定义：id → {name, desc, effect}
# effect: focus_exp_mult / realm_progress / skip_break
const PILL_DROP_RATE := 0.10  # 每次完整专注的掉落概率
const PILLS := {
	"ningshen": {
		"name": "凝神丹",
		"desc": "下一次闭关经验 ×1.5",
		"effect": "focus_exp_mult",
		"value": 1.5,
	},
	"pozhang": {
		"name": "破障丹",
		"desc": "当前境界进度 +20%",
		"effect": "realm_progress",
		"value": 0.2,
	},
	"bigu": {
		"name": "辟谷丹",
		"desc": "跳过下一次闭关回气",
		"effect": "skip_break",
		"value": 1,
	},
}

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
		"inventory": {},
		"buffs": {
			"focus_exp_mult": 1.0,
			"skip_next_break": false,
		},
		# 自定义境界名：{character_name: ["lv1", ..., "lv9"]}；缺省走 REALMS
		"custom_realms": {},
		"last_backup_date": "",
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
	# R-08 凝神丹 buff：下一次闭关经验 × mult（使用后消耗为 1.0）
	var mult: float = float(_get_buff("focus_exp_mult", 1.0))
	var gain: int = int(round(25.0 * mult))
	add_exp(gain)
	if mult != 1.0:
		_set_buff("focus_exp_mult", 1.0)
	# R-08 丹药随机掉落
	try_drop_pill()
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


# ─── R-08 丹药 / Buff ─────────────────────────────────────────────────────

func _get_buff(key: String, default_v):
	var b: Dictionary = data.get("buffs", {})
	return b.get(key, default_v)


func _set_buff(key: String, value) -> void:
	if not data.has("buffs") or typeof(data["buffs"]) != TYPE_DICTIONARY:
		data["buffs"] = {}
	data["buffs"][key] = value


# 按概率掉落一颗丹药；返回掉落的 id，未掉落返 ""
func try_drop_pill() -> String:
	if randf() > PILL_DROP_RATE:
		return ""
	var ids: Array = PILLS.keys()
	if ids.is_empty():
		return ""
	var pid: String = str(ids[randi() % ids.size()])
	if not data.has("inventory") or typeof(data["inventory"]) != TYPE_DICTIONARY:
		data["inventory"] = {}
	var inv: Dictionary = data["inventory"]
	inv[pid] = int(inv.get(pid, 0)) + 1
	save_data()
	data_changed.emit()
	pill_dropped.emit(pid, str(PILLS[pid]["name"]))
	return pid


func get_pill_count(pid: String) -> int:
	return int(data.get("inventory", {}).get(pid, 0))


# 使用一颗丹药；返回是否成功
func use_pill(pid: String) -> bool:
	if not PILLS.has(pid):
		return false
	var count: int = get_pill_count(pid)
	if count <= 0:
		return false
	var info: Dictionary = PILLS[pid]
	var effect: String = str(info.get("effect", ""))
	var value = info.get("value", 0)
	match effect:
		"focus_exp_mult":
			_set_buff("focus_exp_mult", float(value))
		"realm_progress":
			# 当前阶段跨度 × value 加到 total_exp
			var idx: int = int(data.get("realm_index", 0))
			var cur_th: int = REALM_THRESHOLDS[idx] if idx < REALM_THRESHOLDS.size() else 0
			var nxt_th: int = (
				REALM_THRESHOLDS[idx + 1] if idx + 1 < REALM_THRESHOLDS.size() else cur_th
			)
			var span: int = max(nxt_th - cur_th, 0)
			var bonus: int = int(round(float(span) * float(value)))
			if bonus > 0:
				data["total_exp"] = int(data.get("total_exp", 0)) + bonus
				_check_realm_upgrade()
		"skip_break":
			_set_buff("skip_next_break", true)
		_:
			return false
	data["inventory"][pid] = count - 1
	if int(data["inventory"][pid]) <= 0:
		data["inventory"].erase(pid)
	save_data()
	data_changed.emit()
	pill_used.emit(pid, str(info.get("name", pid)))
	return true


# ─── 自定义境界名（按角色独立） ───────────────────────────────────────────────

func get_realm_names_for(character: String) -> Array:
	var cr: Dictionary = data.get("custom_realms", {}) if typeof(data.get("custom_realms", {})) == TYPE_DICTIONARY else {}
	var arr = cr.get(character, null)
	if typeof(arr) == TYPE_ARRAY and arr.size() == REALMS.size():
		var out: Array = []
		for v in arr:
			out.append(str(v))
		return out
	return REALMS.duplicate()


func has_custom_realms(character: String) -> bool:
	var cr: Dictionary = data.get("custom_realms", {}) if typeof(data.get("custom_realms", {})) == TYPE_DICTIONARY else {}
	return cr.has(character)


func get_display_realm_name(character: String, idx: int) -> String:
	var names: Array = get_realm_names_for(character)
	var i: int = clamp(idx, 0, names.size() - 1)
	return str(names[i])


func get_current_display_realm() -> String:
	var ch: String = str(data.get("character", ""))
	var idx: int = int(data.get("realm_index", 0))
	return get_display_realm_name(ch, idx)


func set_custom_realms(character: String, names: Array) -> bool:
	if character == "":
		return false
	if names.size() != REALMS.size():
		return false
	var clean: Array = []
	for i in range(REALMS.size()):
		var s: String = str(names[i]).strip_edges()
		if s == "":
			s = REALMS[i]  # 空白回退默认
		clean.append(s)
	if not data.has("custom_realms") or typeof(data["custom_realms"]) != TYPE_DICTIONARY:
		data["custom_realms"] = {}
	data["custom_realms"][character] = clean
	save_data()
	custom_realms_changed.emit(character)
	data_changed.emit()
	return true


func clear_custom_realms(character: String) -> void:
	if not data.has("custom_realms") or typeof(data["custom_realms"]) != TYPE_DICTIONARY:
		return
	if data["custom_realms"].has(character):
		data["custom_realms"].erase(character)
		save_data()
		custom_realms_changed.emit(character)
		data_changed.emit()


func consume_skip_break() -> bool:
	if bool(_get_buff("skip_next_break", false)):
		_set_buff("skip_next_break", false)
		save_data()
		return true
	return false


# ─── R-10 存档备份 / 导入导出 / 重置 ────────────────────────────────────────

func _ensure_backup_dir() -> void:
	if not DirAccess.dir_exists_absolute(BACKUP_DIR):
		DirAccess.make_dir_recursive_absolute(BACKUP_DIR)


# 当日首次启动自动备份；保留最近 BACKUP_KEEP_DAYS 份
func backup_today() -> String:
	var today := _today_str()
	if data.get("last_backup_date", "") == today:
		return ""
	_ensure_backup_dir()
	var path: String = "%s/%s.json" % [BACKUP_DIR, today]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	data["last_backup_date"] = today
	save_data()
	_prune_old_backups()
	return path


func _prune_old_backups() -> void:
	var dir := DirAccess.open(BACKUP_DIR)
	if dir == null:
		return
	var files: Array[String] = []
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		if not dir.current_is_dir() and n.ends_with(".json"):
			files.append(n)
		n = dir.get_next()
	dir.list_dir_end()
	files.sort()  # YYYY-MM-DD.json 字序即时序
	while files.size() > BACKUP_KEEP_DAYS:
		var oldest: String = files.pop_front()
		DirAccess.remove_absolute("%s/%s" % [BACKUP_DIR, oldest])


# 导出到任意路径
func export_to_path(abs_path: String) -> bool:
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	return true


# 从任意路径导入；错误保留原数据不覆写
func import_from_path(abs_path: String) -> bool:
	if not FileAccess.file_exists(abs_path):
		return false
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return false
	var txt: String = f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(txt) != OK:
		return false
	var parsed = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	# 先自备份一份当前数据，避免导入出错丢失
	_ensure_backup_dir()
	var safety: String = "%s/_before_import_%d.json" % [
		BACKUP_DIR, int(Time.get_unix_time_from_system())
	]
	var bf := FileAccess.open(safety, FileAccess.WRITE)
	if bf:
		bf.store_string(JSON.stringify(data, "  "))
		bf.close()
	data = parsed
	_migrate_legacy_tasks()
	var defaults := get_default_data()
	for key in defaults:
		if not data.has(key):
			data[key] = defaults[key]
	save_data()
	save_imported.emit()
	data_changed.emit()
	return true


# 重置为默认数据（调用前应由 UI 二次确认）
func reset_all() -> void:
	_ensure_backup_dir()
	var safety: String = "%s/_before_reset_%d.json" % [
		BACKUP_DIR, int(Time.get_unix_time_from_system())
	]
	var bf := FileAccess.open(safety, FileAccess.WRITE)
	if bf:
		bf.store_string(JSON.stringify(data, "  "))
		bf.close()
	data = get_default_data()
	save_data()
	save_imported.emit()
	data_changed.emit()
