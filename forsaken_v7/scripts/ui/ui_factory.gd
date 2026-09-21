extends RefCounted
class_name ForsakenUI

static var _title_font: Font
static var _body_font: Font
static var _bold_font: Font

static func title_font() -> Font:
	if _title_font == null and ResourceLoader.exists("res://assets/v9/fonts/Cinzel-Bold.ttf"):
		_title_font = load("res://assets/v9/fonts/Cinzel-Bold.ttf") as Font
	return _title_font

static func body_font() -> Font:
	if _body_font == null and ResourceLoader.exists("res://assets/v9/fonts/Cinzel-Regular.ttf"):
		_body_font = load("res://assets/v9/fonts/Cinzel-Regular.ttf") as Font
	return _body_font

static func bold_font() -> Font:
	if _bold_font == null and ResourceLoader.exists("res://assets/v9/fonts/Cinzel-Bold.ttf"):
		_bold_font = load("res://assets/v9/fonts/Cinzel-Bold.ttf") as Font
	return _bold_font

static func _texture_style(path: String, margin: float = 18.0) -> StyleBox:
	if ResourceLoader.exists(path):
		var s := StyleBoxTexture.new()
		s.texture = load(path)
		s.set_texture_margin(SIDE_LEFT, margin)
		s.set_texture_margin(SIDE_TOP, margin)
		s.set_texture_margin(SIDE_RIGHT, margin)
		s.set_texture_margin(SIDE_BOTTOM, margin)
		s.content_margin_left = 20
		s.content_margin_right = 20
		s.content_margin_top = 16
		s.content_margin_bottom = 16
		return s
	var f := StyleBoxFlat.new()
	f.bg_color = Color(0.035,0.028,0.035,0.96)
	f.border_color = Color(0.48,0.39,0.32,1.0)
	f.set_border_width_all(2)
	f.content_margin_left = 20
	f.content_margin_right = 20
	f.content_margin_top = 16
	f.content_margin_bottom = 16
	return f

static func panel_style(alpha: float = 0.96) -> StyleBox:
	var s := _texture_style("res://assets/v9/ui/panel.png",22.0)
	if s is StyleBoxTexture:
		s.modulate_color = Color(1,1,1,alpha)
	return s

static func red_panel_style(alpha: float = 0.98) -> StyleBox:
	var s := _texture_style("res://assets/v9/ui/panel_red.png",22.0)
	if s is StyleBoxTexture:
		s.modulate_color = Color(1,1,1,alpha)
	return s

static func slot_style() -> StyleBox:
	return _texture_style("res://assets/v9/ui/slot.png",18.0)

static func style_button(b: Button, compact: bool = false) -> void:
	b.custom_minimum_size = Vector2(126,40 if compact else 50)
	b.add_theme_font_size_override("font_size",16 if compact else 18)
	var f := bold_font()
	if f:
		b.add_theme_font_override("font",f)
	b.add_theme_color_override("font_color",Color(0.93,0.87,0.76))
	b.add_theme_color_override("font_hover_color",Color(1.0,0.82,0.48))
	b.add_theme_color_override("font_pressed_color",Color(1.0,0.72,0.36))
	b.add_theme_color_override("font_disabled_color",Color(0.42,0.39,0.38))
	b.add_theme_stylebox_override("normal",_texture_style("res://assets/v9/ui/button_normal.png",14.0))
	b.add_theme_stylebox_override("hover",_texture_style("res://assets/v9/ui/button_hover.png",14.0))
	b.add_theme_stylebox_override("pressed",_texture_style("res://assets/v9/ui/button_pressed.png",14.0))
	b.add_theme_stylebox_override("disabled",_texture_style("res://assets/v9/ui/button_disabled.png",14.0))
	b.focus_mode = Control.FOCUS_NONE

static func style_item_list(list: ItemList) -> void:
	list.add_theme_font_size_override("font_size",17)
	var f := body_font()
	if f:
		list.add_theme_font_override("font",f)
	list.add_theme_color_override("font_color",Color(0.87,0.83,0.77))
	list.add_theme_color_override("font_selected_color",Color(1.0,0.80,0.43))
	list.add_theme_color_override("guide_color",Color(0.2,0.16,0.15,0.5))
	list.add_theme_stylebox_override("panel",panel_style(0.94))
	var selected := StyleBoxFlat.new()
	selected.bg_color = Color(0.28,0.10,0.10,0.85)
	selected.border_color = Color(0.58,0.39,0.22,1)
	selected.set_border_width_all(1)
	list.add_theme_stylebox_override("selected",selected)
	list.add_theme_stylebox_override("selected_focus",selected)

static func style_progress(bar: ProgressBar, fill_color: Color) -> void:
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.025,0.022,0.027,1)
	bg.border_color = Color(0.30,0.23,0.20,1)
	bg.set_border_width_all(1)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.border_color = fill_color.lightened(0.12)
	fill.set_border_width_all(1)
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background",bg)
	bar.add_theme_stylebox_override("fill",fill)

static func title_label(text: String, size: int = 36) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size",size)
	var f := title_font()
	if f:
		l.add_theme_font_override("font",f)
	l.add_theme_color_override("font_color",Color(0.91,0.77,0.52))
	l.add_theme_color_override("font_shadow_color",Color(0,0,0,0.95))
	l.add_theme_constant_override("shadow_offset_x",3)
	l.add_theme_constant_override("shadow_offset_y",3)
	l.add_theme_color_override("font_outline_color",Color(0.12,0.055,0.05,0.95))
	l.add_theme_constant_override("outline_size",2)
	return l

static func heading_label(text: String, size: int = 18) -> Label:
	var l := body_label(text,size)
	var f := bold_font()
	if f:
		l.add_theme_font_override("font",f)
	l.add_theme_color_override("font_color",Color(0.88,0.69,0.42))
	return l

static func body_label(text: String = "", size: int = 18) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size",size)
	var f := body_font()
	if f:
		l.add_theme_font_override("font",f)
	l.add_theme_color_override("font_color",Color(0.88,0.86,0.82))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l

static func add_divider(parent: Control) -> TextureRect:
	var t := TextureRect.new()
	if ResourceLoader.exists("res://assets/v9/ui/divider.png"):
		t.texture = load("res://assets/v9/ui/divider.png")
	t.custom_minimum_size = Vector2(0,18)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t
