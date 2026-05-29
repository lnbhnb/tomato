extends Node2D

# ─── Subsystems ────────────────────────────────────────────────────────────────
var state_machine: CharacterStateMachine
var anim_controller: CharacterAnimController
var pomodoro: PomodoroTimer
var ui_panel: GameUIPanel
var fx: BreakthroughFX

# ─── Node refs ─────────────────────────────────────────────────────────────────
var animated_sprite: AnimatedSprite2D
var collision_area: Area2D
var status_label: Label
var particles: CPUParticles2D
var glow_sprite: Sprite2D

# ─── Drag state ────────────────────────────────────────────────────────────────
var is_dragging: bool = false
var drag_offset: Vector2i  # Mouse offset relative to window top-left when drag started
var _can_move_window: bool = true  # Becomes false if window is embedded

# ─── Edge state ────────────────────────────────────────────────────────────────
var is_at_edge: bool = false
var edge_side: String = ""  # "left", "right", "top", "bottom"

const CENTER = Vector2(120, 140)  # Character center (left portion of 480x280 window)
const WIN_SIZE = Vector2i(480, 420)

# ─── Character switching ───────────────────────────────────────────────────────
const BUILTIN_CHARACTER := "generated"
const LEGACY_DIR := "res://assets/sprites"
const CHARACTERS_DIR := "res://assets/characters"
var available_characters: Array[String] = []
var current_character: String = ""


func _ready():
	# Force transparent window flags at runtime (defensive: some drivers ignore project.godot)
	get_viewport().transparent_bg = true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)

	# Center window on screen
	_center_window()

	# Build scene tree
	_build_scene()

	# Initialize subsystems
	state_machine = CharacterStateMachine.new()
	add_child(state_machine)

	anim_controller = CharacterAnimController.new()
	anim_controller.setup(animated_sprite)
	add_child(anim_controller)

	pomodoro = PomodoroTimer.new()
	add_child(pomodoro)
	# R-02 从 SaveManager.settings 注入三个时长
	pomodoro.set_durations(
		float(SaveManager.get_setting("focus_min", 25)),
		float(SaveManager.get_setting("short_break_min", 5)),
		float(SaveManager.get_setting("long_break_min", 15)),
	)

	# R-06 突破仪式特效
	fx = BreakthroughFX.new()
	add_child(fx)

	# Generate pixel-art sprite frames (or load custom images)
	available_characters = _scan_characters()
	var saved: String = SaveManager.data.get("character", "")
	if saved == "" or not (saved in available_characters):
		saved = available_characters[0]
	current_character = saved
	animated_sprite.sprite_frames = _build_frames_for_character(saved)
	animated_sprite.play("idle")

	# Build UI panel (reference the one in .tscn)
	_setup_ui_panel()

	# Build floating status label
	_build_status_label()

	# Connect all signals
	_connect_signals()

	# Initial UI sync
	_update_ui_status()


func _center_window():
	if not _can_move_window:
		return
	var screen_size = DisplayServer.screen_get_size()
	var pos = Vector2i(
		(screen_size.x - WIN_SIZE.x) / 2,
		(screen_size.y - WIN_SIZE.y) / 2
	)
	_try_move_window(pos)


func _is_window_embedded() -> bool:
	return not _can_move_window


func _try_move_window(pos: Vector2i):
	var before = DisplayServer.window_get_position()
	DisplayServer.window_set_position(pos)
	var after = DisplayServer.window_get_position()
	# If position didn't change, window is likely embedded and can't move
	if before == after and before != pos:
		_can_move_window = false


# ─── Scene construction ────────────────────────────────────────────────────────

func _build_scene():
	# Soft glow background (behind character)
	glow_sprite = Sprite2D.new()
	var glow_img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var dist = Vector2(x, y).distance_to(Vector2(32, 32))
			if dist < 32:
				var alpha = (1.0 - dist / 32.0) * 0.25
				glow_img.set_pixel(x, y, Color(0.3, 0.5, 0.9, alpha))
	glow_sprite.texture = ImageTexture.create_from_image(glow_img)
	glow_sprite.scale = Vector2(3.5, 3.5)
	glow_sprite.position = CENTER
	add_child(glow_sprite)

	# Area2D for mouse interaction (drag / right-click)
	collision_area = Area2D.new()
	collision_area.input_pickable = true
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(180, 180)  # Matches sprite visual size (96 * ~1.9)
	collision.shape = shape
	collision_area.add_child(collision)
	collision_area.position = CENTER
	add_child(collision_area)
	collision_area.input_event.connect(_on_area_input_event)
	collision_area.mouse_entered.connect(_on_mouse_entered)
	collision_area.mouse_exited.connect(_on_mouse_exited)

	# AnimatedSprite2D for the character
	animated_sprite = AnimatedSprite2D.new()
	animated_sprite.scale = Vector2(1.8, 1.8)
	animated_sprite.position = CENTER
	add_child(animated_sprite)

	# Ambient qi particles
	particles = CPUParticles2D.new()
	particles.emitting = true
	particles.amount = 12
	particles.lifetime = 2.5
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.initial_velocity_min = 8.0
	particles.initial_velocity_max = 20.0
	particles.gravity = Vector2(0, -5)
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.5
	particles.color = Color(0.45, 0.7, 1.0, 0.5)
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 30.0
	particles.position = CENTER
	add_child(particles)


func _setup_ui_panel():
	ui_panel = $UIPanel
	# Right-click is handled globally via _input, no need for per-node handler


# ─── Sprite loading ────────────────────────────────────────────────────────────

func _scan_characters() -> Array[String]:
	# Discover available characters: legacy assets/sprites/ + assets/characters/<name>/
	# + builtin code-generated fallback (always present).
	var list: Array[String] = []
	if _dir_has_images(LEGACY_DIR + "/idle"):
		list.append("default")
	var dir = DirAccess.open(CHARACTERS_DIR)
	if dir != null:
		dir.list_dir_begin()
		var n = dir.get_next()
		while n != "":
			if dir.current_is_dir() and n != "." and n != "..":
				if _dir_has_images(CHARACTERS_DIR + "/" + n + "/idle"):
					list.append(n)
			n = dir.get_next()
		dir.list_dir_end()
	list.append(BUILTIN_CHARACTER)
	print("[修仙桌宠] 可用形象: ", list)
	return list


func _build_frames_for_character(name: String) -> SpriteFrames:
	if name == BUILTIN_CHARACTER:
		return SpriteGenerator.generate_all_frames()
	var base: String = LEGACY_DIR if name == "default" else CHARACTERS_DIR + "/" + name
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	_load_anim_from_dir(frames, "idle", base + "/idle", 8)
	_load_anim_from_dir(frames, "focus", base + "/focus", 6)
	_load_anim_from_dir(frames, "sleep", base + "/sleep", 5)
	if frames.get_frame_count("idle") == 0:
		push_warning("[修仙桌宠] 角色 %s 加载失败，回退到内置形象" % name)
		return SpriteGenerator.generate_all_frames()
	print("[修仙桌宠] 加载形象: ", name)
	return frames


func switch_character(name: String) -> void:
	if name == current_character:
		return
	current_character = name
	animated_sprite.sprite_frames = _build_frames_for_character(name)
	var anim := state_machine.get_state_name().to_lower() if state_machine else "idle"
	if animated_sprite.sprite_frames.has_animation(anim):
		animated_sprite.play(anim)
	SaveManager.data["character"] = name
	# R-05 记录已见形象，检测收集癖成就
	if not SaveManager.data.has("seen_characters") or typeof(SaveManager.data["seen_characters"]) != TYPE_ARRAY:
		SaveManager.data["seen_characters"] = []
	var seen: Array = SaveManager.data["seen_characters"]
	if not (name in seen):
		seen.append(name)
	var all_seen: bool = true
	for c in available_characters:
		if not (c in seen):
			all_seen = false
			break
	if all_seen and available_characters.size() > 1:
		SaveManager.unlock_achievement("collector")
	SaveManager.save_data()
	var idx := available_characters.find(name)
	if ui_panel:
		ui_panel.update_character_label(name, idx, available_characters.size())
		ui_panel.update_character_options(available_characters, name)
		ui_panel.show_message("切换形象: %s (%d/%d)" % [name, idx + 1, available_characters.size()])


func cycle_character() -> void:
	if available_characters.is_empty():
		return
	var idx := available_characters.find(current_character)
	if idx < 0:
		idx = -1
	idx = (idx + 1) % available_characters.size()
	switch_character(available_characters[idx])


func _load_sprite_frames() -> SpriteFrames:
	# Try to load custom images from assets/sprites/{idle,focus,sleep}/
	# If no custom images found, fall back to code-generated sprites
	var has_custom = _dir_has_images("res://assets/sprites/idle")
	if has_custom:
		return _load_custom_frames()
	else:
		print("[修仙桌宠] 未找到自定义素材，使用代码生成的像素小人")
		return SpriteGenerator.generate_all_frames()


func _dir_has_images(path: String) -> bool:
	var dir = DirAccess.open(path)
	if dir == null:
		return false
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var lower = file_name.to_lower()
			if lower.ends_with(".png") or lower.ends_with(".import"):
				dir.list_dir_end()
				return true
		file_name = dir.get_next()
	dir.list_dir_end()
	return false


func _load_custom_frames() -> SpriteFrames:
	var frames = SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	_load_anim_from_dir(frames, "idle", "res://assets/sprites/idle", 8)
	_load_anim_from_dir(frames, "focus", "res://assets/sprites/focus", 6)
	_load_anim_from_dir(frames, "sleep", "res://assets/sprites/sleep", 5)

	# If any animation is empty, fill with generated fallback
	if frames.get_frame_count("idle") == 0:
		frames.remove_animation("idle")
		var fallback = SpriteGenerator.generate_all_frames()
		return fallback

	print("[修仙桌宠] 自定义素材加载完成!")
	return frames


func _load_anim_from_dir(frames: SpriteFrames, anim_name: String, dir_path: String, fps: float):
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, true)

	var dir = DirAccess.open(dir_path)
	if dir == null:
		return

	# Collect all PNG files and sort them
	var files: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".png"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	files.sort()

	# Load each frame using Image.load_from_file (bypasses Godot import system)
	for f in files:
		var full_path = dir_path + "/" + f
		# Convert res:// path to absolute path for Image.load_from_file
		var abs_path = ProjectSettings.globalize_path(full_path)
		var img = Image.new()
		var err = img.load(abs_path)
		if err == OK:
			var tex = ImageTexture.create_from_image(img)
			frames.add_frame(anim_name, tex)
		else:
			push_warning("[修仙桌宠] 无法加载: " + abs_path)

	print("[修仙桌宠] 加载 %s: %d 帧" % [anim_name, frames.get_frame_count(anim_name)])


func _build_status_label():
	status_label = Label.new()
	status_label.position = Vector2(8, 4)  # Top-left corner of window
	status_label.add_theme_font_size_override("font_size", 9)
	status_label.add_theme_color_override("font_color", Color(0.75, 0.92, 0.78, 0.85))
	add_child(status_label)
	_update_status_label_text()


# ─── Signal wiring ─────────────────────────────────────────────────────────────

func _connect_signals():
	# Pomodoro -> Main
	pomodoro.focus_completed.connect(_on_focus_completed)
	pomodoro.focus_interrupted.connect(_on_focus_interrupted)
	pomodoro.break_started.connect(_on_break_started)
	pomodoro.break_completed.connect(_on_break_completed)

	# State machine -> animation + UI
	state_machine.state_changed.connect(_on_state_changed)

	# SaveManager -> UI refresh
	SaveManager.data_changed.connect(_on_data_changed)
	SaveManager.realm_changed.connect(_on_realm_changed)
	SaveManager.tribulation_started.connect(_on_tribulation_started)
	SaveManager.tribulation_failed.connect(_on_tribulation_failed)

	# UI panel buttons -> Main
	ui_panel.start_focus_pressed.connect(_on_start_focus)
	ui_panel.interrupt_focus_pressed.connect(_on_interrupt_focus)
	ui_panel.task_check_in_pressed.connect(_on_task_check_in)
	ui_panel.task_add_pressed.connect(_on_task_add)
	ui_panel.task_remove_pressed.connect(_on_task_remove)
	ui_panel.switch_character_pressed.connect(cycle_character)
	ui_panel.character_selected.connect(switch_character)
	ui_panel.settings_changed.connect(_on_settings_changed)
	ui_panel.pin_toggled.connect(_on_pin_toggled)
	var idx := available_characters.find(current_character)
	ui_panel.update_character_label(current_character, idx, available_characters.size())
	ui_panel.update_character_options(available_characters, current_character)
	_refresh_task_list()

	# R-05 成就触发
	SaveManager.achievement_unlocked.connect(_on_achievement_unlocked)

	# R-02 同步设置面板初始值
	var f := int(SaveManager.get_setting("focus_min", 25))
	var s := int(SaveManager.get_setting("short_break_min", 5))
	var l := int(SaveManager.get_setting("long_break_min", 15))
	ui_panel.set_settings_values(f, s, l)

	# 默认收起 UI 面板 · 应用鼠标穿透 · 同步置顶状态
	ui_panel.visible = false
	var pinned: bool = bool(SaveManager.get_setting("always_on_top", true))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, pinned)
	ui_panel.set_pin_state(pinned)
	_apply_mouse_passthrough()

	# R-01 跨天检测：需在 ui_panel 初始化完成后调用，以便弹气泡
	var roll: Dictionary = SaveManager.check_daily_rollover()
	if roll.get("rolled", false):
		var prev_done: int = roll.get("prev_done", 0)
		if prev_done > 0:
			ui_panel.show_message("道友醒来 · 昨日修炼 %d 项" % prev_done)
		else:
			ui_panel.show_message("道友醒来，新的一日修炼开始")
		_refresh_task_list()

	# R-03 跨周检测：weekly 任务重置
	if SaveManager.check_weekly_rollover():
		ui_panel.show_message("新的一周·每周任务已重置")
		_refresh_task_list()

	# R-05 初始统计面板刷新
	_refresh_stats()


# ─── Input handling ────────────────────────────────────────────────────────────

func _on_area_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			is_dragging = true
			# Record mouse position relative to window top-left
			var win_pos = DisplayServer.window_get_position()
			var mouse_pos = DisplayServer.mouse_get_position()
			drag_offset = mouse_pos - win_pos


func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			is_dragging = false
		# Right-click anywhere toggles UI panel (if not consumed by Area2D or UI)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_toggle_ui_panel()


func _process(_delta):
	# Handle window dragging (only in standalone window mode)
	if is_dragging and _can_move_window:
		var mouse_pos = DisplayServer.mouse_get_position()
		var new_pos = mouse_pos - drag_offset
		# Clamp to screen bounds
		new_pos = _clamp_to_screen(new_pos)
		DisplayServer.window_set_position(new_pos)

	# Check edge state
	if _can_move_window:
		_check_screen_edge()

	# Update pomodoro timer display
	if pomodoro.is_running:
		ui_panel.update_timer_display(pomodoro.get_time_left_string())


func _clamp_to_screen(pos: Vector2i) -> Vector2i:
	var screen_size = DisplayServer.screen_get_size()
	# Allow the window to show at least 60px on screen
	var margin = 60
	pos.x = clampi(pos.x, -WIN_SIZE.x + margin, screen_size.x - margin)
	pos.y = clampi(pos.y, 0, screen_size.y - margin)
	return pos


func _check_screen_edge():
	var win_pos = DisplayServer.window_get_position()
	var screen_size = DisplayServer.screen_get_size()
	var edge_threshold = 8  # pixels from edge to trigger

	var new_edge = ""
	if win_pos.x <= edge_threshold:
		new_edge = "left"
	elif win_pos.x + WIN_SIZE.x >= screen_size.x - edge_threshold:
		new_edge = "right"
	elif win_pos.y <= edge_threshold:
		new_edge = "top"
	elif win_pos.y + WIN_SIZE.y >= screen_size.y - edge_threshold:
		new_edge = "bottom"

	if new_edge != edge_side:
		edge_side = new_edge
		if new_edge != "":
			_enter_edge_mode(new_edge)
		else:
			_exit_edge_mode()


func _enter_edge_mode(side: String):
	is_at_edge = true
	# Tilt/lean the sprite toward the edge
	match side:
		"left":
			animated_sprite.rotation = deg_to_rad(25)
			animated_sprite.position = Vector2(CENTER.x - 20, CENTER.y + 10)
		"right":
			animated_sprite.rotation = deg_to_rad(-25)
			animated_sprite.position = Vector2(CENTER.x + 20, CENTER.y + 10)
		"top":
			animated_sprite.rotation = deg_to_rad(180)
			animated_sprite.position = Vector2(CENTER.x, CENTER.y - 20)
		"bottom":
			animated_sprite.rotation = 0
			animated_sprite.position = Vector2(CENTER.x, CENTER.y + 25)
	# Squish effect (compression against edge)
	match side:
		"left", "right":
			animated_sprite.scale = Vector2(1.4, 2.0)
		"top":
			animated_sprite.scale = Vector2(2.0, 1.4)
		"bottom":
			animated_sprite.scale = Vector2(2.2, 1.5)


func _exit_edge_mode():
	is_at_edge = false
	animated_sprite.rotation = 0
	animated_sprite.position = CENTER
	animated_sprite.scale = Vector2(1.8, 1.8)


func _toggle_ui_panel():
	ui_panel.visible = not ui_panel.visible
	_apply_mouse_passthrough()


# 默认只让桌宠区接受鼠标事件，其它区域透透到桌面；UI 面板展开时整个窗口可点
func _apply_mouse_passthrough():
	if ui_panel and ui_panel.visible:
		DisplayServer.window_set_mouse_passthrough(PackedVector2Array())
		return
	# 桌宠交互区：以 CENTER (120, 140) 为中心的矩形，允许拖拽边距
	var r := Rect2(40, 60, 160, 170)
	var poly := PackedVector2Array([
		Vector2(r.position.x, r.position.y),
		Vector2(r.position.x + r.size.x, r.position.y),
		Vector2(r.position.x + r.size.x, r.position.y + r.size.y),
		Vector2(r.position.x, r.position.y + r.size.y),
	])
	DisplayServer.window_set_mouse_passthrough(poly)


func _on_pin_toggled(pinned: bool):
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, pinned)
	SaveManager.set_setting("always_on_top", pinned)


func _on_mouse_entered():
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)


func _on_mouse_exited():
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	is_dragging = false


# ─── Focus (Pomodoro) handlers ─────────────────────────────────────────────────

func _on_start_focus():
	pomodoro.start_focus()
	state_machine.go_focus()
	ui_panel.set_focus_active(true)


func _on_interrupt_focus():
	var was_in_trib: bool = SaveManager.is_in_tribulation()
	var was_focusing: bool = pomodoro.is_focusing() if pomodoro.has_method("is_focusing") else false
	pomodoro.interrupt()
	state_machine.go_sleep()
	ui_panel.set_focus_active(false)
	ui_panel.reset_timer_display()
	if was_focusing:
		SaveManager.on_focus_interrupted()
	if was_in_trib:
		SaveManager.fail_tribulation()
	else:
		ui_panel.show_message("走火入魔! 本次闭关中断，不扣经验")


func _on_focus_completed():
	var was_in_trib: bool = SaveManager.is_in_tribulation()
	SaveManager.focus_completed()
	ui_panel.set_focus_active(false)
	ui_panel.reset_timer_display()
	ui_panel.show_message("闭关成功! 修为精进 +25 EXP")
	# R-06 渡劫成功：进渡劫态下完整走完一次专注 → 实现提阶
	if was_in_trib:
		SaveManager.confirm_breakthrough()
		state_machine.go_idle()
		return
	# R-02 自动进入闭关回气（休息态）
	var break_mode: String = pomodoro.start_next_break()
	state_machine.go_sleep()
	var label: String = "长闭关" if break_mode == PomodoroTimer.MODE_LONG else "短闭关"
	ui_panel.show_message("%s中·静坐回气" % label)


func _on_break_started(_mode: String, _duration: float):
	ui_panel.set_focus_active(false)


func _on_break_completed(mode: String):
	state_machine.go_idle()
	ui_panel.reset_timer_display()
	var label: String = "长闭关" if mode == PomodoroTimer.MODE_LONG else "短闭关"
	ui_panel.show_message("%s已毕，可继续修炼" % label)


func _on_settings_changed(focus_min: int, short_min: int, long_min: int):
	SaveManager.set_setting("focus_min", focus_min)
	SaveManager.set_setting("short_break_min", short_min)
	SaveManager.set_setting("long_break_min", long_min)
	pomodoro.set_durations(float(focus_min), float(short_min), float(long_min))
	# 如果当前不在计时，同步刷新倒计时初始显示
	if not pomodoro.is_running:
		ui_panel.set_settings_values(focus_min, short_min, long_min)


func _on_focus_interrupted():
	# Called from pomodoro signal (redundant safety)
	pass


# ─── State change handler ──────────────────────────────────────────────────────

func _on_state_changed(new_state: String):
	anim_controller.play_animation(new_state)
	_update_status_label_text()
	# Adjust visual effects based on state
	match new_state:
		"IDLE":
			particles.amount = 8
			particles.color = Color(0.45, 0.7, 1.0, 0.4)
			particles.emitting = true
			glow_sprite.modulate = Color(1, 1, 1, 1)
		"FOCUS":
			particles.amount = 20
			particles.color = Color(0.6, 0.85, 1.0, 0.7)
			particles.emitting = true
			glow_sprite.modulate = Color(1.5, 1.3, 1.0, 1)
		"SLEEP":
			particles.amount = 4
			particles.color = Color(0.4, 0.5, 0.7, 0.25)
			particles.emitting = true
			glow_sprite.modulate = Color(0.5, 0.5, 0.7, 1)


# ─── Task check-in handler ────────────────────────────────────────────────────

func _on_task_check_in(task_id: String):
	var def = SaveManager.get_task_def(task_id)
	if def.is_empty():
		ui_panel.show_message("任务不存在")
		_refresh_task_list()
		return
	var success = SaveManager.complete_task(task_id)
	if success:
		if def["is_body"]:
			ui_panel.show_message("肉体横练! 罡气 +%d" % int(def["exp"]))
		else:
			ui_panel.show_message("修炼有成! EXP +%d" % int(def["exp"]))
	else:
		ui_panel.show_message("今日此项修炼已完成")
	_refresh_task_list()


func _on_task_add(task_name: String, exp: int, is_body: bool, cycle: String):
	SaveManager.add_task_def(task_name, exp, is_body, cycle)
	_refresh_task_list()
	var cyc_lab: String
	match cycle:
		"weekly":
			cyc_lab = "每周"
		"once":
			cyc_lab = "一次性"
		_:
			cyc_lab = "日常"
	ui_panel.show_message("已新增[%s]: %s (+%d%s)" % [cyc_lab, task_name, exp, "罡气" if is_body else "EXP"])


func _on_task_remove(task_id: String):
	var def = SaveManager.get_task_def(task_id)
	var label : String = def.get("name", task_id) if not def.is_empty() else task_id
	SaveManager.remove_task_def(task_id)
	_refresh_task_list()
	ui_panel.show_message("已删除: %s" % label)


func _refresh_task_list():
	ui_panel.update_task_list(
		SaveManager.data.get("task_defs", []),
		SaveManager.data.get("tasks_done_today", [])
	)


# ─── Data change handlers ─────────────────────────────────────────────────────

func _on_data_changed():
	_update_ui_status()
	_refresh_task_list()
	_refresh_stats()


func _refresh_stats():
	if not ui_panel:
		return
	var d = SaveManager.data
	var idx: int = int(d.get("realm_index", 0))
	var threshold_now: int = SaveManager.REALM_THRESHOLDS[idx] if idx < SaveManager.REALM_THRESHOLDS.size() else 0
	var threshold_next: int = (
		SaveManager.REALM_THRESHOLDS[idx + 1]
		if idx + 1 < SaveManager.REALM_THRESHOLDS.size()
		else threshold_now
	)
	ui_panel.update_stats(
		str(d.get("realm", "练气")),
		int(d.get("total_exp", 0)),
		threshold_now,
		threshold_next,
		int(d.get("streak_days", 0)),
		d.get("history_focus", {}),
		d.get("achievements", {}),
		SaveManager.ACHIEVEMENTS,
	)


func _on_achievement_unlocked(_id: String, title: String):
	ui_panel.show_message("成就解锁: %s" % title, 4.5)
	if fx:
		fx.play("·成就· %s" % title, Color(1.0, 0.78, 0.3))
	_refresh_stats()


func _on_realm_changed(new_realm: String):
	ui_panel.show_message("突破成功! 当前境界: %s" % new_realm, 5.0)
	if fx:
		fx.play("恭喜道友突破至 %s" % new_realm)


func _on_tribulation_started(target_realm: String):
	ui_panel.show_message(
		"渡劫之期临! 须以一次完整闭关方可渡 %s 之劫" % target_realm,
		6.0,
	)
	if fx:
		fx.play("渡劫之期临 · %s" % target_realm, Color(0.6, 0.85, 1.0))


func _on_tribulation_failed(stay_realm: String):
	ui_panel.show_message("走火入魔! %s 折修，本阶经验清零" % stay_realm, 6.0)
	if fx:
		fx.play("渡劫失败 · %s" % stay_realm, Color(0.95, 0.35, 0.3))


func _update_ui_status():
	var d = SaveManager.data
	ui_panel.update_status(
		d.get("realm", "练气"),
		d.get("total_exp", 0),
		d.get("body_strength", 0),
		SaveManager.get_exp_to_next_realm()
	)
	_update_status_label_text()


func _update_status_label_text():
	var d = SaveManager.data
	var state = state_machine.get_state_name() if state_machine else "IDLE"
	status_label.text = "%s [%s]" % [d.get("realm", "练气"), state]
