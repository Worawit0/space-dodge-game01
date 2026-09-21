extends Node

var ambient_player: AudioStreamPlayer
var ui_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_cursor := 0

func _ready() -> void:
	_ensure_bus("Ambient", -10.0)
	_ensure_bus("SFX", -4.0)
	_ensure_bus("UI", -7.0)
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = "Ambient"
	add_child(ambient_player)
	ui_player = AudioStreamPlayer.new()
	ui_player.bus = "UI"
	add_child(ui_player)
	for i in range(6):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)

func _ensure_bus(bus_name: String, db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		AudioServer.add_bus(AudioServer.bus_count)
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_volume_db(idx, db)

func _safe_load(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream

func play_ambient(path: String = "res://assets/audio/dungeon_ambient.wav") -> void:
	var stream := _safe_load(path)
	if stream == null:
		return
	if stream is AudioStreamWAV:
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	ambient_player.stream = stream
	if not ambient_player.playing:
		ambient_player.play()

func stop_ambient() -> void:
	if ambient_player:
		ambient_player.stop()

func play_sfx(path: String) -> void:
	var stream := _safe_load(path)
	if stream == null or sfx_players.is_empty():
		return
	var p := sfx_players[sfx_cursor % sfx_players.size()]
	sfx_cursor += 1
	p.stream = stream
	p.pitch_scale = randf_range(0.96, 1.04)
	p.play()

func play_ui() -> void:
	var stream := _safe_load("res://assets/audio/ui_click.wav")
	if stream == null:
		return
	ui_player.stream = stream
	ui_player.play()
