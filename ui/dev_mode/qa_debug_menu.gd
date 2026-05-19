extends Control

@onready var status_label: Label = $VBoxContainer/StatusLabel

func _ready() -> void:
	status_label.text = "QA DEBUG MODE ACTIVE"
	print("QA: Debug menu loaded. Scene run directly.")

func _on_clear_button_pressed() -> void:
	SaveManager.clear_all_standard_profiles()
	status_label.text = "SUCCESS: All standard profiles cleared."
	status_label.modulate = Color(0.5, 1.0, 0.5) # Greenish
	print("QA: Standard profiles cleared.")

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu_v2/MainMenuV2.tscn")
