extends Node2D

@export var door_name := "Iron Gate"
@export var required_key := ""
@export var open_flag := ""
@export var width := 64.0
@export var height := 190.0

var open_amount := 0.0
var opening := false
var collider: CollisionShape2D

func _ready() -> void:
	add_to_group("interactable")
	_build_collision()
	if open_flag != "" and bool(GameState.flags.get(open_flag, false)):
		open_amount = 1.0
		opening = true
		collider.disabled = true
	queue_redraw()

func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	add_child(body)
	collider = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width - 12.0, height - 10.0)
	collider.shape = shape
	body.add_child(collider)

func interact(_player) -> void:
	if open_amount >= 0.98:
		GameState.message_requested.emit(door_name + " is already open.")
		return
	if required_key != "" and not GameState.has_key_item(required_key):
		GameState.message_requested.emit("%s is locked. Required: %s" % [door_name, required_key])
		AudioManager.play_sfx("res://assets/audio/locked.wav")
		return
	opening = true
	if open_flag != "":
		GameState.flags[open_flag] = true
	GameState.message_requested.emit(door_name + " opens with a grinding sound.")
	AudioManager.play_sfx("res://assets/audio/door.wav")

func _process(delta: float) -> void:
	if opening and open_amount < 1.0:
		open_amount = min(1.0, open_amount + delta * 0.72)
		if open_amount > 0.66 and collider and not collider.disabled:
			collider.set_deferred("disabled", true)
		queue_redraw()

func _draw() -> void:
	var lift := -height * 0.86 * ease(open_amount, -1.6)
	var frame_color := Color(0.24,0.20,0.18,1)
	var metal := Color(0.35,0.31,0.27,1)
	var glow := Color(0.62,0.16,0.10,0.65)
	draw_rect(Rect2(-width*0.58, -height*0.55, width*1.16, height*1.10), Color(0.035,0.028,0.03,0.96))
	draw_rect(Rect2(-width*0.54, -height*0.53, width*1.08, height*1.06), frame_color, false, 6.0)
	for x in [-width*0.36, -width*0.12, width*0.12, width*0.36]:
		draw_rect(Rect2(x-3, -height*0.47 + lift, 6, height*0.94), metal)
	for y in [-height*0.34, 0.0, height*0.34]:
		draw_rect(Rect2(-width*0.43, y-3 + lift, width*0.86, 6), metal)
	draw_circle(Vector2(0, lift), 8.0, glow)
	if required_key != "" and open_amount < 0.98:
		draw_arc(Vector2(0, lift), 13, 0, TAU, 24, Color(0.84,0.58,0.30,0.8), 2.0)
