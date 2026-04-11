extends Control

@onready var code_label = $CodeLabel
@onready var answer_input = $AnswerInput

var target_code:String = ""

func _ready():
	randomize()
	target_code = generate_code()
	code_label.text = target_code
	answer_input.text = ""

func generate_code() -> String:
	var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var part1 = ""
	var part2 = ""

	for i in range(4):
		part1 += chars[randi() % chars.length()]

	for i in range(4):
		part2 += chars[randi() % chars.length()]

	return part1 + "-" + part2

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

	if GameManager.in_tutorial:
		get_tree().change_scene_to_file("res://shop_floor.tscn")
	else:
		get_tree().change_scene_to_file("res://success_screen.tscn")
