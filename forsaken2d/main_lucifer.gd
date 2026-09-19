extends Node2D

const SAVE_PATH := "user://forsaken_depths_overhaul_v3_save.json"
const WORLD_TOP := -400.0
const WORLD_BOTTOM := 400.0
const WORLD_LEFT := -600.0
const WORLD_RIGHT := 4600.0
const INTERACT_RANGE := 92.0

var player: CharacterBody2D
var player_anim: AnimatedSprite2D
var maren_follower: AnimatedSprite2D
var player_light: PointLight2D
var darkness: CanvasModulate
var camera: Camera2D
var facing := "down"

var game_mode := "title"
var current_location := "OLD PRISON"
var elapsed := 0.0
var title_elapsed := 0.0
var title_frame_index := 0

var body := 100.0
var mind := 100.0
var hunger := 100.0
var torch := 100.0
var max_body := 100.0
var bleeding := false
var infected := false
var fractured := false
var torch_on := true
var coins := 0

var inventory := {
	"Ration": 2,
	"Bandage": 2,
	"Blue Vial": 1,
	"Antiseptic": 1,
	"Splint": 1,
	"Torch Oil": 1,
	"Wax Seal": 2
}
var weapons := ["Rusted Sword"]
var armor := ["Ragged Shirt"]
var books := []
var key_items := []
var equipped_weapon := "Rusted Sword"
var equipped_armor := "Ragged Shirt"

var party := {
	"Maren": {"joined": false, "body": 78.0, "mind": 82.0, "max_body": 78.0}
}

var flags := {
	"rust_key": false,
	"prison_gate_open": false,
	"maren_helped": false,
	"sever_spared": false,
	"ritual_prayed": false,
	"blood_rite": false,
	"bell_sigil": false,
	"temple_gate_open": false,
	"heart_gate_open": false,
	"boss_dead": false
}

var removed_ids: Array[String] = []
var interactables: Array[Dictionary] = []
var world_nodes := {}
var traps: Array[Dictionary] = []
var trap_cooldowns := {}

var ui: CanvasLayer
var hud_panel: Panel
var hud_location: Label
var hud_stats: Label
var hud_status: Label
var prompt_label: Label
var message_label: Label
var sanity_overlay: ColorRect

var title_overlay: ColorRect
var title_background: TextureRect
var title_frames: Array[Texture2D] = []
var continue_button: Button

var dialogue_panel: Panel
var dialogue_text: RichTextLabel
var dialogue_choices: VBoxContainer

var inventory_overlay: ColorRect
var inventory_desc: RichTextLabel
var inventory_list: VBoxContainer
var inventory_current_tab := "Item"
var inventory_use_button: Button
var inventory_selected := ""
var inventory_status: RichTextLabel

var battle_overlay: ColorRect
var battle_enemy_art: TextureRect
var battle_enemy_name: Label
var battle_log: RichTextLabel
var battle_parts: Array[Button] = []
var battle_party_stats: RichTextLabel
var battle_enemy := {}
var battle_source_id := ""
var guarding := false
var boss_hp_label: Label

var ending_overlay: ColorRect
var ending_title: Label
var ending_text: RichTextLabel

var objective_panel: Panel
var objective_label: RichTextLabel
var journal_overlay: ColorRect
var journal_text: RichTextLabel
var story_overlay: ColorRect
var story_title: Label
var story_text: RichTextLabel
var story_continue: Button
var story_queue: Array = []
var last_location := "OLD PRISON"
var story_seen := {
	"intro": false,
	"infirmary": false,
	"temple": false,
	"heart": false,
	"boss": false
}

var radial_light_texture: GradientTexture2D
var ambient_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var battle_music_player: AudioStreamPlayer
var footstep_timer := 0.0
var enemy_battle_lock := false
var lucifer_panel: Texture2D
var lucifer_button: Texture2D
var lucifer_button_active: Texture2D
var lucifer_button_pressed: Texture2D

func _ready():
	randomize()
	get_window().content_scale_size = Vector2i(1280,720)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	radial_light_texture = _make_radial_texture()
	_load_lucifer_ui()
	_build_world_visuals()
	_build_player()
	_build_world_content()
	_build_ui()
	_build_audio()
	_apply_darkness()

func _process(delta):
	elapsed += delta
	if game_mode == "title":
		_update_title_animation(delta)
	if game_mode == "explore":
		_update_survival(delta)
		_update_player(delta)
		_update_follower(delta)
		_update_enemies(delta)
		_update_interaction_prompt()
		_update_traps(delta)
		_update_location()
	_update_visual_effects()
	_update_hud()

func _unhandled_key_input(event):
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_F11:
		_toggle_fullscreen()
		return
	if game_mode == "explore":
		if event.keycode == KEY_E:
			_interact()
		elif event.keycode == KEY_I:
			_open_inventory()
		elif event.keycode == KEY_Q:
			_open_journal()
		elif event.keycode == KEY_T:
			torch_on = not torch_on
			_show_message("Torch " + ("lit." if torch_on else "extinguished."))
		elif event.keycode == KEY_F9:
			_load_game()
	elif event.keycode == KEY_ESCAPE:
		if game_mode == "inventory":
			_close_inventory()
		elif game_mode == "dialogue":
			_close_dialogue()
		elif game_mode == "journal":
			_close_journal()

func _load_lucifer_ui():
	lucifer_panel = _load_tex("res://assets/lucifer/ui/panel.png")
	lucifer_button = _load_tex("res://assets/lucifer/ui/button.png")
	lucifer_button_active = _load_tex("res://assets/lucifer/ui/button_active.png")
	lucifer_button_pressed = _load_tex("res://assets/lucifer/ui/button_pressed.png")
	for i in range(1,13):
		var p = "res://assets/lucifer/ui/title/%02d.png" % i
		var t = _load_tex(p)
		if t:
			title_frames.append(t)

func _load_tex(path:String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _build_world_visuals():
	for spec in [
		["prison",Vector2(0,0),Vector2(1200,800)],
		["infirmary",Vector2(1200,0),Vector2(1200,800)],
		["temple",Vector2(2400,0),Vector2(1200,800)],
		["heart",Vector2(3800,0),Vector2(1600,800)]
	]:
		var s = Sprite2D.new()
		s.texture = _load_tex("res://assets/lucifer/rooms/"+String(spec[0])+".png")
		s.position = spec[1]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(s)

	darkness = CanvasModulate.new()
	darkness.color = Color(0.20,0.19,0.20,1.0)
	add_child(darkness)

	_make_static_rect(Vector2((WORLD_LEFT+WORLD_RIGHT)/2.0,WORLD_TOP-12), Vector2(WORLD_RIGHT-WORLD_LEFT,24))
	_make_static_rect(Vector2((WORLD_LEFT+WORLD_RIGHT)/2.0,WORLD_BOTTOM+12), Vector2(WORLD_RIGHT-WORLD_LEFT,24))
	_make_static_rect(Vector2(WORLD_LEFT-12,0), Vector2(24,WORLD_BOTTOM-WORLD_TOP))
	_make_static_rect(Vector2(WORLD_RIGHT+12,0), Vector2(24,WORLD_BOTTOM-WORLD_TOP))
	for gx in [600.0,1800.0,3000.0]:
		_make_static_rect(Vector2(gx,(WORLD_TOP-120)/2.0), Vector2(24,280))
		_make_static_rect(Vector2(gx,(WORLD_BOTTOM+120)/2.0), Vector2(24,280))
	_build_collision_layout()

func _build_collision_layout():
	# The same rectangles are both visible walls and physics. Nothing decorative is fake collision.
	var blocks = [
		# OLD PRISON: cells and broken masonry
		[Vector2(-430,-260),Vector2(220,150)],[Vector2(-120,-285),Vector2(220,110)],[Vector2(285,-270),Vector2(260,135)],
		[Vector2(-375,270),Vector2(260,145)],[Vector2(120,285),Vector2(250,115)],[Vector2(430,255),Vector2(140,170)],
		[Vector2(-80,-70),Vector2(65,170)],
		# INFIRMARY: operating rooms and storage
		[Vector2(770,-270),Vector2(190,145)],[Vector2(1150,-285),Vector2(260,110)],[Vector2(1570,-255),Vector2(250,155)],
		[Vector2(820,275),Vector2(235,135)],[Vector2(1370,275),Vector2(270,135)],[Vector2(1660,230),Vector2(150,220)],
		[Vector2(1250,75),Vector2(70,155)],
		# TEMPLE: side chapels around a central ritual aisle
		[Vector2(1980,-270),Vector2(220,145)],[Vector2(2340,-290),Vector2(190,105)],[Vector2(2760,-255),Vector2(250,165)],
		[Vector2(2020,270),Vector2(240,145)],[Vector2(2740,270),Vector2(260,145)],
		[Vector2(2220,70),Vector2(70,150)],[Vector2(2700,-20),Vector2(70,150)],
		# HEART: columns leave a clear boss arena and route to altar
		[Vector2(3200,-270),Vector2(260,150)],[Vector2(3200,270),Vector2(260,150)],
		[Vector2(4050,-275),Vector2(270,145)],[Vector2(4050,275),Vector2(270,145)],
		[Vector2(3460,-210),Vector2(90,130)],[Vector2(3460,210),Vector2(90,130)],
		[Vector2(3950,-190),Vector2(90,130)],[Vector2(3950,190),Vector2(90,130)]
	]
	for spec in blocks:
		_make_wall_block(spec[0],spec[1])

func _make_wall_block(center:Vector2,size:Vector2):
	var holder=Node2D.new()
	holder.position=center
	holder.z_index=1
	add_child(holder)
	var poly=Polygon2D.new()
	poly.polygon=PackedVector2Array([Vector2(-size.x/2,-size.y/2),Vector2(size.x/2,-size.y/2),Vector2(size.x/2,size.y/2),Vector2(-size.x/2,size.y/2)])
	poly.color=Color(0.075,0.060,0.055,0.96)
	holder.add_child(poly)
	var top=Line2D.new()
	top.points=PackedVector2Array([Vector2(-size.x/2,-size.y/2),Vector2(size.x/2,-size.y/2),Vector2(size.x/2,size.y/2),Vector2(-size.x/2,size.y/2),Vector2(-size.x/2,-size.y/2)])
	top.width=5.0
	top.default_color=Color(0.20,0.16,0.13,1.0)
	holder.add_child(top)
	var body_node=StaticBody2D.new()
	body_node.collision_layer=1
	body_node.collision_mask=1
	var cs=CollisionShape2D.new()
	var rect=RectangleShape2D.new()
	rect.size=size
	cs.shape=rect
	body_node.add_child(cs)
	holder.add_child(body_node)

func _build_player():
	player = CharacterBody2D.new()
	player.name = "Player"
	player.position = Vector2(-470,40)
	player.collision_layer = 1
	player.collision_mask = 3
	add_child(player)

	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 17
	collision.shape = shape
	player.add_child(collision)

	player_anim = AnimatedSprite2D.new()
	player_anim.name = "LuciferWarrior"
	player_anim.sprite_frames = _build_actor_frames("player")
	player_anim.scale = Vector2(1.9,1.9)
	player_anim.position = Vector2(0,-30)
	player_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_anim.play("idle_down")
	player.add_child(player_anim)

	player_light = PointLight2D.new()
	player_light.texture = radial_light_texture
	player_light.texture_scale = 1.52
	player_light.energy = 1.7
	player_light.color = Color(1.0,0.63,0.34)
	player_light.position = Vector2(18,-35)
	player.add_child(player_light)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.zoom = Vector2(1.08,1.08)
	player.add_child(camera)

	maren_follower = AnimatedSprite2D.new()
	maren_follower.sprite_frames = _build_actor_frames("player")
	maren_follower.scale = Vector2(1.72,1.72)
	maren_follower.modulate = Color(0.72,0.83,0.92,1.0)
	maren_follower.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	maren_follower.visible = false
	maren_follower.play("idle_down")
	add_child(maren_follower)

func _build_actor_frames(kind:String) -> SpriteFrames:
	var frames = SpriteFrames.new()
	frames.remove_animation("default")
	var base = "res://assets/lucifer/"+kind+"/"
	for dir in ["down","left","right","up"]:
		_add_strip_animation(frames,"idle_"+dir,base+"idle_"+dir+".png",48,6.0,true)
		_add_strip_animation(frames,"walk_"+dir,base+"walk_"+dir+".png",48,10.0,true)
	return frames

func _build_enemy_frames(kind:String) -> SpriteFrames:
	var frames = SpriteFrames.new()
	frames.remove_animation("default")
	var base = "res://assets/lucifer/"+kind+"/"
	for dir in ["down","left","right","up"]:
		_add_strip_animation(frames,"idle_"+dir,base+"idle_"+dir+".png",48,6.0,true)
		_add_strip_animation(frames,"walk_"+dir,base+"walk_"+dir+".png",48,8.0,true)
	return frames

func _add_strip_animation(frames:SpriteFrames,name:String,path:String,frame_width:int,fps:float,looping:bool):
	if not ResourceLoader.exists(path):
		return
	var tex = load(path) as Texture2D
	if not tex:
		return
	frames.add_animation(name)
	frames.set_animation_speed(name,fps)
	frames.set_animation_loop(name,looping)
	var count = maxi(1,int(tex.get_width()/frame_width))
	for i in range(count):
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i*frame_width,0,frame_width,tex.get_height())
		frames.add_frame(name,atlas)

func _build_world_content():
	# CHAPTER I
	_make_pickup("rust_key",Vector2(-320,-150),"Rust Key","key","A corroded key. The tag reads CELL BLOCK E.","")
	_make_pickup("prison_ration",Vector2(120,215),"Ration","item","Dry food. Barely edible.","")
	_make_pickup("coin_prison",Vector2(355,170),"Old Coin","coin","A worn coin stamped with a bell.","")
	_make_lore("prison_note",Vector2(-500,65),"Blood-stained Letter","The last guard wrote: [i]We sealed the eastern gate, but the ringing continued from below. The prisoners started answering it in their sleep.[/i]")
	_make_enemy("maw_prison",Vector2(210,-70),"Maw Wretch","demon_maw",78,15,false)
	_make_gate("prison_gate",Vector2(600,0),"Rust Key","prison_gate_open")

	# CHAPTER II
	_make_npc("maren",Vector2(820,-95),"Maren","maren",Color(0.72,0.83,0.92))
	_make_pickup("blue_vial_1",Vector2(1325,170),"Blue Vial","item","A cold restorative.","")
	_make_pickup("bandage_1",Vector2(1480,-175),"Bandage","item","Clean enough to stop bleeding.","")
	_make_pickup("coin_infirmary",Vector2(1540,185),"Old Coin","coin","A worn coin stamped with a bell.","")
	_make_pickup("axe_1",Vector2(1030,215),"Bearded Axe","weapon","A heavy common axe.","res://assets/lucifer/equipment/bearded_axe.png")
	_make_lore("infirmary_chart",Vector2(1020,-140),"Patient Chart","Every patient developed the same symptom: they heard a bell that no one else could hear. The final entry simply says: [i]DO NOT LET THEM SLEEP.[/i]")
	_make_enemy("husk_infirmary",Vector2(1570,45),"Bell Husk","demon_bell",92,17,false)
	_make_shrine("deep_shrine",Vector2(1110,70))

	# CHAPTER III
	_make_npc("sever",Vector2(2020,-145),"Priest Sever","sever",Color(0.76,0.68,0.61))
	_make_enemy("cultist_temple",Vector2(2550,125),"Faceless Devotee","demon_bell",108,20,false)
	_make_ritual("ritual_circle",Vector2(2420,-20))
	_make_pickup("book_echoes",Vector2(2820,-185),"Book of Echoes","book","A ritual manuscript describing the Bell as a lock.","")
	_make_pickup("coin_temple",Vector2(2140,205),"Old Coin","coin","A worn coin stamped with a bell.","")
	_make_pickup("coin_temple_2",Vector2(2860,205),"Old Coin","coin","A second ritual coin. Three are enough for the circle.","")
	_make_pickup("chainmail_1",Vector2(2120,120),"Chainmail Chestpiece","armor","Old chainmail with several repaired rings.","res://assets/lucifer/equipment/chainmail.png")
	_make_pickup("greatsword_1",Vector2(2780,105),"Greatsword","weapon","A broad blade meant for two hands.","res://assets/lucifer/equipment/greatsword.png")
	_make_lore("temple_inscription",Vector2(2860,-70),"Bell Inscription","The inscription names the Warden as a jailer. Beneath it, someone scratched: [i]The prisoner is not in the city. The city is the prison.[/i]")
	_make_gate("temple_gate",Vector2(1800,0),"The temple is sealed from this side.","temple_gate_open")
	_make_gate("heart_gate",Vector2(3000,0),"Bell Sigil","heart_gate_open")

	# CHAPTER IV
	_make_enemy("bell_warden",Vector2(3650,-10),"The Bell Warden","boss",260,29,true)
	_make_lore("heart_warning",Vector2(4140,-40),"Final Warning","Maren's missing brother left one sentence carved into the stone: [i]If you hear me calling from the Heart, it is already too late.[/i]")
	_make_altar("heart_altar",Vector2(4380,0))

	_make_trap("trap_prison",Vector2(60,120))
	_make_trap("trap_infirmary",Vector2(1640,-110))
	_make_trap("trap_temple",Vector2(2890,120))

func _make_static_rect(center:Vector2,size:Vector2):
	var body_node = StaticBody2D.new()
	body_node.position = center
	body_node.collision_layer = 1
	body_node.collision_mask = 1
	var cs = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	body_node.add_child(cs)
	add_child(body_node)

func _make_gate(id:String,pos:Vector2,need:String,flag_name:String):
	var holder = Node2D.new()
	holder.position = pos
	holder.name = id
	add_child(holder)
	var gate = Sprite2D.new()
	gate.texture = _load_tex("res://assets/lucifer/dungeon/gate.png")
	gate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gate.scale = Vector2(2.0,2.0)
	holder.add_child(gate)
	var collider = StaticBody2D.new()
	collider.collision_layer = 1
	collider.collision_mask = 1
	var cs = CollisionShape2D.new()
	var rs = RectangleShape2D.new()
	rs.size = Vector2(28,220)
	cs.shape = rs
	collider.add_child(cs)
	holder.add_child(collider)
	_register_entry({"id":id,"node":holder,"type":"gate","need":need,"flag":flag_name,"active":true,"collider":collider})

func _make_pickup(id:String,pos:Vector2,label:String,kind:String,desc:String,icon_path:String):
	var holder = Node2D.new()
	holder.position = pos
	holder.name = id
	add_child(holder)
	var glow = PointLight2D.new()
	glow.texture = radial_light_texture
	glow.texture_scale = 0.28
	glow.energy = 0.52
	glow.color = Color(0.72,0.69,0.48)
	holder.add_child(glow)
	var s = Sprite2D.new()
	var chosen = icon_path
	if chosen == "":
		chosen = _item_icon_path(label)
	s.texture = _load_tex(chosen) if chosen != "" else _load_tex("res://assets/item.svg")
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(2.6,2.6) if chosen.begins_with("res://assets/lucifer") else Vector2(0.25,0.25)
	holder.add_child(s)
	_register_entry({"id":id,"node":holder,"type":"pickup","label":label,"kind":kind,"desc":desc,"active":true})

func _make_enemy(id:String,pos:Vector2,label:String,art:String,enemy_body:int,damage:int,boss_enemy:bool):
	var holder = CharacterBody2D.new()
	holder.position = pos
	holder.name = id
	holder.collision_layer = 2
	holder.collision_mask = 1
	add_child(holder)
	var cs=CollisionShape2D.new()
	var shape=CircleShape2D.new()
	shape.radius=24.0 if not boss_enemy else 34.0
	cs.shape=shape
	holder.add_child(cs)
	var s = AnimatedSprite2D.new()
	if art.begins_with("demon_") or art=="boss":
		s.sprite_frames = _build_horror_frames(art)
		s.scale = Vector2(0.42,0.42) if not boss_enemy else Vector2(0.58,0.58)
		s.position = Vector2(0,-48)
	else:
		s.sprite_frames = _build_enemy_frames("cultist" if art=="cultist" else "skeleton")
		s.scale = Vector2(2.0,2.0)
		s.position = Vector2(0,-28)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.play("idle_down")
	holder.add_child(s)
	if boss_enemy:
		var red = PointLight2D.new()
		red.texture = radial_light_texture
		red.texture_scale = 0.42
		red.energy = 1.1
		red.color = Color(0.75,0.08,0.08)
		holder.add_child(red)
	var left = -560.0 if pos.x < 600 else (640.0 if pos.x < 1800 else (1840.0 if pos.x < 3000 else 3040.0))
	var right = 560.0 if pos.x < 600 else (1760.0 if pos.x < 1800 else (2960.0 if pos.x < 3000 else 4560.0))
	_register_entry({
		"id":id,"node":holder,"type":"enemy","label":label,"art":art,"body":enemy_body,"damage":damage,"boss":boss_enemy,"active":true,
		"sprite":s,"home":pos,"wander_dir":Vector2.ZERO,"wander_time":0.0,"room_left":left,"room_right":right,
		"speed":92.0 if boss_enemy else 68.0,"detect":260.0 if boss_enemy else 190.0
	})

func _build_horror_frames(art:String)->SpriteFrames:
	var frames=SpriteFrames.new()
	frames.remove_animation("default")
	var path="res://assets/horror_warden.svg" if art=="boss" else ("res://assets/horror_maw.svg" if art=="demon_maw" else "res://assets/horror_bell_husk.svg")
	var tex=_load_tex(path)
	for dir in ["down","left","right","up"]:
		var idle="idle_"+dir
		var walk="walk_"+dir
		frames.add_animation(idle);frames.set_animation_speed(idle,2.0);frames.set_animation_loop(idle,true)
		frames.add_animation(walk);frames.set_animation_speed(walk,4.0);frames.set_animation_loop(walk,true)
		if tex:
			frames.add_frame(idle,tex)
			frames.add_frame(walk,tex)
	return frames

func _make_lore(id:String,pos:Vector2,label:String,text:String):
	var holder=Node2D.new()
	holder.position=pos
	holder.name=id
	add_child(holder)
	var icon=Sprite2D.new()
	icon.texture=_load_tex("res://assets/lucifer/equipment/ragged_shirt.png")
	icon.scale=Vector2(1.8,1.8)
	icon.modulate=Color(0.82,0.72,0.55)
	holder.add_child(icon)
	var glow=PointLight2D.new()
	glow.texture=radial_light_texture
	glow.texture_scale=0.22
	glow.energy=0.35
	glow.color=Color(0.7,0.55,0.36)
	holder.add_child(glow)
	_register_entry({"id":id,"node":holder,"type":"lore","label":label,"text":text,"active":true})

func _make_npc(id:String,pos:Vector2,label:String,kind:String,tint:Color):
	var holder = Node2D.new()
	holder.position = pos
	holder.name = id
	add_child(holder)
	var s = AnimatedSprite2D.new()
	s.sprite_frames = _build_actor_frames("player")
	s.scale = Vector2(1.72,1.72)
	s.position = Vector2(0,-28)
	s.modulate = tint
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.play("idle_down")
	holder.add_child(s)
	_register_entry({"id":id,"node":holder,"type":"npc","label":label,"kind":kind,"active":true})

func _make_shrine(id:String,pos:Vector2):
	var holder = Node2D.new()
	holder.position = pos
	add_child(holder)
	var s = Sprite2D.new()
	s.texture = _load_tex("res://assets/shrine.svg")
	s.scale = Vector2(0.48,0.48)
	holder.add_child(s)
	var light = PointLight2D.new()
	light.texture = radial_light_texture
	light.texture_scale = 0.60
	light.energy = 0.85
	light.color = Color(0.40,0.55,0.84)
	holder.add_child(light)
	_register_entry({"id":id,"node":holder,"type":"shrine","label":"Deep Shrine","active":true})

func _make_ritual(id:String,pos:Vector2):
	var holder = Node2D.new()
	holder.position = pos
	add_child(holder)
	var s = Sprite2D.new()
	s.texture = _load_tex("res://assets/ritual.svg")
	s.scale = Vector2(0.55,0.55)
	holder.add_child(s)
	var light = PointLight2D.new()
	light.texture = radial_light_texture
	light.texture_scale = 0.78
	light.energy = 0.8
	light.color = Color(0.78,0.10,0.12)
	holder.add_child(light)
	_register_entry({"id":id,"node":holder,"type":"ritual","label":"Ritual Circle","active":true})

func _make_altar(id:String,pos:Vector2):
	var holder = Node2D.new()
	holder.position = pos
	add_child(holder)
	var s = Sprite2D.new()
	s.texture = _load_tex("res://assets/heart_altar.svg")
	s.scale = Vector2(0.52,0.52)
	holder.add_child(s)
	var light = PointLight2D.new()
	light.texture = radial_light_texture
	light.texture_scale = 0.9
	light.energy = 1.0
	light.color = Color(0.60,0.06,0.08)
	holder.add_child(light)
	_register_entry({"id":id,"node":holder,"type":"altar","label":"Heart Altar","active":true})

func _make_trap(id:String,pos:Vector2):
	var holder = Node2D.new()
	holder.position = pos
	add_child(holder)
	var p = Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(-25,18),Vector2(-12,-14),Vector2(0,18),Vector2(12,-14),Vector2(25,18)])
	p.color = Color("#554b3f")
	holder.add_child(p)
	var entry = {"id":id,"node":holder,"active":true}
	traps.append(entry)
	trap_cooldowns[id] = 0.0

func _register_entry(entry:Dictionary):
	interactables.append(entry)
	world_nodes[String(entry["id"])] = entry

func _make_radial_texture() -> GradientTexture2D:
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0,0.48,1.0])
	g.colors = PackedColorArray([Color(1,1,1,1),Color(1,1,1,0.66),Color(1,1,1,0)])
	var tex = GradientTexture2D.new()
	tex.gradient = g
	tex.width = 512
	tex.height = 512
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5,0.5)
	tex.fill_to = Vector2(1.0,0.5)
	return tex

func _update_player(delta):
	var dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W): dir.y -= 1
	if Input.is_key_pressed(KEY_S): dir.y += 1
	if Input.is_key_pressed(KEY_A): dir.x -= 1
	if Input.is_key_pressed(KEY_D): dir.x += 1
	dir = dir.normalized()
	var speed = 190.0
	if Input.is_key_pressed(KEY_SHIFT) and hunger > 8:
		speed = 275.0
	if fractured:
		speed *= 0.58
	player.velocity = dir * speed
	player.move_and_slide()

	if dir.length() > 0.0:
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			footstep_timer = 0.34 if speed < 250.0 else 0.24
			_play_sfx("footstep")
	else:
		footstep_timer = 0.0

	if dir.length() > 0.0:
		if abs(dir.x) > abs(dir.y):
			facing = "right" if dir.x > 0 else "left"
		else:
			facing = "down" if dir.y > 0 else "up"
		var anim = "walk_"+facing
		if player_anim.animation != anim:
			player_anim.play(anim)
	else:
		var idle = "idle_"+facing
		if player_anim.animation != idle:
			player_anim.play(idle)

func _update_follower(delta):
	if not maren_follower:
		return
	maren_follower.visible = bool(party["Maren"]["joined"])
	if not maren_follower.visible:
		return
	var target = player.position + Vector2(-48,34)
	var d = maren_follower.position.distance_to(target)
	maren_follower.position = maren_follower.position.lerp(target,clamp(delta*5.0,0.0,1.0))
	var anim = ("walk_"+facing) if d > 8 else ("idle_"+facing)
	if maren_follower.animation != anim:
		maren_follower.play(anim)

func _update_enemies(delta):
	if enemy_battle_lock:
		return
	for entry in interactables:
		if String(entry.get("type",""))!="enemy" or not bool(entry.get("active",false)):
			continue
		var body_node=entry["node"] as CharacterBody2D
		var sprite=entry["sprite"] as AnimatedSprite2D
		if not is_instance_valid(body_node):
			continue
		var dist=body_node.position.distance_to(player.position)
		var velocity=Vector2.ZERO
		if dist<float(entry["detect"]):
			velocity=body_node.position.direction_to(player.position)*float(entry["speed"])
		else:
			entry["wander_time"]=float(entry["wander_time"])-delta
			if float(entry["wander_time"])<=0.0:
				entry["wander_time"]=randf_range(1.0,2.8)
				var dirs=[Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,Vector2.ZERO]
				entry["wander_dir"]=dirs[randi()%dirs.size()]
			velocity=Vector2(entry["wander_dir"])*float(entry["speed"])*0.34
		if body_node.position.x < float(entry["room_left"])+35.0 and velocity.x<0: velocity.x=0
		if body_node.position.x > float(entry["room_right"])-35.0 and velocity.x>0: velocity.x=0
		if body_node.position.y < WORLD_TOP+42.0 and velocity.y<0: velocity.y=0
		if body_node.position.y > WORLD_BOTTOM-42.0 and velocity.y>0: velocity.y=0
		body_node.velocity=velocity
		body_node.move_and_slide()
		_play_enemy_anim(sprite,velocity)
		if String(entry["art"]).begins_with("demon_") or String(entry["art"])=="boss":
			sprite.rotation=sin(elapsed*3.5+body_node.position.x*0.01)*0.035
			sprite.scale*=1.0+sin(elapsed*5.0)*0.0008
		if body_node.position.distance_to(player.position)<48.0:
			enemy_battle_lock=true
			body_node.velocity=Vector2.ZERO
			_start_battle(entry)
			break

func _play_enemy_anim(sprite:AnimatedSprite2D,vel:Vector2):
	var dir="down"
	if abs(vel.x)>abs(vel.y):
		dir="right" if vel.x>0 else "left"
	elif abs(vel.y)>0.1:
		dir="down" if vel.y>0 else "up"
	var name=("walk_" if vel.length()>5.0 else "idle_")+dir
	if sprite.animation!=name:
		sprite.play(name)

func _update_survival(delta):
	hunger = max(0.0,hunger-delta*0.18)
	mind = max(0.0,mind-delta*(0.055 if torch_on else 0.18))
	if torch_on:
		torch = max(0.0,torch-delta*0.16)
		if torch <= 0:
			torch_on = false
			_show_message("The torch dies.")
	if bleeding: body=max(0.0,body-delta*0.24)
	if infected: body=max(0.0,body-delta*0.08)
	if hunger<=0: body=max(0.0,body-delta*0.55)
	if mind<=0: body=max(0.0,body-delta*0.16)
	if body<=0 and game_mode!="ending":
		_game_over()

func _update_visual_effects():
	if player_light:
		player_light.visible = torch_on and torch > 0
		player_light.texture_scale = lerp(0.78,1.55,clamp(torch/100.0,0.0,1.0))
		player_light.energy = lerp(0.75,1.75,clamp(torch/100.0,0.0,1.0))
	if darkness:
		var low = 1.0-clamp(mind/100.0,0.0,1.0)
		darkness.color = Color(0.21-low*0.06,0.20-low*0.07,0.21-low*0.07,1.0)
	if sanity_overlay:
		var danger = clamp((35.0-mind)/35.0,0.0,1.0)
		sanity_overlay.color = Color(0.20,0.0,0.03,danger*(0.08+0.035*sin(elapsed*2.5)))

func _update_traps(delta):
	for entry in traps:
		if not bool(entry["active"]): continue
		var id = String(entry["id"])
		trap_cooldowns[id] = max(0.0,float(trap_cooldowns[id])-delta)
		if player.position.distance_to((entry["node"] as Node2D).position)<34 and float(trap_cooldowns[id])<=0:
			trap_cooldowns[id]=5.0
			body=max(1.0,body-12)
			bleeding=true
			_show_message("A rusted trap closes around your leg. [BLEEDING]")

func _update_location():
	var x = player.position.x
	var next_location = "OLD PRISON" if x < 600 else ("ABANDONED INFIRMARY" if x < 1800 else ("TEMPLE DISTRICT" if x < 3000 else "HEART OF THE BELL"))
	if next_location != current_location:
		last_location = current_location
		current_location = next_location
		_on_location_changed(next_location)

func _on_location_changed(location:String):
	if location == "ABANDONED INFIRMARY" and not bool(story_seen["infirmary"]):
		story_seen["infirmary"] = true
		_show_story_card(
			"CHAPTER II — THE ABANDONED INFIRMARY",
			"Beyond the prison gate is an infirmary that should have been abandoned years ago. Fresh blood marks the floor. A wounded scavenger named Maren is still alive, and the old Deep Shrine here can preserve a memory — but only with a Wax Seal.",
			"Speak to Maren, find the Deep Shrine, then continue east toward the Temple District."
		)
	elif location == "TEMPLE DISTRICT" and not bool(story_seen["temple"]):
		story_seen["temple"] = true
		_show_story_card(
			"CHAPTER III — THE TEMPLE DISTRICT",
			"The temple was built around a ritual older than the city. Priest Sever claims the Bell Warden is not a god but a lock. The red circle can forge a Bell Sigil from three old coins — or from blood.",
			"Speak to Sever. Inspect the ritual circle and obtain the Bell Sigil."
		)
	elif location == "HEART OF THE BELL" and not bool(story_seen["heart"]):
		story_seen["heart"] = true
		_show_story_card(
			"CHAPTER IV — HEART OF THE BELL",
			"The sound is no longer coming through the walls. It is inside your teeth. At the center of the buried city waits the Bell Warden, guarding the thing that has been calling the missing people for years.",
			"Defeat the Bell Warden, then approach the Heart Altar."
		)

func _nearest_interactable() -> Dictionary:
	var best := {}
	var best_d := INTERACT_RANGE
	for entry in interactables:
		if not bool(entry.get("active",false)): continue
		var node = entry["node"] as Node2D
		if not is_instance_valid(node): continue
		var d=player.position.distance_to(node.position)
		if d<best_d:
			best=entry
			best_d=d
	return best

func _update_interaction_prompt():
	var e=_nearest_interactable()
	prompt_label.text="" if e.is_empty() else "[ E ]  "+_interaction_label(e)

func _interaction_label(e:Dictionary)->String:
	match String(e["type"]):
		"pickup": return "Take "+String(e["label"])
		"enemy": return "Confront "+String(e["label"])
		"npc": return "Talk to "+String(e["label"])
		"gate": return "Inspect gate"
		"shrine": return "Pray at the Deep Shrine"
		"ritual": return "Inspect ritual circle"
		"altar": return "Approach the Heart Altar"
		"lore": return "Inspect "+String(e["label"])
	return "Interact"

func _interact():
	var e=_nearest_interactable()
	if e.is_empty(): return
	match String(e["type"]):
		"pickup": _take_pickup(e)
		"enemy": _start_battle(e)
		"npc": _open_npc(e)
		"gate": _open_gate(e)
		"shrine": _open_shrine()
		"ritual": _open_ritual()
		"altar": _open_ending()
		"lore": _open_lore(e)

func _open_lore(e:Dictionary):
	_show_dialogue("[b]"+String(e["label"]).to_upper()+"[/b]\n\n"+String(e["text"]),[{"text":"Leave","call":func():_close_dialogue()}])

func _take_pickup(e:Dictionary):
	var label=String(e["label"])
	var kind=String(e["kind"])
	if kind=="item":
		inventory[label]=int(inventory.get(label,0))+1
	elif kind=="key":
		flags["rust_key"]=true
		if not key_items.has(label): key_items.append(label)
	elif kind=="book":
		if not books.has(label): books.append(label)
	elif kind=="weapon":
		if not weapons.has(label): weapons.append(label)
	elif kind=="armor":
		if not armor.has(label): armor.append(label)
	elif kind=="coin":
		coins += 1
	_play_sfx("pickup")
	_show_message("Obtained: "+label+"\n"+String(e["desc"]))
	_deactivate_entry(e,true)

func _open_gate(e:Dictionary):
	var id=String(e["id"])
	if id=="prison_gate":
		if flags["rust_key"]:
			flags["prison_gate_open"]=true
			_play_sfx("door")
			_show_message("The rusted key turns.")
			_deactivate_entry(e,true)
		else:
			_show_dialogue("The iron gate is locked.\n\nA small keyhole is buried beneath rust.",[{"text":"Leave","call":func():_close_dialogue()}])
	elif id=="temple_gate":
		flags["temple_gate_open"]=true
		_play_sfx("door")
		_show_message("The temple gate opens from this side.")
		_deactivate_entry(e,true)
	elif id=="heart_gate":
		if flags["bell_sigil"]:
			flags["heart_gate_open"]=true
			_play_sfx("door")
			_show_message("The Bell Sigil sinks into the lock.")
			_deactivate_entry(e,true)
		else:
			_show_dialogue("A circular socket waits in the gate.\n\nSomething shaped like a seal is missing.",[{"text":"Leave","call":func():_close_dialogue()}])

func _open_npc(e:Dictionary):
	var id=String(e["id"])
	if id=="maren":
		if flags["maren_helped"]:
			_show_dialogue("[b]MAREN[/b]\n\n\"Keep your torch low. Things here notice hope faster than sound.\"",[{"text":"Leave","call":func():_close_dialogue()}])
			return
		_show_dialogue("[b]MAREN[/b]\n\nA wounded scavenger leans against an operating table.\n\n\"If you have a bandage... I can still walk.\"",[
			{"text":"Give Bandage","call":func():_help_maren()},
			{"text":"Ask about the depths","call":func():dialogue_text.text="[b]MAREN[/b]\n\n\"The red circle in the temple trades intent for form. Coins, teeth, blood—anything carrying a promise.\""},
			{"text":"Leave","call":func():_close_dialogue()}
		])
	else:
		_show_dialogue("[b]PRIEST SEVER[/b]\n\n\"The Bell Warden was built as a lock, not a king. Break it and the city may breathe again.\"",[
			{"text":"Spare him","call":func():flags["sever_spared"]=true;mind=min(100.0,mind+7.0);_close_dialogue();_show_message("Sever lowers his head.")},
			{"text":"Condemn him","call":func():flags["sever_spared"]=false;_close_dialogue();_show_message("Sever smiles without warmth.")},
			{"text":"Leave","call":func():_close_dialogue()}
		])

func _help_maren():
	if int(inventory.get("Bandage",0))<=0:
		_show_message("You have no Bandage.")
		_close_dialogue()
		return
	inventory["Bandage"]-=1
	flags["maren_helped"]=true
	party["Maren"]["joined"]=true
	mind=min(100.0,mind+10)
	maren_follower.position=player.position+Vector2(-48,34)
	_close_dialogue()
	_show_message("Maren joins the party.")

func _open_ritual():
	var choices:Array=[
		{"text":"Pray","call":func():_ritual_pray()},
		{"text":"Offer 3 coins","call":func():_ritual_coin()},
		{"text":"Offer blood","call":func():_ritual_blood()},
		{"text":"Leave","call":func():_close_dialogue()}
	]
	_show_dialogue("A ritual circle is carved into the stone.\n\nThe grooves are dark, but not dry.",choices)

func _ritual_pray():
	_play_sfx("ritual")
	if not flags["ritual_prayed"]:
		flags["ritual_prayed"]=true
		mind=min(100.0,mind+22)
		hunger=max(0.0,hunger-7)
	_show_message("The chamber becomes silent. Your thoughts become your own.")
	_close_dialogue()

func _ritual_coin():
	_play_sfx("ritual")
	if flags["bell_sigil"]:
		_show_message("The circle has already answered.")
	elif coins<3:
		_show_message("Three old coins may be enough.")
	else:
		coins-=3
		flags["bell_sigil"]=true
		if not key_items.has("Bell Sigil"):key_items.append("Bell Sigil")
		_show_message("The coins melt into black metal. Obtained: Bell Sigil.")
	_close_dialogue()

func _ritual_blood():
	_play_sfx("ritual")
	if not flags["blood_rite"]:
		flags["blood_rite"]=true
		body=max(1.0,body-22)
		bleeding=true
		flags["bell_sigil"]=true
		if not key_items.has("Bell Sigil"): key_items.append("Bell Sigil")
		if not books.has("Rite of the Hollow Palm"): books.append("Rite of the Hollow Palm")
	_show_message("Your blood hardens into black metal. Obtained: Bell Sigil. [BLEEDING]")
	_close_dialogue()

func _open_shrine():
	_show_dialogue("The Deep Shrine is cold to the touch.\n\nA wax seal can bind a memory here.",[
		{"text":"Save (Wax Seal)","call":func():_save_game();_close_dialogue()},
		{"text":"Rest","call":func():hunger=max(0.0,hunger-12);body=min(max_body,body+18);mind=min(100.0,mind+12);_close_dialogue();_show_message("You rest without sleeping.")},
		{"text":"Leave","call":func():_close_dialogue()}
	])

func _start_battle(e:Dictionary):
	enemy_battle_lock=true
	_play_sfx("battle_start")
	battle_source_id=String(e["id"])
	var total=int(e["body"])
	battle_enemy={
		"name":String(e["label"]),"art":String(e["art"]),"max_body":total,"body":total,
		"damage":int(e["damage"]),"boss":bool(e["boss"]),
		"parts":{"Head":maxi(16,int(total*0.28)),"Torso":maxi(30,int(total*0.58)),"Left Arm":maxi(14,int(total*0.25)),"Right Arm":maxi(14,int(total*0.25)),"Legs":maxi(18,int(total*0.33))}
	}
	guarding=false
	game_mode="battle"
	battle_overlay.visible=true
	dialogue_panel.visible=false
	inventory_overlay.visible=false
	var art=String(e["art"])
	if art=="demon_maw":
		battle_enemy_art.texture=_load_tex("res://assets/horror_maw.svg")
	elif art=="demon_bell":
		battle_enemy_art.texture=_load_tex("res://assets/horror_bell_husk.svg")
	elif art=="boss":
		battle_enemy_art.texture=_load_tex("res://assets/horror_warden.svg")
	else:
		battle_enemy_art.texture=_load_tex("res://assets/lucifer/battle/"+art+".png")
	battle_enemy_name.text=String(e["label"])
	battle_log.text="[center][i]The encounter begins.[/i][/center]"
	_set_part_buttons(false)
	_refresh_battle_party()
	_refresh_battle_stats()

func _battle_choose_attack():
	_set_part_buttons(true)
	battle_log.append_text("\nChoose a body part.")

func _battle_attack(part:String):
	if game_mode!="battle":return
	_set_part_buttons(false)
	var chance={"Head":0.58,"Torso":0.93,"Left Arm":0.82,"Right Arm":0.82,"Legs":0.78}[part]
	var dmg=randi_range(15,23)+_weapon_bonus()
	if randf()<=chance:
		_play_sfx("hit")
		battle_enemy["parts"][part]=maxi(0,int(battle_enemy["parts"][part])-dmg)
		battle_enemy["body"]=maxi(0,int(battle_enemy["body"])-dmg)
		battle_log.append_text("\nYou strike [b]"+part+"[/b] for "+str(dmg)+".")
		if int(battle_enemy["parts"][part])<=0:battle_log.append_text(" [color=#d39a63]Disabled.[/color]")
	else:
		battle_log.append_text("\nYour attack misses.")
	if _battle_enemy_dead():_battle_win();return
	_party_followup()
	if _battle_enemy_dead():_battle_win();return
	_enemy_turn()
	_refresh_battle_party();_refresh_battle_stats()

func _battle_skill():
	if mind<12:
		battle_log.append_text("\nYour MIND cannot hold the skill.");return
	mind-=12
	var dmg=randi_range(25,35)+int(_weapon_bonus()/2)
	battle_enemy["parts"]["Torso"]=maxi(0,int(battle_enemy["parts"]["Torso"])-dmg)
	battle_enemy["body"]=maxi(0,int(battle_enemy["body"])-dmg)
	battle_log.append_text("\n[color=#d0b36d][b]Focused Strike[/b][/color] deals "+str(dmg)+".")
	if _battle_enemy_dead():_battle_win();return
	_party_followup()
	if _battle_enemy_dead():_battle_win();return
	_enemy_turn();_refresh_battle_party();_refresh_battle_stats()

func _battle_guard():
	guarding=true
	battle_log.append_text("\nYou raise your guard.")
	_party_followup()
	if _battle_enemy_dead():_battle_win();return
	_enemy_turn();_refresh_battle_party();_refresh_battle_stats()

func _battle_item():
	if bleeding and int(inventory.get("Bandage",0))>0:
		inventory["Bandage"]-=1;bleeding=false;body=min(max_body,body+7);battle_log.append_text("\nYou bind the wound.")
	elif int(inventory.get("Blue Vial",0))>0:
		inventory["Blue Vial"]-=1;body=min(max_body,body+28);mind=min(100.0,mind+10);battle_log.append_text("\nThe Blue Vial burns cold.")
	else:
		battle_log.append_text("\nNo useful battle item.");return
	_enemy_turn();_refresh_battle_party();_refresh_battle_stats()

func _battle_run():
	if bool(battle_enemy["boss"]):
		battle_log.append_text("\nThere is nowhere to run.");_enemy_turn();return
	var chance=0.88 if int(battle_enemy["parts"]["Legs"])<=0 else 0.38
	if randf()<chance:
		_end_battle(false);_show_message("You escape into the dark.")
	else:
		battle_log.append_text("\nThe enemy blocks your retreat.");_enemy_turn();_refresh_battle_party();_refresh_battle_stats()

func _party_followup():
	if bool(party["Maren"]["joined"]) and float(party["Maren"]["body"])>0:
		var dmg=randi_range(8,14)
		battle_enemy["parts"]["Torso"]=maxi(0,int(battle_enemy["parts"]["Torso"])-dmg)
		battle_enemy["body"]=maxi(0,int(battle_enemy["body"])-dmg)
		battle_log.append_text("\n[color=#9fc0d5]Maren attacks for "+str(dmg)+".[/color]")

func _enemy_turn():
	var hit_maren=bool(party["Maren"]["joined"]) and float(party["Maren"]["body"])>0 and randf()<0.30
	var dmg=int(battle_enemy["damage"])+randi_range(-3,3)
	if int(battle_enemy["parts"]["Left Arm"])<=0:dmg=int(dmg*0.72)
	if int(battle_enemy["parts"]["Right Arm"])<=0:dmg=int(dmg*0.72)
	if guarding and not hit_maren:dmg=int(dmg*0.42)
	guarding=false
	dmg=maxi(1,dmg-_armor_defense())
	if hit_maren:
		party["Maren"]["body"]=max(0.0,float(party["Maren"]["body"])-dmg)
		battle_log.append_text("\n"+String(battle_enemy["name"])+" strikes Maren for "+str(dmg)+".")
	else:
		body=max(0.0,body-dmg)
		battle_log.append_text("\n"+String(battle_enemy["name"])+" strikes you for "+str(dmg)+".")
		if randf()<0.14 and not bleeding:bleeding=true;battle_log.append_text(" [color=#bd4b4b]BLEEDING[/color]")
		if randf()<0.07 and not fractured:fractured=true;battle_log.append_text(" [color=#d2ad65]FRACTURE[/color]")
	if bool(battle_enemy["boss"]):mind=max(0.0,mind-5)
	if body<=0:_game_over()

func _weapon_bonus()->int:
	match equipped_weapon:
		"Bearded Axe":return 7
		"Greatsword":return 10
	return 4

func _armor_defense()->int:
	match equipped_armor:
		"Chainmail Chestpiece":return 3
		"Plate Chestpiece":return 6
	return 0

func _battle_enemy_dead()->bool:
	return int(battle_enemy["body"])<=0 or int(battle_enemy["parts"]["Head"])<=0

func _battle_win():
	var was_boss = bool(battle_enemy["boss"])
	if was_boss:
		flags["boss_dead"]=true
		coins+=5
	else:
		coins+=1
	if world_nodes.has(battle_source_id): _deactivate_entry(world_nodes[battle_source_id],true)
	_end_battle(true)
	if was_boss and not bool(story_seen["boss"]):
		story_seen["boss"] = true
		_show_story_card(
			"THE BELL FALLS SILENT",
			"The Warden collapses, but the bell does not die. Its final vibration travels downward into the Heart Altar. Whatever is buried beneath the city is waiting for your answer.",
			"Approach the Heart Altar and decide what becomes of the buried city."
		)
	else:
		_show_message("Victory. The silence returns.")

func _end_battle(_victory:bool):
	battle_overlay.visible=false
	battle_enemy={}
	battle_source_id=""
	game_mode="explore"
	enemy_battle_lock=false

func _refresh_battle_stats():
	if battle_enemy.is_empty():return
	var p=battle_enemy["parts"]
	boss_hp_label.text="BODY "+str(battle_enemy["body"])+"/"+str(battle_enemy["max_body"])
	battle_log.append_text("\n[color=#857d74]Head "+str(p["Head"])+" | Torso "+str(p["Torso"])+" | L.Arm "+str(p["Left Arm"])+" | R.Arm "+str(p["Right Arm"])+" | Legs "+str(p["Legs"])+"[/color]")

func _refresh_battle_party():
	var t="[b]PARTY[/b]\n\nWanderer  BODY %3d/%3d   MIND %3d\n" % [int(body),int(max_body),int(mind)]
	t+="Weapon: "+equipped_weapon+"\nArmor: "+equipped_armor+"\n"
	if bool(party["Maren"]["joined"]):t+="\nMaren     BODY %3d/%3d" % [int(party["Maren"]["body"]),int(party["Maren"]["max_body"])]
	battle_party_stats.text=t

func _set_part_buttons(value:bool):
	for b in battle_parts:b.visible=value

func _open_inventory():
	game_mode="inventory"
	inventory_overlay.visible=true
	inventory_selected=""
	inventory_desc.text="Select an item to inspect it."
	inventory_use_button.visible=false
	_refresh_inventory_tab()

func _close_inventory():
	inventory_overlay.visible=false
	game_mode="explore"

func _set_inventory_tab(tab:String):
	inventory_current_tab=tab
	inventory_selected=""
	inventory_desc.text="Select an entry."
	inventory_use_button.visible=false
	_refresh_inventory_tab()

func _refresh_inventory_tab():
	for c in inventory_list.get_children():c.queue_free()
	var entries:Array=[]
	match inventory_current_tab:
		"Item":
			for k in inventory.keys():
				if int(inventory[k])>0:entries.append({"name":String(k),"count":int(inventory[k])})
		"Weapon":
			for k in weapons:entries.append({"name":String(k),"count":1})
		"Armor":
			for k in armor:entries.append({"name":String(k),"count":1})
		"Books":
			for k in books:entries.append({"name":String(k),"count":1})
		"Key Items":
			for k in key_items:entries.append({"name":String(k),"count":1})
	for data in entries:
		var name=String(data["name"])
		var b=_button(name+("  x"+str(data["count"]) if inventory_current_tab=="Item" else ""))
		b.custom_minimum_size=Vector2(500,46)
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		var icon_path=_item_icon_path(name)
		if icon_path!="":b.icon=_load_tex(icon_path)
		b.pressed.connect(func():_select_inventory_entry(name))
		inventory_list.add_child(b)

func _select_inventory_entry(name:String):
	inventory_selected=name
	inventory_desc.text="[b]"+name+"[/b]\n\n"+_item_description(name)
	inventory_use_button.visible=inventory_current_tab=="Item" or inventory_current_tab=="Weapon" or inventory_current_tab=="Armor"
	inventory_use_button.text="Use" if inventory_current_tab=="Item" else "Equip"

func _inventory_use_selected():
	if inventory_selected=="":return
	if inventory_current_tab=="Item":_use_item(inventory_selected)
	elif inventory_current_tab=="Weapon":
		equipped_weapon=inventory_selected;_show_message("Equipped: "+inventory_selected)
	elif inventory_current_tab=="Armor":
		equipped_armor=inventory_selected;_show_message("Equipped: "+inventory_selected)
	_refresh_inventory_tab()

func _use_item(name:String):
	if int(inventory.get(name,0))<=0:return
	match name:
		"Ration":hunger=min(100.0,hunger+34)
		"Bandage":bleeding=false;body=min(max_body,body+8)
		"Blue Vial":body=min(max_body,body+30);mind=min(100.0,mind+8)
		"Antiseptic":infected=false
		"Splint":fractured=false
		"Torch Oil":torch=min(100.0,torch+58)
		"Wax Seal":_show_message("Wax Seals can only be used at a Deep Shrine.");return
	inventory[name]-=1
	inventory_desc.text="[b]"+name+"[/b]\n\nUsed."
	_show_message("Used "+name+".")

func _item_description(name:String)->String:
	var d={
		"Ration":"Dry preserved food. Restores HUNGER.",
		"Bandage":"Stops BLEEDING and restores a little BODY.",
		"Blue Vial":"Restores BODY and steadies MIND.",
		"Antiseptic":"Cleans INFECTION.","Splint":"Stabilizes a FRACTURE.",
		"Torch Oil":"Restores the TORCH meter.","Wax Seal":"Consumed when saving at a Deep Shrine.",
		"Rusted Sword":"A chipped arming sword. +4 attack.","Bearded Axe":"Heavy and brutal. +7 attack.",
		"Greatsword":"A broad two-handed blade. +10 attack.","Ragged Shirt":"Little protection.",
		"Chainmail Chestpiece":"Reduces incoming damage by 3.","Book of Echoes":"Notes on the Bell and ritual exchange.",
		"Rite of the Hollow Palm":"A blood-fed ritual phrase.","Rust Key":"Opens the Old Prison gate.","Bell Sigil":"A black seal formed by the ritual circle."
	}
	return String(d.get(name,"Its purpose is unclear."))

func _item_icon_path(name:String)->String:
	var m={
		"Rusted Sword":"res://assets/lucifer/equipment/arming_sword.png",
		"Bearded Axe":"res://assets/lucifer/equipment/bearded_axe.png",
		"Greatsword":"res://assets/lucifer/equipment/greatsword.png",
		"Ragged Shirt":"res://assets/lucifer/equipment/ragged_shirt.png",
		"Chainmail Chestpiece":"res://assets/lucifer/equipment/chainmail.png",
		"Rust Key":"res://assets/lucifer/ui/key_icon.png",
		"Bell Sigil":"res://assets/lucifer/ui/skill_icon.png",
		"Blue Vial":"res://assets/lucifer/ui/skill_icon.png",
		"Bandage":"res://assets/lucifer/ui/skill_icon.png",
		"Ration":"res://assets/lucifer/ui/skill_icon.png"
	}
	return String(m.get(name,""))

func _save_game():
	if int(inventory.get("Wax Seal",0))<=0:_show_message("You have no Wax Seal.");return
	inventory["Wax Seal"]-=1
	var data={"body":body,"mind":mind,"hunger":hunger,"torch":torch,"bleeding":bleeding,"infected":infected,"fractured":fractured,"coins":coins,"inventory":inventory,"weapons":weapons,"armor":armor,"books":books,"key_items":key_items,"equipped_weapon":equipped_weapon,"equipped_armor":equipped_armor,"flags":flags,"party":party,"removed_ids":removed_ids,"story_seen":story_seen,"player_pos":[player.position.x,player.position.y]}
	var f=FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	_show_message("Your memory is sealed in wax.")
	if continue_button:continue_button.disabled=false

func _load_game():
	if not FileAccess.file_exists(SAVE_PATH):_show_message("No sealed memory exists.");return
	var f=FileAccess.open(SAVE_PATH,FileAccess.READ)
	var data=JSON.parse_string(f.get_as_text())
	if typeof(data)!=TYPE_DICTIONARY:_show_message("The save cannot be read.");return
	body=float(data.get("body",100));mind=float(data.get("mind",100));hunger=float(data.get("hunger",100));torch=float(data.get("torch",100))
	bleeding=bool(data.get("bleeding",false));infected=bool(data.get("infected",false));fractured=bool(data.get("fractured",false));coins=int(data.get("coins",0))
	inventory=data.get("inventory",inventory);weapons=data.get("weapons",weapons);armor=data.get("armor",armor);books=data.get("books",books);key_items=data.get("key_items",key_items)
	equipped_weapon=String(data.get("equipped_weapon","Rusted Sword"));equipped_armor=String(data.get("equipped_armor","Ragged Shirt"));flags=data.get("flags",flags);party=data.get("party",party);story_seen=data.get("story_seen",story_seen)
	removed_ids.clear()
	for rid in data.get("removed_ids",[]):
		var id=String(rid);removed_ids.append(id)
		if world_nodes.has(id):_deactivate_entry(world_nodes[id],false)
	var p=data.get("player_pos",[-470,40]);player.position=Vector2(float(p[0]),float(p[1]))
	title_overlay.visible=false;ending_overlay.visible=false
	maren_follower.position=player.position+Vector2(-48,34)
	_show_story_card(
		"MEMORY RESTORED",
		"Your last sealed memory returns in fragments. The trail still leads deeper beneath the city, toward the Bell and the person who sent the impossible letter.",
		_current_objective()
	)

func _deactivate_entry(e:Dictionary,remember:bool):
	e["active"]=false
	var id=String(e["id"])
	if remember and not removed_ids.has(id):removed_ids.append(id)
	var node=e["node"] as Node2D
	if is_instance_valid(node):
		node.visible=false
		for c in node.get_children():
			if c is StaticBody2D:
				c.collision_layer=0;c.collision_mask=0

func _open_ending():
	if not flags["boss_dead"]:
		_show_dialogue("The Heart Altar is still bound to the Bell Warden.\n\nSomething behind the stone is listening.",[{"text":"Leave","call":func():_close_dialogue()}]);return
	game_mode="ending";ending_overlay.visible=true
	if mind>=45 and flags["maren_helped"] and flags["sever_spared"]:
		ending_title.text="ENDING A — THE SILENT CITY"
		ending_text.text="You break the final clapper from the heart of the bell.\n\nFor the first time in generations, the buried city hears nothing. Maren leads the survivors toward dawn while Sever closes the old rites.\n\nDeep below, something notices the absence of its song."
	elif flags["blood_rite"] and mind<45:
		ending_title.text="ENDING C — HOLLOW PALM"
		ending_text.text="You touch the Heart with the hand that fed the circle.\n\nThe bell changes rhythm. When the gates open, your shadow moves a heartbeat before you do.\n\nThe depths have learned how to leave."
	else:
		ending_title.text="ENDING B — NEW WARDEN"
		ending_text.text="You silence the Warden and place your hand upon the Heart.\n\nThe doors open for everyone except you. A new pulse begins beneath your ribs.\n\nA new Warden has been chosen."

func _game_over():
	game_mode="ending";battle_overlay.visible=false;dialogue_panel.visible=false;inventory_overlay.visible=false;ending_overlay.visible=true
	ending_title.text="YOU DIED"
	ending_text.text="The depths remember your name.\n\nUse Continue to return to your last sealed memory."

func _show_dialogue(text:String,choices:Array):
	game_mode="dialogue";dialogue_panel.visible=true;dialogue_text.text=text
	for c in dialogue_choices.get_children():c.queue_free()
	for choice in choices:
		var b=_button(String(choice["text"]));b.custom_minimum_size=Vector2(255,48);b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.pressed.connect(choice["call"]);dialogue_choices.add_child(b)

func _close_dialogue():
	dialogue_panel.visible=false
	if game_mode!="ending":game_mode="explore"

func _build_audio():
	ambient_player=AudioStreamPlayer.new()
	ambient_player.name="Ambient"
	ambient_player.volume_db=-17.0
	add_child(ambient_player)
	sfx_player=AudioStreamPlayer.new()
	sfx_player.name="SFX"
	sfx_player.volume_db=-5.0
	add_child(sfx_player)
	battle_music_player=AudioStreamPlayer.new()
	battle_music_player.name="BattleAudio"
	battle_music_player.volume_db=-9.0
	add_child(battle_music_player)
	var ambient=_load_audio("res://assets/audio/ambient.wav")
	if ambient:
		ambient_player.stream=ambient
		ambient_player.finished.connect(func(): ambient_player.play())
		ambient_player.play()

func _load_audio(path:String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	return null

func _play_sfx(name:String):
	if not sfx_player:return
	var stream=_load_audio("res://assets/audio/"+name+".wav")
	if stream:
		sfx_player.stop()
		sfx_player.stream=stream
		sfx_player.play()

func _show_message(text:String):
	if not message_label:return
	message_label.text=text;message_label.modulate=Color.WHITE
	var tw=create_tween();tw.tween_interval(3.0);tw.tween_property(message_label,"modulate:a",0.0,0.6)

func _apply_darkness():
	darkness.color=Color(0.20,0.19,0.20,1)

func _build_ui():
	ui=CanvasLayer.new();add_child(ui)
	var root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.add_child(root)
	sanity_overlay=ColorRect.new();sanity_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);sanity_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(sanity_overlay)

	hud_panel=_make_panel(Vector2(18,16),Vector2(405,108));root.add_child(hud_panel)
	hud_location=Label.new();hud_location.position=Vector2(20,12);hud_location.add_theme_font_size_override("font_size",22);hud_panel.add_child(hud_location)
	hud_stats=Label.new();hud_stats.position=Vector2(20,45);hud_stats.add_theme_font_size_override("font_size",16);hud_panel.add_child(hud_stats)
	hud_status=Label.new();hud_status.position=Vector2(20,75);hud_status.add_theme_font_size_override("font_size",14);hud_panel.add_child(hud_status)

	objective_panel=_make_panel(Vector2(815,16),Vector2(445,108));root.add_child(objective_panel)
	objective_label=RichTextLabel.new();objective_label.bbcode_enabled=true;objective_label.position=Vector2(18,10);objective_label.size=Vector2(410,88);objective_label.add_theme_font_size_override("normal_font_size",15);objective_panel.add_child(objective_label)

	prompt_label=Label.new();prompt_label.position=Vector2(455,646);prompt_label.size=Vector2(370,44);prompt_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;prompt_label.add_theme_font_size_override("font_size",20);root.add_child(prompt_label)
	message_label=Label.new();message_label.position=Vector2(350,30);message_label.size=Vector2(580,90);message_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;message_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;message_label.add_theme_font_size_override("font_size",18);root.add_child(message_label)

	_build_title_ui(root);_build_dialogue_ui(root);_build_inventory_ui(root);_build_battle_ui(root);_build_journal_ui(root);_build_story_ui(root);_build_ending_ui(root)

func _build_title_ui(root:Control):
	title_overlay=ColorRect.new();title_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);title_overlay.color=Color(0.005,0.004,0.005,1);root.add_child(title_overlay)
	title_background=TextureRect.new();title_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);title_background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;title_background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;title_background.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;title_background.modulate=Color(0.45,0.39,0.39,1);title_overlay.add_child(title_background)
	if title_frames.size()>0:title_background.texture=title_frames[0]
	var shade=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0.02,0.01,0.015,0.52);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;title_overlay.add_child(shade)
	var title=Label.new();title.text="THE FORSAKEN DEPTHS";title.position=Vector2(215,105);title.size=Vector2(850,80);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",48);title_overlay.add_child(title)
	var sub=Label.new();sub.text="LUCIFER COMPLETE — DARK SURVIVAL RPG";sub.position=Vector2(370,188);sub.size=Vector2(540,42);sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;sub.modulate=Color("#c3ad91");sub.add_theme_font_size_override("font_size",18);title_overlay.add_child(sub)
	var menu=VBoxContainer.new();menu.position=Vector2(485,315);menu.size=Vector2(310,220);title_overlay.add_child(menu)
	var nb=_button("NEW DESCENT");nb.custom_minimum_size=Vector2(310,56);nb.pressed.connect(_new_game);menu.add_child(nb)
	continue_button=_button("CONTINUE");continue_button.custom_minimum_size=Vector2(310,56);continue_button.disabled=not FileAccess.file_exists(SAVE_PATH);continue_button.pressed.connect(_load_game);menu.add_child(continue_button)
	var cb=_button("CONTROLS");cb.custom_minimum_size=Vector2(310,56);cb.pressed.connect(func():message_label.modulate=Color.WHITE;message_label.text="WASD Move   Shift Run   E Interact   I Inventory   T Torch   F9 Load");menu.add_child(cb)

func _update_title_animation(delta):
	if title_frames.is_empty() or not title_overlay.visible:return
	title_elapsed+=delta
	if title_elapsed>=0.12:
		title_elapsed=0.0;title_frame_index=(title_frame_index+1)%title_frames.size();title_background.texture=title_frames[title_frame_index]

func _new_game():
	_play_sfx("ui")
	body=100;mind=100;hunger=100;torch=100;bleeding=false;infected=false;fractured=false;torch_on=true;coins=0
	story_seen={"intro":true,"infirmary":false,"temple":false,"heart":false,"boss":false}
	player.position=Vector2(-470,40)
	current_location="OLD PRISON"
	last_location="OLD PRISON"
	title_overlay.visible=false
	_show_story_sequence([
		{
			"title":"บทนำ I — ระฆังที่ไม่ควรดัง",
			"body":"เจ็ดปีก่อน ระฆังใต้เมืองดังขึ้นเพียงครั้งเดียว ก่อนรุ่งเช้ามีคนหายไปหลายร้อยคน หนึ่งในนั้นคือน้องชายของคุณ ไม่มีศพ ไม่มีร่องรอย และไม่มีใครกล้าลงไปค้นหาใต้เมืองอีก",
			"objective":"อ่านต่อเพื่อรู้ว่าเหตุใดคุณจึงกลับมาที่นี่"
		},
		{
			"title":"บทนำ II — จดหมาย",
			"body":"สามคืนก่อน คุณได้รับจดหมายที่เขียนด้วยลายมือของน้องชาย ทั้งที่เขาหายไปเจ็ดปีแล้ว\n\n\"ถ้าระฆังดังอีกครั้ง อย่าให้ผมตอบมัน\"\n\nด้านหลังจดหมายมีแผนที่เพียงจุดเดียว: เรือนจำเก่าที่ถูกสั่งปิดตาย",
			"objective":"ตามรอยจดหมายลงไปใต้ Old Prison"
		},
		{
			"title":"บทที่ I — OLD PRISON",
			"body":"บันไดด้านหลังพังลงทันทีที่คุณลงมาถึง ทางกลับถูกตัดขาด เหลือเพียงคบเพลิง ดาบสนิม และเสียงเหมือนโลหะสั่นอยู่ลึกลงไปใต้พื้น",
			"objective":"ค้นหา Rust Key ทางฝั่งตะวันตก แล้วเปิดประตูเหล็กด้านตะวันออก"
		}
	])

func _build_dialogue_ui(root:Control):
	dialogue_panel=_make_panel(Vector2(70,438),Vector2(1140,245));root.add_child(dialogue_panel);dialogue_panel.visible=false
	dialogue_text=RichTextLabel.new();dialogue_text.bbcode_enabled=true;dialogue_text.position=Vector2(28,24);dialogue_text.size=Vector2(760,190);dialogue_text.add_theme_font_size_override("normal_font_size",22);dialogue_text.add_theme_font_size_override("bold_font_size",24);dialogue_panel.add_child(dialogue_text)
	dialogue_choices=VBoxContainer.new();dialogue_choices.position=Vector2(815,24);dialogue_choices.size=Vector2(295,190);dialogue_panel.add_child(dialogue_choices)

func _build_inventory_ui(root:Control):
	inventory_overlay=ColorRect.new();inventory_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);inventory_overlay.color=Color(0.002,0.002,0.003,0.985);root.add_child(inventory_overlay);inventory_overlay.visible=false
	var frame=_make_panel(Vector2(105,48),Vector2(1070,620));inventory_overlay.add_child(frame)

	var header=Label.new()
	header.text="INVENTORY"
	header.position=Vector2(28,18)
	header.size=Vector2(1015,42)
	header.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size",28)
	frame.add_child(header)

	var tabs=HBoxContainer.new();tabs.position=Vector2(30,72);frame.add_child(tabs)
	for tab in ["Item","Weapon","Armor","Books","Key Items"]:
		var b=_button(tab);b.custom_minimum_size=Vector2(196,46);var lt=tab;b.pressed.connect(func():_set_inventory_tab(lt));tabs.add_child(b)

	var scroll=ScrollContainer.new();scroll.position=Vector2(30,138);scroll.size=Vector2(470,390);frame.add_child(scroll)
	inventory_list=VBoxContainer.new();inventory_list.custom_minimum_size=Vector2(445,380);inventory_list.add_theme_constant_override("separation",6);scroll.add_child(inventory_list)

	inventory_desc=RichTextLabel.new();inventory_desc.bbcode_enabled=true;inventory_desc.position=Vector2(535,145);inventory_desc.size=Vector2(500,180);inventory_desc.add_theme_font_size_override("normal_font_size",20);inventory_desc.add_theme_font_size_override("bold_font_size",22);frame.add_child(inventory_desc)
	inventory_status=RichTextLabel.new();inventory_status.bbcode_enabled=true;inventory_status.position=Vector2(535,335);inventory_status.size=Vector2(500,155);inventory_status.add_theme_font_size_override("normal_font_size",18);frame.add_child(inventory_status)

	inventory_use_button=_button("USE / EQUIP");inventory_use_button.position=Vector2(535,520);inventory_use_button.size=Vector2(230,54);inventory_use_button.visible=false;inventory_use_button.pressed.connect(_inventory_use_selected);frame.add_child(inventory_use_button)
	var close=_button("BACK  [Esc]");close.position=Vector2(805,520);close.size=Vector2(230,54);close.pressed.connect(_close_inventory);frame.add_child(close)

func _build_battle_ui(root:Control):
	battle_overlay=ColorRect.new();battle_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);battle_overlay.color=Color(0.003,0.002,0.003,1);root.add_child(battle_overlay);battle_overlay.visible=false
	battle_enemy_name=Label.new();battle_enemy_name.position=Vector2(350,20);battle_enemy_name.size=Vector2(580,44);battle_enemy_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;battle_enemy_name.add_theme_font_size_override("font_size",28);battle_overlay.add_child(battle_enemy_name)
	boss_hp_label=Label.new();boss_hp_label.position=Vector2(515,62);boss_hp_label.size=Vector2(250,30);boss_hp_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;boss_hp_label.modulate=Color("#c8b593");battle_overlay.add_child(boss_hp_label)
	var bossbar=TextureRect.new();bossbar.texture=_load_tex("res://assets/lucifer/ui/boss_health.png");bossbar.position=Vector2(488,88);bossbar.size=Vector2(304,72);bossbar.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;bossbar.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;battle_overlay.add_child(bossbar)
	battle_enemy_art=TextureRect.new();battle_enemy_art.position=Vector2(390,105);battle_enemy_art.size=Vector2(500,330);battle_enemy_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;battle_enemy_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;battle_enemy_art.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;battle_overlay.add_child(battle_enemy_art)
	for spec in [["Head",Vector2(585,115)],["Left Arm",Vector2(365,235)],["Right Arm",Vector2(805,235)],["Torso",Vector2(585,270)],["Legs",Vector2(585,385)]]:
		var b=_button(String(spec[0]));b.position=spec[1];b.size=Vector2(110,38);b.visible=false;var part=String(spec[0]);b.pressed.connect(func():_battle_attack(part));battle_overlay.add_child(b);battle_parts.append(b)
	var bottom=_make_panel(Vector2(80,450),Vector2(1120,245));battle_overlay.add_child(bottom)
	var menu=VBoxContainer.new();menu.position=Vector2(22,18);bottom.add_child(menu)
	for spec in [["Attack",Callable(self,"_battle_choose_attack")],["Skills",Callable(self,"_battle_skill")],["Guard",Callable(self,"_battle_guard")],["Items",Callable(self,"_battle_item")],["Run",Callable(self,"_battle_run")]]:
		var b=_button(String(spec[0]));b.custom_minimum_size=Vector2(205,36);b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.pressed.connect(spec[1]);menu.add_child(b)
	battle_log=RichTextLabel.new();battle_log.bbcode_enabled=true;battle_log.position=Vector2(250,18);battle_log.size=Vector2(500,195);battle_log.add_theme_font_size_override("normal_font_size",17);bottom.add_child(battle_log)
	battle_party_stats=RichTextLabel.new();battle_party_stats.bbcode_enabled=true;battle_party_stats.position=Vector2(775,18);battle_party_stats.size=Vector2(320,195);battle_party_stats.add_theme_font_size_override("normal_font_size",17);bottom.add_child(battle_party_stats)

func _build_journal_ui(root:Control):
	journal_overlay=ColorRect.new()
	journal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	journal_overlay.color=Color(0.004,0.003,0.004,0.985)
	root.add_child(journal_overlay)
	journal_overlay.visible=false
	var frame=_make_panel(Vector2(145,70),Vector2(990,580))
	journal_overlay.add_child(frame)
	var title=Label.new()
	title.text="JOURNAL / OBJECTIVE"
	title.position=Vector2(35,25)
	title.size=Vector2(920,45)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",28)
	frame.add_child(title)
	journal_text=RichTextLabel.new()
	journal_text.bbcode_enabled=true
	journal_text.position=Vector2(55,90)
	journal_text.size=Vector2(880,390)
	journal_text.add_theme_font_size_override("normal_font_size",19)
	frame.add_child(journal_text)
	var close=_button("BACK TO GAME  [Q / Esc]")
	close.position=Vector2(330,500)
	close.size=Vector2(330,50)
	close.pressed.connect(_close_journal)
	frame.add_child(close)

func _build_story_ui(root:Control):
	story_overlay=ColorRect.new()
	story_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	story_overlay.color=Color(0.002,0.002,0.003,0.97)
	root.add_child(story_overlay)
	story_overlay.visible=false
	var frame=_make_panel(Vector2(145,85),Vector2(990,550))
	story_overlay.add_child(frame)
	story_title=Label.new()
	story_title.position=Vector2(45,35)
	story_title.size=Vector2(900,60)
	story_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	story_title.add_theme_font_size_override("font_size",31)
	frame.add_child(story_title)
	story_text=RichTextLabel.new()
	story_text.bbcode_enabled=true
	story_text.position=Vector2(80,120)
	story_text.size=Vector2(830,300)
	story_text.add_theme_font_size_override("normal_font_size",20)
	frame.add_child(story_text)
	story_continue=_button("ต่อไป")
	story_continue.position=Vector2(345,455)
	story_continue.size=Vector2(300,55)
	story_continue.pressed.connect(_advance_story_card)
	frame.add_child(story_continue)

func _build_ending_ui(root:Control):
	ending_overlay=ColorRect.new();ending_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ending_overlay.color=Color(0.002,0.002,0.003,0.985);root.add_child(ending_overlay);ending_overlay.visible=false
	ending_title=Label.new();ending_title.position=Vector2(180,100);ending_title.size=Vector2(920,70);ending_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;ending_title.add_theme_font_size_override("font_size",38);ending_overlay.add_child(ending_title)
	ending_text=RichTextLabel.new();ending_text.position=Vector2(250,205);ending_text.size=Vector2(780,300);ending_text.add_theme_font_size_override("normal_font_size",23);ending_overlay.add_child(ending_text)
	var lb=_button("LOAD LAST MEMORY");lb.position=Vector2(440,555);lb.size=Vector2(400,55);lb.pressed.connect(func():ending_overlay.visible=false;_load_game());ending_overlay.add_child(lb)

func _show_story_card(title_text:String,body_text:String,objective_text:String):
	_show_story_sequence([{"title":title_text,"body":body_text,"objective":objective_text}])

func _show_story_sequence(cards:Array):
	story_queue=cards.duplicate(true)
	game_mode="story"
	story_overlay.visible=true
	_display_story_page()

func _display_story_page():
	if story_queue.is_empty():
		story_overlay.visible=false
		game_mode="explore"
		return
	var page:Dictionary=story_queue[0]
	story_title.text=String(page["title"])
	story_text.text=String(page["body"])+"\n\n[color=#d8c398][b]เป้าหมาย[/b][/color]\n"+String(page["objective"])+"\n\n[color=#817b75]WASD เดิน • E สำรวจ/คุย • I ไอเทม • Q บันทึกเรื่องราว • T คบเพลิง • F11 เต็มจอ[/color]"
	story_continue.text="ต่อไป" if story_queue.size()>1 else "เริ่มเล่น"

func _advance_story_card():
	if not story_queue.is_empty():
		story_queue.pop_front()
	_display_story_page()

func _close_story_card():
	story_queue.clear()
	story_overlay.visible=false
	game_mode="explore"

func _open_journal():
	game_mode="journal"
	journal_overlay.visible=true
	journal_text.text=_journal_text()

func _close_journal():
	journal_overlay.visible=false
	game_mode="explore"

func _journal_text()->String:
	var recap="[b]เรื่องราว[/b]\nเจ็ดปีก่อนระฆังใต้เมืองดังหนึ่งครั้งและผู้คนหลายร้อยคนหายตัวไป รวมถึงน้องชายของคุณ จดหมายลึกลับที่เขียนด้วยลายมือของเขาพาคุณกลับมายัง Old Prison ตอนนี้ Maren เชื่อว่า Ritual Circle สามารถสร้าง Bell Sigil ได้ ส่วน Priest Sever บอกว่า Bell Warden เป็นเพียง \"กุญแจล็อก\" ของสิ่งที่อยู่ลึกกว่านั้น\n\n"
	recap+="[color=#d8c398][b]เป้าหมายปัจจุบัน[/b][/color]\n"+_current_objective()+"\n\n"
	recap+="[b]เอาตัวรอด[/b]\nBODY = พลังชีวิต • MIND = สติ • HUNGER ลดลงตามเวลา • TORCH ช่วยต้านความมืด\nBLEEDING จะลด BODY ต่อเนื่อง ใช้ Bandage หยุดเลือด และต้องใช้ Wax Seal เพื่อเซฟที่ Deep Shrine\n\n"
	recap+="[b]ปุ่ม[/b]\nWASD เดิน • Shift วิ่ง • E สำรวจ/คุย • I ไอเทม • Q Journal • T คบเพลิง • F9 โหลดเซฟ • F11 เต็มจอ"
	return recap

func _current_objective()->String:
	if bool(flags["boss_dead"]):
		return "Bell Warden ตายแล้ว → ไปทางตะวันออกและตรวจสอบ Heart Altar"
	if not bool(flags["prison_gate_open"]):
		if not bool(flags["rust_key"]):
			return "OLD PRISON → หา Rust Key ทางฝั่งตะวันตก แล้วกลับมาที่ประตูเหล็กด้านตะวันออก"
		return "OLD PRISON → มี Rust Key แล้ว ไปเปิดประตูเหล็กด้านตะวันออก"
	if not bool(flags["temple_gate_open"]):
		return "INFIRMARY → คุยกับ Maren สำรวจ Deep Shrine แล้วไปทางตะวันออกสู่ Temple"
	if not bool(flags["bell_sigil"]):
		return "TEMPLE → คุยกับ Sever แล้วใช้ Ritual Circle สร้าง Bell Sigil (Old Coin "+str(coins)+"/3 หรือถวายเลือด)"
	if not bool(flags["heart_gate_open"]):
		return "TEMPLE → นำ Bell Sigil ไปใช้กับประตูด้านตะวันออก"
	return "HEART OF THE BELL → ตามหาและกำจัด Bell Warden แล้วไปยัง Heart Altar"

func _toggle_fullscreen():
	var w=get_window()
	if w.mode==Window.MODE_FULLSCREEN or w.mode==Window.MODE_EXCLUSIVE_FULLSCREEN:
		w.mode=Window.MODE_WINDOWED
		w.size=Vector2i(1280,720)
	else:
		w.mode=Window.MODE_FULLSCREEN

func _make_panel(pos:Vector2,size:Vector2)->Panel:
	var p=Panel.new();p.position=pos;p.size=size
	var sb=StyleBoxFlat.new()
	sb.bg_color=Color(0.015,0.013,0.014,0.96)
	sb.border_color=Color(0.62,0.58,0.55,1.0)
	sb.set_border_width_all(2)
	sb.corner_radius_top_left=2;sb.corner_radius_top_right=2;sb.corner_radius_bottom_left=2;sb.corner_radius_bottom_right=2
	p.add_theme_stylebox_override("panel",sb)
	return p

func _button(text:String)->Button:
	var b=Button.new()
	b.text=text
	b.add_theme_font_size_override("font_size",18)
	b.add_theme_color_override("font_color",Color(0.92,0.90,0.86))
	b.add_theme_color_override("font_hover_color",Color.WHITE)
	var normal=StyleBoxFlat.new();normal.bg_color=Color(0.035,0.030,0.032,1);normal.border_color=Color(0.34,0.32,0.31,1);normal.set_border_width_all(1)
	var hover=StyleBoxFlat.new();hover.bg_color=Color(0.27,0.20,0.22,1);hover.border_color=Color(0.70,0.62,0.61,1);hover.set_border_width_all(2)
	var pressed=StyleBoxFlat.new();pressed.bg_color=Color(0.38,0.27,0.29,1);pressed.border_color=Color(0.82,0.74,0.71,1);pressed.set_border_width_all(2)
	b.add_theme_stylebox_override("normal",normal);b.add_theme_stylebox_override("hover",hover);b.add_theme_stylebox_override("pressed",pressed);b.add_theme_stylebox_override("focus",hover)
	return b

func _update_hud():
	if not hud_stats:return
	hud_location.text=current_location
	hud_stats.text="BODY %3d/%3d   MIND %3d   HUNGER %3d   TORCH %3d" % [int(body),int(max_body),int(mind),int(hunger),int(torch)]
	var status:Array[String]=[]
	if bleeding:status.append("BLEEDING")
	if infected:status.append("INFECTION")
	if fractured:status.append("FRACTURE")
	if bool(party["Maren"]["joined"]):status.append("PARTY: MAREN")
	hud_status.text=(" | ".join(status) if status.size()>0 else "Stable")+"   COINS: "+str(coins)
	if objective_label:
		objective_label.text="[color=#d8c398][b]NEXT[/b][/color]  "+_current_objective()+"\n[color=#817b75]Q Journal   I Inventory   F11 Fullscreen[/color]"
	if inventory_overlay and inventory_overlay.visible:
		inventory_status.text="[b]STATUS[/b]\nBODY "+str(int(body))+"/"+str(int(max_body))+"\nMIND "+str(int(mind))+"\nHUNGER "+str(int(hunger))+"\nTORCH "+str(int(torch))+"\n\nWeapon: "+equipped_weapon+"\nArmor: "+equipped_armor+"\nCoins: "+str(coins)
