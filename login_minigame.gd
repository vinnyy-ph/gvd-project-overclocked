extends Control

@onready var answer_input = $AnswerInput

var target_code:String = "A7X9-KQ2P"

func _on_submit_button_pressed():
	if answer_input.text.strip_edges() == target_code:
		GameManager.money += 15
		GameManager.satisfaction += 5
		GameManager.last_money_change = 15
		GameManager.last_satisfaction_change = 5
	else:
		GameManager.satisfaction -= 10
		GameManager.last_money_change = 0
		GameManager.last_satisfaction_change = -10

	if GameManager.satisfaction > 100:
		GameManager.satisfaction = 100
	if GameManager.satisfaction < 0:
		GameManager.satisfaction = 0

	GameManager.save_game()
	get_tree().change_scene_to_file("res://success_screen.tscn")
