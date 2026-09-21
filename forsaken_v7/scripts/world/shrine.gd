extends Node2D

func _ready() -> void:
	add_to_group("interactable")
	var sprite := Sprite2D.new()
	var path := "res://assets/v8/props/altar.png"
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	elif ResourceLoader.exists("res://assets/shrine.svg"):
		sprite.texture = load("res://assets/shrine.svg")
	sprite.scale = Vector2(0.46,0.46)
	sprite.position = Vector2(0,-20)
	add_child(sprite)

	if ResourceLoader.exists("res://assets/v8/fx/light.png"):
		var light := PointLight2D.new()
		light.texture = load("res://assets/v8/fx/light.png")
		light.texture_scale = 1.7
		light.energy = 0.75
		light.color = Color(0.36,0.52,1.0)
		light.position = Vector2(0,-30)
		add_child(light)

func interact(player) -> void:
	GameState.last_safe_position = player.global_position
	GameState.player_position = player.global_position
	GameState.body = minf(100.0, GameState.body + 20.0)
	GameState.mind = minf(100.0, GameState.mind + 18.0)
	GameState.stats_changed.emit()
	GameState.save_game()
	AudioManager.play_event("shrine")
