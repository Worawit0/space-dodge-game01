extends Node2D

@export_enum("floor","back","foreground") var layer_type := "floor"

func _ready() -> void:
	_build_visuals()
	queue_redraw()

func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _region_sprite(path: String, rect: Rect2, z: int = 0, modulate_color: Color = Color.WHITE) -> Sprite2D:
	var tex := _tex(path)
	if tex == null:
		return null
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.region_enabled = true
	sp.region_rect = Rect2(Vector2.ZERO, rect.size)
	sp.position = rect.position
	sp.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.modulate = modulate_color
	sp.z_index = z
	add_child(sp)
	return sp

func _prop(path: String, pos: Vector2, scale_value: float = 1.0, z: int = 0, alpha: float = 1.0) -> void:
	var tex := _tex(path)
	if tex == null:
		return
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.position = pos
	sp.scale = Vector2(scale_value,scale_value)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.modulate.a = alpha
	sp.z_index = z
	add_child(sp)

func _build_visuals() -> void:
	match layer_type:
		"floor":
			_region_sprite("res://assets/v8/dungeon/floor_tile.png", Rect2(0,0,2400,1200), 0, Color(0.78,0.72,0.69))
			_region_sprite("res://assets/v8/dungeon/floor_detail.png", Rect2(90,90,2220,1020), 1, Color(1,1,1,0.15))
		"back":
			for rect in _wall_rects():
				_region_sprite("res://assets/v8/dungeon/wall_tile.png", rect, 0, Color(0.76,0.69,0.65))
				var cap := Rect2(rect.position, Vector2(rect.size.x, minf(28.0,rect.size.y)))
				_region_sprite("res://assets/v8/dungeon/wall_top.png", cap, 1, Color(0.92,0.84,0.76))
			_prop("res://assets/v8/props/cage.png", Vector2(365,210), 0.42, 2)
			_prop("res://assets/v8/props/skull.png", Vector2(660,760), 0.48, 2)
			_prop("res://assets/v8/props/shelf.png", Vector2(1130,245), 0.38, 2)
			_prop("res://assets/v8/props/altar.png", Vector2(1890,560), 0.42, 2)
			_prop("res://assets/v8/props/gore.png", Vector2(2060,820), 0.45, 2, 0.92)
			_prop("res://assets/v8/props/pillar.png", Vector2(1730,860), 0.36, 2)
			_prop("res://assets/v8/props/lantern.png", Vector2(890,190), 0.42, 3)
			_prop("res://assets/v8/props/lantern.png", Vector2(1490,190), 0.42, 3)
			_prop("res://assets/v8/props/book.png", Vector2(1360,785), 0.44, 3)
		"foreground":
			for rect in [
				Rect2(0,72,2400,24), Rect2(0,1098,2400,24),
				Rect2(770,90,60,26), Rect2(770,1082,60,28),
				Rect2(1570,90,60,26), Rect2(1570,1082,60,28)
			]:
				_region_sprite("res://assets/v8/dungeon/wall_top.png", rect, 0, Color(0.62,0.56,0.54,0.96))
			_prop("res://assets/v8/dungeon/foreground_rock.png", Vector2(255,1035), 0.85, 1, 0.96)
			_prop("res://assets/v8/dungeon/foreground_rock.png", Vector2(2170,1030), 0.95, 1, 0.96)

func _wall_rects() -> Array[Rect2]:
	return [
		Rect2(0,0,2400,90),
		Rect2(0,1110,2400,90),
		Rect2(0,0,90,1200),
		Rect2(2310,0,90,1200),
		Rect2(780,90,40,410),
		Rect2(780,700,40,410),
		Rect2(1580,90,40,410),
		Rect2(1580,700,40,410),
		Rect2(310,280,260,70),
		Rect2(1040,835,330,70),
		Rect2(1780,240,270,65)
	]

func _draw() -> void:
	if _tex("res://assets/v8/dungeon/floor_tile.png") != null:
		return
	match layer_type:
		"floor":
			draw_rect(Rect2(0,0,2400,1200), Color(0.07,0.055,0.052))
		"back":
			for rect in _wall_rects():
				draw_rect(rect, Color(0.11,0.08,0.07))
		"foreground":
			draw_rect(Rect2(0,72,2400,24), Color(0.025,0.018,0.022,0.94))
