extends Node2D

@export var pickup_name := "Ration"
@export_enum("item","key","weapon","armor") var pickup_type := "item"
@export var amount := 1

var taken := false

func _ready() -> void:
	var flag := "pickup_" + pickup_name.replace(" ", "_")
	if bool(GameState.flags.get(flag, false)):
		queue_free()
		return
	add_to_group("interactable")
	queue_redraw()

func interact(_player) -> void:
	if taken:
		return
	taken = true
	match pickup_type:
		"key":
			GameState.add_key_item(pickup_name)
		"weapon":
			GameState.add_weapon(pickup_name)
		"armor":
			GameState.add_armor(pickup_name)
		_:
			GameState.add_consumable(pickup_name, amount)
	GameState.flags["pickup_" + pickup_name.replace(" ", "_")] = true
	AudioManager.play_sfx("res://assets/audio/pickup.wav")
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 16, Color(0.08,0.06,0.05,0.95))
	draw_arc(Vector2.ZERO, 16, 0, TAU, 24, Color(0.78,0.61,0.27), 2.0)
	draw_circle(Vector2.ZERO, 5, Color(0.88,0.70,0.34))
