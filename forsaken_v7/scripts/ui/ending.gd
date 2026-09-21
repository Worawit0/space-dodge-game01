extends Control

signal main_menu

const UI = preload("res://scripts/ui/ui_factory.gd")

var title_label: Label
var text_label: Label
var pending_title := "ENDING"
var pending_text := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func setup(title: String, text: String) -> void:
	pending_title = title
	pending_text = text
	if title_label:
		title_label.text = pending_title
	if text_label:
		text_label.text = pending_text

func _build() -> void:
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/v9/ui/title_bg.png"):
		bg.texture = load("res://assets/v9/ui/title_bg.png")
	add_child(bg)

	var shade := ColorRect.new()
	shade.color = Color(0.005,0.008,0.012,0.68)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.18
	panel.anchor_top = 0.12
	panel.anchor_right = 0.82
	panel.anchor_bottom = 0.88
	panel.add_theme_stylebox_override("panel",UI.panel_style(0.97))
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",54)
	margin.add_theme_constant_override("margin_right",54)
	margin.add_theme_constant_override("margin_top",44)
	margin.add_theme_constant_override("margin_bottom",42)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation",20)
	margin.add_child(box)

	title_label = UI.title_label(pending_title,40)
	box.add_child(title_label)
	UI.add_divider(box)

	text_label = UI.body_label(pending_text,18)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.custom_minimum_size = Vector2(0,250)
	box.add_child(text_label)

	var b := Button.new()
	b.text = "RETURN TO MAIN MENU"
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(b)
	b.pressed.connect(func(): AudioManager.play_ui(); main_menu.emit())
	box.add_child(b)
