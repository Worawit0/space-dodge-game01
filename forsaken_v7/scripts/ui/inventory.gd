extends CanvasLayer

signal closed

const UI = preload("res://scripts/ui/ui_factory.gd")

var root: Control
var item_list: ItemList
var preview: TextureRect
var detail_title: Label
var detail_text: Label
var stats_text: Label
var action_button: Button
var category := "Items"
var entries: Array[String] = []
var tab_buttons: Dictionary = {}

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

func _icon_path(name: String) -> String:
	return "res://assets/v8/items/" + name.to_lower().replace(" ","_").replace("-","_") + ".png"

func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)

	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/v9/ui/inventory_bg.png"):
		bg.texture = load("res://assets/v9/ui/inventory_bg.png")
	root.add_child(bg)

	var dim := ColorRect.new()
	dim.color = Color(0.01,0.005,0.009,0.58)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.055
	panel.anchor_top = 0.045
	panel.anchor_right = 0.945
	panel.anchor_bottom = 0.955
	panel.add_theme_stylebox_override("panel",UI.panel_style(0.985))
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",34)
	margin.add_theme_constant_override("margin_right",34)
	margin.add_theme_constant_override("margin_top",26)
	margin.add_theme_constant_override("margin_bottom",26)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation",12)
	margin.add_child(outer)

	var title_row := HBoxContainer.new()
	outer.add_child(title_row)
	var title := UI.title_label("INVENTORY",34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var equipped := UI.heading_label("EQUIPMENT & SURVIVAL",14)
	equipped.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(equipped)
	UI.add_divider(outer)

	var cats := HBoxContainer.new()
	cats.add_theme_constant_override("separation",8)
	outer.add_child(cats)
	for c in ["Items","Weapons","Armor","Key Items"]:
		var b := Button.new()
		b.text = c.to_upper()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI.style_button(b,true)
		b.pressed.connect(_set_category.bind(c))
		cats.add_child(b)
		tab_buttons[c] = b

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 445
	outer.add_child(split)

	var left_panel := PanelContainer.new()
	left_panel.add_theme_stylebox_override("panel",UI.slot_style())
	left_panel.custom_minimum_size = Vector2(420,0)
	split.add_child(left_panel)
	item_list = ItemList.new()
	item_list.custom_minimum_size = Vector2(395,0)
	UI.style_item_list(item_list)
	item_list.item_selected.connect(_on_selected)
	left_panel.add_child(item_list)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation",12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation",20)
	right.add_child(top)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(170,170)
	preview_panel.add_theme_stylebox_override("panel",UI.slot_style())
	top.add_child(preview_panel)
	preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(142,142)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_panel.add_child(preview)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation",8)
	top.add_child(title_box)
	detail_title = UI.title_label("Select an item",27)
	detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_box.add_child(detail_title)
	stats_text = UI.body_label("",14)
	stats_text.add_theme_color_override("font_color",Color(0.82,0.69,0.50))
	title_box.add_child(stats_text)

	UI.add_divider(right)
	detail_text = UI.body_label("",17)
	detail_text.custom_minimum_size = Vector2(0,130)
	detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(detail_text)

	action_button = Button.new()
	action_button.text = "ACTION"
	action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(action_button)
	action_button.pressed.connect(_on_action)
	right.add_child(action_button)

	var close_button := Button.new()
	close_button.text = "BACK  [ESC]"
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(close_button,true)
	close_button.pressed.connect(close)
	right.add_child(close_button)

func _set_category(next_category: String) -> void:
	category = next_category
	AudioManager.play_ui()
	refresh()

func _refresh_tabs() -> void:
	for key in tab_buttons.keys():
		var b: Button = tab_buttons[key]
		if key == category:
			b.add_theme_color_override("font_color",Color(1.0,0.76,0.36))
		else:
			b.add_theme_color_override("font_color",Color(0.84,0.79,0.71))

func refresh() -> void:
	if not item_list:
		return
	_refresh_tabs()
	item_list.clear()
	entries.clear()
	match category:
		"Items":
			for name in GameState.consumables.keys():
				if int(GameState.consumables[name]) > 0:
					entries.append(str(name))
					item_list.add_item("%s   x%d" % [name,int(GameState.consumables[name])])
		"Weapons":
			for name in GameState.owned_weapons:
				entries.append(str(name))
				var mark := "   [EQUIPPED]" if name == GameState.equipped_weapon else ""
				item_list.add_item("%s   ATK +%d%s" % [name,int(GameState.WEAPONS[name].attack),mark])
		"Armor":
			for name in GameState.owned_armor:
				entries.append(str(name))
				var mark := "   [EQUIPPED]" if name == GameState.equipped_armor else ""
				item_list.add_item("%s   DEF +%d%s" % [name,int(GameState.ARMOR[name].defense),mark])
		"Key Items":
			for name in GameState.key_items:
				entries.append(str(name))
				item_list.add_item(str(name))

	stats_text.text = "BODY %.0f / 100    MIND %.0f    HUNGER %.0f    TORCH %.0f\n\nWEAPON  %s    ATK %d\nARMOR     %s    DEF %d" % [
		GameState.body,GameState.mind,GameState.hunger,GameState.torch,
		GameState.equipped_weapon,GameState.attack_power(),
		GameState.equipped_armor,GameState.armor_defense()
	]

	if entries.is_empty():
		detail_title.text = "Nothing here"
		detail_text.text = "This category is empty."
		preview.texture = null
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
	var icon := _icon_path(name)
	preview.texture = load(icon) if ResourceLoader.exists(icon) else null
	match category:
		"Items":
			detail_text.text = _item_description(name)
			action_button.text = "USE ITEM"
			action_button.disabled = false
		"Weapons":
			detail_text.text = str(GameState.WEAPONS[name].description) + "\n\nThe weapon is visibly carried by the player after equipping."
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
		"Bandage": return "Restores BODY and keeps you alive after a bad encounter."
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
