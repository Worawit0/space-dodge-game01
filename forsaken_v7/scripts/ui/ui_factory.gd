extends RefCounted
class_name ForsakenUI

static func _texture_style(path: String, margin: float = 14.0) -> StyleBox:
	if ResourceLoader.exists(path):
		var s := StyleBoxTexture.new()
		s.texture = load(path)
		s.set_texture_margin(SIDE_LEFT, margin)
		s.set_texture_margin(SIDE_TOP, margin)
		s.set_texture_margin(SIDE_RIGHT, margin)
		s.set_texture_margin(SIDE_BOTTOM, margin)
		s.content_margin_left = 18
		s.content_margin_right = 18
		s.content_margin_top = 14
		s.content_margin_bottom = 14
		return s
	var f := StyleBoxFlat.new()
	f.bg_color = Color(0.035,0.028,0.035,0.96)
	f.border_color = Color(0.48,0.39,0.32,1.0)
	f.set_border_width_all(2)
	f.content_margin_left = 18
	f.content_margin_right = 18
	f.content_margin_top = 14
	f.content_margin_bottom = 14
	return f

static func panel_style(alpha: float = 0.96) -> StyleBox:
	var s := _texture_style("res://assets/v8/ui/panel_frame.png", 16.0)
	if s is StyleBoxTexture:
		s.modulate_color = Color(1,1,1,alpha)
	elif s is StyleBoxFlat:
		s.bg_color.a = alpha
	return s

static func style_button(b: Button) -> void:
	b.custom_minimum_size = Vector2(150, 46)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", Color(0.94,0.91,0.84))
	b.add_theme_color_override("font_hover_color", Color(1.0,0.88,0.58))
	b.add_theme_color_override("font_pressed_color", Color(1.0,0.82,0.45))
	b.add_theme_stylebox_override("normal", _texture_style("res://assets/v8/ui/button_normal.png", 10.0))
	b.add_theme_stylebox_override("hover", _texture_style("res://assets/v8/ui/button_hover.png", 10.0))
	b.add_theme_stylebox_override("pressed", _texture_style("res://assets/v8/ui/button_pressed.png", 10.0))
	b.add_theme_stylebox_override("disabled", _texture_style("res://assets/v8/ui/button_disabled.png", 10.0))

static func style_item_list(list: ItemList) -> void:
	list.add_theme_font_size_override("font_size", 18)
	list.add_theme_color_override("font_color", Color(0.90,0.87,0.80))
	list.add_theme_color_override("font_selected_color", Color(1.0,0.86,0.56))
	list.add_theme_stylebox_override("panel", panel_style(0.88))

static func title_label(text: String, size: int = 36) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.93,0.82,0.60))
	l.add_theme_color_override("font_shadow_color", Color(0,0,0,0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l

static func body_label(text: String = "", size: int = 20) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.90,0.88,0.84))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l
