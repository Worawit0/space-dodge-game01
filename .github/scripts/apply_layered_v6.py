from pathlib import Path
import re

path = Path("main.gd")
s = path.read_text(encoding="utf-8")

def sub(pattern, repl, name, flags=re.S):
    global s
    s2, n = re.subn(pattern, repl, s, count=1, flags=flags)
    if n != 1:
        raise SystemExit(f"layered-v6: failed replacement {name}, count={n}")
    s = s2

def replace(old, new, name):
    global s
    if old not in s:
        raise SystemExit(f"layered-v6: missing {name}")
    s = s.replace(old, new, 1)

# Fresh save namespace for the structural map/audio/UI overhaul.
s = s.replace(
    'const SAVE_PATH := "user://forsaken_depths_fullasset_v5_save.json"',
    'const SAVE_PATH := "user://forsaken_depths_layered_v6_save.json"'
)

# Structural scene layers + HUD bars + audio pool.
replace(
'''var hud_panel: Panel
var hud_location: Label
var hud_stats: Label
var hud_status: Label''',
'''var hud_panel: Panel
var hud_location: Label
var hud_stats: Label
var hud_status: Label
var body_bar: ProgressBar
var mind_bar: ProgressBar
var hunger_bar: ProgressBar
var torch_bar: ProgressBar

var floor_layer: Node2D
var back_layer: Node2D
var world_fx_layer: Node2D
var foreground_layer: Node2D''',
"layer and HUD vars"
)

replace(
'''var ambient_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var battle_music_player: AudioStreamPlayer''',
'''var ambient_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var battle_music_player: AudioStreamPlayer
var ui_audio_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_cursor := 0''',
"audio pool vars"
)

# New layer-based dungeon construction. Floor, back walls and foreground are truly separate nodes/z-levels.
sub(
r'func _build_world_visuals\(\):.*?(?=\nfunc _build_collision_layout)',
r'''func _build_world_visuals():
	floor_layer = Node2D.new()
	floor_layer.name = "Layer1_Floor"
	floor_layer.z_index = -30
	add_child(floor_layer)

	back_layer = Node2D.new()
	back_layer.name = "Layer2_BackWalls"
	back_layer.z_index = -10
	add_child(back_layer)

	world_fx_layer = Node2D.new()
	world_fx_layer.name = "Layer3_World"
	world_fx_layer.z_index = 0
	add_child(world_fx_layer)

	foreground_layer = Node2D.new()
	foreground_layer.name = "Layer4_Foreground"
	foreground_layer.z_index = 20
	add_child(foreground_layer)

	# Four connected rooms. The ground is a repeatable tile from the new dungeon pack, not a baked fake wall image.
	var room_specs = [
		[Vector2(0,0),Vector2(1200,800),Color(0.72,0.68,0.65,1.0)],
		[Vector2(1200,0),Vector2(1200,800),Color(0.66,0.70,0.66,1.0)],
		[Vector2(2400,0),Vector2(1200,800),Color(0.73,0.64,0.61,1.0)],
		[Vector2(3800,0),Vector2(1600,800),Color(0.62,0.52,0.54,1.0)]
	]
	for spec in room_specs:
		_make_floor_room(Vector2(spec[0]),Vector2(spec[1]),Color(spec[2]))

	# Visible perimeter walls: these replace the old invisible boundaries.
	_make_wall_block(Vector2(2000,-365),Vector2(5200,70))
	_make_wall_block(Vector2(2000,365),Vector2(5200,70))
	_make_wall_block(Vector2(-565,0),Vector2(70,800))
	_make_wall_block(Vector2(4565,0),Vector2(70,800))

	# Passage dividers leave a 230 px doorway opening for each real gate.
	for gx in [600.0,1800.0,3000.0]:
		_make_wall_block(Vector2(gx,-270),Vector2(70,260))
		_make_wall_block(Vector2(gx,270),Vector2(70,260))
		_make_gate_arch(gx)

	_build_collision_layout()
	_build_layered_set_dressing()

	darkness = CanvasModulate.new()
	darkness.color = Color(0.23,0.22,0.23,1.0)
	add_child(darkness)

func _make_floor_room(center:Vector2,size:Vector2,tint:Color):
	var floor = Sprite2D.new()
	floor.texture = _load_tex("res://assets/v6/dungeon/floor_tile.png")
	floor.position = center
	floor.centered = true
	floor.region_enabled = true
	floor.region_rect = Rect2(-size/2.0,size)
	floor.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	floor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floor.modulate = tint
	floor_layer.add_child(floor)

	# Soft room-edge stain adds depth without pretending to be collision.
	for y in [-320.0,320.0]:
		var shadow = Polygon2D.new()
		shadow.position = center + Vector2(0,y)
		shadow.polygon = PackedVector2Array([
			Vector2(-size.x/2.0,-40),Vector2(size.x/2.0,-40),
			Vector2(size.x/2.0,40),Vector2(-size.x/2.0,40)
		])
		shadow.color = Color(0.015,0.008,0.008,0.42)
		back_layer.add_child(shadow)

func _make_gate_arch(x:float):
	# Foreground stone lip makes the passage read as a hole through a thick wall.
	for side in [-1.0,1.0]:
		var cap = Sprite2D.new()
		cap.texture = _load_tex("res://assets/v6/dungeon/wall_top_tile.png")
		cap.position = Vector2(x + side*42.0,-120)
		cap.scale = Vector2(2.4,1.6)
		cap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		foreground_layer.add_child(cap)

func _build_layered_set_dressing():
	# Back-layer stains/torches and foreground silhouettes create parallax/occlusion.
	var back_specs = [
		[Vector2(-410,-175),0.70],[Vector2(850,-195),0.62],[Vector2(1450,-190),0.72],
		[Vector2(2130,-185),0.76],[Vector2(2780,-195),0.68],[Vector2(3350,-190),0.80],[Vector2(4200,-190),0.84]
	]
	for spec in back_specs:
		var decal = Sprite2D.new()
		decal.texture = _load_tex("res://assets/v6/dungeon/wall_decal.png")
		decal.position = Vector2(spec[0])
		decal.scale = Vector2(float(spec[1]),float(spec[1]))
		decal.modulate = Color(0.55,0.46,0.43,0.58)
		decal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		back_layer.add_child(decal)

	# Foreground strips intentionally pass in front of the player at room edges.
	for x in [-500.0,520.0,680.0,1720.0,1880.0,2920.0,3080.0,4460.0]:
		var fg = Sprite2D.new()
		fg.texture = _load_tex("res://assets/v6/dungeon/foreground_rock.png")
		fg.position = Vector2(x,315)
		fg.scale = Vector2(0.62,0.62)
		fg.modulate = Color(0.42,0.36,0.35,0.92)
		fg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		foreground_layer.add_child(fg)
''',
"layered world"
)

# Wall = textured body on layer 2 + shadow + top cap on layer 4. Collision exactly matches the visible body.
sub(
r'func _make_wall_block\(center:Vector2,size:Vector2\):.*?(?=\nfunc _build_player)',
r'''func _make_wall_block(center:Vector2,size:Vector2):
	var holder = Node2D.new()
	holder.position = center
	holder.name = "Wall"
	back_layer.add_child(holder)

	var shadow = Polygon2D.new()
	shadow.position = Vector2(10,14)
	shadow.polygon = PackedVector2Array([
		Vector2(-size.x/2.0,-size.y/2.0),Vector2(size.x/2.0,-size.y/2.0),
		Vector2(size.x/2.0,size.y/2.0),Vector2(-size.x/2.0,size.y/2.0)
	])
	shadow.color = Color(0,0,0,0.52)
	holder.add_child(shadow)

	var wall = Sprite2D.new()
	wall.texture = _load_tex("res://assets/v6/dungeon/wall_tile.png")
	wall.centered = true
	wall.region_enabled = true
	wall.region_rect = Rect2(-size/2.0,size)
	wall.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	wall.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wall.modulate = Color(0.84,0.76,0.70,1.0)
	holder.add_child(wall)

	var body_node = StaticBody2D.new()
	body_node.collision_layer = 1
	body_node.collision_mask = 1
	var cs = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	body_node.add_child(cs)
	holder.add_child(body_node)

	# Layer 4 cap overlaps actors slightly, giving wall thickness instead of flat rectangles.
	var cap = Sprite2D.new()
	cap.texture = _load_tex("res://assets/v6/dungeon/wall_top_tile.png")
	cap.position = center + Vector2(0,-size.y/2.0+10)
	cap.centered = true
	cap.region_enabled = true
	cap.region_rect = Rect2(Vector2(-size.x/2.0,-16),Vector2(size.x,32))
	cap.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	cap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cap.modulate = Color(0.96,0.86,0.77,1.0)
	foreground_layer.add_child(cap)
''',
"layered wall"
)

# Use one coherent monster family for normal encounters.
s = s.replace('"Flesh Gaoler","orc_gaoler",84,16,false', '"Blood Gaoler","blood_monster",88,17,false')
s = s.replace('"Winged Husk","flying_demon",96,18,false', '"Ash Demon","demon_a",100,19,false')
s = s.replace('"Winged Penitent","flying_demon",112,21,false', '"Temple Demon","demon_a",116,22,false')

# Enemy builder: Tiny RPG Pack 02 for normal enemies, old Demon Slime retained only for the boss.
sub(
r'func _make_enemy\(id:String,pos:Vector2,label:String,art:String,enemy_body:int,damage:int,boss_enemy:bool\):.*?(?=\nfunc _build_full_enemy_frames)',
r'''func _make_enemy(id:String,pos:Vector2,label:String,art:String,enemy_body:int,damage:int,boss_enemy:bool):
	var holder = CharacterBody2D.new()
	holder.position = pos
	holder.name = id
	holder.collision_layer = 2
	holder.collision_mask = 1
	holder.z_index = 4
	add_child(holder)

	var cs = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 24.0 if not boss_enemy else 42.0
	cs.shape = shape
	holder.add_child(cs)

	var sprite = AnimatedSprite2D.new()
	if art == "blood_monster":
		sprite.sprite_frames = _build_v6_enemy_frames("blood_monster")
		sprite.scale = Vector2(0.92,0.92)
		sprite.position = Vector2(0,-38)
		sprite.set_meta("sideview",true)
	elif art == "demon_a":
		sprite.sprite_frames = _build_v6_enemy_frames("demon_a")
		sprite.scale = Vector2(0.96,0.96)
		sprite.position = Vector2(0,-40)
		sprite.set_meta("sideview",true)
	elif art == "demon_slime_boss":
		sprite.sprite_frames = _build_full_enemy_frames("demon_slime",6,12)
		sprite.scale = Vector2(0.82,0.82)
		sprite.position = Vector2(0,-54)
		sprite.set_meta("sideview",true)
	else:
		sprite.sprite_frames = _build_horror_frames(art)
		sprite.scale = Vector2(0.50,0.50)
		sprite.position = Vector2(0,-42)

	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.play("idle_down")
	holder.add_child(sprite)

	if boss_enemy:
		var red = PointLight2D.new()
		red.texture = radial_light_texture
		red.texture_scale = 0.60
		red.energy = 1.30
		red.color = Color(0.68,0.04,0.05)
		holder.add_child(red)

	var left = -540.0 if pos.x < 600 else (660.0 if pos.x < 1800 else (1860.0 if pos.x < 3000 else 3060.0))
	var right = 540.0 if pos.x < 600 else (1740.0 if pos.x < 1800 else (2940.0 if pos.x < 3000 else 4500.0))
	_register_entry({
		"id":id,"node":holder,"type":"enemy","label":label,"art":art,"body":enemy_body,"damage":damage,"boss":boss_enemy,"active":true,
		"sprite":sprite,"home":pos,"wander_dir":Vector2.ZERO,"wander_time":0.0,"room_left":left,"room_right":right,
		"speed":82.0 if boss_enemy else 68.0,
		"detect":310.0 if boss_enemy else 220.0
	})

func _build_v6_enemy_frames(folder:String)->SpriteFrames:
	var frames = SpriteFrames.new()
	frames.remove_animation("default")
	var base = "res://assets/v6/enemies/"+folder+"/"
	var counts = {"idle":6,"walk":8}
	for dir in ["down","left","right","up"]:
		for state in ["idle","walk"]:
			var anim = state+"_"+dir
			frames.add_animation(anim)
			frames.set_animation_speed(anim,5.5 if state=="idle" else 8.0)
			frames.set_animation_loop(anim,true)
			for i in range(int(counts[state])):
				var tex = _load_tex(base+state+"_%02d.png" % i)
				if tex:
					frames.add_frame(anim,tex)
	return frames
''',
"v6 enemy builder"
)

# Actual Demon Door art, plus aligned collision. Each gate can use a distinct color/variant.
sub(
r'func _make_gate\(id:String,pos:Vector2,need:String,flag_name:String\):.*?(?=\nfunc _make_pickup)',
r'''func _make_gate(id:String,pos:Vector2,need:String,flag_name:String):
	var holder = Node2D.new()
	holder.position = pos
	holder.name = id
	holder.z_index = 8
	add_child(holder)

	var visual = Sprite2D.new()
	var gate_file = "prison.png"
	if id=="temple_gate": gate_file="temple.png"
	elif id=="heart_gate": gate_file="heart.png"
	visual.texture = _load_tex("res://assets/v6/gates/"+gate_file)
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.scale = Vector2(1.08,1.08)
	visual.position = Vector2(0,-8)
	holder.add_child(visual)

	var glow = PointLight2D.new()
	glow.texture = radial_light_texture
	glow.texture_scale = 0.38 if id!="heart_gate" else 0.55
	glow.energy = 0.26 if id!="heart_gate" else 0.55
	glow.color = Color(0.55,0.22,0.14) if id!="heart_gate" else Color(0.62,0.06,0.08)
	holder.add_child(glow)

	var collider = StaticBody2D.new()
	collider.collision_layer = 1
	collider.collision_mask = 1
	var cs = CollisionShape2D.new()
	var rs = RectangleShape2D.new()
	rs.size = Vector2(64,190)
	cs.shape = rs
	collider.add_child(cs)
	holder.add_child(collider)
	_register_entry({"id":id,"node":holder,"type":"gate","need":need,"flag":flag_name,"active":true,"collider":collider,"visual":visual})
''',
"demon door gate"
)

# Smooth gate opening: physics turns off immediately, visual retracts/fades instead of popping away.
sub(
r'func _open_gate\(e:Dictionary\):.*?(?=\nfunc _open_npc)',
r'''func _open_gate(e:Dictionary):
	var id = String(e["id"])
	if id=="prison_gate":
		if not bool(flags["rust_key"]):
			_show_dialogue("ประตูเหล็กถูกล็อกแน่น\\n\\nรูกุญแจเต็มไปด้วยสนิม แต่ Rust Key น่าจะใช้ได้",[{"text":"ออก","call":func():_close_dialogue()}])
			return
		flags["prison_gate_open"]=true
	elif id=="temple_gate":
		flags["temple_gate_open"]=true
	elif id=="heart_gate":
		if not bool(flags["bell_sigil"]):
			_show_dialogue("ตราประทับกลางประตูกำลังรอบางสิ่ง\\n\\nต้องใช้ Bell Sigil",[{"text":"ออก","call":func():_close_dialogue()}])
			return
		flags["heart_gate_open"]=true
	_play_sfx("door")
	_animate_gate_open(e)

func _animate_gate_open(e:Dictionary):
	e["active"]=false
	var id=String(e["id"])
	if not removed_ids.has(id):
		removed_ids.append(id)
	var collider=e.get("collider") as StaticBody2D
	if collider:
		collider.collision_layer=0
		collider.collision_mask=0
	var visual=e.get("visual") as Sprite2D
	var node=e["node"] as Node2D
	if visual:
		var tw=create_tween()
		tw.set_parallel(true)
		tw.tween_property(visual,"position:y",-130.0,0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(visual,"modulate:a",0.0,0.65)
		tw.set_parallel(false)
		tw.tween_callback(func(): node.visible=false)
	else:
		node.visible=false
''',
"gate opening"
)

# Battle artwork for the coherent v6 monster set.
s = s.replace(
'''if art=="orc_gaoler":
		battle_enemy_art.texture=_load_tex("res://assets/full/enemies/orc/idle_00.png")
	elif art=="flying_demon":
		battle_enemy_art.texture=_load_tex("res://assets/full/enemies/flying_demon/idle_00.png")''',
'''if art=="blood_monster":
		battle_enemy_art.texture=_load_tex("res://assets/v6/enemies/blood_monster/idle_00.png")
	elif art=="demon_a":
		battle_enemy_art.texture=_load_tex("res://assets/v6/enemies/demon_a/idle_00.png")'''
)

# Audio architecture: buses + six SFX voices + independent UI voice. Footsteps no longer cut doors/growls.
sub(
r'func _build_audio\(\):.*?(?=\nfunc _show_message)',
r'''func _build_audio():
	_ensure_audio_bus("Ambience",-6.0)
	_ensure_audio_bus("SFX",-2.0)
	_ensure_audio_bus("UI",-3.0)

	ambient_player=AudioStreamPlayer.new()
	ambient_player.name="Ambient"
	ambient_player.bus="Ambience"
	ambient_player.volume_db=-14.0
	add_child(ambient_player)

	battle_music_player=AudioStreamPlayer.new()
	battle_music_player.name="BattleAudio"
	battle_music_player.bus="Ambience"
	battle_music_player.volume_db=-10.0
	add_child(battle_music_player)

	ui_audio_player=AudioStreamPlayer.new()
	ui_audio_player.name="UIAudio"
	ui_audio_player.bus="UI"
	add_child(ui_audio_player)

	sfx_pool.clear()
	for i in range(6):
		var p=AudioStreamPlayer.new()
		p.name="SFX_%02d" % i
		p.bus="SFX"
		add_child(p)
		sfx_pool.append(p)
	sfx_player=sfx_pool[0]

	var ambient=_load_audio_any("ambient")
	if ambient:
		ambient_player.stream=ambient
		if ambient is AudioStreamMP3:
			(ambient as AudioStreamMP3).loop=true
		elif ambient is AudioStreamOggVorbis:
			(ambient as AudioStreamOggVorbis).loop=true
		ambient_player.play()

func _ensure_audio_bus(name:String,volume_db:float):
	var index=AudioServer.get_bus_index(name)
	if index<0:
		AudioServer.add_bus()
		index=AudioServer.bus_count-1
		AudioServer.set_bus_name(index,name)
	AudioServer.set_bus_volume_db(index,volume_db)

func _load_audio(path:String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	return null

func _load_audio_any(name:String)->AudioStream:
	for ext in [".ogg",".mp3",".wav"]:
		var audio_path="res://assets/audio/"+name+ext
		if ResourceLoader.exists(audio_path):
			var imported=load(audio_path) as AudioStream
			if imported:
				return imported
		var absolute_path=ProjectSettings.globalize_path(audio_path)
		if FileAccess.file_exists(absolute_path):
			if ext==".mp3":
				var mp3=AudioStreamMP3.load_from_file(absolute_path)
				if mp3:return mp3
			elif ext==".ogg":
				var ogg=AudioStreamOggVorbis.load_from_file(absolute_path)
				if ogg:return ogg
	return null

func _play_sfx(name:String):
	var stream=_load_audio_any(name)
	if not stream:
		return
	if name=="ui" and ui_audio_player:
		ui_audio_player.stop()
		ui_audio_player.stream=stream
		ui_audio_player.volume_db=-4.0
		ui_audio_player.play()
		return
	if sfx_pool.is_empty():
		return
	var chosen:AudioStreamPlayer=null
	for p in sfx_pool:
		if not p.playing:
			chosen=p
			break
	if chosen==null:
		chosen=sfx_pool[sfx_cursor%sfx_pool.size()]
		sfx_cursor=(sfx_cursor+1)%sfx_pool.size()
	chosen.stream=stream
	chosen.volume_db=-13.0 if name=="footstep" else (-7.0 if name=="monster_growl" else -5.0)
	chosen.pitch_scale=randf_range(0.96,1.04) if name=="footstep" else 1.0
	chosen.play()
''',
"pooled audio"
)

# Gothic UI HUD: compact panels plus four readable bars.
sub(
r'func _build_ui\(\):.*?(?=\nfunc _build_title_ui)',
r'''func _build_ui():
	ui=CanvasLayer.new()
	add_child(ui)
	var root=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)

	sanity_overlay=ColorRect.new()
	sanity_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sanity_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(sanity_overlay)

	hud_panel=_make_panel(Vector2(18,16),Vector2(392,154))
	root.add_child(hud_panel)
	hud_location=Label.new()
	hud_location.position=Vector2(20,12)
	hud_location.size=Vector2(350,28)
	hud_location.add_theme_font_size_override("font_size",21)
	hud_panel.add_child(hud_location)

	body_bar=_make_stat_bar("BODY",Vector2(20,47),Color(0.62,0.12,0.12,1.0))
	mind_bar=_make_stat_bar("MIND",Vector2(20,70),Color(0.25,0.38,0.62,1.0))
	hunger_bar=_make_stat_bar("HUNGER",Vector2(20,93),Color(0.55,0.42,0.18,1.0))
	torch_bar=_make_stat_bar("TORCH",Vector2(20,116),Color(0.78,0.42,0.13,1.0))
	for bar in [body_bar,mind_bar,hunger_bar,torch_bar]:
		hud_panel.add_child(bar)

	hud_stats=Label.new()
	hud_stats.visible=false
	hud_panel.add_child(hud_stats)
	hud_status=Label.new()
	hud_status.position=Vector2(205,12)
	hud_status.size=Vector2(170,30)
	hud_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	hud_status.add_theme_font_size_override("font_size",13)
	hud_panel.add_child(hud_status)

	objective_panel=_make_panel(Vector2(830,16),Vector2(430,122))
	root.add_child(objective_panel)
	objective_label=RichTextLabel.new()
	objective_label.bbcode_enabled=true
	objective_label.position=Vector2(20,14)
	objective_label.size=Vector2(390,94)
	objective_label.add_theme_font_size_override("normal_font_size",15)
	objective_panel.add_child(objective_label)

	prompt_label=Label.new()
	prompt_label.position=Vector2(450,647)
	prompt_label.size=Vector2(380,44)
	prompt_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size",19)
	root.add_child(prompt_label)

	message_label=Label.new()
	message_label.position=Vector2(350,34)
	message_label.size=Vector2(580,80)
	message_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size",17)
	root.add_child(message_label)

	_build_title_ui(root)
	_build_dialogue_ui(root)
	_build_ritual_ui(root)
	_build_inventory_ui(root)
	_build_battle_ui(root)
	_build_journal_ui(root)
	_build_story_ui(root)
	_build_ending_ui(root)

func _make_stat_bar(label_text:String,pos:Vector2,fill_color:Color)->ProgressBar:
	var bar=ProgressBar.new()
	bar.position=pos
	bar.size=Vector2(350,17)
	bar.min_value=0
	bar.max_value=100
	bar.value=100
	bar.show_percentage=false
	var bg=StyleBoxFlat.new()
	bg.bg_color=Color(0.025,0.021,0.022,0.96)
	bg.border_color=Color(0.30,0.25,0.23,1.0)
	bg.set_border_width_all(1)
	var fill=StyleBoxFlat.new()
	fill.bg_color=fill_color
	fill.border_color=fill_color.lightened(0.18)
	fill.set_border_width_all(1)
	bar.add_theme_stylebox_override("background",bg)
	bar.add_theme_stylebox_override("fill",fill)
	var label=Label.new()
	label.text=label_text
	label.position=Vector2(6,-2)
	label.size=Vector2(330,20)
	label.add_theme_font_size_override("font_size",12)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bar.add_child(label)
	return bar
''',
"gothic HUD"
)

# Global dark-age style applies to inventory, dialogue, journal, ritual and battle panels.
sub(
r'func _make_panel\(pos:Vector2,size:Vector2\)->Panel:.*?(?=\nfunc _button)',
r'''func _make_panel(pos:Vector2,size:Vector2)->Panel:
	var p=Panel.new()
	p.position=pos
	p.size=size
	var tex=_load_tex("res://assets/v6/ui/panel_frame.png")
	if tex:
		var sb=StyleBoxTexture.new()
		sb.texture=tex
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
			sb.set_texture_margin(side,18.0)
		p.add_theme_stylebox_override("panel",sb)
	else:
		var flat=StyleBoxFlat.new()
		flat.bg_color=Color(0.012,0.010,0.011,0.96)
		flat.border_color=Color(0.48,0.38,0.28,1)
		flat.set_border_width_all(3)
		p.add_theme_stylebox_override("panel",flat)
	return p
''',
"panel skin"
)

sub(
r'func _button\(text:String\)->Button:.*?(?=\nfunc _update_hud)',
r'''func _button(text:String)->Button:
	var b=Button.new()
	b.text=text
	b.add_theme_font_size_override("font_size",17)
	b.add_theme_color_override("font_color",Color(0.90,0.86,0.78))
	b.add_theme_color_override("font_hover_color",Color(1.0,0.94,0.78))
	for pair in [
		["normal","res://assets/v6/ui/button_normal.png"],
		["hover","res://assets/v6/ui/button_hover.png"],
		["pressed","res://assets/v6/ui/button_pressed.png"],
		["focus","res://assets/v6/ui/button_hover.png"]
	]:
		var tex=_load_tex(String(pair[1]))
		if tex:
			var sb=StyleBoxTexture.new()
			sb.texture=tex
			for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
				sb.set_texture_margin(side,12.0)
			b.add_theme_stylebox_override(String(pair[0]),sb)
	return b
''',
"button skin"
)

sub(
r'func _update_hud\(\):.*?(?=\n\nfunc _[a-zA-Z_])',
r'''func _update_hud():
	if not hud_location:
		return
	hud_location.text=current_location
	if body_bar:
		body_bar.max_value=max_body
		body_bar.value=body
	if mind_bar: mind_bar.value=mind
	if hunger_bar: hunger_bar.value=hunger
	if torch_bar: torch_bar.value=torch

	var status:Array[String]=[]
	if bleeding:status.append("BLEED")
	if infected:status.append("INFECT")
	if fractured:status.append("FRACTURE")
	if bool(party["Maren"]["joined"]):status.append("MAREN")
	hud_status.text=(" · ".join(status) if status.size()>0 else "STABLE")+"\\nCOINS "+str(coins)

	if objective_label:
		objective_label.text="[color=#d8b56d][b]OBJECTIVE[/b][/color]\\n"+_current_objective()+"\\n[color=#82786f]Q Journal   I Inventory   F11 Fullscreen[/color]"
	if inventory_overlay and inventory_overlay.visible:
		inventory_status.text="[b]EQUIPPED[/b]\\nWeapon: "+equipped_weapon+"   ATK +"+str(_weapon_bonus())+"\\nArmor: "+equipped_armor+"   DEF "+str(_armor_defense())+"\\n\\n[b]STATUS[/b]\\nBODY "+str(int(body))+"/"+str(int(max_body))+"   MIND "+str(int(mind))+"\\nHUNGER "+str(int(hunger))+"   TORCH "+str(int(torch))+"\\nCoins: "+str(coins)
''',
"HUD updates"
)

# Slightly stronger local light and mind-darkness while retaining visibility.
sub(
r'func _update_visual_effects\(\):.*?(?=\nfunc _update_traps)',
r'''func _update_visual_effects():
	if player_light:
		player_light.visible=torch_on and torch>0
		var fuel=clamp(torch/100.0,0.0,1.0)
		var flicker=0.96+0.035*sin(elapsed*17.0)+0.018*sin(elapsed*31.0)
		player_light.texture_scale=lerp(0.92,1.68,fuel)*flicker
		player_light.energy=lerp(0.90,1.85,fuel)*flicker
	if darkness:
		var low=1.0-clamp(mind/100.0,0.0,1.0)
		darkness.color=Color(0.25-low*0.07,0.235-low*0.075,0.24-low*0.075,1.0)
	if sanity_overlay:
		var danger=clamp((35.0-mind)/35.0,0.0,1.0)
		sanity_overlay.color=Color(0.18,0.0,0.02,danger*(0.07+0.025*sin(elapsed*2.5)))
''',
"lighting polish"
)

path.write_text(s, encoding="utf-8")
print("layered v6 patch applied", len(s))
