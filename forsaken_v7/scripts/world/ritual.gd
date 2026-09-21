extends Node2D

func _ready() -> void:
	add_to_group("interactable")
	var sprite := Sprite2D.new()
	if ResourceLoader.exists("res://assets/ritual.svg"):
		sprite.texture = load("res://assets/ritual.svg")
	sprite.scale = Vector2(1.05,1.05)
	sprite.position = Vector2(0,-4)
	add_child(sprite)

func interact(_player) -> void:
	if bool(GameState.flags.get("ritual_done", false)):
		GameState.message_requested.emit("The ritual marks have gone cold.")
		return
	GameState.flags["ritual_done"] = true
	GameState.lose_mind(8.0)
	GameState.message_requested.emit("You break the bell-seal. Something enormous wakes beyond the chamber.")
	AudioManager.play_sfx("res://assets/audio/ritual.wav")
