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
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/v9/ui/game_over_bg.png"):
		bg.texture = load("res://assets/v9/ui/game_over_bg.png")
	add_child(bg)

	var shade := ColorRect.new()
	shade.color = Color(0.07,0.0,0.008,0.50)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.27
	panel.anchor_top = 0.15
	panel.anchor_right = 0.73
	panel.anchor_bottom = 0.86
	panel.add_theme_stylebox_override("panel",UI.red_panel_style(0.98))
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",48)
	margin.add_theme_constant_override("margin_right",48)
	margin.add_theme_constant_override("margin_top",40)
	margin.add_theme_constant_override("margin_bottom",38)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation",18)
	margin.add_child(box)

	var title := UI.title_label("YOU DIED",56)
	title.add_theme_color_override("font_color",Color(0.74,0.12,0.12))
	box.add_child(title)

	var subtitle := UI.heading_label("THE DEPTHS REMEMBER",16)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	UI.add_divider(box)

	reason_label = UI.body_label(reason_text,18)
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.custom_minimum_size = Vector2(0,100)
	reason_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(reason_label)

	var retry := Button.new()
	retry.text = "RETRY LAST SHRINE"
	retry.disabled = not GameState.has_save()
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(retry)
	retry.pressed.connect(func(): AudioManager.play_ui(); retry_last_save.emit())
	box.add_child(retry)

	var fresh := Button.new()
	fresh.text = "BEGIN A NEW DESCENT"
	fresh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(fresh)
	fresh.pressed.connect(func(): AudioManager.play_ui(); new_descent.emit())
	box.add_child(fresh)

	var menu := Button.new()
	menu.text = "RETURN TO MAIN MENU"
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(menu,true)
	menu.pressed.connect(func(): AudioManager.play_ui(); main_menu.emit())
	box.add_child(menu)
