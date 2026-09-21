extends CharacterBody2D

signal inventory_requested
signal attack_requested

@export var speed := 155.0

var can_move := true
var sprite: AnimatedSprite2D
var step_accum := 0.0
var facing := "down"

func _ready() -> void:
	_build_visuals()

func _load_sequence(anim_name: String, prefix: String, fps: float, looped: bool = true) -> void:
	sprite.sprite_frames.add_animation(anim_name)
	sprite.sprite_frames.set_animation_speed(anim_name, fps)
	sprite.sprite_frames.set_animation_loop(anim_name, looped)
	for i in range(32):
		var path := "%s_%02d.png" % [prefix, i]
		if not ResourceLoader.exists(path):
			break
		var tex = load(path)
		if tex:
			sprite.sprite_frames.add_frame(anim_name, tex)

func _build_visuals() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = SpriteFrames.new()
	for d in ["down","up","left","right"]:
		_load_sequence("idle_" + d, "res://assets/v8/player/idle_" + d, 5.0, true)
		_load_sequence("walk_" + d, "res://assets/v8/player/walk_" + d, 8.0, true)
	if sprite.sprite_frames.get_frame_count("idle_down") == 0 and ResourceLoader.exists("res://assets/player.svg"):
		sprite.sprite_frames.add_frame("idle_down", load("res://assets/player.svg"))
	sprite.animation = "idle_down"
	sprite.position = Vector2(0,-18)
	sprite.scale = Vector2(2.0,2.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([Vector2(-15,8),Vector2(15,8),Vector2(10,14),Vector2(-10,14)])
	shadow.color = Color(0,0,0,0.35)
	shadow.z_index = -1
	add_child(shadow)

	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 11
	capsule.height = 30
	shape.shape = capsule
	shape.position = Vector2(0,3)
	add_child(shape)

	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = 2400
	cam.limit_bottom = 1200
	cam.enabled = true
	add_child(cam)

func _set_animation(dir: Vector2) -> void:
	if dir.length() > 0.1:
		if abs(dir.x) > abs(dir.y):
			facing = "right" if dir.x > 0 else "left"
		else:
			facing = "down" if dir.y > 0 else "up"
		var walk_name := "walk_" + facing
		if sprite.sprite_frames.has_animation(walk_name) and sprite.sprite_frames.get_frame_count(walk_name) > 0:
			if sprite.animation != walk_name:
				sprite.play(walk_name)
	else:
		var idle_name := "idle_" + facing
		if sprite.sprite_frames.has_animation(idle_name) and sprite.sprite_frames.get_frame_count(idle_name) > 0:
			if sprite.animation != idle_name:
				sprite.play(idle_name)

func _physics_process(delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
		_set_animation(Vector2.ZERO)
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.y += 1
	dir = dir.normalized()
	velocity = dir * speed
	move_and_slide()
	_set_animation(dir)
	if dir.length() > 0.1:
		step_accum += delta
		if step_accum >= 0.34:
			step_accum = 0.0
			AudioManager.play_event("footstep")

func _unhandled_input(event: InputEvent) -> void:
	if not can_move or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_E:
			_interact()
		KEY_I:
			inventory_requested.emit()
		KEY_SPACE:
			attack_requested.emit()
		KEY_F11:
			var mode := DisplayServer.window_get_mode()
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if mode != DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_WINDOWED)

func _interact() -> void:
	var nearest: Node2D = null
	var nearest_dist := 82.0
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is Node2D and node.has_method("interact"):
			var d := global_position.distance_to(node.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = node
	if nearest:
		nearest.interact(self)
	else:
		GameState.message_requested.emit("Nothing nearby can be interacted with.")
