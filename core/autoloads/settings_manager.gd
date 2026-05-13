extends Node

const SETTINGS_FILE = "user://settings.cfg"

var music_volume: float = 0.8
var sfx_volume: float = 0.8
var quality: int = 2 # 0: Low, 1: Medium, 2: High

func _ready():
	load_settings()
	apply_settings()

func apply_settings():
	# Apply Audio
	set_bus_volume("Music", music_volume)
	set_bus_volume("SFX", sfx_volume)
	
	# Apply Quality
	match quality:
		0: # Low
			RenderingServer.viewport_set_msaa_2d(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_DISABLED)
			# Add more low-quality settings here if needed
		1: # Medium
			RenderingServer.viewport_set_msaa_2d(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_2X)
		2: # High
			RenderingServer.viewport_set_msaa_2d(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_4X)

func set_bus_volume(bus_name: String, volume_fraction: float):
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index != -1:
		# Map 0.0-1.0 to -80dB to 0dB (or slightly more)
		var db = linear_to_db(max(volume_fraction, 0.0001))
		AudioServer.set_bus_volume_db(bus_index, db)
		AudioServer.set_bus_mute(bus_index, volume_fraction <= 0)

func save_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("graphics", "quality", quality)
	config.save(SETTINGS_FILE)

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	if err == OK:
		music_volume = config.get_value("audio", "music_volume", 0.8)
		sfx_volume = config.get_value("audio", "sfx_volume", 0.8)
		quality = config.get_value("graphics", "quality", 2)
