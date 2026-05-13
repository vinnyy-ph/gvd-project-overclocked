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
	var dialog = ColorRect.new()
	dialog.name = "ExitConfirmation"
	dialog.color = Color(0, 0, 0, 0.8)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dialog)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 200)
	dialog.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	var vbox = VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 30)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	var label = Label.new()
	label.text = "ARE YOU SURE YOU WANT TO EXIT?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var hbox = HBoxContainer.new()
	hbox.set("theme_override_constants/separation", 50)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)
	
	var yes_btn = Button.new()
	yes_btn.text = " YES "
	yes_btn.pressed.connect(func(): get_tree().quit())
	hbox.add_child(yes_btn)
	
	var no_btn = Button.new()
	no_btn.text = " NO "
	no_btn.pressed.connect(func(): dialog.queue_free())
	hbox.add_child(no_btn)
	
	# Optional: Apply GameManager button effects if they exist
	if GameManager.has_method("setup_button_effect"):
		GameManager.setup_button_effect(yes_btn)
		GameManager.setup_button_effect(no_btn)
