extends RefCounted
class_name ForsakenUI

static func panel_style(alpha: float = 0.96) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.035, 0.028, 0.035, alpha)
	s.border_color = Color(0.48, 0.39, 0.32, 1.0)
	s.set_border_width_all(2)
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s

static func button_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = Color(0.53, 0.42, 0.34, 1)
	s.set_border_width_all(1)
	s.corner_radius_top_left = 3
	s.corner_radius_top_right = 3
	s.corner_radius_bottom_left = 3
	s.corner_radius_bottom_right = 3
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 9
	s.content_margin_bottom = 9
	return s

static func style_button(b: Button) -> void:
	b.custom_minimum_size = Vector2(150, 44)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.92,0.90,0.86))
	b.add_theme_color_override("font_hover_color", Color(1.0,0.91,0.70))
	b.add_theme_stylebox_override("normal", button_style(Color(0.07,0.055,0.065,0.98)))
	b.add_theme_stylebox_override("hover", button_style(Color(0.14,0.085,0.09,1.0)))
	b.add_theme_stylebox_override("pressed", button_style(Color(0.22,0.10,0.09,1.0)))
	b.add_theme_stylebox_override("disabled", button_style(Color(0.035,0.035,0.04,0.8)))

static func title_label(text: String, size: int = 36) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.93,0.84,0.65))
	return l

static func body_label(text: String = "", size: int = 20) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.90,0.88,0.84))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
