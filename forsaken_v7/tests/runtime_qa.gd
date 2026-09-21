extends SceneTree

var failed := false

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		push_error("FAIL: " + message)
		failed = true

func _run() -> void:
	await process_frame

	var required_scenes := [
		"res://scenes/main/main.tscn",
		"res://scenes/ui/main_menu.tscn",
		"res://scenes/ui/game_over.tscn",
		"res://scenes/ui/inventory.tscn",
		"res://scenes/ui/battle.tscn",
		"res://scenes/world/game_world.tscn",
		"res://scenes/world/door.tscn",
		"res://scenes/actors/player.tscn",
		"res://scenes/actors/enemy.tscn"
	]
	for path in required_scenes:
		check(ResourceLoader.exists(path), "scene exists: " + path)
		var res = load(path)
		check(res != null, "scene loads: " + path)

	var gs = root.get_node_or_null("GameState")
	check(gs != null, "GameState autoload exists")
	if gs == null:
		quit(1)
		return

	gs.reset_new_game()
	gs.add_weapon("Bearded Axe")
	check(gs.equip_weapon("Bearded Axe"), "weapon equip returns true")
	check(gs.equipped_weapon == "Bearded Axe", "equipped weapon state updated")
	check(gs.attack_power() == 7, "equipped weapon affects attack")

	gs.add_armor("Chainmail")
	check(gs.equip_armor("Chainmail"), "armor equip returns true")
	check(gs.armor_defense() == 3, "equipped armor affects defense")

	var death_seen := false
	gs.game_over.connect(func(_reason): death_seen = true, CONNECT_ONE_SHOT)
	gs.damage(9999.0, "QA death")
	await process_frame
	check(death_seen, "death signal fires")
	gs.reset_new_game()

	var door_res = load("res://scenes/world/door.tscn")
	var door = door_res.instantiate()
	door.required_key = "Rust Key"
	door.open_flag = "qa_gate"
	root.add_child(door)
	await process_frame
	door.interact(null)
	check(door.opening == false, "locked door stays closed without key")
	gs.add_key_item("Rust Key")
	door.interact(null)
	check(door.opening == true, "door begins animation with key")
	door._process(2.0)
	check(door.open_amount > 0.9, "door animation reaches open state")
	door.queue_free()

	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	check(menu.get_child_count() > 0, "main menu builds controls")
	menu.queue_free()

	var over = load("res://scenes/ui/game_over.tscn").instantiate()
	root.add_child(over)
	await process_frame
	over.setup("QA reason")
	check(over.reason_label != null and over.reason_label.text == "QA reason", "game over screen accepts death reason")
	over.queue_free()

	var world = load("res://scenes/world/game_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	check(world.get_node_or_null("Layer_floor") != null, "floor layer exists")
	check(world.get_node_or_null("Layer_back") != null, "back-wall layer exists")
	check(world.get_node_or_null("Layer_Actors") != null, "actor layer exists")
	check(world.get_node_or_null("Layer_foreground") != null, "foreground layer exists")
	check(world.player != null, "player spawns")
	check(world.inventory != null, "inventory scene attached")
	check(world.battle != null, "battle scene attached")
	world.queue_free()

	await process_frame
	if failed:
		push_error("STRUCTURED_V7_QA_FAILED")
		quit(1)
	else:
		print("STRUCTURED_V7_QA_PASS")
		quit(0)
