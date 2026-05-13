extends Node

@onready var bgm_player = AudioStreamPlayer.new()
@onready var sfx_player = AudioStreamPlayer.new()

var bgm_tracks = {
	"shop": preload("res://assets/audio/bgm/shop_chill.ogg"),
	"minigame": preload("res://assets/audio/bgm/minigame_fast.ogg")
}

var sfx_library = {
	"click": preload("res://assets/audio/sfx/button_click.wav"),
	"alert": preload("res://assets/audio/sfx/issue_spawned.wav"),
	"success": preload("res://assets/audio/sfx/issue_complete.ogg"),
	"fail": preload("res://assets/audio/sfx/issue_failed.ogg"),
	"coin": preload("res://assets/audio/sfx/coin.wav"),
	"day_start": preload("res://assets/audio/sfx/day_start.ogg")
}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	add_child(bgm_player)
	add_child(sfx_player)
	
	bgm_player.bus = "Music"
	sfx_player.bus = "SFX"

func _setup_buses():
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_idx, "Music")
		AudioServer.set_bus_send(bus_idx, "Master")
	
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_idx, "SFX")
		AudioServer.set_bus_send(bus_idx, "Master")

var current_bgm_track: String = ""
var bgm_positions: Dictionary = {}

func play_bgm(track_name: String):
	if bgm_tracks.has(track_name):
		var stream = bgm_tracks[track_name]
		if current_bgm_track == track_name and bgm_player.playing:
			return # Already playing
		
		# Save position of the current track before switching
		if current_bgm_track != "" and bgm_player.playing:
			bgm_positions[current_bgm_track] = bgm_player.get_playback_position()
			
		bgm_player.stream = stream
		# Ensure looping is enabled for the stream
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		elif stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		
		# Resume from saved position if available
		var start_pos = bgm_positions.get(track_name, 0.0)
		bgm_player.play(start_pos)
		current_bgm_track = track_name

func stop_bgm():
	if current_bgm_track != "" and bgm_player.playing:
		bgm_positions[current_bgm_track] = bgm_player.get_playback_position()
	bgm_player.stop()
	current_bgm_track = ""

var active_result_sfx: AudioStreamPlayer = null

func play_result_sfx(sfx_name: String):
	if not sfx_library.has(sfx_name): return
	
	stop_result_sfx()
	
	active_result_sfx = AudioStreamPlayer.new()
	add_child(active_result_sfx)
	active_result_sfx.stream = sfx_library[sfx_name]
	active_result_sfx.bus = "SFX"
	
	# Duck BGM
	var tween = create_tween()
	tween.tween_property(bgm_player, "volume_db", -15.0, 0.2)
	
	active_result_sfx.finished.connect(_on_result_sfx_finished)
	active_result_sfx.play()

func _on_result_sfx_finished():
	if active_result_sfx:
		active_result_sfx.queue_free()
		active_result_sfx = null
	
	var tween = create_tween()
	# Restore BGM volume
	tween.tween_property(bgm_player, "volume_db", 0.0, 0.5)

func stop_result_sfx():
	if active_result_sfx and is_instance_valid(active_result_sfx):
		active_result_sfx.stop()
		_on_result_sfx_finished()

func play_sfx(sfx_name: String):
	if sfx_library.has(sfx_name):
		var p = AudioStreamPlayer.new()
		add_child(p)
		p.stream = sfx_library[sfx_name]
		p.bus = "SFX"
		p.finished.connect(p.queue_free)
		p.play()
