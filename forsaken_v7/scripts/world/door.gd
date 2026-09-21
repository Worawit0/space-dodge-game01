extends Node2D

@export var door_name := "Iron Gate"
@export var required_key := ""
@export var open_flag := ""
@export var required_flag := ""
@export_enum("prison","temple","heart") var door_style := "prison"

var opening := false
var is_open := false
var collider: CollisionShape2D
var sprite: AnimatedSprite2D

func _ready() -> void:
	add_to_group("interactable")
	_build_visual()
	_build_collision()
	if open_flag != "" and bool(GameState.flags.get(open_flag, false)):
		_force_open()

func _build_visual() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = SpriteFrames.new()
	sprite.sprite_frames.add_animation("opening")
	sprite.sprite_frames.set_animation_speed("opening", 8.0)
	sprite.sprite_frames.set_animation_loop("opening", false)
	for i in range(12):
		var path := "res://assets/v8/gates/%s_%02d.png" % [door_style, i]
		if not ResourceLoader.exists(path):
			break
		var tex = load(path)
		if tex:
			sprite.sprite_frames.add_frame("opening", tex)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(0.9,0.9)
	sprite.position = Vector2(0,-64)
	sprite.animation_finished.connect(_on_animation_finished)
	add_child(sprite)
	if sprite.sprite_frames.get_frame_count("opening") > 0:
		sprite.animation = "opening"
		sprite.frame = 0

func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	add_child(body)
	collider = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(86,150)
	collider.shape = shape
	collider.position = Vector2(0,-8)
	body.add_child(collider)

func _force_open() -> void:
	is_open = true
	opening = false
	if collider:
		collider.set_deferred("disabled", true)
	if sprite and sprite.sprite_frames.get_frame_count("opening") > 0:
		sprite.animation = "opening"
		sprite.frame = sprite.sprite_frames.get_frame_count("opening") - 1

func interact(_player) -> void:
	if is_open or opening:
		GameState.message_requested.emit(door_name + " is open.")
		return
	if required_flag != "" and not bool(GameState.flags.get(required_flag, false)):
		GameState.message_requested.emit(door_name + " is bound by a ritual seal.")
		AudioManager.play_event("locked")
		return
	if required_key != "" and not GameState.has_key_item(required_key):
		GameState.message_requested.emit("%s is sealed. Required: %s" % [door_name, required_key])
		AudioManager.play_event("locked")
		return
	opening = true
	if open_flag != "":
		GameState.flags[open_flag] = true
	GameState.message_requested.emit(door_name + " groans open.")
	AudioManager.play_event("door")
	if sprite and sprite.sprite_frames.get_frame_count("opening") > 0:
		sprite.play("opening")
	else:
		_force_open()

func _process(_delta: float) -> void:
	if opening and sprite and sprite.sprite_frames.get_frame_count("opening") > 0:
		var count := sprite.sprite_frames.get_frame_count("opening")
		if count > 1 and sprite.frame >= int(count * 0.55) and collider and not collider.disabled:
			collider.set_deferred("disabled", true)

func _on_animation_finished() -> void:
	if opening:
		is_open = true
		opening = false
		if collider:
			collider.set_deferred("disabled", true)
