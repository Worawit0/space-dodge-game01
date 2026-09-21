extends Node2D

@export var pickup_name := "Ration"
@export_enum("item","key","weapon","armor") var pickup_type := "item"
@export var amount := 1

var taken := false
var has_art := false

func _ready() -> void:
	var flag := "pickup_" + pickup_name.replace(" ", "_")
	if bool(GameState.flags.get(flag, false)):
		queue_free()
		return
	add_to_group("interactable")
	_build_visual()
	queue_redraw()

func _slug() -> String:
	return pickup_name.to_lower().replace(" ","_").replace("-","_")

func _build_visual() -> void:
	var path := "res://assets/v8/items/" + _slug() + ".png"
	if not ResourceLoader.exists(path):
		return
	var sp := Sprite2D.new()
	sp.texture = load(path)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.scale = Vector2(2.0,2.0)
	sp.position = Vector2(0,-12)
	add_child(sp)
	has_art = true

	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([Vector2(-13,4),Vector2(13,4),Vector2(9,9),Vector2(-9,9)])
	shadow.color = Color(0,0,0,0.35)
	shadow.z_index = -1
	add_child(shadow)

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
	AudioManager.play_event("pickup")
	queue_free()

func _draw() -> void:
	if has_art:
		return
	draw_circle(Vector2.ZERO,16,Color(0.08,0.06,0.05,0.95))
	draw_arc(Vector2.ZERO,16,0,TAU,24,Color(0.78,0.61,0.27),2.0)
	draw_circle(Vector2.ZERO,5,Color(0.88,0.70,0.34))
