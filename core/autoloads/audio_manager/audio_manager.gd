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
	"success": preload("res://assets/audio/sfx/success.wav"),
	"fail": preload("res://assets/audio/sfx/fail.wav"),
	"coin": preload("res://assets/audio/sfx/coin.wav")
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
		if bgm_player.stream == bgm_tracks[track_name] and bgm_player.playing:
			return # Already playing
			
		bgm_player.stream = bgm_tracks[track_name]
		# Ensure looping is handled. In Godot 4, it's often on the resource or done via code for WAV.
		# For .wav, we might need to enable it if not set in import settings.
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
