extends Control

signal start_new
signal continue_game
signal quit_requested

const UI = preload("res://scripts/ui/ui_factory.gd")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/v9/ui/title_bg.png"):
		bg.texture = load("res://assets/v9/ui/title_bg.png")
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(bg)

	var shade := ColorRect.new()
	shade.color = Color(0.005,0.003,0.006,0.38)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.29
	panel.anchor_top = 0.10
	panel.anchor_right = 0.71
	panel.anchor_bottom = 0.90
	panel.add_theme_stylebox_override("panel",UI.panel_style(0.96))
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",46)
	margin.add_theme_constant_override("margin_right",46)
	margin.add_theme_constant_override("margin_top",42)
	margin.add_theme_constant_override("margin_bottom",38)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation",15)
	margin.add_child(box)

	var title := UI.title_label("THE FORSAKEN DEPTHS",46)
	box.add_child(title)

	var chapter := UI.heading_label("THE BELL BELOW",18)
	chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(chapter)
	UI.add_divider(box)

	var flavor := UI.body_label("Descend beneath the abandoned city. Hunger, fear and the Bell wait below.",15)
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.custom_minimum_size = Vector2(0,58)
	box.add_child(flavor)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0,18)
	box.add_child(spacer)

	var new_button := Button.new()
	new_button.text = "NEW DESCENT"
	new_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(new_button)
	new_button.pressed.connect(func(): AudioManager.play_ui(); start_new.emit())
	box.add_child(new_button)

	var continue_button := Button.new()
	continue_button.text = "CONTINUE"
	continue_button.disabled = not GameState.has_save()
	continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(continue_button)
	continue_button.pressed.connect(func(): AudioManager.play_ui(); continue_game.emit())
	box.add_child(continue_button)

	var quit_button := Button.new()
	quit_button.text = "LEAVE THE DEPTHS"
	quit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(quit_button)
	quit_button.pressed.connect(func(): AudioManager.play_ui(); quit_requested.emit())
	box.add_child(quit_button)

	var spacer2 := Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer2)

	UI.add_divider(box)
	var hint := UI.body_label("WASD / ARROWS  MOVE   •   E  INTERACT   •   I  INVENTORY   •   F11  FULLSCREEN",13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color",Color(0.52,0.48,0.46))
	box.add_child(hint)
