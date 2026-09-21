extends Node

const MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const GAME_SCENE := preload("res://scenes/world/game_world.tscn")
const GAME_OVER_SCENE := preload("res://scenes/ui/game_over.tscn")
const ENDING_SCENE := preload("res://scenes/ui/ending.tscn")

@onready var screen_root: Node = $ScreenRoot

func _ready() -> void:
	GameState.game_over.connect(_on_game_over)
	_show_menu()

func _clear_screen() -> void:
	for child in screen_root.get_children():
		screen_root.remove_child(child)
		child.queue_free()

func _show_menu() -> void:
	_clear_screen()
	AudioManager.stop_ambient()
	var menu = MENU_SCENE.instantiate()
	screen_root.add_child(menu)
	menu.start_new.connect(_start_new)
	menu.continue_game.connect(_continue_game)
	menu.quit_requested.connect(func(): get_tree().quit())

func _start_new() -> void:
	GameState.reset_new_game()
	_start_game()

func _continue_game() -> void:
	if GameState.load_game():
		_start_game()
	else:
		_start_new()

func _start_game() -> void:
	_clear_screen()
	var game = GAME_SCENE.instantiate()
	screen_root.add_child(game)
	game.return_to_menu.connect(_show_menu)
	game.ending_reached.connect(_on_ending)

func _on_game_over(reason: String) -> void:
	_clear_screen()
	AudioManager.stop_ambient()
	var over = GAME_OVER_SCENE.instantiate()
	screen_root.add_child(over)
	over.setup(reason)
	over.retry_last_save.connect(_retry_last_save)
	over.new_descent.connect(_start_new)
	over.main_menu.connect(_show_menu)

func _retry_last_save() -> void:
	if GameState.load_game():
		_start_game()
	else:
		_start_new()

func _on_ending(title: String, text: String) -> void:
	_clear_screen()
	AudioManager.stop_ambient()
	var ending = ENDING_SCENE.instantiate()
	screen_root.add_child(ending)
	ending.setup(title, text)
	ending.main_menu.connect(_show_menu)
