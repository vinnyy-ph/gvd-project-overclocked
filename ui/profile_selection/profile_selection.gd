extends Control

@onready var profile_containers: Array = [
	$ProfileContainer,
	$ProfileContainer2,
	$ProfileContainer3
]

@onready var name_input_dialog: Control = $NameInputDialog
@onready var name_edit: LineEdit = $NameInputDialog/Panel/VBoxContainer/NameEdit
@onready var confirm_name_button: Button = $NameInputDialog/Panel/VBoxContainer/HBoxContainer/ConfirmButton
@onready var cancel_name_button: Button = $NameInputDialog/Panel/VBoxContainer/HBoxContainer/CancelButton

var current_selecting_slot: int = -1

func _ready() -> void:
	PauseMenu.pause_button.visible = false
	update_profile_slots()
	
	$ReturnButton.pressed.connect(_on_return_pressed)
	$SettingsButton.pressed.connect(_on_settings_pressed)
	$ExitButton.pressed.connect(_on_exit_pressed)
	
	for i in range(profile_containers.size()):
		profile_containers[i].pressed.connect(_on_profile_pressed.bind(i))
	
	confirm_name_button.pressed.connect(_on_confirm_name_pressed)
	cancel_name_button.pressed.connect(_on_cancel_name_pressed)
	name_input_dialog.visible = false

func update_profile_slots():
	var profiles = SaveManager.get_all_profiles()
	for i in range(3):
		var container = profile_containers[i]
		var data = profiles[i]
		
		var name_label = container.get_node("NameClipper/ProfileNameLabel")
		var progress_label = container.get_node("ProgressLabel")
		var money_label = container.get_node("MoneyLabel")
		var slots_label = container.get_node("PCSlotsLabel")
		
		if data:
			name_label.text = str(data.get("player_name", "EMPTY")).to_upper()
			progress_label.text = "DAY " + str(int(data.get("current_day", 1)))
			money_label.text = "P%.1f" % float(data.get("current_money", 0))
			
			var upgrades = data.get("unlocked_upgrades", {})
			var slots = 2 + upgrades.get("shop_space", 0)
			slots_label.text = str(int(slots)) + " UNITs"
		else:
			name_label.text = "EMPTY SLOT"
			progress_label.text = ""
			money_label.text = ""
			slots_label.text = ""

func _on_profile_pressed(slot_index: int):
	var profiles = SaveManager.get_all_profiles()
	if profiles[slot_index] == null:
		# Empty slot, ask for name
		current_selecting_slot = slot_index
		name_edit.text = ""
		name_input_dialog.visible = true
		name_edit.grab_focus()
	else:
		# Existing profile, load and start
		SaveManager.active_profile_id = slot_index
		if SaveManager.load_game():
			GameManager.load_game()
			PauseMenu.pause_button.visible = true
			get_tree().change_scene_to_file("res://core/shop_floor/shop_floor_scrollable.tscn")

func _on_confirm_name_pressed():
	var player_name = name_edit.text.strip_edges()
	if player_name == "":
		player_name = "Player " + str(current_selecting_slot + 1)
	
	SaveManager.create_new_profile(current_selecting_slot, player_name)
	name_input_dialog.visible = false
	
	# Start new game
	GameManager.new_game()
	PauseMenu.pause_button.visible = true
	get_tree().change_scene_to_file("res://core/shop_floor/shop_floor_scrollable.tscn")

func _on_cancel_name_pressed():
	name_input_dialog.visible = false

func _on_return_pressed():
	get_tree().change_scene_to_file("res://ui/main_menu_v2/MainMenuV2.tscn")

func _on_settings_pressed():
	GameManager.previous_scene = "res://ui/profile_selection/profile_selection.tscn"
	get_tree().change_scene_to_file("res://ui/settings/settings_menu.tscn")

func _on_exit_pressed():
	_show_exit_confirmation()

func _show_exit_confirmation() -> void:
	var exit_prompt_scene = load("res://ui/pause/ExitPrompt.tscn")
	var exit_prompt = exit_prompt_scene.instantiate()
	add_child(exit_prompt)
