extends Node

var ambient_player: AudioStreamPlayer
var ui_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_cursor := 0

const EVENTS := {
	"ambient": ["res://assets/v8/audio/ambient.mp3", "res://assets/audio/dungeon_ambient.wav"],
	"footstep": ["res://assets/v8/audio/footstep.mp3", "res://assets/audio/step.wav"],
	"door": ["res://assets/v8/audio/door.mp3", "res://assets/audio/door.wav"],
	"locked": ["res://assets/audio/locked.wav"],
	"monster": ["res://assets/v8/audio/monster_growl.mp3", "res://assets/audio/monster.wav"],
	"hit": ["res://assets/audio/hit.wav"],
	"hurt": ["res://assets/audio/hurt.wav"],
	"pickup": ["res://assets/audio/pickup.wav"],
	"shrine": ["res://assets/audio/shrine.wav"],
	"ritual": ["res://assets/audio/ritual.wav"],
	"ui": ["res://assets/audio/ui_click.wav"]
}

func _ready() -> void:
	_ensure_bus("Ambient", -13.0)
	_ensure_bus("SFX", -5.0)
	_ensure_bus("UI", -8.0)
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = "Ambient"
	add_child(ambient_player)
	ui_player = AudioStreamPlayer.new()
	ui_player.bus = "UI"
	add_child(ui_player)
	for i in range(8):
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

func _first_stream(event_name: String) -> AudioStream:
	if not EVENTS.has(event_name):
		return null
	for path in EVENTS[event_name]:
		if ResourceLoader.exists(path):
			var stream = load(path)
			if stream is AudioStream:
				return stream
	return null

func play_ambient() -> void:
	var stream := _first_stream("ambient")
	if stream == null:
		return
	if stream is AudioStreamWAV:
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamMP3:
		stream = stream.duplicate()
		stream.loop = true
	ambient_player.stream = stream
	ambient_player.volume_db = -2.0
	if not ambient_player.playing:
		ambient_player.play()

func stop_ambient() -> void:
	if ambient_player:
		ambient_player.stop()

func play_event(event_name: String) -> void:
	if event_name == "ambient":
		play_ambient()
		return
	var stream := _first_stream(event_name)
	if stream == null:
		return
	if event_name == "ui":
		ui_player.stream = stream
		ui_player.pitch_scale = 1.0
		ui_player.play()
		return
	if sfx_players.is_empty():
		return
	var p := sfx_players[sfx_cursor % sfx_players.size()]
	sfx_cursor += 1
	p.stream = stream
	p.pitch_scale = randf_range(0.97, 1.03)
	match event_name:
		"footstep":
			p.volume_db = -10.0
			p.pitch_scale = randf_range(0.91,1.08)
		"monster":
			p.volume_db = -3.0
		"door":
			p.volume_db = -4.0
		_:
			p.volume_db = -6.0
	p.play()

func play_sfx(path: String) -> void:
	if not ResourceLoader.exists(path) or sfx_players.is_empty():
		return
	var p := sfx_players[sfx_cursor % sfx_players.size()]
	sfx_cursor += 1
	p.stream = load(path)
	p.pitch_scale = randf_range(0.97,1.03)
	p.volume_db = -6.0
	p.play()

func play_ui() -> void:
	play_event("ui")
