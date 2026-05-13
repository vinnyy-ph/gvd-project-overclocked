extends Control

@onready var music_slider = $SettingsMenu/Content/MusicContainer/MusicSlider
@onready var music_label = $SettingsMenu/Content/MusicContainer/MusicLabel
@onready var sfx_slider = $SettingsMenu/Content/SFXContainer/SFXSlider
@onready var sfx_label = $SettingsMenu/Content/SFXContainer/SFXLabel
@onready var quality_option = $SettingsMenu/Content/QualityContainer/QualityOption
@onready var back_button = $SettingsMenu/Content/BackButton

func _ready():
	# Setup Quality Options
	quality_option.add_item("Low", 0)
	quality_option.add_item("Medium", 1)
	quality_option.add_item("High", 2)
	
	# Load Current Settings
	music_slider.value = SettingsManager.music_volume
	sfx_slider.value = SettingsManager.sfx_volume
	quality_option.selected = SettingsManager.quality
	
	_update_labels()
	
	# Connect Signals
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	quality_option.item_selected.connect(_on_quality_selected)
	back_button.pressed.connect(_on_back_pressed)

func _update_labels():
	music_label.text = "Music Volume: %d%%" % (music_slider.value * 100)
	sfx_label.text = "SFX Volume: %d%%" % (sfx_slider.value * 100)

func _on_music_slider_changed(value: float):
	SettingsManager.music_volume = value
	SettingsManager.apply_settings()
	_update_labels()

func _on_sfx_slider_changed(value: float):
	SettingsManager.sfx_volume = value
	SettingsManager.apply_settings()
	_update_labels()

func _on_quality_selected(index: int):
	SettingsManager.quality = index
	SettingsManager.apply_settings()

func _on_back_pressed():
	SettingsManager.save_settings()
	if GameManager.previous_scene != "":
		get_tree().change_scene_to_file(GameManager.previous_scene)
	else:
		get_tree().change_scene_to_file("res://ui/main_menu_v2/MainMenuV2.tscn")
