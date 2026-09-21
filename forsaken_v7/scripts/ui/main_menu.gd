extends Control

signal start_new
signal continue_game
signal quit_requested

const UI = preload("res://scripts/ui/ui_factory.gd")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.008,0.006,0.009,1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vignette := ColorRect.new()
	vignette.color = Color(0.08,0.015,0.018,0.22)
	vignette.anchor_left = 0.08
	vignette.anchor_top = 0.08
	vignette.anchor_right = 0.92
	vignette.anchor_bottom = 0.92
	bg.add_child(vignette)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.28
	panel.anchor_top = 0.16
	panel.anchor_right = 0.72
	panel.anchor_bottom = 0.84
	panel.add_theme_stylebox_override("panel", UI.panel_style(0.94))
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)

	var title := UI.title_label("THE FORSAKEN DEPTHS", 42)
	box.add_child(title)
	var subtitle := UI.body_label("A dark survival descent", 18)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.62,0.58,0.56))
	box.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 28)
	box.add_child(spacer)

	var new_button := Button.new()
	new_button.text = "NEW DESCENT"
	UI.style_button(new_button)
	new_button.pressed.connect(func(): AudioManager.play_ui(); start_new.emit())
	box.add_child(new_button)

	var continue_button := Button.new()
	continue_button.text = "CONTINUE"
	continue_button.disabled = not GameState.has_save()
	UI.style_button(continue_button)
	continue_button.pressed.connect(func(): AudioManager.play_ui(); continue_game.emit())
	box.add_child(continue_button)

	var quit_button := Button.new()
	quit_button.text = "QUIT"
	UI.style_button(quit_button)
	quit_button.pressed.connect(func(): AudioManager.play_ui(); quit_requested.emit())
	box.add_child(quit_button)

	var hint := UI.body_label("WASD Move   •   E Interact   •   I Inventory", 16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.52,0.49,0.47))
	box.add_child(hint)
