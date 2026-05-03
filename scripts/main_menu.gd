extends Control

func _ready() -> void:
	PauseMenu.pause_button.visible = false

func _process(delta: float) -> void:
	pass

func _on_new_game_button_pressed() -> void:
	GameManager.new_game()
	PauseMenu.pause_button.visible = true
	get_tree().change_scene_to_file("res://shop_floor_scrollable.tscn")

func _on_continue_button_pressed() -> void:
	if GameManager.load_game():
		PauseMenu.pause_button.visible = true
		get_tree().change_scene_to_file("res://shop_floor_scrollable.tscn")

func _on_hi_score_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/hi_score.tscn")

func _on_tutorial_button_pressed():
	GameManager.in_tutorial = true
	GameManager.new_game()
	get_tree().change_scene_to_file("res://shop_floor_scrollable_tutorial.tscn")
