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
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/v8/ui/title_bg.png"):
		bg.texture = load("res://assets/v8/ui/title_bg.png")
	add_child(bg)

	var shade := ColorRect.new()
	shade.color = Color(0.008,0.003,0.008,0.64)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var blood_glow := ColorRect.new()
	blood_glow.color = Color(0.13,0.015,0.02,0.18)
	blood_glow.anchor_left = 0.06
	blood_glow.anchor_top = 0.07
	blood_glow.anchor_right = 0.94
	blood_glow.anchor_bottom = 0.93
	add_child(blood_glow)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.29
	panel.anchor_top = 0.12
	panel.anchor_right = 0.71
	panel.anchor_bottom = 0.88
	panel.add_theme_stylebox_override("panel", UI.panel_style(0.94))
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 38)
	margin.add_theme_constant_override("margin_bottom", 38)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	var title := UI.title_label("THE FORSAKEN DEPTHS", 44)
	box.add_child(title)
	var subtitle := UI.body_label("THE BELL BELOW", 17)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.67,0.56,0.47))
	box.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 34)
	box.add_child(spacer)

	for spec in [
		["NEW DESCENT", func(): AudioManager.play_ui(); start_new.emit()],
		["CONTINUE", func(): AudioManager.play_ui(); continue_game.emit()],
		["QUIT", func(): AudioManager.play_ui(); quit_requested.emit()]
	]:
		var b := Button.new()
		b.text = str(spec[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI.style_button(b)
		if b.text == "CONTINUE":
			b.disabled = not GameState.has_save()
		b.pressed.connect(spec[1])
		box.add_child(b)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 16)
	box.add_child(spacer2)
	var hint := UI.body_label("WASD MOVE  •  E INTERACT  •  I INVENTORY  •  F11 FULLSCREEN", 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.52,0.48,0.45))
	box.add_child(hint)
