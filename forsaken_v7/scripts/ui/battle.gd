extends CanvasLayer

signal battle_finished(victory: bool, enemy)

const UI = preload("res://scripts/ui/ui_factory.gd")

var root: Control
var enemy_name_label: Label
var enemy_hp_bar: ProgressBar
var player_status: Label
var log_label: Label
var target_select: OptionButton
var attack_button: Button
var current_enemy
var enemy_hp := 0
var enemy_max_hp := 0
var enemy_attack := 0
var arm_disabled := false
var leg_disabled := false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_build()

func is_open() -> bool:
	return root != null and root.visible

func begin(enemy) -> void:
	current_enemy = enemy
	var data: Dictionary = enemy.battle_data()
	enemy_max_hp = int(data.get("hp", 30))
	enemy_hp = enemy_max_hp
	enemy_attack = int(data.get("attack", 8))
	arm_disabled = false
	leg_disabled = false
	enemy_name_label.text = str(data.get("name", "Unknown Horror"))
	enemy_hp_bar.max_value = enemy_max_hp
	enemy_hp_bar.value = enemy_hp
	log_label.text = "The creature blocks your path. Choose where to strike."
	root.visible = true
	_update_player()
	AudioManager.play_sfx("res://assets/audio/monster.wav")

func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.015,0.008,0.01,0.93)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var enemy_panel := PanelContainer.new()
	enemy_panel.anchor_left = 0.23
	enemy_panel.anchor_top = 0.08
	enemy_panel.anchor_right = 0.77
	enemy_panel.anchor_bottom = 0.42
	enemy_panel.add_theme_stylebox_override("panel", UI.panel_style(0.98))
	root.add_child(enemy_panel)
	var enemy_box := VBoxContainer.new()
	enemy_box.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_box.add_theme_constant_override("separation", 12)
	enemy_panel.add_child(enemy_box)
	enemy_name_label = UI.title_label("ENEMY", 34)
	enemy_box.add_child(enemy_name_label)
	var silhouette := UI.body_label("◢  ◆  ◣
  ╲╱
  ╱╲", 34)
	silhouette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	silhouette.add_theme_color_override("font_color", Color(0.55,0.12,0.13))
	enemy_box.add_child(silhouette)
	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.custom_minimum_size = Vector2(420, 20)
	enemy_hp_bar.show_percentage = false
	var hpbg := StyleBoxFlat.new(); hpbg.bg_color = Color(0.025,0.02,0.025)
	var hpfill := StyleBoxFlat.new(); hpfill.bg_color = Color(0.55,0.07,0.08)
	enemy_hp_bar.add_theme_stylebox_override("background", hpbg)
	enemy_hp_bar.add_theme_stylebox_override("fill", hpfill)
	enemy_box.add_child(enemy_hp_bar)

	var command_panel := PanelContainer.new()
	command_panel.anchor_left = 0.08
	command_panel.anchor_top = 0.52
	command_panel.anchor_right = 0.92
	command_panel.anchor_bottom = 0.92
	command_panel.add_theme_stylebox_override("panel", UI.panel_style(0.99))
	root.add_child(command_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	command_panel.add_child(row)

	var commands := VBoxContainer.new()
	commands.custom_minimum_size = Vector2(280,0)
	commands.add_theme_constant_override("separation", 10)
	row.add_child(commands)

	target_select = OptionButton.new()
	for part in ["Torso", "Head", "Arm", "Leg"]:
		target_select.add_item(part)
	target_select.custom_minimum_size = Vector2(250,44)
	target_select.add_theme_font_size_override("font_size", 18)
	commands.add_child(target_select)

	attack_button = Button.new()
	attack_button.text = "ATTACK"
	UI.style_button(attack_button)
	attack_button.pressed.connect(_attack)
	commands.add_child(attack_button)

	var guard := Button.new()
	guard.text = "GUARD"
	UI.style_button(guard)
	guard.pressed.connect(_guard)
	commands.add_child(guard)

	var item := Button.new()
	item.text = "USE BANDAGE"
	UI.style_button(item)
	item.pressed.connect(_use_bandage)
	commands.add_child(item)

	var flee := Button.new()
	flee.text = "FLEE"
	UI.style_button(flee)
	flee.pressed.connect(_flee)
	commands.add_child(flee)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 12)
	row.add_child(info)
	player_status = UI.body_label("", 18)
	info.add_child(player_status)
	log_label = UI.body_label("", 19)
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.custom_minimum_size = Vector2(0,150)
	info.add_child(log_label)

func _update_player() -> void:
	if player_status:
		player_status.text = "BODY %.0f/100   MIND %.0f   HUNGER %.0f
%s  ATK %d   •   %s  DEF %d" % [
			GameState.body, GameState.mind, GameState.hunger,
			GameState.equipped_weapon, GameState.attack_power(),
			GameState.equipped_armor, GameState.armor_defense()
		]

func _attack() -> void:
	if current_enemy == null:
		return
	var target := target_select.get_item_text(target_select.selected)
	var hit_chance := 1.0
	var multiplier := 1.0
	match target:
		"Head":
			hit_chance = 0.72
			multiplier = 1.45
		"Arm":
			hit_chance = 0.90
			multiplier = 0.95
		"Leg":
			hit_chance = 0.90
			multiplier = 0.85
		_:
			hit_chance = 1.0
	var roll := rng.randf()
	if roll <= hit_chance:
		var damage: int = maxi(1, int(round((GameState.attack_power() + rng.randi_range(0,3)) * multiplier)))
		enemy_hp = max(0, enemy_hp - damage)
		enemy_hp_bar.value = enemy_hp
		log_label.text = "You strike the %s for %d damage." % [target.to_lower(), damage]
		if target == "Arm" and not arm_disabled and rng.randf() < 0.45:
			arm_disabled = true
			enemy_attack = max(1, enemy_attack - 3)
			log_label.text += "
Its attacking limb is crippled."
		if target == "Leg" and not leg_disabled and rng.randf() < 0.45:
			leg_disabled = true
			log_label.text += "
Its movement is crippled."
		AudioManager.play_sfx("res://assets/audio/hit.wav")
	else:
		log_label.text = "Your attack misses the %s." % target.to_lower()
	if enemy_hp <= 0:
		_win()
		return
	_enemy_turn(1.0)

func _guard() -> void:
	log_label.text = "You brace for the next attack."
	_enemy_turn(0.45)

func _use_bandage() -> void:
	if GameState.use_consumable("Bandage"):
		log_label.text = "You bind your wounds."
		_update_player()
		_enemy_turn(1.0)
	else:
		log_label.text = "No bandages remain."

func _flee() -> void:
	var chance := 0.68 if leg_disabled else 0.52
	if rng.randf() <= chance:
		log_label.text = "You escape the encounter."
		root.visible = false
		battle_finished.emit(false, current_enemy)
	else:
		log_label.text = "Escape failed."
		_enemy_turn(1.0)

func _enemy_turn(multiplier: float) -> void:
	if current_enemy == null:
		return
	var damage: float = maxf(1.0, float(enemy_attack) * multiplier + rng.randf_range(-1.0,2.0))
	GameState.damage(damage, "The %s ended your descent." % enemy_name_label.text)
	_update_player()
	if GameState.body > 0:
		log_label.text += "
%s retaliates. BODY %.0f/100." % [enemy_name_label.text, GameState.body]
		AudioManager.play_sfx("res://assets/audio/hurt.wav")

func _win() -> void:
	log_label.text = "%s collapses." % enemy_name_label.text
	GameState.coins += 1
	GameState.stats_changed.emit()
	var defeated = current_enemy
	root.visible = false
	if defeated:
		defeated.defeat()
	battle_finished.emit(true, defeated)
