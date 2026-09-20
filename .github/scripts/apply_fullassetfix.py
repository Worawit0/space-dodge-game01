from pathlib import Path
import re

path = Path("main.gd")
s = path.read_text(encoding="utf-8")

def sub(pattern, repl, name, flags=re.S):
    global s
    s2, n = re.subn(pattern, repl, s, count=1, flags=flags)
    if n != 1:
        raise SystemExit(f"fullassetfix: failed replacement {name}, count={n}")
    s = s2

def replace(old, new, name):
    global s
    if old not in s:
        raise SystemExit(f"fullassetfix: missing {name}")
    s = s.replace(old, new, 1)

# Make texture loading robust in CI, editor and exported builds.
sub(
r'func _load_tex\(path:String\) -> Texture2D:\n.*?(?=\nfunc _build_world_visuals)',
r'''func _load_tex(path:String) -> Texture2D:
	if ResourceLoader.exists(path):
		var resource = load(path) as Texture2D
		if resource:
			return resource
	# Raw-file fallback is important for freshly generated/copied PNGs before Godot import metadata settles.
	var absolute_path = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		var image = Image.new()
		var err = image.load(absolute_path)
		if err == OK and not image.is_empty():
			return ImageTexture.create_from_image(image)
	return null
''',
"robust texture loader"
)

# All strip animations use the same robust loader instead of silently returning an empty SpriteFrames.
sub(
r'func _add_strip_animation\(frames:SpriteFrames,name:String,path:String,frame_width:int,fps:float,looping:bool\):.*?(?=\nfunc _build_world_content)',
r'''func _add_strip_animation(frames:SpriteFrames,name:String,path:String,frame_width:int,fps:float,looping:bool):
	var tex = _load_tex(path)
	if not tex:
		push_error("Animation texture missing: "+path)
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
''',
"strip animation loader"
)

# New save namespace so old broken saves cannot leak state into the fixed build.
s = s.replace(
    'const SAVE_PATH := "user://forsaken_depths_cinematic_v4_save.json"',
    'const SAVE_PATH := "user://forsaken_depths_fullasset_v5_save.json"'
)

# Decorative prop pass after gameplay objects.
replace(
    "\t_build_world_content()\n\t_build_ui()",
    "\t_build_world_content()\n\t_build_environment_props()\n\t_build_ui()",
    "ready environment props"
)

# Replace the placeholder-looking gate with a physics-aligned iron gate drawn from the same dimensions.
sub(
r'func _make_gate\(id:String,pos:Vector2,need:String,flag_name:String\):.*?(?=\nfunc _make_pickup)',
r'''func _make_gate(id:String,pos:Vector2,need:String,flag_name:String):
	var holder = Node2D.new()
	holder.position = pos
	holder.name = id
	holder.z_index = 5
	add_child(holder)

	# Visual and collision share the same height, so there is no invisible gap to walk through.
	var gate_height := 226.0
	var gate_width := 112.0

	var back = Polygon2D.new()
	back.polygon = PackedVector2Array([
		Vector2(-gate_width/2.0,-gate_height/2.0),
		Vector2(gate_width/2.0,-gate_height/2.0),
		Vector2(gate_width/2.0,gate_height/2.0),
		Vector2(-gate_width/2.0,gate_height/2.0)
	])
	back.color = Color(0.055,0.045,0.043,0.88)
	holder.add_child(back)

	for x in [-45.0,-27.0,-9.0,9.0,27.0,45.0]:
		var bar = Line2D.new()
		bar.points = PackedVector2Array([Vector2(x,-106),Vector2(x,106)])
		bar.width = 7.0
		bar.default_color = Color(0.19,0.16,0.14,1.0)
		holder.add_child(bar)
	for y in [-76.0,0.0,76.0]:
		var brace = Line2D.new()
		brace.points = PackedVector2Array([Vector2(-54,y),Vector2(54,y)])
		brace.width = 9.0
		brace.default_color = Color(0.24,0.19,0.15,1.0)
		holder.add_child(brace)

	var frame = Line2D.new()
	frame.points = PackedVector2Array([
		Vector2(-56,-113),Vector2(56,-113),Vector2(56,113),
		Vector2(-56,113),Vector2(-56,-113)
	])
	frame.width = 8.0
	frame.default_color = Color(0.30,0.23,0.18,1.0)
	holder.add_child(frame)

	var lock = Polygon2D.new()
	lock.polygon = PackedVector2Array([
		Vector2(-13,-13),Vector2(13,-13),Vector2(13,13),Vector2(-13,13)
	])
	lock.color = Color(0.42,0.29,0.17,1.0)
	holder.add_child(lock)
	var keyhole = Line2D.new()
	keyhole.points = PackedVector2Array([Vector2(0,-4),Vector2(0,7)])
	keyhole.width = 4.0
	keyhole.default_color = Color(0.03,0.025,0.025,1.0)
	holder.add_child(keyhole)

	var collider = StaticBody2D.new()
	collider.collision_layer = 1
	collider.collision_mask = 1
	var cs = CollisionShape2D.new()
	var rs = RectangleShape2D.new()
	rs.size = Vector2(46,gate_height)
	cs.shape = rs
	collider.add_child(cs)
	holder.add_child(collider)
	_register_entry({"id":id,"node":holder,"type":"gate","need":need,"flag":flag_name,"active":true,"collider":collider})
''',
"gate"
)

# Use the new uploaded/public-equivalent monster packs in world exploration.
s = s.replace('"Maw Wretch","demon_maw",78,15,false', '"Flesh Gaoler","orc_gaoler",84,16,false')
s = s.replace('"Bell Husk","demon_bell",92,17,false', '"Winged Husk","flying_demon",96,18,false')
s = s.replace('"Faceless Devotee","demon_bell",108,20,false', '"Winged Penitent","flying_demon",112,21,false')
s = s.replace('"The Bell Warden","boss",260,29,true', '"The Bell Warden","demon_slime_boss",300,31,true')

# Replace enemy builder with normalized animated sheets created by the build workflow.
sub(
r'func _make_enemy\(id:String,pos:Vector2,label:String,art:String,enemy_body:int,damage:int,boss_enemy:bool\):.*?(?=\nfunc _build_horror_frames)',
r'''func _make_enemy(id:String,pos:Vector2,label:String,art:String,enemy_body:int,damage:int,boss_enemy:bool):
	var holder = CharacterBody2D.new()
	holder.position = pos
	holder.name = id
	holder.collision_layer = 2
	holder.collision_mask = 1
	holder.z_index = 3
	add_child(holder)

	var cs = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 25.0 if not boss_enemy else 42.0
	cs.shape = shape
	holder.add_child(cs)

	var sprite = AnimatedSprite2D.new()
	if art == "orc_gaoler":
		sprite.sprite_frames = _build_full_enemy_frames("orc",6,8)
		sprite.scale = Vector2(0.90,0.90)
		sprite.position = Vector2(0,-34)
		sprite.set_meta("sideview",true)
	elif art == "flying_demon":
		sprite.sprite_frames = _build_full_enemy_frames("flying_demon",4,4)
		sprite.scale = Vector2(1.48,1.48)
		sprite.position = Vector2(0,-44)
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
		red.texture_scale = 0.58
		red.energy = 1.35
		red.color = Color(0.70,0.05,0.06)
		holder.add_child(red)

	var left = -560.0 if pos.x < 600 else (640.0 if pos.x < 1800 else (1840.0 if pos.x < 3000 else 3040.0))
	var right = 560.0 if pos.x < 600 else (1760.0 if pos.x < 1800 else (2960.0 if pos.x < 3000 else 4560.0))
	_register_entry({
		"id":id,"node":holder,"type":"enemy","label":label,"art":art,"body":enemy_body,"damage":damage,"boss":boss_enemy,"active":true,
		"sprite":sprite,"home":pos,"wander_dir":Vector2.ZERO,"wander_time":0.0,"room_left":left,"room_right":right,
		"speed":78.0 if boss_enemy else (82.0 if art=="flying_demon" else 66.0),
		"detect":310.0 if boss_enemy else (245.0 if art=="flying_demon" else 205.0)
	})
''',
"enemy builder"
)

# Insert a reusable frame loader before legacy horror loader.
insert = r'''
func _build_full_enemy_frames(folder:String,idle_count:int,walk_count:int)->SpriteFrames:
	var frames = SpriteFrames.new()
	frames.remove_animation("default")
	for dir in ["down","left","right","up"]:
		var idle = "idle_"+dir
		var walk = "walk_"+dir
		frames.add_animation(idle)
		frames.set_animation_speed(idle,5.0)
		frames.set_animation_loop(idle,true)
		frames.add_animation(walk)
		frames.set_animation_speed(walk,8.0)
		frames.set_animation_loop(walk,true)
		for i in range(idle_count):
			var p = "res://assets/full/enemies/"+folder+"/idle_%02d.png" % i
			var tex = _load_tex(p)
			if tex:
				frames.add_frame(idle,tex)
		for i in range(walk_count):
			var p = "res://assets/full/enemies/"+folder+"/walk_%02d.png" % i
			var tex = _load_tex(p)
			if tex:
				frames.add_frame(walk,tex)
	return frames

'''
replace("func _build_horror_frames(art:String)->SpriteFrames:\n", insert+"func _build_horror_frames(art:String)->SpriteFrames:\n", "full enemy loader")

# Side-view assets face left/right by flip, while retaining collision AI.
replace(
'''\tvar name=("walk_" if vel.length()>5.0 else "idle_")+dir
\tif sprite.animation!=name:
\t\tsprite.play(name)
''',
'''\tvar name=("walk_" if vel.length()>5.0 else "idle_")+dir
\tif sprite.has_meta("sideview") and abs(vel.x)>0.1:
\t\tsprite.flip_h = vel.x < 0
\tif sprite.animation!=name:
\t\tsprite.play(name)
''',
"enemy flip"
)

# Add set dressing from the safe monster/scene assets already packaged with the project.
# These are non-blocking and are kept against room edges so physics remains readable.
insert_props = r'''
func _build_environment_props():
	var props = [
		["res://assets/full/props/cage.png",Vector2(-430,-175),Vector2(0.78,0.78),Color(0.72,0.68,0.64,1)],
		["res://assets/full/props/gore.png",Vector2(280,205),Vector2(0.62,0.62),Color(0.78,0.54,0.50,0.86)],
		["res://assets/full/props/lantern.png",Vector2(720,-210),Vector2(0.65,0.65),Color.WHITE],
		["res://assets/full/props/shelf.png",Vector2(980,-205),Vector2(0.78,0.78),Color(0.72,0.70,0.68,1)],
		["res://assets/full/props/gore.png",Vector2(1510,210),Vector2(0.50,0.50),Color(0.72,0.47,0.45,0.82)],
		["res://assets/full/props/pillar.png",Vector2(2050,-215),Vector2(0.95,0.95),Color(0.74,0.68,0.64,1)],
		["res://assets/full/props/altar.png",Vector2(2430,-195),Vector2(0.82,0.82),Color(0.77,0.66,0.61,1)],
		["res://assets/full/props/skull.png",Vector2(2770,205),Vector2(1.05,1.05),Color(0.84,0.76,0.65,1)],
		["res://assets/full/props/pillar.png",Vector2(3380,-205),Vector2(1.05,1.05),Color(0.63,0.56,0.55,1)],
		["res://assets/full/props/altar.png",Vector2(4250,-170),Vector2(0.92,0.92),Color(0.66,0.53,0.52,1)]
	]
	for p in props:
		_add_environment_prop(String(p[0]),Vector2(p[1]),Vector2(p[2]),Color(p[3]))

func _add_environment_prop(path:String,pos:Vector2,scale_value:Vector2,tint:Color):
	if not ResourceLoader.exists(path):
		return
	var holder = Node2D.new()
	holder.position = pos
	holder.z_index = 2
	add_child(holder)
	var sprite = Sprite2D.new()
	sprite.texture = _load_tex(path)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = scale_value
	sprite.modulate = tint
	holder.add_child(sprite)
	if path.contains("lantern"):
		var light = PointLight2D.new()
		light.texture = radial_light_texture
		light.texture_scale = 0.36
		light.energy = 0.58
		light.color = Color(0.92,0.51,0.24)
		holder.add_child(light)

'''
replace("func _make_static_rect(center:Vector2,size:Vector2):\n", insert_props+"func _make_static_rect(center:Vector2,size:Vector2):\n", "environment props")

# Gate prompt now tells the player what the gate needs.
replace(
'''\t\t"gate": return "Inspect gate"
''',
'''\t\t"gate":
\t\t\tvar gate_id=String(e.get("id",""))
\t\t\tif gate_id=="prison_gate": return "Unlock iron gate" if bool(flags["rust_key"]) else "Locked — Rust Key required"
\t\t\tif gate_id=="heart_gate": return "Use Bell Sigil" if bool(flags["bell_sigil"]) else "Sealed — Bell Sigil required"
\t\t\treturn "Open gate"
''',
"gate prompt"
)

# Visible, reliable equip UX. Weapon damage already reads equipped_weapon in battle.
sub(
r'func _refresh_inventory_tab\(\):.*?(?=\nfunc _use_item)',
r'''func _refresh_inventory_tab():
	for c in inventory_list.get_children():
		c.queue_free()
	var entries:Array=[]
	match inventory_current_tab:
		"Item":
			for k in inventory.keys():
				if int(inventory[k])>0:
					entries.append({"name":String(k),"count":int(inventory[k])})
		"Weapon":
			for k in weapons:
				entries.append({"name":String(k),"count":1})
		"Armor":
			for k in armor:
				entries.append({"name":String(k),"count":1})
		"Books":
			for k in books:
				entries.append({"name":String(k),"count":1})
		"Key Items":
			for k in key_items:
				entries.append({"name":String(k),"count":1})

	for data in entries:
		var name=String(data["name"])
		var suffix=""
		if inventory_current_tab=="Item":
			suffix="  x"+str(data["count"])
		elif inventory_current_tab=="Weapon" and name==equipped_weapon:
			suffix="   ✓ EQUIPPED"
		elif inventory_current_tab=="Armor" and name==equipped_armor:
			suffix="   ✓ EQUIPPED"
		var b=_button(name+suffix)
		b.custom_minimum_size=Vector2(420,48)
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		var icon_path=_item_icon_path(name)
		if icon_path!="":
			b.icon=_load_tex(icon_path)
		b.pressed.connect(func():_select_inventory_entry(name))
		inventory_list.add_child(b)

func _select_inventory_entry(name:String):
	inventory_selected=name
	var equip_note=""
	if inventory_current_tab=="Weapon":
		equip_note="\n\n[color=#d7c088]Equipped weapon[/color]" if name==equipped_weapon else "\n\nAttack bonus: +"+str(_weapon_value(name))
	elif inventory_current_tab=="Armor":
		equip_note="\n\n[color=#d7c088]Equipped armor[/color]" if name==equipped_armor else "\n\nDefense: "+str(_armor_value(name))
	inventory_desc.text="[b]"+name+"[/b]\n\n"+_item_description(name)+equip_note
	inventory_use_button.visible=inventory_current_tab in ["Item","Weapon","Armor"]
	if inventory_current_tab=="Item":
		inventory_use_button.text="USE"
		inventory_use_button.disabled=false
	elif inventory_current_tab=="Weapon":
		inventory_use_button.text="EQUIPPED" if name==equipped_weapon else "EQUIP WEAPON"
		inventory_use_button.disabled=name==equipped_weapon
	elif inventory_current_tab=="Armor":
		inventory_use_button.text="EQUIPPED" if name==equipped_armor else "EQUIP ARMOR"
		inventory_use_button.disabled=name==equipped_armor

func _inventory_use_selected():
	if inventory_selected=="":
		return
	if inventory_current_tab=="Item":
		_use_item(inventory_selected)
	elif inventory_current_tab=="Weapon":
		if not weapons.has(inventory_selected):
			_show_message("That weapon is not in your inventory.")
			return
		equipped_weapon=inventory_selected
		_play_sfx("ui")
		_show_message("Equipped weapon: "+inventory_selected+"  (ATK +"+str(_weapon_bonus())+")")
	elif inventory_current_tab=="Armor":
		if not armor.has(inventory_selected):
			_show_message("That armor is not in your inventory.")
			return
		equipped_armor=inventory_selected
		_play_sfx("ui")
		_show_message("Equipped armor: "+inventory_selected+"  (DEF "+str(_armor_defense())+")")
	_update_hud()
	_select_inventory_entry(inventory_selected)
	_refresh_inventory_tab()

func _weapon_value(name:String)->int:
	match name:
		"Bearded Axe": return 7
		"Greatsword": return 10
		_: return 4

func _armor_value(name:String)->int:
	match name:
		"Chainmail Chestpiece": return 3
		"Plate Chestpiece": return 6
		_: return 0
''',
"inventory equip"
)

# Existing combat helpers now delegate to the same values shown by inventory.
sub(
r'func _weapon_bonus\(\)->int:\n.*?(?=\nfunc _armor_defense)',
r'''func _weapon_bonus()->int:
	return _weapon_value(equipped_weapon)
''',
"weapon bonus"
)
sub(
r'func _armor_defense\(\)->int:\n.*?(?=\nfunc _battle_enemy_dead)',
r'''func _armor_defense()->int:
	return _armor_value(equipped_armor)
''',
"armor defense"
)

# Better inventory status readability and explicit equipped stats.
replace(
'''inventory_status.text="[b]STATUS[/b]\\nBODY "+str(int(body))+"/"+str(int(max_body))+"\\nMIND "+str(int(mind))+"\\nHUNGER "+str(int(hunger))+"\\nTORCH "+str(int(torch))+"\\n\\nWeapon: "+equipped_weapon+"\\nArmor: "+equipped_armor+"\\nCoins: "+str(coins)''',
'''inventory_status.text="[b]EQUIPPED[/b]\\nWeapon: "+equipped_weapon+"   ATK +"+str(_weapon_bonus())+"\\nArmor: "+equipped_armor+"   DEF "+str(_armor_defense())+"\\n\\n[b]STATUS[/b]\\nBODY "+str(int(body))+"/"+str(int(max_body))+"   MIND "+str(int(mind))+"\\nHUNGER "+str(int(hunger))+"   TORCH "+str(int(torch))+"\\nCoins: "+str(coins)''',
"inventory status"
)

# Avoid the horizontal scrollbar seen in the screenshot and enlarge the right information panel.
replace(
'''var scroll=ScrollContainer.new();scroll.position=Vector2(30,138);scroll.size=Vector2(470,390);frame.add_child(scroll)''',
'''var scroll=ScrollContainer.new();scroll.position=Vector2(30,138);scroll.size=Vector2(470,390);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;frame.add_child(scroll)''',
"inventory scroll"
)
replace(
'''inventory_status=RichTextLabel.new();inventory_status.bbcode_enabled=true;inventory_status.position=Vector2(535,335);inventory_status.size=Vector2(500,155);inventory_status.add_theme_font_size_override("normal_font_size",18);frame.add_child(inventory_status)''',
'''inventory_status=RichTextLabel.new();inventory_status.bbcode_enabled=true;inventory_status.position=Vector2(535,335);inventory_status.size=Vector2(500,175);inventory_status.add_theme_font_size_override("normal_font_size",18);frame.add_child(inventory_status)''',
"inventory status box"
)

# Real horror audio: prefer uploaded-equivalent MP3/OGG assets; fall back to old generated WAV.
sub(
r'func _build_audio\(\):.*?(?=\nfunc _show_message)',
r'''func _build_audio():
	ambient_player=AudioStreamPlayer.new()
	ambient_player.name="Ambient"
	ambient_player.volume_db=-18.0
	add_child(ambient_player)
	sfx_player=AudioStreamPlayer.new()
	sfx_player.name="SFX"
	sfx_player.volume_db=-7.0
	add_child(sfx_player)
	battle_music_player=AudioStreamPlayer.new()
	battle_music_player.name="BattleAudio"
	battle_music_player.volume_db=-9.0
	add_child(battle_music_player)
	var ambient=_load_audio_any("ambient")
	if ambient:
		ambient_player.stream=ambient
		ambient_player.finished.connect(func(): ambient_player.play())
		ambient_player.play()

func _load_audio(path:String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	return null

func _load_audio_any(name:String)->AudioStream:
	for ext in [".mp3",".ogg",".wav"]:
		var path="res://assets/audio/"+name+ext
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null

func _play_sfx(name:String):
	if not sfx_player:
		return
	var stream=_load_audio_any(name)
	if stream:
		sfx_player.stop()
		sfx_player.stream=stream
		sfx_player.play()
''',
"audio"
)

# Monster growl when an encounter triggers.
replace(
'''func _start_battle(e:Dictionary):
	enemy_battle_lock=true
	_play_sfx("battle_start")''',
'''func _start_battle(e:Dictionary):
	enemy_battle_lock=true
	_play_sfx("monster_growl")''',
"battle growl"
)

# Use real asset portraits in battle, including a visible boss over the cinematic background.
sub(
r'\tvar art=String\(e\["art"\]\)\n\tbattle_background\.visible=.*?(?=\n\tbattle_enemy_name\.text=String\(e\["label"\]\))',
r'''\tvar art=String(e["art"])
	battle_background.visible=bool(e["boss"])
	battle_enemy_art.visible=true
	if bool(e["boss"]):
		battle_background.texture=_load_tex("res://assets/cinematic/boss_bg.jpg")
	if art=="orc_gaoler":
		battle_enemy_art.texture=_load_tex("res://assets/full/enemies/orc/idle_00.png")
	elif art=="flying_demon":
		battle_enemy_art.texture=_load_tex("res://assets/full/enemies/flying_demon/idle_00.png")
	elif art=="demon_slime_boss":
		battle_enemy_art.texture=_load_tex("res://assets/full/enemies/demon_slime/idle_00.png")
	elif art=="demon_maw":
		battle_enemy_art.texture=_load_tex("res://assets/horror_maw.svg")
	elif art=="demon_bell":
		battle_enemy_art.texture=_load_tex("res://assets/horror_bell_husk.svg")
	else:
		battle_enemy_art.texture=_load_tex("res://assets/lucifer/battle/"+art+".png")
''',
"battle art"
)

# Cleaner labels in screenshots.
s = s.replace('"Take "+String(e["label"])', '"เก็บ "+String(e["label"])')
s = s.replace('"Confront "+String(e["label"])', '"เผชิญหน้า "+String(e["label"])')
s = s.replace('"Talk to "+String(e["label"])', '"คุยกับ "+String(e["label"])')

path.write_text(s, encoding="utf-8")
print("fullassetfix applied", len(s))
