extends Control
class_name GameUIPanel

signal start_focus_pressed
signal interrupt_focus_pressed
signal task_check_in_pressed(task_id: String)
signal task_add_pressed(task_name: String, exp: int, is_body: bool, cycle: String)
signal task_remove_pressed(task_id: String)
signal switch_character_pressed
signal character_selected(name: String)
signal settings_changed(focus_min: int, short_min: int, long_min: int)
signal pin_toggled(pinned: bool)

var pomodoro_label: Label
var focus_btn: Button
var switch_btn: Button
var character_option: OptionButton
var status_label: Label
var task_dropdown: OptionButton
var task_checkin_btn: Button
var task_remove_btn: Button
var task_add_panel: VBoxContainer
var task_add_name_edit: LineEdit
var task_add_exp_edit: SpinBox
var task_add_is_body_cb: CheckBox
var task_add_cycle_option: OptionButton
var message_label: Label

var settings_panel: VBoxContainer
var settings_focus_spin: SpinBox
var settings_short_spin: SpinBox
var settings_long_spin: SpinBox
var pin_check: CheckBox

# R-05 统计面板
var stats_panel: VBoxContainer
var stats_realm_label: Label
var stats_progress_bar: ProgressBar
var stats_streak_label: Label
var stats_heatmap: GridContainer
var stats_achievements: VBoxContainer

var _focus_active: bool = false


func _ready():
	visible = false
	_build_ui()


func _build_ui():
	# Background panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.18, 0.92)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.border_color = Color(0.3, 0.5, 0.9, 0.6)
	panel_style.set_border_width_all(1)
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", panel_style)

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Title
	var title_label = Label.new()
	title_label.text = "修仙面板"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	title_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title_label)

	# Separator
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	# Status display
	status_label = Label.new()
	status_label.text = "境界: 练气 | EXP: 0"
	status_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	status_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(status_label)

	# Pomodoro section
	var pomodoro_title = Label.new()
	pomodoro_title.text = "番茄闭关"
	pomodoro_title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	pomodoro_title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(pomodoro_title)

	pomodoro_label = Label.new()
	pomodoro_label.text = "25:00"
	pomodoro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pomodoro_label.add_theme_font_size_override("font_size", 20)
	pomodoro_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.7))
	vbox.add_child(pomodoro_label)

	focus_btn = _create_button("开始闭关", Color(0.2, 0.55, 0.25), Color(0.15, 0.4, 0.18))
	focus_btn.pressed.connect(_on_focus_btn_pressed)
	vbox.add_child(focus_btn)

	# R-04 Character switch dropdown
	var char_row := HBoxContainer.new()
	char_row.add_theme_constant_override("separation", 4)
	vbox.add_child(char_row)
	var char_lab := Label.new()
	char_lab.text = "形象"
	char_lab.add_theme_font_size_override("font_size", 10)
	char_lab.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	char_lab.custom_minimum_size = Vector2(36, 24)
	char_row.add_child(char_lab)
	character_option = OptionButton.new()
	character_option.custom_minimum_size = Vector2(130, 24)
	character_option.add_theme_font_size_override("font_size", 10)
	character_option.item_selected.connect(_on_character_option_selected)
	char_row.add_child(character_option)

	# 保留原「切换」按钮作为快捷忪环（隐藏占位）
	switch_btn = _create_button("", Color(0.45, 0.3, 0.2), Color(0.32, 0.2, 0.13))
	switch_btn.visible = false

	# Settings (番茄钟时长) 折叠区
	_add_settings_block(vbox)

	# Separator
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Task check-in section
	var task_title = Label.new()
	task_title.text = "日常修炼"
	task_title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	task_title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(task_title)

	_add_task_block(vbox)

	# Separator
	var sep3 = HSeparator.new()
	vbox.add_child(sep3)

	# R-05 修仙日志（统计 / 热力图 / 成就墙）
	_add_stats_block(vbox)

	# Message display
	message_label = Label.new()
	message_label.text = ""
	message_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	message_label.add_theme_font_size_override("font_size", 10)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(message_label)

	# Tips
	var tip_label = Label.new()
	tip_label.text = "右键: 开关面板 | 拖拽: 移动"
	tip_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	tip_label.add_theme_font_size_override("font_size", 9)
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tip_label)


func _create_button(text: String, normal_color: Color, hover_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(170, 28)
	btn.add_theme_font_size_override("font_size", 11)

	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = normal_color
	normal_style.corner_radius_top_left = 4
	normal_style.corner_radius_top_right = 4
	normal_style.corner_radius_bottom_left = 4
	normal_style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = hover_color
	hover_style.corner_radius_top_left = 4
	hover_style.corner_radius_top_right = 4
	hover_style.corner_radius_bottom_left = 4
	hover_style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = hover_color.darkened(0.2)
	pressed_style.corner_radius_top_left = 4
	pressed_style.corner_radius_top_right = 4
	pressed_style.corner_radius_bottom_left = 4
	pressed_style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("pressed", pressed_style)

	return btn


func _add_settings_block(parent: Control):
	var toggle = _create_button("⚙ 调整闭关时长", Color(0.3, 0.3, 0.45), Color(0.22, 0.22, 0.35))
	toggle.custom_minimum_size = Vector2(170, 22)
	toggle.add_theme_font_size_override("font_size", 10)
	parent.add_child(toggle)

	settings_panel = VBoxContainer.new()
	settings_panel.add_theme_constant_override("separation", 3)
	settings_panel.visible = false
	parent.add_child(settings_panel)

	settings_focus_spin = _make_spin("专注时长·分", 1, 120, 25)
	settings_panel.add_child(settings_focus_spin.get_parent())
	settings_short_spin = _make_spin("短闭关·分", 1, 60, 5)
	settings_panel.add_child(settings_short_spin.get_parent())
	settings_long_spin = _make_spin("长闭关·分", 1, 60, 15)
	settings_panel.add_child(settings_long_spin.get_parent())

	pin_check = CheckBox.new()
	pin_check.text = "📌 始终置顶"
	pin_check.button_pressed = true
	pin_check.add_theme_font_size_override("font_size", 10)
	pin_check.toggled.connect(func(p): pin_toggled.emit(p))
	settings_panel.add_child(pin_check)

	var apply_btn = _create_button("应用", Color(0.2, 0.5, 0.3), Color(0.15, 0.4, 0.22))
	apply_btn.custom_minimum_size = Vector2(170, 22)
	apply_btn.add_theme_font_size_override("font_size", 10)
	apply_btn.pressed.connect(_on_settings_apply)
	settings_panel.add_child(apply_btn)

	toggle.pressed.connect(func(): settings_panel.visible = not settings_panel.visible)


func _make_spin(label_text: String, min_v: int, max_v: int, default_v: int) -> SpinBox:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var lab = Label.new()
	lab.text = label_text
	lab.add_theme_font_size_override("font_size", 10)
	lab.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	lab.custom_minimum_size = Vector2(100, 22)
	row.add_child(lab)
	var sb = SpinBox.new()
	sb.min_value = min_v
	sb.max_value = max_v
	sb.step = 1
	sb.value = default_v
	sb.custom_minimum_size = Vector2(64, 22)
	row.add_child(sb)
	return sb


func _on_settings_apply():
	var f := int(settings_focus_spin.value)
	var s := int(settings_short_spin.value)
	var l := int(settings_long_spin.value)
	settings_changed.emit(f, s, l)
	show_message("时长已更新：%d / %d / %d 分" % [f, s, l])
	settings_panel.visible = false

func set_settings_values(focus_min: int, short_min: int, long_min: int) -> void:
	if settings_focus_spin:
		settings_focus_spin.value = focus_min
	if settings_short_spin:
		settings_short_spin.value = short_min
	if settings_long_spin:
		settings_long_spin.value = long_min
	if pomodoro_label:
		pomodoro_label.text = "%02d:00" % focus_min

func set_pin_state(pinned: bool) -> void:
	if pin_check:
		pin_check.set_pressed_no_signal(pinned)


func _add_task_block(parent: Control):
	# 任务下拉
	task_dropdown = OptionButton.new()
	task_dropdown.custom_minimum_size = Vector2(170, 26)
	task_dropdown.add_theme_font_size_override("font_size", 11)
	parent.add_child(task_dropdown)

	# 打卡 + 删除（横排）
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	task_checkin_btn = _create_button("打卡", Color(0.35, 0.25, 0.5), Color(0.25, 0.18, 0.4))
	task_checkin_btn.custom_minimum_size = Vector2(110, 24)
	task_checkin_btn.add_theme_font_size_override("font_size", 10)
	task_checkin_btn.pressed.connect(_on_task_checkin_pressed)
	row.add_child(task_checkin_btn)

	task_remove_btn = _create_button("删除", Color(0.5, 0.25, 0.25), Color(0.4, 0.18, 0.18))
	task_remove_btn.custom_minimum_size = Vector2(56, 24)
	task_remove_btn.add_theme_font_size_override("font_size", 10)
	task_remove_btn.pressed.connect(_on_task_remove_pressed)
	row.add_child(task_remove_btn)

	# "+ 新增任务" 折叠入口
	var add_toggle = _create_button("+ 新增任务", Color(0.25, 0.4, 0.3), Color(0.18, 0.3, 0.2))
	add_toggle.custom_minimum_size = Vector2(170, 22)
	add_toggle.add_theme_font_size_override("font_size", 10)
	add_toggle.pressed.connect(_on_add_toggle_pressed)
	parent.add_child(add_toggle)

	task_add_panel = VBoxContainer.new()
	task_add_panel.add_theme_constant_override("separation", 3)
	task_add_panel.visible = false
	parent.add_child(task_add_panel)

	task_add_name_edit = LineEdit.new()
	task_add_name_edit.placeholder_text = "任务名 (例: 早起冥想)"
	task_add_name_edit.add_theme_font_size_override("font_size", 10)
	task_add_name_edit.custom_minimum_size = Vector2(170, 22)
	task_add_panel.add_child(task_add_name_edit)

	var exp_row := HBoxContainer.new()
	exp_row.add_theme_constant_override("separation", 4)
	var exp_lab := Label.new()
	exp_lab.text = "经验/罡气"
	exp_lab.add_theme_font_size_override("font_size", 10)
	exp_lab.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	exp_lab.custom_minimum_size = Vector2(60, 22)
	exp_row.add_child(exp_lab)
	task_add_exp_edit = SpinBox.new()
	task_add_exp_edit.min_value = 1
	task_add_exp_edit.max_value = 200
	task_add_exp_edit.step = 1
	task_add_exp_edit.value = 10
	task_add_exp_edit.custom_minimum_size = Vector2(106, 22)
	exp_row.add_child(task_add_exp_edit)
	task_add_panel.add_child(exp_row)

	# R-03 周期下拉
	var cyc_row := HBoxContainer.new()
	cyc_row.add_theme_constant_override("separation", 4)
	var cyc_lab := Label.new()
	cyc_lab.text = "周期"
	cyc_lab.add_theme_font_size_override("font_size", 10)
	cyc_lab.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	cyc_lab.custom_minimum_size = Vector2(60, 22)
	cyc_row.add_child(cyc_lab)
	task_add_cycle_option = OptionButton.new()
	task_add_cycle_option.add_theme_font_size_override("font_size", 10)
	task_add_cycle_option.custom_minimum_size = Vector2(106, 22)
	task_add_cycle_option.add_item("☀️ 日常", 0)
	task_add_cycle_option.set_item_metadata(0, "daily")
	task_add_cycle_option.add_item("📅 每周", 1)
	task_add_cycle_option.set_item_metadata(1, "weekly")
	task_add_cycle_option.add_item("🎯 一次性", 2)
	task_add_cycle_option.set_item_metadata(2, "once")
	task_add_cycle_option.select(0)
	cyc_row.add_child(task_add_cycle_option)
	task_add_panel.add_child(cyc_row)

	task_add_is_body_cb = CheckBox.new()
	task_add_is_body_cb.text = "归入罡气 (代替经验)"
	task_add_is_body_cb.add_theme_font_size_override("font_size", 10)
	task_add_panel.add_child(task_add_is_body_cb)

	var confirm_btn = _create_button("确认新增", Color(0.2, 0.5, 0.3), Color(0.15, 0.4, 0.22))
	confirm_btn.custom_minimum_size = Vector2(170, 22)
	confirm_btn.add_theme_font_size_override("font_size", 10)
	confirm_btn.pressed.connect(_on_task_add_confirm)
	task_add_panel.add_child(confirm_btn)


func _on_task_checkin_pressed():
	var id := _get_selected_task_id()
	if id != "":
		task_check_in_pressed.emit(id)


func _on_task_remove_pressed():
	var id := _get_selected_task_id()
	if id != "":
		task_remove_pressed.emit(id)


func _on_add_toggle_pressed():
	if task_add_panel:
		task_add_panel.visible = not task_add_panel.visible


func _on_task_add_confirm():
	var n := task_add_name_edit.text.strip_edges()
	if n.is_empty():
		show_message("任务名不能为空")
		return
	var exp_val := int(task_add_exp_edit.value)
	exp_val = clampi(exp_val, 1, 200)
	var cyc: String = "daily"
	if task_add_cycle_option and task_add_cycle_option.selected >= 0:
		var meta = task_add_cycle_option.get_item_metadata(task_add_cycle_option.selected)
		cyc = str(meta) if meta != null else "daily"
	task_add_pressed.emit(n, exp_val, task_add_is_body_cb.button_pressed, cyc)
	task_add_name_edit.text = ""
	task_add_exp_edit.value = 10
	task_add_is_body_cb.button_pressed = false
	if task_add_cycle_option:
		task_add_cycle_option.select(0)
	task_add_panel.visible = false


func _get_selected_task_id() -> String:
	if not task_dropdown or task_dropdown.item_count == 0:
		return ""
	var idx := task_dropdown.selected
	if idx < 0:
		return ""
	var meta = task_dropdown.get_item_metadata(idx)
	return str(meta) if meta != null else ""


func update_task_list(task_defs: Array, done_ids: Array):
	if not task_dropdown:
		return
	var prev_id := _get_selected_task_id()
	task_dropdown.clear()
	# R-03 按周期分组（daily / weekly / once）
	var groups := {
		"daily":  {"icon": "☀️", "label": "日常",   "items": []},
		"weekly": {"icon": "📅", "label": "每周",   "items": []},
		"once":   {"icon": "🎯", "label": "一次性", "items": []},
	}
	for d in task_defs:
		var c: String = str(d.get("cycle", "daily"))
		if not groups.has(c):
			c = "daily"
		groups[c]["items"].append(d)
	var option_idx: int = 0
	for key in ["daily", "weekly", "once"]:
		var g: Dictionary = groups[key]
		var items: Array = g["items"]
		if items.is_empty():
			continue
		task_dropdown.add_separator("%s %s" % [g["icon"], g["label"]])
		option_idx += 1
		for d in items:
			var suffix : String
			if d.get("is_body", false):
				suffix = " +%d罡气" % int(d["exp"])
			else:
				suffix = " +%dEXP" % int(d["exp"])
			var label := str(d["name"]) + suffix
			var done : bool = d["id"] in done_ids
			if done:
				label = "[✓] " + label
			task_dropdown.add_item(label, option_idx)
			var idx_now: int = task_dropdown.item_count - 1
			task_dropdown.set_item_metadata(idx_now, d["id"])
			task_dropdown.set_item_disabled(idx_now, done)
			option_idx += 1
	# 恢复之前选中
	if prev_id != "":
		for i in range(task_dropdown.item_count):
			if str(task_dropdown.get_item_metadata(i)) == prev_id:
				task_dropdown.select(i)
				return
	# 默认选第一个可选项
	for i in range(task_dropdown.item_count):
		if not task_dropdown.is_item_disabled(i):
			task_dropdown.select(i)
			return


func _on_focus_btn_pressed():
	if _focus_active:
		interrupt_focus_pressed.emit()
	else:
		start_focus_pressed.emit()


func update_status(realm: String, exp: int, body: int, next_exp: int):
	var text = "境界: %s | EXP: %d" % [realm, exp]
	if next_exp > 0:
		text += " (还差%d)" % next_exp
	text += "\n罡气: %d/100" % body
	status_label.text = text


func set_focus_active(active: bool):
	_focus_active = active
	if active:
		focus_btn.text = "中断闭关"
	else:
		focus_btn.text = "开始闭关"


func show_message(text: String, duration: float = 3.0):
	message_label.text = text
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(message_label):
		message_label.text = ""


func update_timer_display(time_str: String):
	pomodoro_label.text = time_str


func update_character_label(name: String, idx: int, total: int):
	# 保留调用点兼容：刷新隐藏的 switch_btn 文案，不再起主要作用
	if switch_btn:
		switch_btn.text = "切换: %s" % name if idx >= 0 else "切换形象"


func update_character_options(list: Array, current: String):
	if not character_option:
		return
	character_option.clear()
	for i in range(list.size()):
		var nm: String = str(list[i])
		character_option.add_item(nm, i)
		character_option.set_item_metadata(i, nm)
	for i in range(character_option.item_count):
		if str(character_option.get_item_metadata(i)) == current:
			character_option.select(i)
			break


func _on_character_option_selected(idx: int):
	if idx < 0 or not character_option:
		return
	var meta = character_option.get_item_metadata(idx)
	if meta != null:
		character_selected.emit(str(meta))


func _add_stats_block(parent: Control):
	var toggle = _create_button("📊 修仙日志", Color(0.3, 0.35, 0.5), Color(0.22, 0.25, 0.4))
	toggle.custom_minimum_size = Vector2(170, 22)
	toggle.add_theme_font_size_override("font_size", 10)
	parent.add_child(toggle)

	stats_panel = VBoxContainer.new()
	stats_panel.add_theme_constant_override("separation", 4)
	stats_panel.visible = false
	parent.add_child(stats_panel)

	stats_realm_label = Label.new()
	stats_realm_label.text = "境界: -- | 还差 --"
	stats_realm_label.add_theme_font_size_override("font_size", 10)
	stats_realm_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	stats_panel.add_child(stats_realm_label)

	stats_progress_bar = ProgressBar.new()
	stats_progress_bar.custom_minimum_size = Vector2(170, 10)
	stats_progress_bar.min_value = 0
	stats_progress_bar.max_value = 100
	stats_progress_bar.show_percentage = false
	stats_panel.add_child(stats_progress_bar)

	stats_streak_label = Label.new()
	stats_streak_label.text = "道心稳固: 0 日"
	stats_streak_label.add_theme_font_size_override("font_size", 10)
	stats_streak_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	stats_panel.add_child(stats_streak_label)

	var hm_lab := Label.new()
	hm_lab.text = "近 30 日闭关热力图"
	hm_lab.add_theme_font_size_override("font_size", 9)
	hm_lab.add_theme_color_override("font_color", Color(0.65, 0.75, 0.95))
	stats_panel.add_child(hm_lab)

	stats_heatmap = GridContainer.new()
	stats_heatmap.columns = 10
	stats_heatmap.add_theme_constant_override("h_separation", 2)
	stats_heatmap.add_theme_constant_override("v_separation", 2)
	stats_panel.add_child(stats_heatmap)

	var ach_lab := Label.new()
	ach_lab.text = "成就墙"
	ach_lab.add_theme_font_size_override("font_size", 9)
	ach_lab.add_theme_color_override("font_color", Color(0.65, 0.75, 0.95))
	stats_panel.add_child(ach_lab)

	stats_achievements = VBoxContainer.new()
	stats_achievements.add_theme_constant_override("separation", 1)
	stats_panel.add_child(stats_achievements)

	toggle.pressed.connect(func(): stats_panel.visible = not stats_panel.visible)


func update_stats(
	realm: String,
	total_exp: int,
	realm_threshold: int,
	next_threshold: int,
	streak: int,
	history_focus: Dictionary,
	achievements_data: Dictionary,
	achievement_def: Dictionary,
) -> void:
	if not stats_panel:
		return
	# 境界进度
	var span: int = max(next_threshold - realm_threshold, 1)
	var cur: int = clamp(total_exp - realm_threshold, 0, span)
	stats_progress_bar.max_value = span
	stats_progress_bar.value = cur
	if next_threshold > realm_threshold:
		stats_realm_label.text = "境界: %s   %d / %d   还差 %d" % [
			realm, cur, span, span - cur,
		]
	else:
		stats_realm_label.text = "境界: %s   (已至巅峰)" % realm
	stats_streak_label.text = "道心稳固: %d 日" % streak
	# 热力图（近 30 天，包含今日）
	for c in stats_heatmap.get_children():
		c.queue_free()
	var unix: int = int(Time.get_unix_time_from_system()) - 29 * 86400
	for i in range(30):
		var d: Dictionary = Time.get_date_dict_from_unix_time(unix)
		var k: String = "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]
		var n: int = int(history_focus.get(k, 0))
		var cell := ColorRect.new()
		cell.custom_minimum_size = Vector2(14, 14)
		cell.color = _heat_color(n)
		cell.tooltip_text = "%s\n%d 个番茄" % [k, n]
		stats_heatmap.add_child(cell)
		unix += 86400
	# 成就墙
	for c in stats_achievements.get_children():
		c.queue_free()
	for id in achievement_def.keys():
		var info: Dictionary = achievement_def[id]
		var unlocked: bool = achievements_data.has(id)
		var row := Label.new()
		var mark: String = "✨" if unlocked else "·"
		row.text = "%s %s  —  %s" % [mark, info.get("title", id), info.get("desc", "")]
		row.add_theme_font_size_override("font_size", 9)
		var col := Color(1.0, 0.9, 0.5) if unlocked else Color(0.5, 0.55, 0.65)
		row.add_theme_color_override("font_color", col)
		stats_achievements.add_child(row)


func _heat_color(n: int) -> Color:
	if n <= 0:
		return Color(0.18, 0.20, 0.28, 1.0)
	elif n == 1:
		return Color(0.3, 0.45, 0.6, 1.0)
	elif n == 2:
		return Color(0.35, 0.6, 0.8, 1.0)
	elif n <= 4:
		return Color(0.45, 0.8, 0.95, 1.0)
	else:
		return Color(1.0, 0.85, 0.3, 1.0)


func reset_timer_display():
	var minutes: int = 25
	if settings_focus_spin:
		minutes = int(settings_focus_spin.value)
	pomodoro_label.text = "%02d:00" % minutes
