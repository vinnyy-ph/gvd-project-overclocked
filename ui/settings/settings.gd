extends Control

@onready var music_slider = $MusicSlider
@onready var sfx_slider = $SFXSlider
@onready var back_button = $Yes

@onready var high_btn = $Button
@onready var medium_btn = $Medium
@onready var low_btn = $Low

const HIGH_SELECTED = preload("res://assets/images/ui/settings/selected/high.png")
const HIGH_NOT = preload("res://assets/images/ui/settings/notselected/high.png")
const MEDIUM_SELECTED = preload("res://assets/images/ui/settings/selected/medium.png")
const MEDIUM_NOT = preload("res://assets/images/ui/settings/notselected/medium.png")
const LOW_SELECTED = preload("res://assets/images/ui/settings/selected/low.png")
const LOW_NOT = preload("res://assets/images/ui/settings/notselected/low.png")

func _ready():
	# Load Current Settings
	music_slider.value = SettingsManager.music_volume
	sfx_slider.value = SettingsManager.sfx_volume
	
	_update_quality_visuals()
	
	# Connect Signals
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	
	high_btn.pressed.connect(_on_quality_pressed.bind(2))
	medium_btn.pressed.connect(_on_quality_pressed.bind(1))
	low_btn.pressed.connect(_on_quality_pressed.bind(0))
	
	back_button.pressed.connect(_on_back_pressed)

func _on_music_slider_changed(value: float):
	SettingsManager.music_volume = value
	SettingsManager.apply_settings()

func _on_sfx_slider_changed(value: float):
	SettingsManager.sfx_volume = value
	SettingsManager.apply_settings()

func _on_quality_pressed(index: int):
	SettingsManager.quality = index
	SettingsManager.apply_settings()
	_update_quality_visuals()
	AudioManager.play_sfx("click")

func _update_quality_visuals():
	high_btn.icon = HIGH_SELECTED if SettingsManager.quality == 2 else HIGH_NOT
	medium_btn.icon = MEDIUM_SELECTED if SettingsManager.quality == 1 else MEDIUM_NOT
	low_btn.icon = LOW_SELECTED if SettingsManager.quality == 0 else LOW_NOT

func _on_back_pressed():
	SettingsManager.save_settings()
	AudioManager.play_sfx("click")
	if GameManager.previous_scene != "":
		get_tree().change_scene_to_file(GameManager.previous_scene)
	else:
		get_tree().change_scene_to_file("res://ui/main_menu_v2/MainMenuV2.tscn")
