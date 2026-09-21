extends Control

signal retry_last_save
signal new_descent
signal main_menu

const UI = preload("res://scripts/ui/ui_factory.gd")
var reason_text := "The depths claimed you."
var reason_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func setup(reason: String) -> void:
	reason_text = reason
	if reason_label:
		reason_label.text = reason_text

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.018,0.002,0.004,1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.25
	panel.anchor_top = 0.18
	panel.anchor_right = 0.75
	panel.anchor_bottom = 0.82
	panel.add_theme_stylebox_override("panel", UI.panel_style(0.98))
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 46)
	margin.add_theme_constant_override("margin_right", 46)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	margin.add_child(box)

	var title := UI.title_label("YOU DIED", 54)
	title.add_theme_color_override("font_color", Color(0.77,0.10,0.10))
	box.add_child(title)

	reason_label = UI.body_label(reason_text, 21)
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.custom_minimum_size = Vector2(0, 90)
	box.add_child(reason_label)

	var retry := Button.new()
	retry.text = "RETRY LAST SHRINE"
	retry.disabled = not GameState.has_save()
	UI.style_button(retry)
	retry.pressed.connect(func(): AudioManager.play_ui(); retry_last_save.emit())
	box.add_child(retry)

	var fresh := Button.new()
	fresh.text = "NEW DESCENT"
	UI.style_button(fresh)
	fresh.pressed.connect(func(): AudioManager.play_ui(); new_descent.emit())
	box.add_child(fresh)

	var menu := Button.new()
	menu.text = "MAIN MENU"
	UI.style_button(menu)
	menu.pressed.connect(func(): AudioManager.play_ui(); main_menu.emit())
	box.add_child(menu)
