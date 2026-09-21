extends CanvasLayer

const UI = preload("res://scripts/ui/ui_factory.gd")

var root: Control
var stats_label: Label
var objective_label: Label
var area_label: Label
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
	GameState.inventory_changed.connect(refresh)
	refresh()

func _process(delta: float) -> void:
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0:
			message_panel.visible = false

func _make_bar(name_text: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	var name := UI.heading_label(name_text,13)
	name.custom_minimum_size = Vector2(72,20)
	row.add_child(name)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(245,17)
	bar.max_value = 100.0
	UI.style_progress(bar,color)
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

	var area_panel := PanelContainer.new()
	area_panel.anchor_left = 0.35
	area_panel.anchor_right = 0.65
	area_panel.offset_top = 18
	area_panel.offset_bottom = 72
	area_panel.add_theme_stylebox_override("panel",UI.panel_style(0.86))
	root.add_child(area_panel)
	area_label = UI.title_label("OLD PRISON",20)
	area_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	area_panel.add_child(area_label)

	var stats_panel := PanelContainer.new()
	stats_panel.offset_left = 18
	stats_panel.offset_top = 18
	stats_panel.offset_right = 420
	stats_panel.offset_bottom = 230
	stats_panel.add_theme_stylebox_override("panel",UI.panel_style(0.93))
	root.add_child(stats_panel)

	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation",6)
	stats_panel.add_child(stats_box)
	var heading := UI.title_label("SURVIVAL",20)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stats_box.add_child(heading)
	UI.add_divider(stats_box)
	stats_label = UI.body_label("",13)
	stats_label.add_theme_color_override("font_color",Color(0.82,0.69,0.50))
	stats_box.add_child(stats_label)
	stats_box.add_child(_make_bar("BODY",Color(0.66,0.08,0.10)))
	stats_box.add_child(_make_bar("MIND",Color(0.27,0.36,0.68)))
	stats_box.add_child(_make_bar("HUNGER",Color(0.62,0.43,0.13)))
	stats_box.add_child(_make_bar("TORCH",Color(0.86,0.46,0.10)))

	var objective_panel := PanelContainer.new()
	objective_panel.anchor_left = 1.0
	objective_panel.anchor_right = 1.0
	objective_panel.offset_left = -515
	objective_panel.offset_right = -18
	objective_panel.offset_top = 18
	objective_panel.offset_bottom = 188
	objective_panel.add_theme_stylebox_override("panel",UI.panel_style(0.93))
	root.add_child(objective_panel)

	var objective_box := VBoxContainer.new()
	objective_box.add_theme_constant_override("separation",5)
	objective_panel.add_child(objective_box)
	var objective_heading := UI.title_label("CURRENT OBJECTIVE",18)
	objective_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	objective_box.add_child(objective_heading)
	UI.add_divider(objective_box)
	objective_label = UI.body_label("",15)
	objective_label.custom_minimum_size = Vector2(440,64)
	objective_label.clip_text = true
	objective_box.add_child(objective_label)
	var controls := UI.body_label("E  INTERACT     I  INVENTORY     F11  FULLSCREEN",12)
	controls.add_theme_color_override("font_color",Color(0.48,0.45,0.44))
	objective_box.add_child(controls)

	message_panel = PanelContainer.new()
	message_panel.anchor_left = 0.19
	message_panel.anchor_top = 1.0
	message_panel.anchor_right = 0.81
	message_panel.anchor_bottom = 1.0
	message_panel.offset_top = -108
	message_panel.offset_bottom = -22
	message_panel.add_theme_stylebox_override("panel",UI.panel_style(0.97))
	message_panel.visible = false
	root.add_child(message_panel)
	message_label = UI.body_label("",16)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_panel.add_child(message_label)

func refresh() -> void:
	if not stats_label:
		return
	stats_label.text = "%s  •  ATK %d     %s  •  DEF %d     COINS %d" % [
		GameState.equipped_weapon,GameState.attack_power(),
		GameState.equipped_armor,GameState.armor_defense(),
		GameState.coins
	]
	body_bar.value = GameState.body
	mind_bar.value = GameState.mind
	hunger_bar.value = GameState.hunger
	torch_bar.value = GameState.torch

func set_objective(text: String) -> void:
	if objective_label:
		objective_label.text = text

func set_area(text: String) -> void:
	if area_label and area_label.text != text:
		area_label.text = text

func show_message(text: String, duration: float = 3.0) -> void:
	if not message_label:
		return
	message_label.text = text
	message_panel.visible = true
	message_timer = duration
