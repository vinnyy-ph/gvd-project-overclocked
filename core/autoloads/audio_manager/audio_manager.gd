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
	add_child(bgm_player)
	add_child(sfx_player)
	
	# Set BGM to loop
	bgm_player.bus = "Master"
	sfx_player.bus = "Master"

func play_bgm(track_name: String):
	if bgm_tracks.has(track_name):
		var stream = bgm_tracks[track_name]
		if bgm_player.stream == stream and bgm_player.playing:
			return # Already playing
			
		bgm_player.stream = stream
		# Ensure looping is enabled for the stream
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		elif stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			
		bgm_player.play()

func stop_bgm():
	bgm_player.stop()

func play_sfx(sfx_name: String):
	if sfx_library.has(sfx_name):
		# For overlapping SFX, we might want multiple players, 
		# but for this task, a simple one-shot or dedicated player is fine.
		var p = AudioStreamPlayer.new()
		add_child(p)
		p.stream = sfx_library[sfx_name]
		p.finished.connect(p.queue_free)
		p.play()
