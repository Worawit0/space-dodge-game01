extends Node2D

var sprite: Sprite2D

func _ready() -> void:
	add_to_group("interactable")
	sprite = Sprite2D.new()
	if ResourceLoader.exists("res://assets/v8/props/ritual_circle.png"):
		sprite.texture = load("res://assets/v8/props/ritual_circle.png")
	elif ResourceLoader.exists("res://assets/ritual.svg"):
		sprite.texture = load("res://assets/ritual.svg")
	sprite.scale = Vector2(1.15,1.15)
	sprite.position = Vector2(0,0)
	sprite.modulate = Color(0.92,0.55,0.55,1.0)
	add_child(sprite)

	if ResourceLoader.exists("res://assets/v8/fx/light.png"):
		var light := PointLight2D.new()
		light.texture = load("res://assets/v8/fx/light.png")
		light.texture_scale = 2.1
		light.energy = 0.8
		light.color = Color(0.95,0.12,0.08)
		light.position = Vector2(0,-5)
		add_child(light)

func _process(_delta: float) -> void:
	if sprite:
		sprite.rotation += 0.0008
		sprite.modulate.a = 0.82 + sin(Time.get_ticks_msec() * 0.004) * 0.12

func interact(_player) -> void:
	if bool(GameState.flags.get("ritual_done", false)):
		GameState.message_requested.emit("The ritual marks have gone cold.")
		return
	GameState.flags["ritual_done"] = true
	GameState.lose_mind(8.0)
	GameState.message_requested.emit("You break the bell-seal. The Heart Gate answers from the east.")
	AudioManager.play_event("ritual")
