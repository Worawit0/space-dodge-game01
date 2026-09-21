extends Node2D

signal return_to_menu
signal ending_reached(title: String, text: String)

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")
const ENEMY_SCENE := preload("res://scenes/actors/enemy.tscn")
const DOOR_SCENE := preload("res://scenes/world/door.tscn")
const PICKUP_SCENE := preload("res://scenes/world/pickup.tscn")
const NPC_SCENE := preload("res://scenes/world/npc.tscn")
const SHRINE_SCENE := preload("res://scenes/world/shrine.tscn")
const RITUAL_SCENE := preload("res://scenes/world/ritual.tscn")
const PAINTER_SCENE := preload("res://scenes/world/world_painter.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const INVENTORY_SCENE := preload("res://scenes/ui/inventory.tscn")
const BATTLE_SCENE := preload("res://scenes/ui/battle.tscn")

var actors: Node2D
var player
var hud
var inventory
var battle
var battle_active := false
var objective_cache := ""
var position_accum := 0.0

func _ready() -> void:
	_build_lighting()
	_build_layers()
	_build_collision_world()
	_spawn_player()
	_spawn_interactables()
	_spawn_enemies()
	_build_ui()
	GameState.message_requested.connect(_on_message)
	GameState.inventory_changed.connect(_update_objective)
	AudioManager.play_ambient()
	_update_objective()
	_update_area()
	GameState.message_requested.emit("The descent begins. Find the Rust Key in the western prison cells.")

func _build_lighting() -> void:
	var modulate := CanvasModulate.new()
	modulate.color = Color(0.46,0.40,0.43,1.0)
	add_child(modulate)

func _build_layers() -> void:
	for info in [
		["floor",-30],
		["back",-20],
		["foreground",20]
	]:
		var painter = PAINTER_SCENE.instantiate()
		painter.layer_type = info[0]
		painter.z_index = int(info[1])
		painter.name = "Layer_" + str(info[0])
		add_child(painter)
	actors = Node2D.new()
	actors.name = "Layer_Actors"
	actors.z_index = 0
	add_child(actors)

func _build_collision_world() -> void:
	var collision_root := Node2D.new()
	collision_root.name = "CollisionLayer"
	add_child(collision_root)
	_add_wall(collision_root, Vector2(1200,45), Vector2(2400,90))
	_add_wall(collision_root, Vector2(1200,1155), Vector2(2400,90))
	_add_wall(collision_root, Vector2(45,600), Vector2(90,1200))
	_add_wall(collision_root, Vector2(2355,600), Vector2(90,1200))

	# Prison -> Infirmary wall with a 200px doorway.
	_add_wall(collision_root, Vector2(800,295), Vector2(40,410))
	_add_wall(collision_root, Vector2(800,905), Vector2(40,410))

	# Infirmary -> Temple.
	_add_wall(collision_root, Vector2(1600,295), Vector2(40,410))
	_add_wall(collision_root, Vector2(1600,905), Vector2(40,410))

	# Temple -> Heart chamber, opened only after the ritual.
	_add_wall(collision_root, Vector2(2040,295), Vector2(40,410))
	_add_wall(collision_root, Vector2(2040,905), Vector2(40,410))

	# Internal room architecture.
	_add_wall(collision_root, Vector2(440,315), Vector2(260,70))
	_add_wall(collision_root, Vector2(1205,870), Vector2(330,70))
	_add_wall(collision_root, Vector2(1815,272), Vector2(230,65))

func _add_wall(parent: Node, pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 1
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	actors.add_child(player)
	player.global_position = GameState.player_position
	player.inventory_requested.connect(_toggle_inventory)
	player.attack_requested.connect(func(): GameState.message_requested.emit("Enemies trigger turn-based combat on contact. Choose a limb target in battle."))

func _spawn_interactables() -> void:
	_spawn_door(Vector2(800,600), "Prison Iron Gate", "Rust Key", "infirmary_open", "", "prison")
	_spawn_door(Vector2(1600,600), "Temple Bell Gate", "Bell Sigil", "temple_open", "", "temple")
	_spawn_door(Vector2(2040,600), "Heart Gate", "", "heart_open", "ritual_done", "heart")

	_spawn_pickup(Vector2(610,230), "Rust Key", "key")
	_spawn_pickup(Vector2(520,900), "Bearded Axe", "weapon")
	_spawn_pickup(Vector2(1300,945), "Chainmail", "armor")
	_spawn_pickup(Vector2(1435,280), "Bell Sigil", "key")
	_spawn_pickup(Vector2(1880,955), "Greatsword", "weapon")
	_spawn_pickup(Vector2(990,310), "Ration", "item")

	var maren = NPC_SCENE.instantiate()
	maren.position = Vector2(1110,380)
	maren.npc_name = "Maren"
	maren.flag_name = "met_maren"
	maren.asset_set = "maren"
	maren.first_text = "The prison is only the mouth of this place. The Bell Sigil is hidden beyond the shrine. Take this bandage."
	maren.repeat_text = "Do not trust the sound of the bell. It calls with voices you remember."
	actors.add_child(maren)

	var sever = NPC_SCENE.instantiate()
	sever.position = Vector2(1775,760)
	sever.npc_name = "Priest Sever"
	sever.flag_name = "met_sever"
	sever.asset_set = "sever"
	sever.first_text = "The Heart Gate will not answer a key. Break the ritual seal and it will open."
	sever.repeat_text = "The Warden is not a king. It is a lock."
	actors.add_child(sever)

	var shrine = SHRINE_SCENE.instantiate()
	shrine.position = Vector2(1190,720)
	actors.add_child(shrine)

	var ritual = RITUAL_SCENE.instantiate()
	ritual.position = Vector2(1870,610)
	actors.add_child(ritual)

func _spawn_door(pos: Vector2, title: String, key: String, flag: String, req_flag: String, style: String) -> void:
	var d = DOOR_SCENE.instantiate()
	d.position = pos
	d.door_name = title
	d.required_key = key
	d.open_flag = flag
	d.required_flag = req_flag
	d.door_style = style
	actors.add_child(d)

func _spawn_pickup(pos: Vector2, title: String, kind: String, amount: int = 1) -> void:
	var p = PICKUP_SCENE.instantiate()
	p.position = pos
	p.pickup_name = title
	p.pickup_type = kind
	p.amount = amount
	actors.add_child(p)

func _spawn_enemies() -> void:
	_spawn_enemy(Vector2(560,610), "Starved Gaoler", 34, 8, false, "demon_a")
	_spawn_enemy(Vector2(1280,560), "Blood Husk", 42, 10, false, "blood_monster")
	_spawn_enemy(Vector2(1770,430), "Winged Penitent", 52, 12, false, "flying_demon")
	if not bool(GameState.flags.get("boss_dead", false)):
		_spawn_enemy(Vector2(2200,610), "The Bell Warden", 120, 17, true, "demon_slime", "heart_open")

func _spawn_enemy(pos: Vector2, title: String, hp: int, atk: int, boss: bool, set_name: String, required_flag: String = "") -> void:
	var e = ENEMY_SCENE.instantiate()
	e.position = pos
	e.enemy_name = title
	e.max_hp = hp
	e.attack = atk
	e.is_boss = boss
	e.asset_set = set_name
	e.required_flag = required_flag
	actors.add_child(e)
	e.set_player(player)
	e.encounter_requested.connect(_start_battle)

func _build_ui() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	inventory = INVENTORY_SCENE.instantiate()
	add_child(inventory)
	inventory.closed.connect(_on_inventory_closed)
	battle = BATTLE_SCENE.instantiate()
	add_child(battle)
	battle.battle_finished.connect(_finish_battle)

func _process(delta: float) -> void:
	if not battle_active and not inventory.is_open():
		GameState.tick_survival(delta)
	position_accum += delta
	if position_accum >= 0.25:
		position_accum = 0.0
		GameState.player_position = player.global_position
	_update_objective()
	_update_area()

func _update_area() -> void:
	if not hud or not player:
		return
	var x := player.global_position.x
	var area := "OLD PRISON"
	if x >= 2040.0:
		area = "HEART OF THE BELL"
	elif x >= 1600.0:
		area = "TEMPLE DISTRICT"
	elif x >= 800.0:
		area = "ABANDONED INFIRMARY"
	hud.set_area(area)

func _toggle_inventory() -> void:
	if battle_active:
		return
	if inventory.is_open():
		inventory.close()
		return
	_pause_enemies(true)
	player.can_move = false
	inventory.open()

func _on_inventory_closed() -> void:
	if not battle_active:
		player.can_move = true
		_pause_enemies(false)

func _start_battle(enemy) -> void:
	if battle_active or inventory.is_open() or enemy == null:
		return
	battle_active = true
	player.can_move = false
	_pause_enemies(true)
	battle.begin(enemy)

func _finish_battle(victory: bool, enemy) -> void:
	battle_active = false
	player.can_move = true
	_pause_enemies(false)
	if enemy and not victory:
		enemy.retreat_from(player)
	if victory and enemy and enemy.is_boss:
		GameState.flags["boss_dead"] = true
		GameState.save_game()
		ending_reached.emit(
			"THE SILENT BELL",
			"The Bell Warden collapses before the dead mechanism beneath the city. The final toll never comes.\n\nYou climb toward daylight carrying the knowledge that the thing below was only a lock — and something older remains behind it."
		)

func _pause_enemies(paused: bool) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.has_method("battle_data") and not e.defeated:
			e.set_physics_process(not paused)

func _on_message(text: String) -> void:
	if hud:
		hud.show_message(text)

func _update_objective() -> void:
	if not hud:
		return
	var next := ""
	if not GameState.has_key_item("Rust Key"):
		next = "OLD PRISON — Search the western cells for the Rust Key."
	elif not bool(GameState.flags.get("infirmary_open", false)):
		next = "OLD PRISON — Unlock the eastern iron gate."
	elif not bool(GameState.flags.get("met_maren", false)):
		next = "INFIRMARY — Find Maren."
	elif not GameState.has_key_item("Bell Sigil"):
		next = "INFIRMARY — Search beyond the Deep Shrine for the Bell Sigil."
	elif not bool(GameState.flags.get("temple_open", false)):
		next = "INFIRMARY — Use the Bell Sigil on the Temple Gate."
	elif not bool(GameState.flags.get("met_sever", false)):
		next = "TEMPLE — Find Priest Sever."
	elif not bool(GameState.flags.get("ritual_done", false)):
		next = "TEMPLE — Break the red ritual seal."
	elif not bool(GameState.flags.get("heart_open", false)):
		next = "TEMPLE — Open the Heart Gate."
	elif not bool(GameState.flags.get("boss_dead", false)):
		next = "HEART OF THE BELL — Defeat the Bell Warden."
	else:
		next = "The bell is silent."
	if next != objective_cache:
		objective_cache = next
		hud.set_objective(next)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if inventory.is_open():
			inventory.close()
		elif not battle_active:
			GameState.player_position = player.global_position
			return_to_menu.emit()
