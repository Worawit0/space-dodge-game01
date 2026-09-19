extends Node2D

const SAVE_PATH := "user://forsaken_depths_2d_save.json"
const WORLD_TOP := -400.0
const WORLD_BOTTOM := 400.0
const WORLD_LEFT := -600.0
const WORLD_RIGHT := 4600.0

var player: CharacterBody2D
var player_sprite: Sprite2D
var player_light: PointLight2D
var darkness: CanvasModulate
var camera: Camera2D

var game_mode := "title"
var current_location := "OLD PRISON"
var elapsed := 0.0

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
var armor := ["Prisoner's Garb"]
var books := []
var key_items := []
var equipped_weapon := "Rusted Sword"

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
var continue_button: Button

var dialogue_panel: Panel
var dialogue_text: RichTextLabel
var dialogue_choices: VBoxContainer

var inventory_overlay: ColorRect
var inventory_desc: RichTextLabel
var inventory_list: VBoxContainer
var inventory_tabs: HBoxContainer
var inventory_current_tab := "Item"
var inventory_use_button: Button
var inventory_selected := ""

var battle_overlay: ColorRect
var battle_enemy_art: TextureRect
var battle_enemy_name: Label
var battle_log: RichTextLabel
var battle_menu: VBoxContainer
var battle_parts: Array[Button] = []
var battle_party_stats: RichTextLabel
var battle_enemy := {}
var battle_source_id := ""
var guarding := false

var ending_overlay: ColorRect
var ending_title: Label
var ending_text: RichTextLabel

var radial_light_texture: GradientTexture2D

func _ready():
	randomize()
	radial_light_texture = _make_radial_texture()
	_build_world_visuals()
	_build_player()
	_build_world_content()
	_build_ui()
	_apply_darkness()
	queue_redraw()

func _process(delta):
	elapsed += delta
	if game_mode == "explore":
		_update_survival(delta)
		_update_player(delta)
		_update_interaction_prompt()
		_update_traps(delta)
		_update_location()
	_update_visual_effects()
	_update_hud()

func _unhandled_key_input(event):
	if not event.pressed or event.echo:
		return
	if game_mode == "explore":
		if event.keycode == KEY_E:
			_interact()
		elif event.keycode == KEY_I:
			_open_inventory()
		elif event.keycode == KEY_T:
			torch_on = not torch_on
			_show_message("Torch " + ("lit." if torch_on else "extinguished."))
		elif event.keycode == KEY_F5:
			_show_message("Saving is only possible at a Deep Shrine.")
		elif event.keycode == KEY_F9:
			_load_game()
	elif event.keycode == KEY_ESCAPE:
		if game_mode == "inventory":
			_close_inventory()
		elif game_mode == "dialogue":
			_close_dialogue()

func _draw():
	var rooms = [
		{"rect": Rect2(-600,-400,1200,800), "color": Color("#393733")},
		{"rect": Rect2(600,-400,1200,800), "color": Color("#343532")},
		{"rect": Rect2(1800,-400,1200,800), "color": Color("#302d2b")},
		{"rect": Rect2(3000,-400,1600,800), "color": Color("#282423")}
	]
	for room in rooms:
		var r: Rect2 = room["rect"]
		draw_rect(r, room["color"], true)
		draw_rect(r, Color("#706b62"), false, 14.0)
		for x in range(int(r.position.x) + 18, int(r.position.x + r.size.x) - 18, 72):
			for y in range(int(r.position.y) + 18, int(r.position.y + r.size.y) - 18, 56):
				var offset = 20 if int((y - r.position.y) / 56.0) % 2 == 1 else 0
				var stone = Rect2(x + offset, y, 58, 42)
				draw_rect(stone, Color(0.20,0.19,0.18,0.32), false, 2.0)
	# room dividers
	for gx in [600.0, 1800.0, 3000.0]:
		draw_line(Vector2(gx,WORLD_TOP), Vector2(gx,-120), Color("#6f685f"), 18)
		draw_line(Vector2(gx,120), Vector2(gx,WORLD_BOTTOM), Color("#6f685f"), 18)
	# blood and grime, deterministic decorative marks
	for p in [Vector2(-280,140),Vector2(190,-190),Vector2(970,210),Vector2(1510,-220),Vector2(2350,180),Vector2(2710,-170),Vector2(3510,220)]:
		draw_circle(p, 28, Color(0.20,0.03,0.03,0.40))
		draw_circle(p + Vector2(24,8), 13, Color(0.15,0.02,0.02,0.34))
	for p in [Vector2(-420,-290),Vector2(1120,-300),Vector2(2480,-310),Vector2(4250,-290)]:
		draw_line(p, p+Vector2(120,25), Color(0.06,0.055,0.05,0.5), 8)
		draw_line(p+Vector2(20,20), p+Vector2(100,-10), Color(0.06,0.055,0.05,0.5), 5)

func _build_world_visuals():
	darkness = CanvasModulate.new()
	darkness.color = Color(0.16,0.15,0.16,1.0)
	add_child(darkness)
	_make_static_rect(Vector2((WORLD_LEFT+WORLD_RIGHT)/2.0,WORLD_TOP-12), Vector2(WORLD_RIGHT-WORLD_LEFT,24))
	_make_static_rect(Vector2((WORLD_LEFT+WORLD_RIGHT)/2.0,WORLD_BOTTOM+12), Vector2(WORLD_RIGHT-WORLD_LEFT,24))
	_make_static_rect(Vector2(WORLD_LEFT-12,0), Vector2(24,WORLD_BOTTOM-WORLD_TOP))
	_make_static_rect(Vector2(WORLD_RIGHT+12,0), Vector2(24,WORLD_BOTTOM-WORLD_TOP))
	for gx in [600.0,1800.0,3000.0]:
		_make_static_rect(Vector2(gx,(WORLD_TOP-120)/2.0), Vector2(24,280))
		_make_static_rect(Vector2(gx,(WORLD_BOTTOM+120)/2.0), Vector2(24,280))

func _build_player():
	player = CharacterBody2D.new()
	player.name = "Player"
	player.position = Vector2(-470,40)
	player.collision_layer = 1
	player.collision_mask = 1
	add_child(player)

	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 22
	collision.shape = shape
	player.add_child(collision)

	player_sprite = Sprite2D.new()
	player_sprite.texture = load("res://assets/player.svg")
	player_sprite.scale = Vector2(0.44,0.44)
	player_sprite.position = Vector2(0,-28)
	player.add_child(player_sprite)

	player_light = PointLight2D.new()
	player_light.texture = radial_light_texture
	player_light.texture_scale = 1.55
	player_light.energy = 1.6
	player_light.color = Color(1.0,0.68,0.40)
	player_light.position = Vector2(20,-40)
	player.add_child(player_light)

	camera = Camera2D.new()
	camera.position = Vector2.ZERO
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.zoom = Vector2(1.06,1.06)
	player.add_child(camera)

func _build_world_content():
	# Prison
	_make_pickup("rust_key", Vector2(-260,-220), "Rust Key", "key", "A corroded key. Its teeth are dark with old blood.")
	_make_pickup("prison_ration", Vector2(210,220), "Ration", "item", "Dry food. Barely edible, but hunger is less discerning.")
	_make_enemy("ghoul_prison", Vector2(260,-80), "Starved Gaoler", "ghoul", 62, 13, false)
	_make_gate("prison_gate", Vector2(600,0), "Rust Key", "prison_gate_open")

	# Infirmary
	_make_npc("maren", Vector2(870,-110), "Maren", "maren")
	_make_pickup("blue_vial_1", Vector2(1310,190), "Blue Vial", "item", "A cold restorative. It smells faintly of iron.")
	_make_pickup("bandage_1", Vector2(1460,-210), "Bandage", "item", "A strip of cloth clean enough to stop bleeding.")
	_make_enemy("ghoul_infirmary", Vector2(1580,80), "Mutilated Patient", "ghoul", 72, 15, false)
	_make_shrine("deep_shrine", Vector2(1110,0))

	# Temple
	_make_npc("sever", Vector2(2040,-160), "Priest Sever", "sever")
	_make_enemy("cultist_temple", Vector2(2550,130), "Bell Cultist", "cultist", 88, 18, false)
	_make_ritual("ritual_circle", Vector2(2360,-30))
	_make_pickup("book_echoes", Vector2(2790,-215), "Book of Echoes", "book", "A damp book describing rituals that predate the city.")
	_make_gate("temple_gate", Vector2(1800,0), "The temple is sealed from this side.", "temple_gate_open")
	_make_gate("heart_gate", Vector2(3000,0), "Bell Sigil", "heart_gate_open")

	# Heart
	_make_enemy("bell_warden", Vector2(3670,-10), "The Bell Warden", "boss", 210, 26, true)
	_make_altar("heart_altar", Vector2(4340,0))

	# traps and props
	_make_trap("trap_prison", Vector2(80,-250))
	_make_trap("trap_infirmary", Vector2(1660,-250))
	_make_trap("trap_temple", Vector2(2870,210))
	_make_prop("prison_altar", Vector2(-420,-210), "shrine")
	_make_prop("infirmary_table", Vector2(1040,220), "table")
	_make_prop("temple_pedestal", Vector2(2690,40), "pedestal")

func _make_static_rect(center: Vector2, size: Vector2):
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

func _make_gate(id:String, pos:Vector2, need:String, flag_name:String):
	var holder = Node2D.new()
	holder.position = pos
	holder.name = id
	add_child(holder)
	var panel = Polygon2D.new()
	panel.polygon = PackedVector2Array([Vector2(-14,-108),Vector2(14,-108),Vector2(14,108),Vector2(-14,108)])
	panel.color = Color("#756a5d")
	holder.add_child(panel)
	for y in [-78,-38,2,42,82]:
		var bar = Polygon2D.new()
		bar.polygon = PackedVector2Array([Vector2(-56,y-5),Vector2(56,y-5),Vector2(56,y+5),Vector2(-56,y+5)])
		bar.color = Color("#3a342e")
		holder.add_child(bar)
	var gate_body = StaticBody2D.new()
	gate_body.collision_layer = 1
	gate_body.collision_mask = 1
	var cs = CollisionShape2D.new()
	var rs = RectangleShape2D.new()
	rs.size = Vector2(30,220)
	cs.shape = rs
	gate_body.add_child(cs)
	holder.add_child(gate_body)
	var entry = {"id":id,"node":holder,"type":"gate","need":need,"flag":flag_name,"active":true,"collider":gate_body}
	_register_entry(entry)

func _make_pickup(id:String,pos:Vector2,label:String,kind:String,desc:String):
	var holder = Node2D.new()
	holder.position = pos
	holder.name = id
	add_child(holder)
	var glow = PointLight2D.new()
	glow.texture = radial_light_texture
	glow.texture_scale = 0.32
	glow.energy = 0.55
	glow.color = Color(0.70,0.72,0.55)
	holder.add_child(glow)
	var s = Sprite2D.new()
	s.texture = load("res://assets/item.svg")
	s.scale = Vector2(0.25,0.25)
	holder.add_child(s)
	var entry = {"id":id,"node":holder,"type":"pickup","label":label,"kind":kind,"desc":desc,"active":true}
	_register_entry(entry)

func _make_enemy(id:String,pos:Vector2,label:String,art:String,enemy_body:int,damage:int,boss_enemy:bool):
	var holder = Node2D.new()
	holder.position = pos
	holder.name = id
	add_child(holder)
	var s = Sprite2D.new()
	var path = "res://assets/" + art + ".svg"
	s.texture = load(path)
	s.scale = Vector2(0.44,0.44) if not boss_enemy else Vector2(0.32,0.32)
	s.position = Vector2(0,-35)
	holder.add_child(s)
	var entry = {
		"id":id,"node":holder,"type":"enemy","label":label,"art":art,
		"body":enemy_body,"damage":damage,"boss":boss_enemy,"active":true
	}
	_register_entry(entry)

func _make_npc(id:String,pos:Vector2,label:String,kind:String):
	var holder = Node2D.new()
	holder.position = pos
	holder.name = id
	add_child(holder)
	var s = Sprite2D.new()
	s.texture = load("res://assets/" + id + ".svg")
	s.scale = Vector2(0.42,0.42)
	s.position = Vector2(0,-28)
	holder.add_child(s)
	var entry = {"id":id,"node":holder,"type":"npc","label":label,"kind":kind,"active":true}
	_register_entry(entry)

func _make_shrine(id:String,pos:Vector2):
	var holder = Node2D.new()
	holder.position = pos
	add_child(holder)
	var s = Sprite2D.new()
	s.texture = load("res://assets/shrine.svg")
	s.scale = Vector2(0.52,0.52)
	holder.add_child(s)
	var light = PointLight2D.new()
	light.texture = radial_light_texture
	light.texture_scale = 0.62
	light.energy = 0.85
	light.color = Color(0.45,0.58,0.78)
	holder.add_child(light)
	_register_entry({"id":id,"node":holder,"type":"shrine","label":"Deep Shrine","active":true})

func _make_ritual(id:String,pos:Vector2):
	var holder = Node2D.new()
	holder.position = pos
	add_child(holder)
	var s = Sprite2D.new()
	s.texture = load("res://assets/ritual.svg")
	s.scale = Vector2(0.58,0.58)
	holder.add_child(s)
	var light = PointLight2D.new()
	light.texture = radial_light_texture
	light.texture_scale = 0.8
	light.energy = 0.75
	light.color = Color(0.70,0.12,0.12)
	holder.add_child(light)
	_register_entry({"id":id,"node":holder,"type":"ritual","label":"Ritual Circle","active":true})

func _make_altar(id:String,pos:Vector2):
	var holder = Node2D.new()
	holder.position = pos
	add_child(holder)
	var s = Sprite2D.new()
	s.texture = load("res://assets/heart_altar.svg")
	s.scale = Vector2(0.55,0.55)
	holder.add_child(s)
	var light = PointLight2D.new()
	light.texture = radial_light_texture
	light.texture_scale = 0.9
	light.energy = 0.9
	light.color = Color(0.52,0.08,0.08)
	holder.add_child(light)
	_register_entry({"id":id,"node":holder,"type":"altar","label":"Heart Altar","active":true})

func _make_prop(id:String,pos:Vector2,kind:String):
	var holder = Node2D.new()
	holder.position = pos
	add_child(holder)
	var s = Sprite2D.new()
	s.texture = load("res://assets/prop_" + kind + ".svg")
	s.scale = Vector2(0.42,0.42)
	holder.add_child(s)

func _make_trap(id:String,pos:Vector2):
	var holder = Node2D.new()
	holder.position = pos
	add_child(holder)
	var p = Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(-28,20),Vector2(-12,-15),Vector2(0,20),Vector2(12,-15),Vector2(28,20)])
	p.color = Color("#534b42")
	holder.add_child(p)
	var entry = {"id":id,"node":holder,"active":true}
	traps.append(entry)
	trap_cooldowns[id] = 0.0

func _register_entry(entry:Dictionary):
	interactables.append(entry)
	world_nodes[entry["id"]] = entry

func _make_radial_texture() -> GradientTexture2D:
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0,0.55,1.0])
	g.colors = PackedColorArray([Color(1,1,1,1),Color(1,1,1,0.55),Color(1,1,1,0)])
	var tex = GradientTexture2D.new()
	tex.gradient = g
	tex.width = 512
	tex.height = 512
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5,0.5)
	tex.fill_to = Vector2(1.0,0.5)
	return tex

func _update_player(_delta):
	var dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W): dir.y -= 1
	if Input.is_key_pressed(KEY_S): dir.y += 1
	if Input.is_key_pressed(KEY_A): dir.x -= 1
	if Input.is_key_pressed(KEY_D): dir.x += 1
	dir = dir.normalized()
	var speed = 195.0
	if Input.is_key_pressed(KEY_SHIFT) and hunger > 8:
		speed = 285.0
	if fractured:
		speed *= 0.58
	player.velocity = dir * speed
	player.move_and_slide()
	if dir.x != 0:
		player_sprite.flip_h = dir.x < 0
	if dir.length() > 0:
		player_sprite.position.y = -28 + sin(elapsed * 10.0) * 2.0

func _update_survival(delta):
	hunger = max(0.0, hunger - delta * 0.18)
	mind = max(0.0, mind - delta * (0.055 if torch_on else 0.18))
	if torch_on:
		torch = max(0.0, torch - delta * 0.16)
		if torch <= 0:
			torch_on = false
			_show_message("The torch dies.")
	if bleeding:
		body = max(0.0, body - delta * 0.24)
	if infected:
		body = max(0.0, body - delta * 0.08)
	if hunger <= 0:
		body = max(0.0, body - delta * 0.55)
	if mind <= 0:
		body = max(0.0, body - delta * 0.16)
	if body <= 0 and game_mode != "ending":
		_game_over()

func _update_visual_effects():
	if player_light:
		player_light.visible = torch_on and torch > 0
		player_light.texture_scale = lerp(0.82,1.58,clamp(torch/100.0,0.0,1.0))
		player_light.energy = lerp(0.75,1.65,clamp(torch/100.0,0.0,1.0))
	if darkness:
		var low_mind = 1.0 - clamp(mind/100.0,0.0,1.0)
		darkness.color = Color(0.18-low_mind*0.055,0.17-low_mind*0.065,0.18-low_mind*0.07,1.0)
	if sanity_overlay:
		var danger = clamp((35.0-mind)/35.0,0.0,1.0)
		sanity_overlay.color = Color(0.16,0.0,0.02,danger*(0.08+0.035*sin(elapsed*2.5)))

func _update_traps(delta):
	for entry in traps:
		if not entry["active"]:
			continue
		var id:String = entry["id"]
		trap_cooldowns[id] = max(0.0,float(trap_cooldowns[id])-delta)
		if player.position.distance_to(entry["node"].position) < 34 and trap_cooldowns[id] <= 0:
			trap_cooldowns[id] = 5.0
			body = max(1.0,body-12)
			bleeding = true
			_show_message("A rusted trap closes around your leg. [BLEEDING]")

func _update_location():
	var x = player.position.x
	if x < 600:
		current_location = "OLD PRISON"
	elif x < 1800:
		current_location = "ABANDONED INFIRMARY"
	elif x < 3000:
		current_location = "TEMPLE DISTRICT"
	else:
		current_location = "HEART OF THE BELL"

func _nearest_interactable() -> Dictionary:
	var best := {}
	var best_distance := 92.0
	for entry in interactables:
		if not entry.get("active",false):
			continue
		var node:Node2D = entry["node"]
		if not is_instance_valid(node):
			continue
		var d = player.position.distance_to(node.position)
		if d < best_distance:
			best = entry
			best_distance = d
	return best

func _update_interaction_prompt():
	var entry = _nearest_interactable()
	if entry.is_empty():
		prompt_label.text = ""
		return
	prompt_label.text = "[ E ]  " + _interaction_label(entry)

func _interaction_label(entry:Dictionary) -> String:
	match String(entry["type"]):
		"pickup": return "Take " + String(entry["label"])
		"enemy": return "Confront " + String(entry["label"])
		"npc": return "Talk to " + String(entry["label"])
		"gate": return "Inspect gate"
		"shrine": return "Pray at the Deep Shrine"
		"ritual": return "Inspect ritual circle"
		"altar": return "Approach the Heart Altar"
	return "Interact"

func _interact():
	var entry = _nearest_interactable()
	if entry.is_empty():
		return
	match String(entry["type"]):
		"pickup": _take_pickup(entry)
		"enemy": _start_battle(entry)
		"npc": _open_npc(entry)
		"gate": _open_gate(entry)
		"shrine": _open_shrine()
		"ritual": _open_ritual()
		"altar": _open_ending()

func _take_pickup(entry:Dictionary):
	var label = String(entry["label"])
	var kind = String(entry["kind"])
	if kind == "item":
		inventory[label] = int(inventory.get(label,0)) + 1
	elif kind == "key":
		if label == "Rust Key":
			flags["rust_key"] = true
		if not key_items.has(label):
			key_items.append(label)
	elif kind == "book":
		if not books.has(label):
			books.append(label)
	_show_message("Obtained: " + label + "\n" + String(entry["desc"]))
	_deactivate_entry(entry,true)

func _open_gate(entry:Dictionary):
	var id = String(entry["id"])
	if id == "prison_gate":
		if flags["rust_key"]:
			flags["prison_gate_open"] = true
			_show_message("The rusted key turns with a painful scrape.")
			_deactivate_entry(entry,true)
		else:
			_show_dialogue("The iron gate is locked.\n\nA small keyhole is buried beneath layers of rust.",[{"text":"Leave","call":func(): _close_dialogue()}])
	elif id == "temple_gate":
		flags["temple_gate_open"] = true
		_show_message("The temple door opens from the infirmary side.")
		_deactivate_entry(entry,true)
	elif id == "heart_gate":
		if flags["bell_sigil"]:
			flags["heart_gate_open"] = true
			_show_message("The Bell Sigil grows warm. The final gate withdraws into the stone.")
			_deactivate_entry(entry,true)
		else:
			_show_dialogue("A circular socket waits in the center of the gate.\n\nSomething shaped like a seal is missing.",[{"text":"Leave","call":func(): _close_dialogue()}])

func _open_npc(entry:Dictionary):
	var id = String(entry["id"])
	if id == "maren":
		if flags["maren_helped"]:
			_show_dialogue("[b]MAREN[/b]\n\n\"Keep your torch low. Things in this place notice hope faster than sound.\"",[
				{"text":"Leave","call":func(): _close_dialogue()}
			])
			return
		_show_dialogue("[b]MAREN[/b]\n\nA wounded scavenger is pressed against an old operating table. Blood has soaked through the cloth around her ribs.\n\n\"If you have a bandage... I can still walk.\"",[
			{"text":"Give Bandage","call":func(): _help_maren()},
			{"text":"Ask about the depths","call":func(): _maren_lore()},
			{"text":"Leave","call":func(): _close_dialogue()}
		])
	else:
		_show_dialogue("[b]PRIEST SEVER[/b]\n\n\"The Bell Warden was built as a lock, not a king. Break the lock and the city may breathe again... or inhale something worse.\"",[
			{"text":"Spare him","call":func(): flags["sever_spared"]=true; mind=min(100.0,mind+7.0); _show_message("Sever lowers his head in silence."); _close_dialogue()},
			{"text":"Condemn him","call":func(): flags["sever_spared"]=false; _show_message("Sever smiles as if this was the answer he expected."); _close_dialogue()},
			{"text":"Leave","call":func(): _close_dialogue()}
		])

func _help_maren():
	if int(inventory.get("Bandage",0)) <= 0:
		_show_message("You have no Bandage.")
		_close_dialogue()
		return
	inventory["Bandage"] -= 1
	flags["maren_helped"] = true
	party["Maren"]["joined"] = true
	mind = min(100.0,mind+10)
	_show_message("Maren joins the party.")
	_close_dialogue()

func _maren_lore():
	dialogue_text.text = "[b]MAREN[/b]\n\n\"There is a red circle in the temple. The cult fed it names, teeth, coins—anything carrying intent. They said the circle can make a key if the offering is accepted.\""

func _open_ritual():
	var choices:Array = []
	if not flags["ritual_prayed"]:
		choices.append({"text":"Pray","call":func(): _ritual_pray()})
	choices.append({"text":"Offer 3 coins","call":func(): _ritual_coin()})
	if not flags["blood_rite"]:
		choices.append({"text":"Offer blood","call":func(): _ritual_blood()})
	choices.append({"text":"Leave","call":func(): _close_dialogue()})
	_show_dialogue("A ritual circle is drawn and carved into the stone.\n\nThe grooves are dark, but not dry.",choices)

func _ritual_pray():
	flags["ritual_prayed"] = true
	mind = min(100.0,mind+22)
	hunger = max(0.0,hunger-7)
	_show_message("The chamber becomes silent. Your thoughts briefly become your own again.")
	_close_dialogue()

func _ritual_coin():
	if flags["bell_sigil"]:
		_show_message("The circle has already answered you.")
		_close_dialogue()
		return
	if coins < 3:
		_show_message("The circle remains still. Three old coins may be enough.")
		_close_dialogue()
		return
	coins -= 3
	flags["bell_sigil"] = true
	if not key_items.has("Bell Sigil"):
		key_items.append("Bell Sigil")
	_show_message("The coins melt into black metal. Obtained: Bell Sigil.")
	_close_dialogue()

func _ritual_blood():
	flags["blood_rite"] = true
	body = max(1.0,body-22)
	bleeding = true
	if not books.has("Rite of the Hollow Palm"):
		books.append("Rite of the Hollow Palm")
	_show_message("The circle accepts the offering. A ritual phrase appears in your memory. [BLEEDING]")
	_close_dialogue()

func _open_shrine():
	_show_dialogue("The Deep Shrine is cold to the touch.\n\nA wax seal can bind a memory here.",[
		{"text":"Save (Wax Seal)","call":func(): _save_game(); _close_dialogue()},
		{"text":"Rest","call":func(): _shrine_rest()},
		{"text":"Leave","call":func(): _close_dialogue()}
	])

func _shrine_rest():
	hunger = max(0.0,hunger-12)
	body = min(max_body,body+18)
	mind = min(100.0,mind+12)
	_show_message("You rest without sleeping. Something scratches behind the walls.")
	_close_dialogue()

func _start_battle(entry:Dictionary):
	battle_source_id = String(entry["id"])
	var total_body = int(entry["body"])
	battle_enemy = {
		"name":String(entry["label"]),
		"art":String(entry["art"]),
		"max_body":total_body,
		"body":total_body,
		"damage":int(entry["damage"]),
		"boss":bool(entry["boss"]),
		"parts":{
			"Head":max(16,int(total_body*0.28)),
			"Torso":max(30,int(total_body*0.58)),
			"Left Arm":max(14,int(total_body*0.25)),
			"Right Arm":max(14,int(total_body*0.25)),
			"Legs":max(18,int(total_body*0.33))
		}
	}
	guarding = false
	game_mode = "battle"
	battle_overlay.visible = true
	inventory_overlay.visible = false
	dialogue_panel.visible = false
	battle_enemy_art.texture = load("res://assets/" + String(entry["art"]) + ".svg")
	battle_enemy_name.text = String(entry["label"])
	battle_log.text = "[center][i]The encounter begins.[/i][/center]"
	_set_part_buttons(false)
	_refresh_battle_party()
	_refresh_battle_log_stats()

func _battle_choose_attack():
	_set_part_buttons(true)
	battle_log.append_text("\nChoose a body part.")

func _battle_attack(part:String):
	if game_mode != "battle":
		return
	_set_part_buttons(false)
	var chance = {
		"Head":0.58,
		"Torso":0.93,
		"Left Arm":0.82,
		"Right Arm":0.82,
		"Legs":0.78
	}[part]
	var base_damage = randi_range(16,24)
	if equipped_weapon == "Rusted Sword":
		base_damage += 4
	if randf() <= chance:
		battle_enemy["parts"][part] = max(0,int(battle_enemy["parts"][part])-base_damage)
		battle_enemy["body"] = max(0,int(battle_enemy["body"])-base_damage)
		battle_log.append_text("\nYou strike the [b]"+part+"[/b] for "+str(base_damage)+".")
		if int(battle_enemy["parts"][part]) <= 0:
			battle_log.append_text(" [color=#d39a63]The "+part+" is disabled.[/color]")
	else:
		battle_log.append_text("\nYour attack misses.")
	if _battle_enemy_dead():
		_battle_win()
		return
	_party_followup()
	if _battle_enemy_dead():
		_battle_win()
		return
	_enemy_turn()
	_refresh_battle_party()
	_refresh_battle_log_stats()

func _battle_skill():
	if mind < 12:
		battle_log.append_text("\nYour mind cannot hold the shape of a skill.")
		return
	mind -= 12
	var dmg = randi_range(24,34)
	battle_enemy["parts"]["Torso"] = max(0,int(battle_enemy["parts"]["Torso"])-dmg)
	battle_enemy["body"] = max(0,int(battle_enemy["body"])-dmg)
	battle_log.append_text("\n[b]Focused Strike[/b] deals "+str(dmg)+" to the torso.")
	if _battle_enemy_dead():
		_battle_win()
		return
	_party_followup()
	if _battle_enemy_dead():
		_battle_win()
		return
	_enemy_turn()
	_refresh_battle_party()
	_refresh_battle_log_stats()

func _battle_guard():
	guarding = true
	battle_log.append_text("\nYou raise your guard.")
	_party_followup()
	if _battle_enemy_dead():
		_battle_win()
		return
	_enemy_turn()
	_refresh_battle_party()
	_refresh_battle_log_stats()

func _battle_item():
	if bleeding and int(inventory.get("Bandage",0)) > 0:
		inventory["Bandage"] -= 1
		bleeding = false
		body = min(max_body,body+7)
		battle_log.append_text("\nYou bind the wound.")
	elif int(inventory.get("Blue Vial",0)) > 0:
		inventory["Blue Vial"] -= 1
		body = min(max_body,body+28)
		mind = min(100.0,mind+10)
		battle_log.append_text("\nThe Blue Vial burns cold in your throat.")
	else:
		battle_log.append_text("\nNo useful battle item.")
		return
	_enemy_turn()
	_refresh_battle_party()
	_refresh_battle_log_stats()

func _battle_run():
	if bool(battle_enemy["boss"]):
		battle_log.append_text("\nThere is nowhere to run.")
		_enemy_turn()
		return
	var chance = 0.38
	if int(battle_enemy["parts"]["Legs"]) <= 0:
		chance = 0.88
	if randf() < chance:
		battle_log.append_text("\nYou escape into the dark.")
		_end_battle(false)
	else:
		battle_log.append_text("\nThe enemy blocks your retreat.")
		_enemy_turn()
		_refresh_battle_party()
		_refresh_battle_log_stats()

func _party_followup():
	if party["Maren"]["joined"] and float(party["Maren"]["body"]) > 0:
		var dmg = randi_range(8,14)
		battle_enemy["parts"]["Torso"] = max(0,int(battle_enemy["parts"]["Torso"])-dmg)
		battle_enemy["body"] = max(0,int(battle_enemy["body"])-dmg)
		battle_log.append_text("\n[color=#c8b8a7]Maren attacks for "+str(dmg)+".[/color]")

func _enemy_turn():
	var target_maren = party["Maren"]["joined"] and float(party["Maren"]["body"]) > 0 and randf() < 0.30
	var damage = int(battle_enemy["damage"]) + randi_range(-3,3)
	if int(battle_enemy["parts"]["Left Arm"]) <= 0:
		damage = int(damage*0.72)
	if int(battle_enemy["parts"]["Right Arm"]) <= 0:
		damage = int(damage*0.72)
	if guarding and not target_maren:
		damage = int(damage*0.42)
	guarding = false
	damage = max(1,damage)
	if target_maren:
		party["Maren"]["body"] = max(0.0,float(party["Maren"]["body"])-damage)
		battle_log.append_text("\n"+String(battle_enemy["name"])+" strikes Maren for "+str(damage)+".")
	else:
		body = max(0.0,body-damage)
		battle_log.append_text("\n"+String(battle_enemy["name"])+" strikes you for "+str(damage)+".")
		if randf() < 0.14 and not bleeding:
			bleeding = true
			battle_log.append_text(" [color=#bd4b4b]BLEEDING[/color]")
		if randf() < 0.07 and not fractured:
			fractured = true
			battle_log.append_text(" [color=#d2ad65]FRACTURE[/color]")
	if bool(battle_enemy["boss"]):
		mind = max(0.0,mind-5)
	if body <= 0:
		_game_over()

func _battle_enemy_dead() -> bool:
	return int(battle_enemy["body"]) <= 0 or int(battle_enemy["parts"]["Head"]) <= 0

func _battle_win():
	battle_log.append_text("\n[color=#d7c79f][b]The enemy collapses.[/b][/color]")
	if bool(battle_enemy["boss"]):
		flags["boss_dead"] = true
		coins += 5
	else:
		coins += 1
	if world_nodes.has(battle_source_id):
		_deactivate_entry(world_nodes[battle_source_id],true)
	_end_battle(true)

func _end_battle(_victory:bool):
	battle_overlay.visible = false
	battle_enemy = {}
	battle_source_id = ""
	game_mode = "explore"
	_show_message("The silence returns.")

func _refresh_battle_log_stats():
	if battle_enemy.is_empty():
		return
	var p = battle_enemy["parts"]
	battle_log.append_text("\n[color=#857d74]Enemy BODY "+str(battle_enemy["body"])+"/"+str(battle_enemy["max_body"])+"  |  Head "+str(p["Head"])+"  Torso "+str(p["Torso"])+"  L.Arm "+str(p["Left Arm"])+"  R.Arm "+str(p["Right Arm"])+"  Legs "+str(p["Legs"])+"[/color]")

func _refresh_battle_party():
	var text = "[b]PARTY[/b]\n\n"
	text += "Wanderer     BODY %3d/%3d    MIND %3d    HUNGER %3d\n" % [int(body),int(max_body),int(mind),int(hunger)]
	if party["Maren"]["joined"]:
		text += "Maren        BODY %3d/%3d    MIND %3d" % [int(party["Maren"]["body"]),int(party["Maren"]["max_body"]),int(party["Maren"]["mind"])]
	battle_party_stats.text = text

func _set_part_buttons(show_buttons:bool):
	for b in battle_parts:
		b.visible = show_buttons

func _open_inventory():
	game_mode = "inventory"
	inventory_overlay.visible = true
	inventory_selected = ""
	inventory_desc.text = "Select an item to inspect it."
	_refresh_inventory_tab()

func _close_inventory():
	inventory_overlay.visible = false
	game_mode = "explore"

func _set_inventory_tab(tab:String):
	inventory_current_tab = tab
	inventory_selected = ""
	inventory_desc.text = "Select an entry."
	_refresh_inventory_tab()

func _refresh_inventory_tab():
	for child in inventory_list.get_children():
		child.queue_free()
	var entries:Array = []
	match inventory_current_tab:
		"Item":
			for k in inventory.keys():
				if int(inventory[k]) > 0:
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
		var name = String(data["name"])
		var b = Button.new()
		b.text = name + ("    : " + str(data["count"]) if inventory_current_tab=="Item" else "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(360,42)
		b.pressed.connect(func(): _select_inventory_entry(name))
		inventory_list.add_child(b)

func _select_inventory_entry(name:String):
	inventory_selected = name
	inventory_desc.text = "[b]"+name+"[/b]\n\n"+_item_description(name)
	inventory_use_button.visible = inventory_current_tab == "Item" or inventory_current_tab == "Weapon"
	inventory_use_button.text = "Use" if inventory_current_tab=="Item" else "Equip"

func _inventory_use_selected():
	if inventory_selected == "":
		return
	if inventory_current_tab == "Item":
		_use_item(inventory_selected)
	elif inventory_current_tab == "Weapon":
		equipped_weapon = inventory_selected
		_show_message("Equipped: "+inventory_selected)
	_refresh_inventory_tab()

func _use_item(name:String):
	if int(inventory.get(name,0)) <= 0:
		return
	match name:
		"Ration":
			hunger = min(100.0,hunger+34)
		"Bandage":
			bleeding = false
			body = min(max_body,body+8)
		"Blue Vial":
			body = min(max_body,body+30)
			mind = min(100.0,mind+8)
		"Antiseptic":
			infected = false
		"Splint":
			fractured = false
		"Torch Oil":
			torch = min(100.0,torch+58)
		"Wax Seal":
			_show_message("Wax Seals can only be used at a Deep Shrine.")
			return
	inventory[name] -= 1
	inventory_desc.text = "[b]"+name+"[/b]\n\nUsed."
	_show_message("Used "+name+".")

func _item_description(name:String) -> String:
	var descriptions = {
		"Ration":"Dry preserved food. Restores Hunger.",
		"Bandage":"Stops Bleeding and restores a little BODY.",
		"Blue Vial":"Restores BODY and steadies the MIND.",
		"Antiseptic":"Cleans Infection.",
		"Splint":"Stabilizes a fracture.",
		"Torch Oil":"Restores the torch meter.",
		"Wax Seal":"Consumed when saving at a Deep Shrine.",
		"Rusted Sword":"A chipped sword recovered from the prison. Equipped weapon.",
		"Prisoner's Garb":"Thin cloth and leather. Better than bare skin.",
		"Book of Echoes":"Notes on the Bell, the old city, and ritual exchange.",
		"Rite of the Hollow Palm":"A ritual phrase learned by feeding blood to the circle.",
		"Rust Key":"Opens the iron gate out of the Old Prison.",
		"Bell Sigil":"A black metal seal formed by the ritual circle."
	}
	return String(descriptions.get(name,"Its purpose is unclear."))

func _save_game():
	if int(inventory.get("Wax Seal",0)) <= 0:
		_show_message("You have no Wax Seal.")
		return
	inventory["Wax Seal"] -= 1
	var data = {
		"body":body,"mind":mind,"hunger":hunger,"torch":torch,
		"bleeding":bleeding,"infected":infected,"fractured":fractured,
		"coins":coins,"inventory":inventory,"weapons":weapons,"armor":armor,
		"books":books,"key_items":key_items,"equipped_weapon":equipped_weapon,
		"flags":flags,"party":party,"removed_ids":removed_ids,
		"player_pos":[player.position.x,player.position.y]
	}
	var f = FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	_show_message("Your memory is sealed in wax.")

func _load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		_show_message("No sealed memory exists.")
		return
	var f = FileAccess.open(SAVE_PATH,FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		_show_message("The save file cannot be read.")
		return
	body = float(data.get("body",100))
	mind = float(data.get("mind",100))
	hunger = float(data.get("hunger",100))
	torch = float(data.get("torch",100))
	bleeding = bool(data.get("bleeding",false))
	infected = bool(data.get("infected",false))
	fractured = bool(data.get("fractured",false))
	coins = int(data.get("coins",0))
	inventory = data.get("inventory",inventory)
	weapons = data.get("weapons",weapons)
	armor = data.get("armor",armor)
	books = data.get("books",books)
	key_items = data.get("key_items",key_items)
	equipped_weapon = String(data.get("equipped_weapon","Rusted Sword"))
	flags = data.get("flags",flags)
	party = data.get("party",party)
	removed_ids.clear()
	for id in data.get("removed_ids",[]):
		removed_ids.append(String(id))
		if world_nodes.has(String(id)):
			_deactivate_entry(world_nodes[String(id)],false)
	var p = data.get("player_pos",[-470,40])
	player.position = Vector2(float(p[0]),float(p[1]))
	title_overlay.visible = false
	game_mode = "explore"
	_show_message("The sealed memory returns.")

func _deactivate_entry(entry:Dictionary,remember:bool):
	entry["active"] = false
	var id = String(entry["id"])
	if remember and not removed_ids.has(id):
		removed_ids.append(id)
	var node:Node2D = entry["node"]
	if is_instance_valid(node):
		node.visible = false
		for child in node.get_children():
			if child is StaticBody2D:
				child.collision_layer = 0
				child.collision_mask = 0

func _open_ending():
	if not flags["boss_dead"]:
		_show_dialogue("The Heart Altar is still bound to the Bell Warden.\n\nSomething behind the stone is listening.",[
			{"text":"Leave","call":func(): _close_dialogue()}
		])
		return
	game_mode = "ending"
	ending_overlay.visible = true
	if mind >= 45 and flags["maren_helped"] and flags["sever_spared"]:
		ending_title.text = "ENDING A — THE SILENT CITY"
		ending_text.text = "You break the final clapper from the heart of the bell.\n\nFor the first time in generations, the buried city hears nothing. Maren leads the survivors toward the surface while Sever remains behind to close the old rites.\n\nThe silence feels merciful.\n\nYet deep below, something notices the absence of its song."
	elif flags["blood_rite"] and mind < 45:
		ending_title.text = "ENDING C — HOLLOW PALM"
		ending_text.text = "You touch the Heart Altar with the hand that fed the circle.\n\nThe bell does not stop. It changes rhythm.\n\nWhen the gates open, the others see your shadow moving a heartbeat before you do.\n\nThe depths have learned how to leave."
	else:
		ending_title.text = "ENDING B — NEW WARDEN"
		ending_text.text = "You silence the Bell Warden and place your hand upon the Heart.\n\nThe doors open for everyone except you.\n\nA new pulse begins beneath your ribs. Somewhere in the city, every locked door turns toward you.\n\nA new Warden has been chosen."

func _game_over():
	game_mode = "ending"
	battle_overlay.visible = false
	dialogue_panel.visible = false
	inventory_overlay.visible = false
	ending_overlay.visible = true
	ending_title.text = "YOU DIED"
	ending_text.text = "The depths remember your name.\n\nWhatever you carried is left somewhere in the dark.\n\nUse Continue from the title screen to return to your last sealed memory."

func _show_dialogue(text:String, choices:Array):
	game_mode = "dialogue"
	dialogue_panel.visible = true
	dialogue_text.text = text
	for child in dialogue_choices.get_children():
		child.queue_free()
	for choice in choices:
		var b = Button.new()
		b.text = String(choice["text"])
		b.custom_minimum_size = Vector2(245,46)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(choice["call"])
		dialogue_choices.add_child(b)

func _close_dialogue():
	dialogue_panel.visible = false
	if game_mode != "ending":
		game_mode = "explore"

func _show_message(text:String):
	message_label.text = text
	var tween = create_tween()
	message_label.modulate = Color(1,1,1,1)
	tween.tween_interval(3.2)
	tween.tween_property(message_label,"modulate:a",0.0,0.7)

func _apply_darkness():
	darkness.color = Color(0.16,0.15,0.16,1)

func _build_ui():
	ui = CanvasLayer.new()
	add_child(ui)
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)

	sanity_overlay = ColorRect.new()
	sanity_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sanity_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sanity_overlay)

	hud_panel = _make_panel(Vector2(18,16),Vector2(350,110),Color(0.015,0.012,0.012,0.88))
	root.add_child(hud_panel)
	hud_location = Label.new()
	hud_location.position = Vector2(16,10)
	hud_location.add_theme_font_size_override("font_size",20)
	hud_panel.add_child(hud_location)
	hud_stats = Label.new()
	hud_stats.position = Vector2(16,42)
	hud_stats.add_theme_font_size_override("font_size",17)
	hud_panel.add_child(hud_stats)
	hud_status = Label.new()
	hud_status.position = Vector2(16,72)
	hud_status.add_theme_font_size_override("font_size",14)
	hud_panel.add_child(hud_status)

	prompt_label = Label.new()
	prompt_label.position = Vector2(470,646)
	prompt_label.size = Vector2(340,48)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size",20)
	root.add_child(prompt_label)

	message_label = Label.new()
	message_label.position = Vector2(340,32)
	message_label.size = Vector2(600,90)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size",18)
	root.add_child(message_label)

	_build_title_ui(root)
	_build_dialogue_ui(root)
	_build_inventory_ui(root)
	_build_battle_ui(root)
	_build_ending_ui(root)

func _build_title_ui(root:Control):
	title_overlay = ColorRect.new()
	title_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_overlay.color = Color(0.005,0.004,0.005,0.97)
	root.add_child(title_overlay)

	var title = Label.new()
	title.text = "THE FORSAKEN DEPTHS"
	title.position = Vector2(260,125)
	title.size = Vector2(760,90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",46)
	title_overlay.add_child(title)
	var sub = Label.new()
	sub.text = "A 2D dark survival RPG"
	sub.position = Vector2(390,205)
	sub.size = Vector2(500,50)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size",20)
	sub.modulate = Color("#a79a8e")
	title_overlay.add_child(sub)

	var menu = VBoxContainer.new()
	menu.position = Vector2(475,315)
	menu.size = Vector2(330,240)
	title_overlay.add_child(menu)
	var new_b = Button.new()
	new_b.text = "NEW DESCENT"
	new_b.custom_minimum_size = Vector2(330,55)
	new_b.pressed.connect(_new_game)
	menu.add_child(new_b)
	continue_button = Button.new()
	continue_button.text = "CONTINUE"
	continue_button.custom_minimum_size = Vector2(330,55)
	continue_button.disabled = not FileAccess.file_exists(SAVE_PATH)
	continue_button.pressed.connect(_load_game)
	menu.add_child(continue_button)
	var controls = Button.new()
	controls.text = "CONTROLS"
	controls.custom_minimum_size = Vector2(330,55)
	controls.pressed.connect(func(): _show_title_controls())
	menu.add_child(controls)

func _show_title_controls():
	message_label.modulate = Color.WHITE
	message_label.text = "WASD Move   Shift Run   E Interact   I Inventory   T Torch   F9 Load Save"

func _new_game():
	body = 100
	mind = 100
	hunger = 100
	torch = 100
	bleeding = false
	infected = false
	fractured = false
	torch_on = true
	coins = 0
	player.position = Vector2(-470,40)
	title_overlay.visible = false
	game_mode = "explore"
	_show_message("You wake beneath the Old Prison. The bell above has not rung in years.")

func _build_dialogue_ui(root:Control):
	dialogue_panel = _make_panel(Vector2(115,430),Vector2(1050,250),Color(0.01,0.008,0.009,0.96))
	root.add_child(dialogue_panel)
	dialogue_panel.visible = false
	dialogue_text = RichTextLabel.new()
	dialogue_text.bbcode_enabled = true
	dialogue_text.position = Vector2(28,22)
	dialogue_text.size = Vector2(700,190)
	dialogue_text.add_theme_font_size_override("normal_font_size",22)
	dialogue_text.add_theme_font_size_override("bold_font_size",23)
	dialogue_panel.add_child(dialogue_text)
	dialogue_choices = VBoxContainer.new()
	dialogue_choices.position = Vector2(760,24)
	dialogue_choices.size = Vector2(260,195)
	dialogue_panel.add_child(dialogue_choices)

func _build_inventory_ui(root:Control):
	inventory_overlay = ColorRect.new()
	inventory_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_overlay.color = Color(0.005,0.004,0.005,0.985)
	root.add_child(inventory_overlay)
	inventory_overlay.visible = false

	var frame = _make_panel(Vector2(110,55),Vector2(1060,610),Color(0.012,0.01,0.011,1))
	inventory_overlay.add_child(frame)
	inventory_desc = RichTextLabel.new()
	inventory_desc.bbcode_enabled = true
	inventory_desc.position = Vector2(28,20)
	inventory_desc.size = Vector2(1000,105)
	inventory_desc.add_theme_font_size_override("normal_font_size",20)
	frame.add_child(inventory_desc)

	inventory_tabs = HBoxContainer.new()
	inventory_tabs.position = Vector2(28,135)
	inventory_tabs.size = Vector2(1000,48)
	frame.add_child(inventory_tabs)
	for tab in ["Item","Weapon","Armor","Books","Key Items"]:
		var b = Button.new()
		b.text = tab
		b.custom_minimum_size = Vector2(190,44)
		var local_tab = tab
		b.pressed.connect(func(): _set_inventory_tab(local_tab))
		inventory_tabs.add_child(b)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(28,198)
	scroll.size = Vector2(610,340)
	frame.add_child(scroll)
	inventory_list = VBoxContainer.new()
	inventory_list.custom_minimum_size = Vector2(580,330)
	scroll.add_child(inventory_list)

	var status = RichTextLabel.new()
	status.name = "InventoryStatus"
	status.bbcode_enabled = true
	status.position = Vector2(680,205)
	status.size = Vector2(340,220)
	frame.add_child(status)

	inventory_use_button = Button.new()
	inventory_use_button.text = "Use"
	inventory_use_button.position = Vector2(680,455)
	inventory_use_button.size = Vector2(160,50)
	inventory_use_button.visible = false
	inventory_use_button.pressed.connect(_inventory_use_selected)
	frame.add_child(inventory_use_button)

	var close_b = Button.new()
	close_b.text = "Close [Esc]"
	close_b.position = Vector2(860,455)
	close_b.size = Vector2(160,50)
	close_b.pressed.connect(_close_inventory)
	frame.add_child(close_b)

func _build_battle_ui(root:Control):
	battle_overlay = ColorRect.new()
	battle_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle_overlay.color = Color(0.004,0.003,0.004,1)
	root.add_child(battle_overlay)
	battle_overlay.visible = false

	battle_enemy_name = Label.new()
	battle_enemy_name.position = Vector2(360,24)
	battle_enemy_name.size = Vector2(560,48)
	battle_enemy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_enemy_name.add_theme_font_size_override("font_size",28)
	battle_overlay.add_child(battle_enemy_name)

	battle_enemy_art = TextureRect.new()
	battle_enemy_art.position = Vector2(370,65)
	battle_enemy_art.size = Vector2(540,385)
	battle_enemy_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	battle_enemy_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	battle_overlay.add_child(battle_enemy_art)

	var part_specs = [
		["Head",Vector2(585,90)],
		["Left Arm",Vector2(365,230)],
		["Right Arm",Vector2(805,230)],
		["Torso",Vector2(585,260)],
		["Legs",Vector2(585,385)]
	]
	for spec in part_specs:
		var b = Button.new()
		b.text = String(spec[0])
		b.position = spec[1]
		b.size = Vector2(110,38)
		b.visible = false
		var part = String(spec[0])
		b.pressed.connect(func(): _battle_attack(part))
		battle_overlay.add_child(b)
		battle_parts.append(b)

	var bottom = _make_panel(Vector2(90,455),Vector2(1100,235),Color(0.01,0.008,0.009,0.98))
	battle_overlay.add_child(bottom)
	battle_menu = VBoxContainer.new()
	battle_menu.position = Vector2(22,18)
	battle_menu.size = Vector2(210,190)
	bottom.add_child(battle_menu)
	for spec in [
		["Attack",Callable(self,"_battle_choose_attack")],
		["Skills",Callable(self,"_battle_skill")],
		["Guard",Callable(self,"_battle_guard")],
		["Items",Callable(self,"_battle_item")],
		["Run",Callable(self,"_battle_run")]
	]:
		var b = Button.new()
		b.text = String(spec[0])
		b.custom_minimum_size = Vector2(200,34)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(spec[1])
		battle_menu.add_child(b)

	battle_log = RichTextLabel.new()
	battle_log.bbcode_enabled = true
	battle_log.position = Vector2(255,18)
	battle_log.size = Vector2(480,190)
	battle_log.add_theme_font_size_override("normal_font_size",17)
	bottom.add_child(battle_log)

	battle_party_stats = RichTextLabel.new()
	battle_party_stats.bbcode_enabled = true
	battle_party_stats.position = Vector2(755,18)
	battle_party_stats.size = Vector2(320,190)
	battle_party_stats.add_theme_font_size_override("normal_font_size",17)
	bottom.add_child(battle_party_stats)

func _build_ending_ui(root:Control):
	ending_overlay = ColorRect.new()
	ending_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ending_overlay.color = Color(0.002,0.002,0.003,0.985)
	root.add_child(ending_overlay)
	ending_overlay.visible = false
	ending_title = Label.new()
	ending_title.position = Vector2(190,110)
	ending_title.size = Vector2(900,70)
	ending_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_title.add_theme_font_size_override("font_size",38)
	ending_overlay.add_child(ending_title)
	ending_text = RichTextLabel.new()
	ending_text.position = Vector2(250,205)
	ending_text.size = Vector2(780,300)
	ending_text.fit_content = false
	ending_text.add_theme_font_size_override("normal_font_size",23)
	ending_text.bbcode_enabled = true
	ending_overlay.add_child(ending_text)
	var load_b = Button.new()
	load_b.text = "LOAD LAST MEMORY"
	load_b.position = Vector2(440,555)
	load_b.size = Vector2(400,55)
	load_b.pressed.connect(func(): ending_overlay.visible=false; _load_game())
	ending_overlay.add_child(load_b)

func _make_panel(pos:Vector2,size:Vector2,color:Color) -> Panel:
	var p = Panel.new()
	p.position = pos
	p.size = size
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = Color("#91877d")
	sb.set_border_width_all(3)
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	p.add_theme_stylebox_override("panel",sb)
	return p

func _update_hud():
	if not hud_stats:
		return
	hud_location.text = current_location
	hud_stats.text = "BODY %3d/%3d    MIND %3d    HUNGER %3d    TORCH %3d" % [int(body),int(max_body),int(mind),int(hunger),int(torch)]
	var status:Array[String] = []
	if bleeding: status.append("BLEEDING")
	if infected: status.append("INFECTION")
	if fractured: status.append("FRACTURE")
	if party["Maren"]["joined"]: status.append("PARTY: MAREN")
	hud_status.text = (" | ".join(status) if status.size()>0 else "Stable") + "    COINS: " + str(coins)
	if inventory_overlay.visible:
		var s = inventory_overlay.get_node("Panel/InventoryStatus") if inventory_overlay.has_node("Panel/InventoryStatus") else null
		if s:
			s.text = "[b]STATUS[/b]\nBODY "+str(int(body))+"/"+str(int(max_body))+"\nMIND "+str(int(mind))+"\nHUNGER "+str(int(hunger))+"\nTORCH "+str(int(torch))+"\n\nWeapon: "+equipped_weapon+"\nCoins: "+str(coins)
