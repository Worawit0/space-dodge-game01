extends Node2D

@export_enum("floor","back","foreground") var layer_type := "floor"

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	match layer_type:
		"floor":
			_draw_floor()
		"back":
			_draw_back()
		"foreground":
			_draw_foreground()

func _draw_floor() -> void:
	draw_rect(Rect2(0,0,2400,1200), Color(0.07,0.055,0.052))
	for y in range(90,1110,48):
		for x in range(90,2310,64):
			var alt := int(x / 64) + int(y / 48)
			var c := Color(0.105,0.082,0.072) if alt % 2 == 0 else Color(0.092,0.072,0.066)
			draw_rect(Rect2(x+2,y+2,60,44), c)
			draw_line(Vector2(x+4,y+44),Vector2(x+58,y+44),Color(0.03,0.025,0.024),1)
	# Zone stains
	draw_circle(Vector2(420,780),100,Color(0.20,0.025,0.035,0.18))
	draw_circle(Vector2(1260,420),120,Color(0.03,0.16,0.10,0.12))
	draw_circle(Vector2(1980,650),150,Color(0.24,0.03,0.04,0.17))

func _wall_rect(rect: Rect2, color := Color(0.12,0.085,0.072)) -> void:
	draw_rect(rect, Color(0.025,0.02,0.022))
	draw_rect(rect.grow(-6), color)
	for yy in range(int(rect.position.y)+10, int(rect.end.y)-8, 28):
		draw_line(Vector2(rect.position.x+8,yy),Vector2(rect.end.x-8,yy),Color(0.04,0.03,0.03),2)

func _draw_back() -> void:
	_wall_rect(Rect2(0,0,2400,90))
	_wall_rect(Rect2(0,1110,2400,90))
	_wall_rect(Rect2(0,0,90,1200))
	_wall_rect(Rect2(2310,0,90,1200))
	_wall_rect(Rect2(780,90,40,410))
	_wall_rect(Rect2(780,700,40,410))
	_wall_rect(Rect2(1580,90,40,410))
	_wall_rect(Rect2(1580,700,40,410))
	_wall_rect(Rect2(310,280,260,70), Color(0.105,0.072,0.064))
	_wall_rect(Rect2(1040,835,330,70), Color(0.08,0.09,0.075))
	_wall_rect(Rect2(1780,240,270,65), Color(0.13,0.075,0.07))

func _draw_foreground() -> void:
	for rect in [
		Rect2(0,72,2400,22), Rect2(0,1100,2400,20),
		Rect2(770,90,60,24), Rect2(770,1086,60,24),
		Rect2(1570,90,60,24), Rect2(1570,1086,60,24)
	]:
		draw_rect(rect, Color(0.025,0.018,0.022,0.94))
	for x in [210,690,950,1480,1740,2210]:
		draw_line(Vector2(x,86),Vector2(x,145),Color(0.14,0.12,0.11),3)
		draw_circle(Vector2(x,151),7,Color(0.16,0.13,0.12))
