extends Node2D

func _ready() -> void:
	add_to_group("interactable")
	var sprite := Sprite2D.new()
	if ResourceLoader.exists("res://assets/shrine.svg"):
		sprite.texture = load("res://assets/shrine.svg")
	sprite.scale = Vector2(0.80,0.80)
	sprite.position = Vector2(0,-18)
	add_child(sprite)

func interact(player) -> void:
	GameState.last_safe_position = player.global_position
	GameState.player_position = player.global_position
	GameState.body = min(100.0, GameState.body + 20.0)
	GameState.mind = min(100.0, GameState.mind + 18.0)
	GameState.stats_changed.emit()
	GameState.save_game()
	AudioManager.play_sfx("res://assets/audio/shrine.wav")
