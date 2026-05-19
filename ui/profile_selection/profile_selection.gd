extends Control

@onready var profile_list: VBoxContainer = $ScrollContainer/ProfileList

var profile_slot_scene = preload("res://ui/profile_selection/profile_slot.tscn")
var name_prompt_scene = preload("res://ui/prompts/NamePrompt.tscn")

func _ready() -> void:
	PauseMenu.pause_button.visible = false
	update_profile_slots()
	
	$ReturnButton.pressed.connect(_on_return_pressed)
	$SettingsButton.pressed.connect(_on_settings_pressed)
	$ExitButton.pressed.connect(_on_exit_pressed)

func update_profile_slots():
	# Clear existing
	for child in profile_list.get_children():
		child.queue_free()
		
	var dev_slot = profile_slot_scene.instantiate()
	profile_list.add_child(dev_slot)
	
	var dev_data = SaveManager.get_profile_data(999)
	if dev_data:
		dev_slot.set_data(dev_data)
	else:
		dev_slot.set_data({
			"player_name": "[DEV MODE]",
			"current_day": 30,
			"current_money": 9999999,
			"unlocked_upgrades": {
				"shop_space": 0,
				"flat_monitors": 0,
				"mid_range_cpu": 0,
				"graphics_upgrade": 0,
				"premium_power_strip": 0,
				"cable_management_kit": 0
			}
		})
	dev_slot.pressed.connect(_on_dev_mode_pressed)
		
	var profiles = SaveManager.get_all_profiles()
	var has_profiles = false
	for i in range(10):
		var data = profiles[i]
		if data:
			has_profiles = true
			var slot = profile_slot_scene.instantiate()
			profile_list.add_child(slot)
			slot.set_data(data)
			slot.pressed.connect(_on_profile_pressed.bind(i))
	
	if not has_profiles and not dev_data:
		# No profiles to continue
		pass

func _on_dev_mode_pressed():
	GameManager.dev_mode = true
	SaveManager.active_profile_id = 999
	
	var loaded = SaveManager.load_game()
	if loaded and SaveManager.game_state.get("dev_reset_v2_done", false):
		GameManager.load_game()
	else:
		# Reset dev mode profile (Day 30, Level 0 upgrades, Max Money)
		SaveManager.player_name = "[DEV MODE]"
		SaveManager.current_money = 9999999
		SaveManager.lifetime_money = 9999999
		SaveManager.max_days_survived = 0
		SaveManager.current_day = 30
		SaveManager.saved_scene = ""
		SaveManager.owned_decorations = []
		SaveManager.placed_decorations = []
		SaveManager.current_floor = ""
		SaveManager.current_wall = ""
		SaveManager.game_state = {"dev_reset_v2_done": true}
		SaveManager.unlocked_upgrades = {
			"flat_monitors": 0,
			"mid_range_cpu": 0,
			"graphics_upgrade": 0,
			"premium_power_strip": 0,
			"cable_management_kit": 0,
			"shop_space": 0
		}
		
		# Sync GameManager internal state
		GameManager.load_game() 
		SaveManager.save_game()
	
	PauseMenu.pause_button.visible = true
	if SaveManager.saved_scene != "":
		get_tree().change_scene_to_file(SaveManager.saved_scene)
	else:
		get_tree().change_scene_to_file("res://core/shop_floor/shop_floor_scrollable.tscn")

func _on_profile_pressed(slot_index: int):
	GameManager.dev_mode = false
	var profiles = SaveManager.get_all_profiles()
	# Only handle existing profiles (should be the only ones connected now)
	if profiles[slot_index] != null:
		SaveManager.active_profile_id = slot_index
		if SaveManager.load_game():
			GameManager.load_game()
			PauseMenu.pause_button.visible = true
			if SaveManager.saved_scene != "":
				get_tree().change_scene_to_file(SaveManager.saved_scene)
			else:
				get_tree().change_scene_to_file("res://core/shop_floor/shop_floor_scrollable.tscn")

func _on_return_pressed():
	get_tree().change_scene_to_file("res://ui/main_menu_v2/MainMenuV2.tscn")

func _on_settings_pressed():
	GameManager.previous_scene = "res://ui/profile_selection/profile_selection.tscn"
	get_tree().change_scene_to_file("res://ui/settings/settings.tscn")

func _on_exit_pressed():
	_show_exit_confirmation()

func _show_exit_confirmation() -> void:
	var exit_prompt_scene = load("res://ui/pause/ExitPrompt.tscn")
	var exit_prompt = exit_prompt_scene.instantiate()
	add_child(exit_prompt)
