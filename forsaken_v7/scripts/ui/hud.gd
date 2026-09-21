extends CanvasLayer

const UI = preload("res://scripts/ui/ui_factory.gd")

var root: Control
var stats_label: Label
var objective_label: Label
var message_panel: PanelContainer
var message_label: Label
var message_timer := 0.0
var body_bar: ProgressBar
var mind_bar: ProgressBar
var hunger_bar: ProgressBar
var torch_bar: ProgressBar

func _ready() -> void:
	_build()
	GameState.stats_changed.connect(refresh)
	refresh()

func _process(delta: float) -> void:
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0:
			message_panel.visible = false

func _make_bar(name_text: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name := UI.body_label(name_text, 14)
	name.custom_minimum_size = Vector2(62, 18)
	row.add_child(name)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(235, 16)
	bar.max_value = 100.0
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03,0.03,0.035,1)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	match name_text:
		"BODY": body_bar = bar
		"MIND": mind_bar = bar
		"HUNGER": hunger_bar = bar
		"TORCH": torch_bar = bar
	return row

func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var stats_panel := PanelContainer.new()
	stats_panel.offset_left = 20
	stats_panel.offset_top = 20
	stats_panel.offset_right = 390
	stats_panel.offset_bottom = 190
	stats_panel.add_theme_stylebox_override("panel", UI.panel_style(0.88))
	root.add_child(stats_panel)
	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 5)
	stats_panel.add_child(stats_box)
	stats_label = UI.body_label("", 16)
	stats_label.add_theme_color_override("font_color", Color(0.93,0.83,0.65))
	stats_box.add_child(stats_label)
	stats_box.add_child(_make_bar("BODY", Color(0.60,0.10,0.11)))
	stats_box.add_child(_make_bar("MIND", Color(0.28,0.35,0.62)))
	stats_box.add_child(_make_bar("HUNGER", Color(0.60,0.48,0.16)))
	stats_box.add_child(_make_bar("TORCH", Color(0.82,0.46,0.10)))

	var objective_panel := PanelContainer.new()
	objective_panel.anchor_left = 1.0
	objective_panel.anchor_right = 1.0
	objective_panel.offset_left = -500
	objective_panel.offset_right = -20
	objective_panel.offset_top = 20
	objective_panel.offset_bottom = 158
	objective_panel.add_theme_stylebox_override("panel", UI.panel_style(0.88))
	root.add_child(objective_panel)
	var objective_box := VBoxContainer.new()
	objective_box.add_theme_constant_override("separation", 5)
	objective_panel.add_child(objective_box)
	var heading := UI.body_label("OBJECTIVE", 17)
	heading.add_theme_color_override("font_color", Color(0.93,0.80,0.56))
	objective_box.add_child(heading)
	objective_label = UI.body_label("", 16)
	objective_label.custom_minimum_size = Vector2(420, 62)
	objective_label.clip_text = true
	objective_box.add_child(objective_label)
	var controls := UI.body_label("E Interact   I Inventory   F11 Fullscreen", 13)
	controls.add_theme_color_override("font_color", Color(0.52,0.49,0.48))
	objective_box.add_child(controls)

	message_panel = PanelContainer.new()
	message_panel.anchor_left = 0.22
	message_panel.anchor_top = 1.0
	message_panel.anchor_right = 0.78
	message_panel.anchor_bottom = 1.0
	message_panel.offset_top = -92
	message_panel.offset_bottom = -24
	message_panel.add_theme_stylebox_override("panel", UI.panel_style(0.92))
	message_panel.visible = false
	root.add_child(message_panel)
	message_label = UI.body_label("", 17)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_panel.add_child(message_label)

func refresh() -> void:
	if not stats_label:
		return
	stats_label.text = "ATK %d   DEF %d   COINS %d" % [GameState.attack_power(), GameState.armor_defense(), GameState.coins]
	body_bar.value = GameState.body
	mind_bar.value = GameState.mind
	hunger_bar.value = GameState.hunger
	torch_bar.value = GameState.torch

func set_objective(text: String) -> void:
	if objective_label:
		objective_label.text = text

func show_message(text: String, duration: float = 3.0) -> void:
	if not message_label:
		return
	message_label.text = text
	message_panel.visible = true
	message_timer = duration
