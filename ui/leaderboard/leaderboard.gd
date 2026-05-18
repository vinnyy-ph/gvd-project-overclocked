extends Control

@onready var leaderboard_list = $ScrollContainer/LeaderboardList
@onready var return_button = $ReturnButton
@onready var settings_button = $SettingsButton
@onready var exit_button = $ExitButton

var entry_scene = preload("res://ui/leaderboard/leaderboard_entry.tscn")

func _ready() -> void:
	# Connect buttons
	return_button.pressed.connect(_on_return_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	populate_leaderboard()

func populate_leaderboard():
	# Clear existing entries
	for child in leaderboard_list.get_children():
		child.queue_free()
	
	var entries = LeaderboardManager.get_entries()
	var rank = 1
	for entry_data in entries:
		var entry = entry_scene.instantiate()
		leaderboard_list.add_child(entry)
		entry.set_data(rank, entry_data)
		rank += 1

func _on_return_pressed():
	get_tree().change_scene_to_file("res://ui/main_menu_v2/MainMenuV2.tscn")

func _on_settings_pressed():
	GameManager.previous_scene = "res://ui/leaderboard/leaderboard.tscn"
	get_tree().change_scene_to_file("res://ui/settings/settings.tscn")

func _on_exit_pressed():
	var exit_prompt_scene = load("res://ui/pause/ExitPrompt.tscn")
	var exit_prompt = exit_prompt_scene.instantiate()
	add_child(exit_prompt)
