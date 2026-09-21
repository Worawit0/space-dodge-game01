extends CanvasLayer

signal closed

const UI = preload("res://scripts/ui/ui_factory.gd")

var root: Control
var item_list: ItemList
var detail_title: Label
var detail_text: Label
var stats_text: Label
var action_button: Button
var category := "Items"
var entries: Array[String] = []

func _ready() -> void:
	_build()
	GameState.inventory_changed.connect(refresh)

func _unhandled_input(event: InputEvent) -> void:
	if root and root.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()

func is_open() -> bool:
	return root != null and root.visible

func open() -> void:
	refresh()
	root.visible = true
	AudioManager.play_ui()

func close() -> void:
	root.visible = false
	AudioManager.play_ui()
	closed.emit()

func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0,0,0,0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.07
	panel.anchor_top = 0.07
	panel.anchor_right = 0.93
	panel.anchor_bottom = 0.93
	panel.add_theme_stylebox_override("panel", UI.panel_style(0.985))
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	margin.add_child(outer)
	outer.add_child(UI.title_label("INVENTORY", 34))

	var cats := HBoxContainer.new()
	cats.add_theme_constant_override("separation", 8)
	outer.add_child(cats)
	for c in ["Items", "Weapons", "Armor", "Key Items"]:
		var b := Button.new()
		b.text = c.to_upper()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI.style_button(b)
		b.pressed.connect(_set_category.bind(c))
		cats.add_child(b)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 430
	outer.add_child(split)

	item_list = ItemList.new()
	item_list.custom_minimum_size = Vector2(420, 0)
	item_list.add_theme_font_size_override("font_size", 19)
	item_list.item_selected.connect(_on_selected)
	split.add_child(item_list)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	split.add_child(right)

	detail_title = UI.title_label("Select an item", 26)
	detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	right.add_child(detail_title)

	detail_text = UI.body_label("", 18)
	detail_text.custom_minimum_size = Vector2(0, 140)
	right.add_child(detail_text)

	stats_text = UI.body_label("", 18)
	stats_text.add_theme_color_override("font_color", Color(0.82,0.72,0.52))
	right.add_child(stats_text)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)

	action_button = Button.new()
	action_button.text = "ACTION"
	UI.style_button(action_button)
	action_button.pressed.connect(_on_action)
	right.add_child(action_button)

	var close_button := Button.new()
	close_button.text = "BACK  [Esc]"
	UI.style_button(close_button)
	close_button.pressed.connect(close)
	right.add_child(close_button)

func _set_category(next_category: String) -> void:
	category = next_category
	AudioManager.play_ui()
	refresh()

func refresh() -> void:
	if not item_list:
		return
	item_list.clear()
	entries.clear()
	match category:
		"Items":
			for name in GameState.consumables.keys():
				if int(GameState.consumables[name]) > 0:
					entries.append(str(name))
					item_list.add_item("%s   x%d" % [name, int(GameState.consumables[name])])
		"Weapons":
			for name in GameState.owned_weapons:
				entries.append(str(name))
				var mark := "  ✓ EQUIPPED" if name == GameState.equipped_weapon else ""
				item_list.add_item("%s   ATK +%d%s" % [name, int(GameState.WEAPONS[name].attack), mark])
		"Armor":
			for name in GameState.owned_armor:
				entries.append(str(name))
				var mark := "  ✓ EQUIPPED" if name == GameState.equipped_armor else ""
				item_list.add_item("%s   DEF +%d%s" % [name, int(GameState.ARMOR[name].defense), mark])
		"Key Items":
			for name in GameState.key_items:
				entries.append(str(name))
				item_list.add_item(str(name))
	stats_text.text = "BODY %.0f/100   MIND %.0f   HUNGER %.0f   TORCH %.0f
Weapon: %s (ATK %d)
Armor: %s (DEF %d)" % [
		GameState.body, GameState.mind, GameState.hunger, GameState.torch,
		GameState.equipped_weapon, GameState.attack_power(),
		GameState.equipped_armor, GameState.armor_defense()
	]
	if entries.is_empty():
		detail_title.text = "Nothing here"
		detail_text.text = "This category is empty."
		action_button.disabled = true
	else:
		item_list.select(0)
		_show_entry(0)

func _on_selected(index: int) -> void:
	_show_entry(index)

func _show_entry(index: int) -> void:
	if index < 0 or index >= entries.size():
		return
	var name := entries[index]
	detail_title.text = name
	match category:
		"Items":
			detail_text.text = _item_description(name)
			action_button.text = "USE ITEM"
			action_button.disabled = false
		"Weapons":
			detail_text.text = str(GameState.WEAPONS[name].description)
			action_button.text = "EQUIPPED" if name == GameState.equipped_weapon else "EQUIP WEAPON"
			action_button.disabled = name == GameState.equipped_weapon
		"Armor":
			detail_text.text = str(GameState.ARMOR[name].description)
			action_button.text = "EQUIPPED" if name == GameState.equipped_armor else "EQUIP ARMOR"
			action_button.disabled = name == GameState.equipped_armor
		"Key Items":
			detail_text.text = "A key object tied to the dungeon's progression."
			action_button.text = "KEY ITEM"
			action_button.disabled = true

func _item_description(name: String) -> String:
	match name:
		"Ration": return "Restores hunger. Food is scarce below."
		"Bandage": return "Restores BODY. Essential after a bad encounter."
		"Blue Vial": return "Restores MIND and steadies the nerves."
		"Torch Oil": return "Refills the torch reserve."
		_: return "A survival item."

func _on_action() -> void:
	var selected := item_list.get_selected_items()
	if selected.is_empty():
		return
	var idx := int(selected[0])
	if idx < 0 or idx >= entries.size():
		return
	var name := entries[idx]
	var changed := false
	match category:
		"Items":
			changed = GameState.use_consumable(name)
		"Weapons":
			changed = GameState.equip_weapon(name)
		"Armor":
			changed = GameState.equip_armor(name)
	if changed:
		AudioManager.play_ui()
		refresh()
