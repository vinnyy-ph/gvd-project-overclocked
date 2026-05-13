extends Control

func _ready() -> void:
	PauseMenu.pause_button.visible = false

func _process(delta: float) -> void:
	pass

func _on_continue_button_pressed() -> void:
	if GameManager.load_game():
		PauseMenu.pause_button.visible = true
		get_tree().change_scene_to_file("res://core/shop_floor/shop_floor_scrollable.tscn")

func _on_hi_score_button_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/hi_score/hi_score.tscn")

func _on_tutorial_button_pressed():
	GameManager.in_tutorial = true
	GameManager.new_game()
	get_tree().change_scene_to_file("res://core/shop_floor/shop_floor_scrollable_tutorial.tscn")

func _on_settings_button_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/settings/settings_menu.tscn")

func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_new_game_button_pressed() -> void:
	GameManager.new_game()
	PauseMenu.pause_button.visible = true
	get_tree().change_scene_to_file("res://core/shop_floor/shop_floor_scrollable.tscn")
