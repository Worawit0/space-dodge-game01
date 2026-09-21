extends Node

signal stats_changed
signal inventory_changed
signal message_requested(text: String)
signal game_over(reason: String)

const SAVE_PATH := "user://forsaken_depths_structured_v7_save.json"

var body := 100.0
var mind := 100.0
var hunger := 100.0
var torch := 100.0
var coins := 0

var consumables := {
	"Ration": 2,
	"Bandage": 2,
	"Blue Vial": 1,
	"Torch Oil": 1
}
var owned_weapons := ["Rusted Sword"]
var owned_armor := ["Ragged Shirt"]
var key_items := []
var equipped_weapon := "Rusted Sword"
var equipped_armor := "Ragged Shirt"
var flags := {}
var player_position := Vector2(240, 600)
var last_safe_position := Vector2(240, 600)

const WEAPONS := {
	"Rusted Sword": {"attack": 4, "description": "A corroded sword. Reliable, but weak."},
	"Bearded Axe": {"attack": 7, "description": "Heavy and brutal. Better against armored limbs."},
	"Greatsword": {"attack": 10, "description": "Slow, heavy steel with exceptional reach."}
}
const ARMOR := {
	"Ragged Shirt": {"defense": 0, "description": "Barely protection at all."},
	"Chainmail": {"defense": 3, "description": "Metal rings soften blades and claws."},
	"Plate Harness": {"defense": 6, "description": "Heavy protection for the deepest chambers."}
}

var _survival_accum := 0.0

func reset_new_game() -> void:
	body = 100.0
	mind = 100.0
	hunger = 100.0
	torch = 100.0
	coins = 0
	consumables = {"Ration": 2, "Bandage": 2, "Blue Vial": 1, "Torch Oil": 1}
	owned_weapons = ["Rusted Sword"]
	owned_armor = ["Ragged Shirt"]
	key_items = []
	equipped_weapon = "Rusted Sword"
	equipped_armor = "Ragged Shirt"
	flags = {}
	player_position = Vector2(240, 600)
	last_safe_position = player_position
	_survival_accum = 0.0
	stats_changed.emit()
	inventory_changed.emit()

func attack_power() -> int:
	return int(WEAPONS.get(equipped_weapon, {"attack": 1}).attack)

func armor_defense() -> int:
	return int(ARMOR.get(equipped_armor, {"defense": 0}).defense)

func has_key_item(item_name: String) -> bool:
	return item_name in key_items

func add_key_item(item_name: String) -> void:
	if item_name not in key_items:
		key_items.append(item_name)
		inventory_changed.emit()
		message_requested.emit("Obtained key item: " + item_name)

func add_weapon(item_name: String) -> void:
	if item_name in WEAPONS and item_name not in owned_weapons:
		owned_weapons.append(item_name)
		inventory_changed.emit()
		message_requested.emit("Obtained weapon: " + item_name)

func add_armor(item_name: String) -> void:
	if item_name in ARMOR and item_name not in owned_armor:
		owned_armor.append(item_name)
		inventory_changed.emit()
		message_requested.emit("Obtained armor: " + item_name)

func add_consumable(item_name: String, amount: int = 1) -> void:
	consumables[item_name] = int(consumables.get(item_name, 0)) + amount
	inventory_changed.emit()
	message_requested.emit("Obtained: %s x%d" % [item_name, amount])

func equip_weapon(item_name: String) -> bool:
	if item_name not in owned_weapons or item_name not in WEAPONS:
		return false
	equipped_weapon = item_name
	inventory_changed.emit()
	stats_changed.emit()
	message_requested.emit("Equipped %s  •  ATK %d" % [item_name, attack_power()])
	return true

func equip_armor(item_name: String) -> bool:
	if item_name not in owned_armor or item_name not in ARMOR:
		return false
	equipped_armor = item_name
	inventory_changed.emit()
	stats_changed.emit()
	message_requested.emit("Equipped %s  •  DEF %d" % [item_name, armor_defense()])
	return true

func use_consumable(item_name: String) -> bool:
	if int(consumables.get(item_name, 0)) <= 0:
		return false
	match item_name:
		"Ration":
			hunger = min(100.0, hunger + 38.0)
		"Bandage":
			body = min(100.0, body + 28.0)
		"Blue Vial":
			mind = min(100.0, mind + 35.0)
		"Torch Oil":
			torch = min(100.0, torch + 45.0)
		_:
			return false
	consumables[item_name] = int(consumables[item_name]) - 1
	inventory_changed.emit()
	stats_changed.emit()
	message_requested.emit("Used " + item_name)
	return true

func damage(raw_amount: float, reason: String = "Your wounds were fatal.") -> void:
	var actual: float = maxf(1.0, raw_amount - float(armor_defense()))
	body = max(0.0, body - actual)
	stats_changed.emit()
	if body <= 0.0:
		game_over.emit(reason)

func lose_mind(amount: float) -> void:
	mind = max(0.0, mind - amount)
	stats_changed.emit()
	if mind <= 0.0:
		game_over.emit("Your mind collapsed in the dark.")

func tick_survival(delta: float) -> void:
	_survival_accum += delta
	if _survival_accum < 1.0:
		return
	var ticks := int(_survival_accum)
	_survival_accum -= float(ticks)
	hunger = max(0.0, hunger - 0.10 * ticks)
	torch = max(0.0, torch - 0.07 * ticks)
	if hunger <= 0.0:
		body = max(0.0, body - 0.35 * ticks)
	if torch <= 0.0:
		mind = max(0.0, mind - 0.15 * ticks)
	stats_changed.emit()
	if body <= 0.0:
		game_over.emit("Starvation claimed you in the depths.")
	elif mind <= 0.0:
		game_over.emit("The darkness consumed your sanity.")

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> bool:
	var data := {
		"body": body, "mind": mind, "hunger": hunger, "torch": torch, "coins": coins,
		"consumables": consumables,
		"owned_weapons": owned_weapons,
		"owned_armor": owned_armor,
		"key_items": key_items,
		"equipped_weapon": equipped_weapon,
		"equipped_armor": equipped_armor,
		"flags": flags,
		"player_position": [player_position.x, player_position.y],
		"last_safe_position": [last_safe_position.x, last_safe_position.y]
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		message_requested.emit("Save failed.")
		return false
	f.store_string(JSON.stringify(data))
	message_requested.emit("Progress saved at the Deep Shrine.")
	return true

func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	body = float(parsed.get("body", 100.0))
	mind = float(parsed.get("mind", 100.0))
	hunger = float(parsed.get("hunger", 100.0))
	torch = float(parsed.get("torch", 100.0))
	coins = int(parsed.get("coins", 0))
	consumables = parsed.get("consumables", consumables)
	owned_weapons = Array(parsed.get("owned_weapons", ["Rusted Sword"]))
	owned_armor = Array(parsed.get("owned_armor", ["Ragged Shirt"]))
	key_items = Array(parsed.get("key_items", []))
	equipped_weapon = str(parsed.get("equipped_weapon", "Rusted Sword"))
	equipped_armor = str(parsed.get("equipped_armor", "Ragged Shirt"))
	flags = parsed.get("flags", {})
	var p = parsed.get("player_position", [240.0, 600.0])
	player_position = Vector2(float(p[0]), float(p[1]))
	var s = parsed.get("last_safe_position", [240.0, 600.0])
	last_safe_position = Vector2(float(s[0]), float(s[1]))
	stats_changed.emit()
	inventory_changed.emit()
	return true
