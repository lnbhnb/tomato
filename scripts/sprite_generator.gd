extends RefCounted
class_name SpriteGenerator

const SPRITE_SIZE = 96  # Larger canvas for more detail
const CX = 48           # Center X
const CY = 48           # Center Y


static func generate_all_frames() -> SpriteFrames:
	var frames = SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	_add_idle_animation(frames)
	_add_focus_animation(frames)
	_add_sleep_animation(frames)
	return frames


# ═══════════════════════════════════════════════════════════════════════════════
#  IDLE — 呼吸悬浮（6帧，角色微微上下浮动+衣袂飘动）
# ═══════════════════════════════════════════════════════════════════════════════
static func _add_idle_animation(frames: SpriteFrames):
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 8)
	frames.set_animation_loop("idle", true)
	var frame_count = 8
	for i in range(frame_count):
		var t = float(i) / frame_count
		var offset_y = sin(t * TAU) * 2.5
		var sway = sin(t * TAU * 2.0) * 0.8
		var img = _draw_character_standing(offset_y, sway, t)
		frames.add_frame("idle", ImageTexture.create_from_image(img))


# ═══════════════════════════════════════════════════════════════════════════════
#  FOCUS — 打坐吐纳（灵气光环脉冲）
# ═══════════════════════════════════════════════════════════════════════════════
static func _add_focus_animation(frames: SpriteFrames):
	frames.add_animation("focus")
	frames.set_animation_speed("focus", 6)
	frames.set_animation_loop("focus", true)
	var frame_count = 6
	for i in range(frame_count):
		var t = float(i) / frame_count
		var pulse = (sin(t * TAU) + 1.0) * 0.5
		var img = _draw_character_sitting(t)
		_draw_qi_aura(img, pulse)
		_draw_meridian_glow(img, t)
		frames.add_frame("focus", ImageTexture.create_from_image(img))


# ═══════════════════════════════════════════════════════════════════════════════
#  SLEEP — 走火入魔打盹（冒泡+歪头）
# ═══════════════════════════════════════════════════════════════════════════════
static func _add_sleep_animation(frames: SpriteFrames):
	frames.add_animation("sleep")
	frames.set_animation_speed("sleep", 5)
	frames.set_animation_loop("sleep", true)
	var frame_count = 10
	for i in range(frame_count):
		var t = float(i) / frame_count
		var img = _draw_character_sitting(t, true)
		_draw_sleep_effects(img, i, frame_count)
		frames.add_frame("sleep", ImageTexture.create_from_image(img))


# ═══════════════════════════════════════════════════════════════════════════════
#  角色绘制 — 站立形态
# ═══════════════════════════════════════════════════════════════════════════════
static func _draw_character_standing(float_offset_y: float, sway: float, t: float) -> Image:
	var img = Image.create(SPRITE_SIZE, SPRITE_SIZE, false, Image.FORMAT_RGBA8)
	var oy = roundi(float_offset_y)

	# ── 阴影（脚下） ──
	_fill_ellipse(img, CX, 82 + oy, 14, 3, Color(0, 0, 0, 0.15))

	# ── 头发/发髻 ──
	_fill_circle(img, CX, 14 + oy, 5, Color(0.12, 0.08, 0.06))  # 发髻顶
	_draw_rect(img, CX - 1, 19 + oy, CX + 1, 23 + oy, Color(0.14, 0.1, 0.07))  # 发簪

	# ── 头部 ──
	_fill_circle(img, CX, 28 + oy, 11, Color(1.0, 0.88, 0.74))
	# 脸颊红晕
	_fill_circle(img, CX - 7, 31 + oy, 2, Color(1.0, 0.72, 0.65, 0.4))
	_fill_circle(img, CX + 7, 31 + oy, 2, Color(1.0, 0.72, 0.65, 0.4))

	# ── 头发（刘海） ──
	_draw_rect(img, CX - 10, 18 + oy, CX + 10, 22 + oy, Color(0.14, 0.1, 0.07))
	_fill_circle(img, CX - 8, 22 + oy, 3, Color(0.14, 0.1, 0.07))
	_fill_circle(img, CX + 8, 22 + oy, 3, Color(0.14, 0.1, 0.07))

	# ── 眼睛 ──
	_draw_rect(img, CX - 5, 27 + oy, CX - 3, 30 + oy, Color(0.1, 0.06, 0.04))
	_draw_rect(img, CX + 3, 27 + oy, CX + 5, 30 + oy, Color(0.1, 0.06, 0.04))
	# 瞳孔高光
	img.set_pixel(CX - 4, 27 + oy, Color(1, 1, 1, 0.8))
	img.set_pixel(CX + 4, 27 + oy, Color(1, 1, 1, 0.8))

	# ── 嘴巴 ──
	_draw_rect(img, CX - 1, 33 + oy, CX + 1, 34 + oy, Color(0.85, 0.5, 0.45))

	# ── 道袍身体 ──
	var robe_color = Color(0.22, 0.36, 0.68)
	var robe_dark = Color(0.16, 0.28, 0.55)
	var robe_light = Color(0.32, 0.48, 0.78)
	# 主体
	_draw_rect(img, CX - 12, 40 + oy, CX + 12, 68 + oy, robe_color)
	# 衣领 V 字
	_draw_line_thick(img, CX - 4, 40 + oy, CX, 50 + oy, Color(0.9, 0.88, 0.82), 2)
	_draw_line_thick(img, CX + 4, 40 + oy, CX, 50 + oy, Color(0.9, 0.88, 0.82), 2)
	# 衣服阴影
	_draw_rect(img, CX - 12, 40 + oy, CX - 8, 68 + oy, robe_dark)
	_draw_rect(img, CX + 8, 40 + oy, CX + 12, 68 + oy, robe_dark)

	# ── 腰带（金色） ──
	var belt_color = Color(0.85, 0.7, 0.2)
	_draw_rect(img, CX - 13, 52 + oy, CX + 13, 55 + oy, belt_color)
	# 腰带玉扣
	_fill_circle(img, CX, 53 + oy, 2, Color(0.6, 0.85, 0.65))

	# ── 袖子（飘动） ──
	var sleeve_sway = roundi(sway * 2)
	_draw_rect(img, CX - 18 + sleeve_sway, 42 + oy, CX - 12, 58 + oy, robe_light)
	_draw_rect(img, CX + 12, 42 + oy, CX + 18 - sleeve_sway, 58 + oy, robe_light)

	# ── 腿/脚 ──
	_draw_rect(img, CX - 8, 68 + oy, CX - 2, 76 + oy, robe_dark)
	_draw_rect(img, CX + 2, 68 + oy, CX + 8, 76 + oy, robe_dark)
	# 靴子
	_draw_rect(img, CX - 9, 76 + oy, CX - 1, 80 + oy, Color(0.18, 0.12, 0.08))
	_draw_rect(img, CX + 1, 76 + oy, CX + 9, 80 + oy, Color(0.18, 0.12, 0.08))

	return img


# ═══════════════════════════════════════════════════════════════════════════════
#  角色绘制 — 打坐形态
# ═══════════════════════════════════════════════════════════════════════════════
static func _draw_character_sitting(t: float, sleeping: bool = false) -> Image:
	var img = Image.create(SPRITE_SIZE, SPRITE_SIZE, false, Image.FORMAT_RGBA8)

	# ── 蒲团 ──
	_fill_ellipse(img, CX, 78, 18, 5, Color(0.55, 0.35, 0.18))
	_fill_ellipse(img, CX, 77, 16, 4, Color(0.7, 0.48, 0.22))

	# ── 发髻 ──
	_fill_circle(img, CX, 20, 5, Color(0.12, 0.08, 0.06))
	_draw_rect(img, CX - 1, 25, CX + 1, 28, Color(0.14, 0.1, 0.07))

	# ── 头部（睡觉时微歪） ──
	var head_ox = 0
	if sleeping:
		head_ox = roundi(sin(t * TAU) * 2.0)
	_fill_circle(img, CX + head_ox, 34, 11, Color(1.0, 0.88, 0.74))
	_fill_circle(img, CX - 7 + head_ox, 37, 2, Color(1.0, 0.72, 0.65, 0.4))
	_fill_circle(img, CX + 7 + head_ox, 37, 2, Color(1.0, 0.72, 0.65, 0.4))

	# 头发
	_draw_rect(img, CX - 10 + head_ox, 24, CX + 10 + head_ox, 28, Color(0.14, 0.1, 0.07))
	_fill_circle(img, CX - 8 + head_ox, 28, 3, Color(0.14, 0.1, 0.07))
	_fill_circle(img, CX + 8 + head_ox, 28, 3, Color(0.14, 0.1, 0.07))

	# 眼睛
	if sleeping:
		# 闭眼（横线）
		_draw_rect(img, CX - 5 + head_ox, 33, CX - 3 + head_ox, 33, Color(0.1, 0.06, 0.04))
		_draw_rect(img, CX + 3 + head_ox, 33, CX + 5 + head_ox, 33, Color(0.1, 0.06, 0.04))
	else:
		# 微闭（半睁）
		_draw_rect(img, CX - 5, 33, CX - 3, 35, Color(0.1, 0.06, 0.04))
		_draw_rect(img, CX + 3, 33, CX + 5, 35, Color(0.1, 0.06, 0.04))
		img.set_pixel(CX - 4, 33, Color(1, 1, 1, 0.6))
		img.set_pixel(CX + 4, 33, Color(1, 1, 1, 0.6))

	# 嘴巴
	if sleeping:
		_fill_circle(img, CX + head_ox, 39, 1, Color(0.85, 0.5, 0.45))
	else:
		_draw_rect(img, CX - 1, 39, CX + 1, 40, Color(0.85, 0.5, 0.45))

	# ── 道袍（盘坐） ──
	var robe_color = Color(0.22, 0.36, 0.68)
	var robe_dark = Color(0.16, 0.28, 0.55)
	_draw_rect(img, CX - 14, 46, CX + 14, 72, robe_color)
	_draw_rect(img, CX - 14, 46, CX - 10, 72, robe_dark)
	_draw_rect(img, CX + 10, 46, CX + 14, 72, robe_dark)

	# 衣领
	_draw_line_thick(img, CX - 4, 46, CX, 54, Color(0.9, 0.88, 0.82), 2)
	_draw_line_thick(img, CX + 4, 46, CX, 54, Color(0.9, 0.88, 0.82), 2)

	# 腰带
	_draw_rect(img, CX - 15, 58, CX + 15, 61, Color(0.85, 0.7, 0.2))
	_fill_circle(img, CX, 59, 2, Color(0.6, 0.85, 0.65))

	# 盘腿
	_draw_rect(img, CX - 18, 72, CX + 18, 78, robe_color)

	# 双手结印（放在膝上）
	_fill_circle(img, CX - 4, 66, 3, Color(1.0, 0.88, 0.74))
	_fill_circle(img, CX + 4, 66, 3, Color(1.0, 0.88, 0.74))

	return img


# ═══════════════════════════════════════════════════════════════════════════════
#  特效 — 灵气光环
# ═══════════════════════════════════════════════════════════════════════════════
static func _draw_qi_aura(img: Image, pulse: float):
	var center = Vector2(CX, 55)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var dist = Vector2(x, y).distance_to(center)
			if dist >= 34.0 and dist <= 42.0:
				var existing = img.get_pixel(x, y)
				if existing.a < 0.3:
					var ring_t = 1.0 - (dist - 34.0) / 8.0
					var alpha = ring_t * pulse * 0.35
					img.set_pixel(x, y, Color(0.4, 0.7, 1.0, alpha))
			elif dist >= 28.0 and dist < 34.0:
				var existing = img.get_pixel(x, y)
				if existing.a < 0.2:
					var alpha = pulse * 0.12
					img.set_pixel(x, y, Color(0.6, 0.85, 1.0, alpha))


# ═══════════════════════════════════════════════════════════════════════════════
#  特效 — 经脉流光（打坐时身体上的光点流动）
# ═══════════════════════════════════════════════════════════════════════════════
static func _draw_meridian_glow(img: Image, t: float):
	var points = [
		Vector2(CX, 50), Vector2(CX, 55), Vector2(CX, 60),
		Vector2(CX - 2, 66), Vector2(CX + 2, 66),
	]
	for i in range(points.size()):
		var p = points[i]
		var phase = fmod(t + float(i) * 0.18, 1.0)
		var brightness = sin(phase * PI) * 0.8
		if brightness > 0.2:
			_fill_circle(img, int(p.x), int(p.y), 1, Color(0.5, 0.9, 1.0, brightness))


# ═══════════════════════════════════════════════════════════════════════════════
#  特效 — 睡眠 ZZZ + 鼻涕泡
# ═══════════════════════════════════════════════════════════════════════════════
static func _draw_sleep_effects(img: Image, frame: int, total_frames: int):
	var t = float(frame) / float(total_frames)

	# 鼻涕泡（嘴巴前的小泡泡，逐渐变大再消失）
	var bubble_size = 1.0 + sin(t * PI) * 2.5
	if bubble_size > 1.0:
		_fill_circle(img, CX + 6, 40, int(bubble_size), Color(0.7, 0.85, 1.0, 0.5))
		# 泡泡高光
		img.set_pixel(CX + 5, 39, Color(1, 1, 1, 0.7))

	# ZZZ 浮动文字
	var z_data = [
		{"x": CX + 16, "y": 28, "size": 4, "phase": 0.0},
		{"x": CX + 22, "y": 20, "size": 5, "phase": 0.3},
		{"x": CX + 28, "y": 12, "size": 6, "phase": 0.6},
	]
	for zd in z_data:
		var phase = fmod(t + zd["phase"], 1.0)
		var y_off = -int(phase * 12.0)
		var alpha = max(0.0, 1.0 - phase) * 0.85
		if alpha > 0.05:
			_draw_z_letter(img, zd["x"], zd["y"] + y_off, zd["size"],
				Color(0.55, 0.78, 1.0, alpha))


# ═══════════════════════════════════════════════════════════════════════════════
#  基础绘图工具
# ═══════════════════════════════════════════════════════════════════════════════

static func _fill_circle(img: Image, cx: int, cy: int, r: int, color: Color):
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
				if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
					_blend_pixel(img, x, y, color)


static func _fill_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, color: Color):
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
				var dx = float(x - cx) / float(rx) if rx > 0 else 0
				var dy = float(y - cy) / float(ry) if ry > 0 else 0
				if dx * dx + dy * dy <= 1.0:
					_blend_pixel(img, x, y, color)


static func _draw_rect(img: Image, x1: int, y1: int, x2: int, y2: int, color: Color):
	for y in range(y1, y2 + 1):
		for x in range(x1, x2 + 1):
			if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
				img.set_pixel(x, y, color)


static func _draw_line_thick(img: Image, x1: int, y1: int, x2: int, y2: int, color: Color, thickness: int):
	var steps = maxi(absi(x2 - x1), absi(y2 - y1))
	if steps == 0:
		_fill_circle(img, x1, y1, thickness / 2, color)
		return
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var x = roundi(x1 + (x2 - x1) * t)
		var y = roundi(y1 + (y2 - y1) * t)
		_fill_circle(img, x, y, thickness / 2, color)


static func _draw_z_letter(img: Image, px: int, py: int, size: int, color: Color):
	# Top line
	for x in range(px, px + size):
		if x >= 0 and x < img.get_width() and py >= 0 and py < img.get_height():
			_blend_pixel(img, x, py, color)
	# Diagonal
	for i in range(size):
		var dx = px + size - 1 - i
		var dy = py + i
		if dx >= 0 and dx < img.get_width() and dy >= 0 and dy < img.get_height():
			_blend_pixel(img, dx, dy, color)
	# Bottom line
	for x in range(px, px + size):
		var dy = py + size - 1
		if x >= 0 and x < img.get_width() and dy >= 0 and dy < img.get_height():
			_blend_pixel(img, x, dy, color)


static func _blend_pixel(img: Image, x: int, y: int, color: Color):
	if x < 0 or x >= img.get_width() or y < 0 or y >= img.get_height():
		return
	if color.a >= 0.99:
		img.set_pixel(x, y, color)
	else:
		var existing = img.get_pixel(x, y)
		var out_a = color.a + existing.a * (1.0 - color.a)
		if out_a > 0.001:
			var r = (color.r * color.a + existing.r * existing.a * (1.0 - color.a)) / out_a
			var g = (color.g * color.a + existing.g * existing.a * (1.0 - color.a)) / out_a
			var b = (color.b * color.a + existing.b * existing.a * (1.0 - color.a)) / out_a
			img.set_pixel(x, y, Color(r, g, b, out_a))
