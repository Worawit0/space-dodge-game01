extends Node3D

const SAVE_PATH := "user://forsaken_save.json"
const WALK_SPEED := 4.0
const RUN_SPEED := 6.5
const INTERACT_RANGE := 2.2

var player: CharacterBody3D
var player_visual: Node3D
var camera: Camera3D
var torch_light: OmniLight3D
var ui: CanvasLayer
var hud_text: Label
var prompt_text: Label
var message_text: Label
var inventory_panel: Panel
var battle_panel: Panel
var battle_log: RichTextLabel
var dialogue_panel: Panel
var dialogue_text: Label
var dialogue_buttons: VBoxContainer
var ending_panel: Panel
var ending_text: Label

var hp := 100.0
var hunger := 100.0
var sanity := 100.0
var torch := 100.0
var bleeding := false
var infected := false
var fractured := false
var torch_on := true
var game_mode := "explore"
var coins := 0
var inventory := {
	"Ration": 2,
	"Bandage": 2,
	"Tonic": 1,
	"Splint": 1,
	"Antiseptic": 1,
	"Torch Oil": 1,
	"Wax Seal": 1
}
var flags := {
	"rust_key": false,
	"infirmary_open": false,
	"puzzle_done": false,
	"sigil": false,
	"maren_helped": false,
	"sever_spared": false,
	"boss_dead": false
}

var interactables: Array[Node3D] = []
var traps: Array[Node3D] = []
var trap_cooldowns := {}
var battle_enemy := {}
var battle_source: Node3D
var guarding := false
var last_message_time := 0.0
var elapsed := 0.0

func _ready():
	_build_environment()
	_build_player()
	_build_world()
	_build_ui()
	_show_message("The Forsaken Depths\nFind a way beneath the old prison.")
	if FileAccess.file_exists(SAVE_PATH):
		_show_message("Save found. Press F9 to load, or continue exploring.")
	set_process(true)

func _process(delta):
	elapsed += delta
	if game_mode == "explore":
		_update_survival(delta)
		_update_player(delta)
		_update_interaction_prompt()
		_update_traps(delta)
	_update_hud()
	if last_message_time > 0.0 and Time.get_ticks_msec() / 1000.0 - last_message_time > 4.0:
		message_text.text = ""
		last_message_time = 0.0

func _unhandled_key_input(event):
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_E and game_mode == "explore":
		_interact()
	elif event.keycode == KEY_I and game_mode == "explore":
		inventory_panel.visible = not inventory_panel.visible
		_refresh_inventory()
	elif event.keycode == KEY_T and game_mode == "explore":
		torch_on = not torch_on
		torch_light.visible = torch_on and torch > 0
	elif event.keycode == KEY_ESCAPE:
		inventory_panel.visible = false
		if dialogue_panel.visible:
			_close_dialogue()
	elif event.keycode == KEY_F5 and game_mode == "explore":
		_try_save()
	elif event.keycode == KEY_F9 and game_mode == "explore":
		_load_game()

func _build_environment():
	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.006, 0.007, 0.01)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.10, 0.09)
	env.ambient_light_energy = 0.35
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.09, 0.08)
	env.fog_density = 0.025
	env.fog_height = 1.0
	world_env.environment = env
	add_child(world_env)

	var moon = DirectionalLight3D.new()
	moon.light_color = Color(0.32, 0.37, 0.45)
	moon.light_energy = 0.25
	moon.rotation_degrees = Vector3(-55, -25, 0)
	moon.shadow_enabled = true
	add_child(moon)

func _build_player():
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 0.9, 1.5)
	add_child(player)

	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.45
	shape.shape = capsule
	player.add_child(shape)

	player_visual = _model("character-human.glb")
	if player_visual == null:
		var fallback = MeshInstance3D.new()
		var cap = CapsuleMesh.new()
		cap.radius = 0.35
		cap.height = 1.6
		fallback.mesh = cap
		player_visual = fallback
	player_visual.scale = Vector3.ONE * 0.85
	player_visual.position.y = -0.9
	player.add_child(player_visual)

	torch_light = OmniLight3D.new()
	torch_light.light_color = Color(1.0, 0.56, 0.26)
	torch_light.light_energy = 2.2
	torch_light.omni_range = 7.5
	torch_light.shadow_enabled = true
	torch_light.position = Vector3(0.25, 0.75, 0.2)
	player.add_child(torch_light)

	camera = Camera3D.new()
	camera.current = true
	camera.position = Vector3(0, 7.8, 9.5)
	camera.rotation_degrees = Vector3(-32, 0, 0)
	player.add_child(camera)

func _build_world():
	# Four connected spaces: Prison -> Infirmary -> Temple -> Bell Heart
	_make_room(Vector3(0,0,0), Vector2(14,12), "OLD PRISON")
	_make_room(Vector3(18,0,0), Vector2(14,12), "ABANDONED INFIRMARY")
	_make_room(Vector3(36,0,0), Vector2(14,12), "TEMPLE DISTRICT")
	_make_room(Vector3(54,0,0), Vector2(14,12), "HEART OF THE BELL")

	_make_gate(Vector3(8.8,0,0), "gate_prison", "Rust Key", "infirmary_open")
	_make_gate(Vector3(26.8,0,0), "gate_temple", "Bell Puzzle", "puzzle_done")
	_make_gate(Vector3(44.8,0,0), "gate_heart", "Bell Sigil", "sigil")

	_make_pickup(Vector3(-3,0.2,-2), "rust_key", "Rust Key", "key")
	_make_pickup(Vector3(19,0.2,2), "Bandage", "Bandage", "item")
	_make_pickup(Vector3(21,0.2,-2.5), "Antiseptic", "Antiseptic", "item")
	_make_pickup(Vector3(37,0.2,2.5), "sigil", "Bell Sigil", "key")
	_make_pickup(Vector3(2,0.2,3), "coin", "Old Coin", "coin")
	_make_pickup(Vector3(20,0.2,3), "coin", "Old Coin", "coin")
	_make_pickup(Vector3(38,0.2,-3), "coin", "Old Coin", "coin")

	_make_enemy(Vector3(3,0,-2), "Starved Ghoul", 48, 10, false)
	_make_enemy(Vector3(20,0,-1), "Starved Ghoul", 56, 12, false)
	_make_enemy(Vector3(39,0,0), "Bell Cultist", 70, 15, false)
	_make_enemy(Vector3(55,0,0), "The Bell Warden", 150, 22, true)

	_make_npc(Vector3(17,0,-3.5), "Maren", "maren")
	_make_npc(Vector3(36,0,-3.5), "Priest Sever", "sever")
	_make_puzzle(Vector3(40,0,3.5))
	_make_save_shrine(Vector3(24,0,3.7))
	_make_ending_altar(Vector3(59,0,0))

	_make_trap(Vector3(5,0,-3))
	_make_trap(Vector3(22,0,2))
	_make_trap(Vector3(41,0,-2))

func _make_room(center: Vector3, size: Vector2, title: String):
	var sx = int(size.x)
	var sz = int(size.y)
	for x in range(-sx/2, sx/2 + 1, 2):
		for z in range(-sz/2, sz/2 + 1, 2):
			var floor = _model("floor.glb")
			if floor:
				floor.position = center + Vector3(x,0,z)
				add_child(floor)
	# collision floor
	var body = StaticBody3D.new()
	body.position = center + Vector3(0,-0.1,0)
	var cs = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = Vector3(size.x,0.2,size.y)
	cs.shape = bs
	body.add_child(cs)
	add_child(body)
	for x in range(-sx/2, sx/2 + 1, 2):
		_place_wall(center + Vector3(x,0,-sz/2))
		_place_wall(center + Vector3(x,0,sz/2), 180)
	for z in range(-sz/2+2, sz/2, 2):
		_place_wall(center + Vector3(-sx/2,0,z), 90)
		_place_wall(center + Vector3(sx/2,0,z), -90)
	var banner = _model("banner.glb")
	if banner:
		banner.position = center + Vector3(0,0.2,-sz/2+0.2)
		add_child(banner)
	for p in [Vector3(-4,0,-3),Vector3(4,0,3)]:
		var barrel = _model("barrel.glb")
		if barrel:
			barrel.position = center + p
			add_child(barrel)
	_make_room_light(center + Vector3(0,2.7,0))

func _place_wall(pos: Vector3, rot_y := 0.0):
	var m = _model("wall.glb")
	if m:
		m.position = pos
		m.rotation_degrees.y = rot_y
		add_child(m)
	var body = StaticBody3D.new()
	body.position = pos + Vector3(0,1,0)
	body.rotation_degrees.y = rot_y
	var cs = CollisionShape3D.new()
	var sh = BoxShape3D.new()
	sh.size = Vector3(2.0,2.0,0.3)
	cs.shape = sh
	body.add_child(cs)
	add_child(body)

func _make_room_light(pos: Vector3):
	var l = OmniLight3D.new()
	l.position = pos
	l.light_color = Color(1.0,0.37,0.14)
	l.light_energy = 1.3
	l.omni_range = 7
	l.shadow_enabled = true
	add_child(l)

func _make_gate(pos: Vector3, id: String, need: String, flag_name: String):
	var n = Node3D.new()
	n.name = id
	n.position = pos
	n.set_meta("type","gate")
	n.set_meta("need",need)
	n.set_meta("flag",flag_name)
	var v = _model("gate.glb")
	if v:
		n.add_child(v)
	else:
		var mi = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.35,2.4,2.6)
		mi.mesh = bm
		n.add_child(mi)
	add_child(n)
	interactables.append(n)

func _make_pickup(pos: Vector3, id: String, label: String, kind: String):
	var n = Node3D.new()
	n.position = pos
	n.name = "pickup_" + id
	n.set_meta("type","pickup")
	n.set_meta("id",id)
	n.set_meta("label",label)
	n.set_meta("kind",kind)
	var v: Node3D
	if id == "coin":
		v = _model("coin.glb")
	elif id == "rust_key" or id == "sigil":
		v = _model("stones.glb")
	else:
		v = _model("barrel.glb")
	if v:
		v.scale *= 0.65
		n.add_child(v)
	add_child(n)
	interactables.append(n)

func _make_enemy(pos: Vector3, enemy_name: String, enemy_hp: int, damage: int, boss: bool):
	var n = Node3D.new()
	n.position = pos
	n.name = enemy_name.replace(" ","_")
	n.set_meta("type","enemy")
	n.set_meta("enemy_name",enemy_name)
	n.set_meta("hp",enemy_hp)
	n.set_meta("damage",damage)
	n.set_meta("boss",boss)
	var v = _model("character-orc.glb")
	if v:
		v.scale *= 0.95 if not boss else 1.35
		n.add_child(v)
	else:
		var mi=MeshInstance3D.new()
		var cm=CapsuleMesh.new()
		mi.mesh=cm
		n.add_child(mi)
	add_child(n)
	interactables.append(n)

func _make_npc(pos: Vector3, npc_name: String, id: String):
	var n=Node3D.new()
	n.position=pos
	n.name=npc_name
	n.set_meta("type","npc")
	n.set_meta("id",id)
	n.set_meta("npc_name",npc_name)
	var v=_model("character-human.glb")
	if v:
		v.scale *= 0.9
		n.add_child(v)
	add_child(n)
	interactables.append(n)

func _make_puzzle(pos: Vector3):
	var n=Node3D.new()
	n.position=pos
	n.name="BellPuzzle"
	n.set_meta("type","puzzle")
	var v=_model("column.glb")
	if v: n.add_child(v)
	add_child(n)
	interactables.append(n)

func _make_save_shrine(pos: Vector3):
	var n=Node3D.new()
	n.position=pos
	n.name="DeepShrine"
	n.set_meta("type","save")
	var v=_model("column.glb")
	if v: n.add_child(v)
	add_child(n)
	interactables.append(n)

func _make_ending_altar(pos: Vector3):
	var n=Node3D.new()
	n.position=pos
	n.name="EndingAltar"
	n.set_meta("type","ending")
	var v=_model("column.glb")
	if v:
		v.scale*=1.2
		n.add_child(v)
	add_child(n)
	interactables.append(n)

func _make_trap(pos: Vector3):
	var n=Node3D.new()
	n.position=pos
	n.name="Trap"
	var v=_model("trap.glb")
	if v: n.add_child(v)
	add_child(n)
	traps.append(n)
	trap_cooldowns[n]=0.0

func _model(file_name: String) -> Node3D:
	var path="res://assets/kenney/" + file_name
	if not ResourceLoader.exists(path):
		return null
	var scene=load(path)
	if scene is PackedScene:
		return scene.instantiate()
	return null

func _update_player(delta):
	var dir=Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir.z-=1
	if Input.is_key_pressed(KEY_S): dir.z+=1
	if Input.is_key_pressed(KEY_A): dir.x-=1
	if Input.is_key_pressed(KEY_D): dir.x+=1
	dir=dir.normalized()
	var speed=RUN_SPEED if Input.is_key_pressed(KEY_SHIFT) and not fractured else WALK_SPEED
	if fractured: speed*=0.65
	player.velocity.x=dir.x*speed
	player.velocity.z=dir.z*speed
	player.velocity.y=-0.1
	player.move_and_slide()
	if dir.length()>0.1:
		player_visual.rotation.y=lerp_angle(player_visual.rotation.y,atan2(dir.x,dir.z),delta*10.0)

func _update_survival(delta):
	hunger=max(0.0,hunger-delta*0.22)
	sanity=max(0.0,sanity-delta*(0.10 if torch_on else 0.28))
	if torch_on:
		torch=max(0.0,torch-delta*0.28)
		if torch<=0:
			torch_on=false
			torch_light.visible=false
	if hunger<=0: hp=max(0,hp-delta*1.3)
	if bleeding: hp=max(0,hp-delta*0.45)
	if infected: hp=max(0,hp-delta*0.14)
	if sanity<=0: hp=max(0,hp-delta*0.25)
	if hp<=0: _game_over()

func _update_traps(delta):
	for t in traps:
		trap_cooldowns[t]=max(0.0,float(trap_cooldowns[t])-delta)
		if player.global_position.distance_to(t.global_position)<0.8 and trap_cooldowns[t]<=0:
			trap_cooldowns[t]=5.0
			hp-=12
			bleeding=true
			_show_message("A rusted trap tears into your leg. BLEEDING.")

func _nearest_interactable() -> Node3D:
	var best:Node3D=null
	var best_d=INTERACT_RANGE
	for n in interactables:
		if not is_instance_valid(n) or not n.visible: continue
		var d=player.global_position.distance_to(n.global_position)
		if d<best_d:
			best=n
			best_d=d
	return best

func _update_interaction_prompt():
	var n=_nearest_interactable()
	prompt_text.text="" if n==null else "[E] " + _interaction_name(n)

func _interaction_name(n:Node3D)->String:
	match str(n.get_meta("type","")):
		"enemy": return "Confront " + str(n.get_meta("enemy_name"))
		"npc": return "Talk to " + str(n.get_meta("npc_name"))
		"pickup": return "Take " + str(n.get_meta("label"))
		"gate": return "Open gate"
		"puzzle": return "Inspect bell relief"
		"save": return "Pray at the Deep Shrine"
		"ending": return "Touch the Heart Altar"
	return "Interact"

func _interact():
	var n=_nearest_interactable()
	if n==null: return
	match str(n.get_meta("type","")):
		"enemy": _start_battle(n)
		"npc": _open_npc(n)
		"pickup": _take_pickup(n)
		"gate": _open_gate(n)
		"puzzle": _open_puzzle()
		"save": _try_save()
		"ending": _try_ending()

func _take_pickup(n:Node3D):
	var id=str(n.get_meta("id"))
	var kind=str(n.get_meta("kind"))
	var label=str(n.get_meta("label"))
	if kind=="key":
		flags[id]=true
	elif kind=="coin":
		coins+=1
	else:
		inventory[label]=int(inventory.get(label,0))+1
	_show_message("Obtained: "+label)
	interactables.erase(n)
	n.queue_free()

func _open_gate(n:Node3D):
	var flag_name=str(n.get_meta("flag"))
	var need=str(n.get_meta("need"))
	var ok=false
	if flag_name=="infirmary_open" and flags.rust_key:
		flags.infirmary_open=true; ok=true
	elif flag_name=="puzzle_done" and flags.puzzle_done:
		ok=true
	elif flag_name=="sigil" and flags.sigil:
		ok=true
	if ok:
		_show_message("The gate groans open.")
		interactables.erase(n)
		n.queue_free()
	else:
		_show_message("Locked. Requires: "+need)

func _open_npc(n:Node3D):
	var id=str(n.get_meta("id"))
	game_mode="dialogue"
	dialogue_panel.visible=true
	for c in dialogue_buttons.get_children(): c.queue_free()
	if id=="maren":
		dialogue_text.text="MAREN\n\nI can still hear the prisoners beneath the stones. If you have medicine, give it to me. I know a safer road."
		_dialogue_choice("Give Bandage",func():
			if int(inventory.get("Bandage",0))>0:
				inventory["Bandage"]-=1; flags.maren_helped=true; sanity=min(100,sanity+12); _show_message("Maren marks a safe passage on your map.")
			else: _show_message("You have no Bandage.")
			_close_dialogue())
		_dialogue_choice("Leave her",func(): _close_dialogue())
	else:
		dialogue_text.text="PRIEST SEVER\n\nThe Bell Warden is not a god. It is a lock. Break it, and something else may wake."
		_dialogue_choice("Spare Sever",func(): flags.sever_spared=true; sanity=min(100,sanity+8); _close_dialogue())
		_dialogue_choice("Condemn him",func(): flags.sever_spared=false; _close_dialogue())

func _dialogue_choice(text:String,callable:Callable):
	var b=Button.new(); b.text=text; b.pressed.connect(callable); dialogue_buttons.add_child(b)

func _close_dialogue():
	dialogue_panel.visible=false
	game_mode="explore"

func _open_puzzle():
	if flags.puzzle_done:
		_show_message("The relief is silent.")
		return
	game_mode="dialogue"
	dialogue_panel.visible=true
	dialogue_text.text="Three symbols are carved beneath the bell.\n\nA witness sees. A bell calls. A circle seals.\nChoose the order."
	for c in dialogue_buttons.get_children(): c.queue_free()
	_dialogue_choice("Eye → Bell → Circle",func(): flags.puzzle_done=true; sanity=min(100,sanity+5); _show_message("Stone gears turn. The temple gate unlocks."); _close_dialogue())
	_dialogue_choice("Bell → Circle → Eye",func(): sanity=max(0,sanity-12); _show_message("A terrible chime rings inside your skull."); _close_dialogue())
	_dialogue_choice("Circle → Eye → Bell",func(): hp=max(1,hp-10); _show_message("The relief bites into your palm."); _close_dialogue())

func _start_battle(source:Node3D):
	battle_source=source
	var maxhp=int(source.get_meta("hp"))
	battle_enemy={
		"name":str(source.get_meta("enemy_name")),
		"max_hp":maxhp,
		"hp":maxhp,
		"damage":int(source.get_meta("damage")),
		"boss":bool(source.get_meta("boss")),
		"parts":{"Head":int(maxhp*0.30),"Torso":int(maxhp*0.55),"Arm":int(maxhp*0.28),"Legs":int(maxhp*0.32)}
	}
	game_mode="battle"
	battle_panel.visible=true
	guarding=false
	battle_log.text="[b]"+battle_enemy.name+"[/b]\nChoose a body part."
	_refresh_battle()

func _battle_attack(part:String):
	if game_mode!="battle": return
	var chance={"Head":0.62,"Torso":0.92,"Arm":0.82,"Legs":0.78}[part]
	var dmg=randi_range(13,22)
	if randf()<=chance:
		battle_enemy.parts[part]=max(0,int(battle_enemy.parts[part])-dmg)
		battle_enemy.hp=max(0,int(battle_enemy.hp)-dmg)
		battle_log.append_text("\nYou strike the "+part+" for "+str(dmg)+".")
		if int(battle_enemy.parts[part])<=0:
			battle_log.append_text(" [color=orange]"+part+" destroyed.[/color]")
	else:
		battle_log.append_text("\nYour attack misses.")
	if int(battle_enemy.parts["Head"])<=0 or int(battle_enemy.hp)<=0:
		_battle_win(); return
	_enemy_turn()
	_refresh_battle()

func _battle_guard():
	guarding=true
	battle_log.append_text("\nYou brace for impact.")
	_enemy_turn()
	_refresh_battle()

func _battle_item():
	if int(inventory.get("Bandage",0))>0 and bleeding:
		inventory["Bandage"]-=1; bleeding=false; hp=min(100,hp+10); battle_log.append_text("\nYou stop the bleeding.")
	elif int(inventory.get("Tonic",0))>0:
		inventory["Tonic"]-=1; hp=min(100,hp+25); sanity=min(100,sanity+12); battle_log.append_text("\nThe tonic steadies you.")
	else:
		battle_log.append_text("\nNo useful battle item.")
		return
	_enemy_turn(); _refresh_battle()

func _battle_flee():
	var chance=0.35
	if int(battle_enemy.parts["Legs"])<=0: chance=0.8
	if bool(battle_enemy.boss): chance=0.0
	if randf()<chance:
		battle_log.append_text("\nYou escape.")
		_end_battle(false)
	else:
		battle_log.append_text("\nYou fail to escape.")
		_enemy_turn(); _refresh_battle()

func _enemy_turn():
	var dmg=int(battle_enemy.damage)
	if int(battle_enemy.parts["Arm"])<=0: dmg=int(dmg*0.45)
	if guarding: dmg=int(dmg*0.45)
	guarding=false
	dmg=max(1,dmg+randi_range(-3,3))
	hp=max(0,hp-dmg)
	battle_log.append_text("\n"+str(battle_enemy.name)+" hits you for "+str(dmg)+".")
	if randf()<0.14 and not bleeding:
		bleeding=true; battle_log.append_text(" [color=red]BLEEDING[/color]")
	if randf()<0.08 and not fractured:
		fractured=true; battle_log.append_text(" [color=yellow]FRACTURE[/color]")
	if bool(battle_enemy.boss):
		sanity=max(0,sanity-5)
	if hp<=0: _game_over()

func _battle_win():
	var boss=bool(battle_enemy.boss)
	battle_log.append_text("\n[color=lime]Enemy defeated.[/color]")
	if boss:
		flags.boss_dead=true
		coins+=5
	else:
		coins+=1
	_end_battle(true)

func _end_battle(defeated:bool):
	if defeated and is_instance_valid(battle_source):
		interactables.erase(battle_source)
		battle_source.queue_free()
	battle_panel.visible=false
	game_mode="explore"
	battle_enemy={}
	if defeated: _show_message("Victory. The dungeon grows quieter.")

func _try_save():
	if int(inventory.get("Wax Seal",0))<=0:
		_show_message("The shrine requires a Wax Seal.")
		return
	inventory["Wax Seal"]-=1
	var data={
		"hp":hp,"hunger":hunger,"sanity":sanity,"torch":torch,
		"bleeding":bleeding,"infected":infected,"fractured":fractured,
		"coins":coins,"inventory":inventory,"flags":flags,
		"pos":[player.position.x,player.position.y,player.position.z]
	}
	var f=FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	_show_message("Your memory is sealed at the Deep Shrine.")

func _load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		_show_message("No save exists."); return
	var f=FileAccess.open(SAVE_PATH,FileAccess.READ)
	var d=JSON.parse_string(f.get_as_text())
	if typeof(d)!=TYPE_DICTIONARY:
		_show_message("Save file is invalid."); return
	hp=float(d.get("hp",100)); hunger=float(d.get("hunger",100)); sanity=float(d.get("sanity",100)); torch=float(d.get("torch",100))
	bleeding=bool(d.get("bleeding",false)); infected=bool(d.get("infected",false)); fractured=bool(d.get("fractured",false))
	coins=int(d.get("coins",0)); inventory=d.get("inventory",inventory); flags=d.get("flags",flags)
	var p=d.get("pos",[0,0.9,1.5]); player.position=Vector3(float(p[0]),float(p[1]),float(p[2]))
	_show_message("Memory restored.")

func _try_ending():
	if not flags.boss_dead:
		_show_message("The Heart Altar rejects you. The Bell Warden still lives.")
		return
	game_mode="ending"
	ending_panel.visible=true
	if sanity>=45 and flags.maren_helped:
		ending_text.text="ENDING A — THE SILENT CITY\n\nYou shatter the heart of the bell. For the first time in generations, the city hears nothing. Maren leads the remaining prisoners toward dawn.\n\nThe curse is wounded, not dead."
	else:
		ending_text.text="ENDING B — NEW WARDEN\n\nYou place your hand on the heart. The bell stops outside you—and begins inside your chest. The doors open for everyone except you.\n\nA new Warden has been chosen."

func _game_over():
	if game_mode=="ending": return
	game_mode="ending"
	if battle_panel: battle_panel.visible=false
	ending_panel.visible=true
	ending_text.text="YOU DIED\n\nThe depths remember your name.\n\nPress F9 after restarting to load your last sealed memory."

func _build_ui():
	ui=CanvasLayer.new(); add_child(ui)
	var root=Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.add_child(root)

	hud_text=Label.new(); hud_text.position=Vector2(18,16); hud_text.add_theme_font_size_override("font_size",18); root.add_child(hud_text)
	prompt_text=Label.new(); prompt_text.position=Vector2(520,650); prompt_text.add_theme_font_size_override("font_size",20); root.add_child(prompt_text)
	message_text=Label.new(); message_text.position=Vector2(360,30); message_text.size=Vector2(600,90); message_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; message_text.add_theme_font_size_override("font_size",20); root.add_child(message_text)

	inventory_panel=_panel(Vector2(30,120),Vector2(330,480)); root.add_child(inventory_panel)
	inventory_panel.visible=false
	var inv_title=Label.new(); inv_title.text="INVENTORY"; inv_title.position=Vector2(18,15); inv_title.add_theme_font_size_override("font_size",24); inventory_panel.add_child(inv_title)
	var inv_text=RichTextLabel.new(); inv_text.name="InventoryText"; inv_text.position=Vector2(18,55); inv_text.size=Vector2(295,330); inv_text.bbcode_enabled=true; inventory_panel.add_child(inv_text)
	var use_r=Button.new(); use_r.text="Eat Ration"; use_r.position=Vector2(18,400); use_r.pressed.connect(func(): _use_item("Ration")); inventory_panel.add_child(use_r)
	var use_b=Button.new(); use_b.text="Use Bandage"; use_b.position=Vector2(120,400); use_b.pressed.connect(func(): _use_item("Bandage")); inventory_panel.add_child(use_b)
	var use_o=Button.new(); use_o.text="Use Torch Oil"; use_o.position=Vector2(18,440); use_o.pressed.connect(func(): _use_item("Torch Oil")); inventory_panel.add_child(use_o)

	battle_panel=_panel(Vector2(160,360),Vector2(960,330)); root.add_child(battle_panel); battle_panel.visible=false
	battle_log=RichTextLabel.new(); battle_log.bbcode_enabled=true; battle_log.position=Vector2(20,16); battle_log.size=Vector2(920,145); battle_panel.add_child(battle_log)
	var parts=["Head","Torso","Arm","Legs"]
	for i in range(parts.size()):
		var b=Button.new(); b.text="Attack "+parts[i]; b.position=Vector2(20+i*145,175); b.size=Vector2(135,45); var part=parts[i]; b.pressed.connect(func(): _battle_attack(part)); battle_panel.add_child(b)
	var guard=Button.new(); guard.text="Guard"; guard.position=Vector2(20,240); guard.size=Vector2(135,45); guard.pressed.connect(_battle_guard); battle_panel.add_child(guard)
	var item=Button.new(); item.text="Item"; item.position=Vector2(165,240); item.size=Vector2(135,45); item.pressed.connect(_battle_item); battle_panel.add_child(item)
	var flee=Button.new(); flee.text="Flee"; flee.position=Vector2(310,240); flee.size=Vector2(135,45); flee.pressed.connect(_battle_flee); battle_panel.add_child(flee)

	dialogue_panel=_panel(Vector2(190,390),Vector2(900,280)); root.add_child(dialogue_panel); dialogue_panel.visible=false
	dialogue_text=Label.new(); dialogue_text.position=Vector2(25,20); dialogue_text.size=Vector2(850,110); dialogue_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; dialogue_text.add_theme_font_size_override("font_size",19); dialogue_panel.add_child(dialogue_text)
	dialogue_buttons=VBoxContainer.new(); dialogue_buttons.position=Vector2(25,145); dialogue_buttons.size=Vector2(850,110); dialogue_panel.add_child(dialogue_buttons)

	ending_panel=_panel(Vector2(220,150),Vector2(840,420)); root.add_child(ending_panel); ending_panel.visible=false
	ending_text=Label.new(); ending_text.position=Vector2(45,45); ending_text.size=Vector2(750,320); ending_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; ending_text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; ending_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; ending_text.add_theme_font_size_override("font_size",25); ending_panel.add_child(ending_text)

func _panel(pos:Vector2,size:Vector2)->Panel:
	var p=Panel.new(); p.position=pos; p.size=size
	var sb=StyleBoxFlat.new(); sb.bg_color=Color(0.025,0.022,0.02,0.94); sb.border_color=Color(0.35,0.24,0.16); sb.set_border_width_all(2); p.add_theme_stylebox_override("panel",sb)
	return p

func _update_hud():
	if hud_text==null:return
	var status=[]
	if bleeding: status.append("BLEEDING")
	if infected: status.append("INFECTED")
	if fractured: status.append("FRACTURE")
	hud_text.text="HP %d   HUNGER %d   SANITY %d   TORCH %d\nCOINS %d   %s" % [int(hp),int(hunger),int(sanity),int(torch),coins,", ".join(status)]
	torch_light.visible=torch_on and torch>0

func _refresh_inventory():
	var t=inventory_panel.get_node("InventoryText") as RichTextLabel
	var s="[b]Items[/b]\n"
	for k in inventory.keys():
		s+=str(k)+" x"+str(inventory[k])+"\n"
	s+="\n[b]Key items[/b]\n"
	if flags.rust_key:s+="Rust Key\n"
	if flags.sigil:s+="Bell Sigil\n"
	t.text=s

func _refresh_battle():
	if battle_enemy.is_empty(): return
	var p=battle_enemy.parts
	battle_log.append_text("\n\n[color=gray]Enemy HP "+str(battle_enemy.hp)+"/"+str(battle_enemy.max_hp)+" | Head "+str(p.Head)+" | Torso "+str(p.Torso)+" | Arm "+str(p.Arm)+" | Legs "+str(p.Legs)+"[/color]")

func _use_item(id:String):
	if int(inventory.get(id,0))<=0:
		_show_message("You have none."); return
	match id:
		"Ration": hunger=min(100,hunger+35)
		"Bandage": bleeding=false; hp=min(100,hp+8)
		"Torch Oil": torch=min(100,torch+55)
		"Tonic": hp=min(100,hp+25); sanity=min(100,sanity+15)
		"Splint": fractured=false
		"Antiseptic": infected=false
	inventory[id]-=1
	_refresh_inventory()
	_show_message("Used "+id+".")

func _show_message(t:String):
	if message_text:
		message_text.text=t
		last_message_time=Time.get_ticks_msec()/1000.0
