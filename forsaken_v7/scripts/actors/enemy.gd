extends CharacterBody2D

signal encounter_requested(enemy)

@export var enemy_name := "Starved Horror"
@export var max_hp := 34
@export var attack := 8
@export var move_speed := 68.0
@export var aggro_range := 280.0
@export var encounter_range := 44.0
@export var is_boss := false
@export var texture_path := "res://assets/ghoul.svg"
@export var required_flag := ""

var player: CharacterBody2D
var sprite: Sprite2D
var defeated := false
var encounter_cooldown := 0.0

func _ready() -> void:
	_build_visuals()

func _build_visuals() -> void:
	sprite = Sprite2D.new()
	if ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)
	sprite.scale = Vector2(0.78,0.78) if not is_boss else Vector2(1.28,1.28)
	sprite.position = Vector2(0,-16 if not is_boss else -30)
	add_child(sprite)

	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 13 if not is_boss else 22
	capsule.height = 34 if not is_boss else 58
	shape.shape = capsule
	shape.position = Vector2(0,3)
	add_child(shape)

func set_player(p: CharacterBody2D) -> void:
	player = p

func _physics_process(delta: float) -> void:
	if required_flag != "" and not bool(GameState.flags.get(required_flag, false)):
		velocity = Vector2.ZERO
		return
	if defeated or player == null:
		velocity = Vector2.ZERO
		return
	encounter_cooldown = maxf(0.0, encounter_cooldown - delta)
	var dist: float = global_position.distance_to(player.global_position)
	if dist <= encounter_range and encounter_cooldown <= 0.0:
		velocity = Vector2.ZERO
		encounter_cooldown = 2.0
		encounter_requested.emit(self)
		return
	if dist <= aggro_range:
		var dir: Vector2 = (player.global_position - global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()
		if sprite:
			sprite.flip_h = dir.x < 0
			sprite.rotation = sin(Time.get_ticks_msec() * 0.006) * 0.025
	else:
		velocity = Vector2.ZERO
		if sprite:
			sprite.rotation = 0.0

func battle_data() -> Dictionary:
	return {"name": enemy_name, "hp": max_hp, "attack": attack, "boss": is_boss}

func defeat() -> void:
	defeated = true
	visible = false
	set_physics_process(false)
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)

func retreat_from(p: Node2D) -> void:
	if defeated:
		return
	var dir: Vector2 = (global_position - p.global_position).normalized()
	if dir.length() < 0.1:
		dir = Vector2.RIGHT
	global_position += dir * 120.0
	encounter_cooldown = 2.5
