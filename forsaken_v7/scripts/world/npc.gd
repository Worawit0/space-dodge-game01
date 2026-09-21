extends Node2D

@export var npc_name := "Maren"
@export_multiline var first_text := "You should not have come this deep."
@export_multiline var repeat_text := "The bell is below the old temple. Do not ring it."
@export var flag_name := "met_maren"
@export var asset_set := "maren"

func _ready() -> void:
	add_to_group("interactable")
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = SpriteFrames.new()
	sprite.sprite_frames.add_animation("idle")
	sprite.sprite_frames.set_animation_speed("idle",5.0)
	sprite.sprite_frames.set_animation_loop("idle",true)
	for i in range(16):
		var path := "res://assets/v8/npc/%s_%02d.png" % [asset_set,i]
		if not ResourceLoader.exists(path):
			break
		var tex = load(path)
		if tex:
			sprite.sprite_frames.add_frame("idle",tex)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(2.0,2.0)
	sprite.position = Vector2(0,-18)
	if sprite.sprite_frames.get_frame_count("idle") > 0:
		sprite.play("idle")
	elif ResourceLoader.exists("res://assets/maren.svg"):
		sprite.sprite_frames.add_frame("idle",load("res://assets/maren.svg"))
	add_child(sprite)

func interact(_player) -> void:
	if not bool(GameState.flags.get(flag_name, false)):
		GameState.flags[flag_name] = true
		if npc_name == "Maren":
			GameState.add_consumable("Bandage",1)
		GameState.message_requested.emit(npc_name + ": " + first_text)
	else:
		GameState.message_requested.emit(npc_name + ": " + repeat_text)
