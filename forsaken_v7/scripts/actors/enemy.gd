extends CharacterBody2D

signal encounter_requested(enemy)

@export var enemy_name := "Starved Horror"
@export var max_hp := 34
@export var attack := 8
@export var move_speed := 68.0
@export var aggro_range := 280.0
@export var encounter_range := 58.0
@export var is_boss := false
@export var asset_set := "demon_a"
@export var required_flag := ""

var player: CharacterBody2D
var sprite: AnimatedSprite2D
var defeated := false
var encounter_cooldown := 0.0

func _ready() -> void:
	_build_visuals()

func _sequence_prefix(state: String) -> String:
	return "res://assets/v8/enemies/%s/%s" % [asset_set, state]

func _load_sequence(anim_name: String, state: String, fps: float, looped: bool) -> void:
	sprite.sprite_frames.add_animation(anim_name)
	sprite.sprite_frames.set_animation_speed(anim_name, fps)
	sprite.sprite_frames.set_animation_loop(anim_name, looped)
	var prefix := _sequence_prefix(state)
	for i in range(40):
		var path := "%s_%02d.png" % [prefix, i]
		if not ResourceLoader.exists(path):
			break
		var tex = load(path)
		if tex:
			sprite.sprite_frames.add_frame(anim_name, tex)

func _world_scale() -> Vector2:
	match asset_set:
		"demon_a", "blood_monster":
			return Vector2(2.15,2.15)
		"flying_demon":
			return Vector2(2.25,2.25)
		"demon_slime":
			return Vector2(0.98,0.98)
		_:
			return Vector2(1.7,1.7)

func _collision_profile() -> Vector2:
	match asset_set:
		"flying_demon":
			return Vector2(22,52)
		"demon_slime":
			return Vector2(38,82)
		_:
			return Vector2(18,48)

func _build_visuals() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = SpriteFrames.new()
	_load_sequence("idle","idle",5.5,true)
	_load_sequence("walk","walk",8.0,true)
	_load_sequence("attack","attack",10.0,false)
	_load_sequence("hurt","hurt",9.0,false)
	_load_sequence("death","death",8.0,false)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(0,-27 if not is_boss else -46)
	sprite.scale = _world_scale()
	if sprite.sprite_frames.get_frame_count("idle") > 0:
		sprite.play("idle")
	add_child(sprite)

	var shadow := Polygon2D.new()
	var sw := 28.0 if not is_boss else 55.0
	shadow.polygon = PackedVector2Array([Vector2(-sw,10),Vector2(sw,10),Vector2(sw*0.7,20),Vector2(-sw*0.7,20)])
	shadow.color = Color(0,0,0,0.48)
	shadow.z_index = -1
	add_child(shadow)

	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	var profile := _collision_profile()
	capsule.radius = profile.x
	capsule.height = profile.y
	shape.shape = capsule
	shape.position = Vector2(0,5)
	add_child(shape)

func set_player(p: CharacterBody2D) -> void:
	player = p

func _physics_process(delta: float) -> void:
	if required_flag != "" and not bool(GameState.flags.get(required_flag, false)):
		velocity = Vector2.ZERO
		visible = false
		return
	visible = true
	if defeated or player == null:
		velocity = Vector2.ZERO
		return
	encounter_cooldown = maxf(0.0, encounter_cooldown - delta)
	var dist: float = global_position.distance_to(player.global_position)
	if dist <= encounter_range and encounter_cooldown <= 0.0:
		velocity = Vector2.ZERO
		if sprite.sprite_frames.get_frame_count("idle") > 0:
			sprite.play("idle")
		encounter_cooldown = 2.0
		encounter_requested.emit(self)
		return
	if dist <= aggro_range:
		var dir: Vector2 = (player.global_position - global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()
		sprite.flip_h = dir.x < 0
		if sprite.sprite_frames.get_frame_count("walk") > 0 and sprite.animation != "walk":
			sprite.play("walk")
	else:
		velocity = Vector2.ZERO
		if sprite.sprite_frames.get_frame_count("idle") > 0 and sprite.animation != "idle":
			sprite.play("idle")

func battle_data() -> Dictionary:
	return {"name": enemy_name, "hp": max_hp, "attack": attack, "boss": is_boss, "asset_set": asset_set}

func get_battle_frames() -> SpriteFrames:
	return sprite.sprite_frames

func get_battle_scale() -> Vector2:
	match asset_set:
		"demon_a", "blood_monster":
			return Vector2(4.6,4.6)
		"flying_demon":
			return Vector2(4.0,4.0)
		"demon_slime":
			return Vector2(1.55,1.55)
		_:
			return Vector2(3.4,3.4)

func play_world_hurt() -> void:
	if sprite.sprite_frames.get_frame_count("hurt") > 0:
		sprite.play("hurt")

func defeat() -> void:
	defeated = true
	set_physics_process(false)
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
	if sprite.sprite_frames.get_frame_count("death") > 0:
		sprite.play("death")
		await sprite.animation_finished
	visible = false

func retreat_from(p: Node2D) -> void:
	if defeated:
		return
	var dir: Vector2 = (global_position - p.global_position).normalized()
	if dir.length() < 0.1:
		dir = Vector2.RIGHT
	global_position += dir * 145.0
	encounter_cooldown = 2.5
