extends Node
class_name BreakthroughFX

# 在桌宠窗口内播放：白色闪光 + 金色飘字
# - text: 主文字（如 "恭喜道友突破至 筑基"）
# - color_main: 飘字主色（突破=金色 / 渡劫失败=暗红）
func play(text: String, color_main: Color = Color(1.0, 0.85, 0.2)) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var viewport_size := get_viewport().get_visible_rect().size

	# ── 闪光层 ─────────────────────────────────────────────────
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.size = viewport_size
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)

	var t_flash := create_tween()
	t_flash.tween_property(flash, "color:a", 0.85, 0.25)
	t_flash.tween_property(flash, "color:a", 0.0, 0.4)
	t_flash.tween_callback(flash.queue_free)

	# ── 飘字层 ─────────────────────────────────────────────────
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", color_main)
	lbl.add_theme_color_override("font_outline_color", Color(0.3, 0.15, 0.0, 0.9))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(viewport_size.x, 50)
	lbl.position = Vector2(0, viewport_size.y * 0.42)
	lbl.modulate.a = 0.0
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(lbl)

	var start_y: float = lbl.position.y
	var t_text := create_tween()
	t_text.tween_property(lbl, "modulate:a", 1.0, 0.4)
	t_text.parallel().tween_property(lbl, "position:y", start_y - 60.0, 3.0)
	t_text.tween_property(lbl, "modulate:a", 0.0, 0.6)
	t_text.tween_callback(layer.queue_free)
