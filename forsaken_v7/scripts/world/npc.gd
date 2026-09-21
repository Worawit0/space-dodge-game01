extends Node2D

@export var npc_name := "Maren"
@export_multiline var first_text := "You should not have come this deep."
@export_multiline var repeat_text := "The bell is below the old temple. Do not ring it."
@export var flag_name := "met_maren"

func _ready() -> void:
	add_to_group("interactable")
	var sprite := Sprite2D.new()
	if ResourceLoader.exists("res://assets/maren.svg"):
		sprite.texture = load("res://assets/maren.svg")
	sprite.scale = Vector2(0.72,0.72)
	sprite.position = Vector2(0,-10)
	add_child(sprite)

func interact(_player) -> void:
	if not bool(GameState.flags.get(flag_name, false)):
		GameState.flags[flag_name] = true
		GameState.add_consumable("Bandage", 1)
		GameState.message_requested.emit(npc_name + ": " + first_text)
	else:
		GameState.message_requested.emit(npc_name + ": " + repeat_text)
