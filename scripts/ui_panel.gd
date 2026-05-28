extends Control
class_name GameUIPanel

signal start_focus_pressed
signal interrupt_focus_pressed
signal task_completed(task_key: String, exp: int, is_body: bool)

var pomodoro_label: Label
var focus_btn: Button
var status_label: Label
var task_buttons: Dictionary = {}
var message_label: Label

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

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

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

	# Separator
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Task check-in section
	var task_title = Label.new()
	task_title.text = "日常修炼"
	task_title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	task_title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(task_title)

	_add_task_button(vbox, "gongfa", "功法修炼 (CET-4) +15EXP", 15, false)
	_add_task_button(vbox, "zhenfa", "阵法推演 (编程) +20EXP", 20, false)
	_add_task_button(vbox, "like", "理科悟性 (数学) +15EXP", 15, false)
	_add_task_button(vbox, "routi", "肉体横练 (运动) +30罡气", 30, true)

	# Separator
	var sep3 = HSeparator.new()
	vbox.add_child(sep3)

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


func _add_task_button(parent: Control, key: String, text: String, exp: int, is_body: bool):
	var btn = _create_button(text, Color(0.35, 0.25, 0.5), Color(0.25, 0.18, 0.4))
	btn.pressed.connect(func(): _on_task_pressed(key, exp, is_body))
	parent.add_child(btn)
	task_buttons[key] = btn


func _on_focus_btn_pressed():
	if _focus_active:
		interrupt_focus_pressed.emit()
	else:
		start_focus_pressed.emit()


func _on_task_pressed(key: String, exp: int, is_body: bool):
	task_completed.emit(key, exp, is_body)


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


func disable_task(key: String):
	if task_buttons.has(key):
		task_buttons[key].disabled = true
		task_buttons[key].text += " [已完成]"


func show_message(text: String, duration: float = 3.0):
	message_label.text = text
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(message_label):
		message_label.text = ""


func update_timer_display(time_str: String):
	pomodoro_label.text = time_str


func reset_timer_display():
	pomodoro_label.text = "25:00"
