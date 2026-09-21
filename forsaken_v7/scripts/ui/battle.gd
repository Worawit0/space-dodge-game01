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
var battle_sprite: AnimatedSprite2D
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
	if enemy.has_method("get_battle_frames"):
		battle_sprite.sprite_frames = enemy.get_battle_frames()
		battle_sprite.scale = enemy.get_battle_scale()
		if battle_sprite.sprite_frames.has_animation("idle"):
			battle_sprite.play("idle")
	battle_sprite.visible = true
	root.visible = true
	attack_button.disabled = false
	_update_player()
	AudioManager.play_event("monster")

func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)

	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/v8/ui/battle_bg.png"):
		bg.texture = load("res://assets/v8/ui/battle_bg.png")
	root.add_child(bg)

	var dim := ColorRect.new()
	dim.color = Color(0.015,0.004,0.008,0.60)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var title_panel := PanelContainer.new()
	title_panel.anchor_left = 0.27
	title_panel.anchor_top = 0.035
	title_panel.anchor_right = 0.73
	title_panel.anchor_bottom = 0.18
	title_panel.add_theme_stylebox_override("panel", UI.panel_style(0.92))
	root.add_child(title_panel)
	var title_box := VBoxContainer.new()
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_panel.add_child(title_box)
	enemy_name_label = UI.title_label("ENEMY", 30)
	title_box.add_child(enemy_name_label)
	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.custom_minimum_size = Vector2(440, 18)
	enemy_hp_bar.show_percentage = false
	var hpbg := StyleBoxFlat.new()
	hpbg.bg_color = Color(0.025,0.018,0.022,0.95)
	var hpfill := StyleBoxFlat.new()
	hpfill.bg_color = Color(0.58,0.055,0.07,1.0)
	enemy_hp_bar.add_theme_stylebox_override("background", hpbg)
	enemy_hp_bar.add_theme_stylebox_override("fill", hpfill)
	title_box.add_child(enemy_hp_bar)

	battle_sprite = AnimatedSprite2D.new()
	battle_sprite.name = "EnemyBattleSprite"
	battle_sprite.position = Vector2(640,315)
	battle_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	battle_sprite.animation_finished.connect(_on_battle_animation_finished)
	root.add_child(battle_sprite)

	var command_panel := PanelContainer.new()
	command_panel.anchor_left = 0.06
	command_panel.anchor_top = 0.60
	command_panel.anchor_right = 0.94
	command_panel.anchor_bottom = 0.95
	command_panel.add_theme_stylebox_override("panel", UI.panel_style(0.98))
	root.add_child(command_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	command_panel.add_child(row)

	var commands := VBoxContainer.new()
	commands.custom_minimum_size = Vector2(285,0)
	commands.add_theme_constant_override("separation", 8)
	row.add_child(commands)

	var target_heading := UI.body_label("TARGET", 15)
	target_heading.add_theme_color_override("font_color", Color(0.78,0.65,0.48))
	commands.add_child(target_heading)
	target_select = OptionButton.new()
	for part in ["Torso", "Head", "Arm", "Leg"]:
		target_select.add_item(part)
	target_select.custom_minimum_size = Vector2(250,42)
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
	info.add_theme_constant_override("separation", 10)
	row.add_child(info)
	player_status = UI.body_label("", 18)
	info.add_child(player_status)
	log_label = UI.body_label("", 18)
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.custom_minimum_size = Vector2(0,145)
	info.add_child(log_label)

func _update_player() -> void:
	if player_status:
		player_status.text = "BODY %.0f/100   MIND %.0f   HUNGER %.0f\n%s  ATK %d   •   %s  DEF %d" % [
			GameState.body, GameState.mind, GameState.hunger,
			GameState.equipped_weapon, GameState.attack_power(),
			GameState.equipped_armor, GameState.armor_defense()
		]

func _attack() -> void:
	if current_enemy == null or attack_button.disabled:
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
	var roll := rng.randf()
	if roll <= hit_chance:
		var damage: int = maxi(1, int(round((GameState.attack_power() + rng.randi_range(0,3)) * multiplier)))
		enemy_hp = maxi(0, enemy_hp - damage)
		enemy_hp_bar.value = enemy_hp
		log_label.text = "You strike the %s for %d damage." % [target.to_lower(), damage]
		if battle_sprite.sprite_frames.has_animation("hurt") and battle_sprite.sprite_frames.get_frame_count("hurt") > 0:
			battle_sprite.play("hurt")
		if target == "Arm" and not arm_disabled and rng.randf() < 0.45:
			arm_disabled = true
			enemy_attack = maxi(1, enemy_attack - 3)
			log_label.text += "\nIts attacking limb is crippled."
		if target == "Leg" and not leg_disabled and rng.randf() < 0.45:
			leg_disabled = true
			log_label.text += "\nIts movement is crippled."
		AudioManager.play_event("hit")
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
	if battle_sprite.sprite_frames.has_animation("attack") and battle_sprite.sprite_frames.get_frame_count("attack") > 0:
		battle_sprite.play("attack")
	var damage: float = maxf(1.0, float(enemy_attack) * multiplier + rng.randf_range(-1.0,2.0))
	GameState.damage(damage, "The %s ended your descent." % enemy_name_label.text)
	_update_player()
	if GameState.body > 0:
		log_label.text += "\n%s retaliates. BODY %.0f/100." % [enemy_name_label.text, GameState.body]
		AudioManager.play_event("hurt")

func _win() -> void:
	attack_button.disabled = true
	log_label.text = "%s collapses." % enemy_name_label.text
	GameState.coins += 1
	GameState.stats_changed.emit()
	var defeated = current_enemy
	if battle_sprite.sprite_frames.has_animation("death") and battle_sprite.sprite_frames.get_frame_count("death") > 0:
		battle_sprite.play("death")
	var timer := get_tree().create_timer(0.55)
	timer.timeout.connect(_complete_win.bind(defeated))

func _complete_win(defeated) -> void:
	root.visible = false
	if defeated:
		defeated.defeat()
	battle_finished.emit(true, defeated)

func _on_battle_animation_finished() -> void:
	if not root.visible or enemy_hp <= 0:
		return
	if battle_sprite.sprite_frames.has_animation("idle") and battle_sprite.sprite_frames.get_frame_count("idle") > 0:
		battle_sprite.play("idle")
