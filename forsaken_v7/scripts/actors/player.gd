extends CharacterBody2D

signal inventory_requested
signal attack_requested

@export var speed := 155.0
var can_move := true
var sprite: Sprite2D
var step_accum := 0.0

func _ready() -> void:
	_build_visuals()

func _build_visuals() -> void:
	sprite = Sprite2D.new()
	if ResourceLoader.exists("res://assets/player.svg"):
		sprite.texture = load("res://assets/player.svg")
	sprite.scale = Vector2(0.72,0.72)
	sprite.position = Vector2(0,-10)
	add_child(sprite)

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

func _physics_process(delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.y += 1
	dir = dir.normalized()
	velocity = dir * speed
	move_and_slide()
	if sprite and abs(dir.x) > 0.01:
		sprite.flip_h = dir.x < 0
	if dir.length() > 0.1:
		step_accum += delta
		sprite.position.y = -10.0 + sin(step_accum * 12.0) * 1.5
		if step_accum > 0.42:
			step_accum = 0.0
			AudioManager.play_sfx("res://assets/audio/step.wav")
	else:
		sprite.position.y = -10

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
	var nearest_dist := 78.0
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
