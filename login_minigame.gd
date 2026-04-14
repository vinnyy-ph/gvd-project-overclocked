extends Control

@onready var timer_label = $TimerLabel
@onready var progress_label = $ProgressLabel
@onready var status_label = $StatusLabel

@onready var request_label = $MainPanel/RequestLabel
@onready var input_box = $MainPanel/InputBox
@onready var submit_button = $MainPanel/SubmitButton
@onready var hint_button_1 = $MainPanel/HintButton1
@onready var hint_button_2 = $MainPanel/HintButton2
@onready var hint_button_3 = $MainPanel/HintButton3

var time_left: int = 20
var solved_count: int = 0
var current_code: String = ""

func _ready():
	randomize()

	submit_button.pressed.connect(check_code)
	hint_button_1.pressed.connect(show_code_again)
	hint_button_2.pressed.connect(clear_input)
	hint_button_3.pressed.connect(wrong_action)

	generate_new_code()
	update_timer()
	update_progress()

func random_letter() -> String:
	var letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	return letters[randi() % letters.length()]

func random_digit() -> String:
	return str(randi() % 10)

func create_temp_code() -> String:
	return random_letter() + random_letter() + "-" + random_digit() + random_digit() + random_digit() + random_letter()

func generate_new_code():
	current_code = create_temp_code()
	request_label.text = "Requested Code: " + current_code
	input_box.text = ""
	status_label.text = "Enter the code shown above."

func update_timer():
	timer_label.text = "Time: " + str(time_left)

func update_progress():
	progress_label.text = "Solved: " + str(solved_count) + " / 3"

func check_code():
	if input_box.text.strip_edges().to_upper() == current_code:
		solved_count += 1
		update_progress()

		if solved_count >= 3:
			win_game()
			return

		status_label.text = "Login approved."
		generate_new_code()
	else:
		status_label.text = "Incorrect code."

func show_code_again():
	status_label.text = "Code reminder: " + current_code

func clear_input():
	input_box.text = ""
	status_label.text = "Input cleared."

func wrong_action():
	status_label.text = "That won't help the customer."

func win_game():
	GameManager.money += 10
	GameManager.satisfaction += 5
	if GameManager.satisfaction > 100:
		GameManager.satisfaction = 100

	GameManager.last_money_change = 10
	GameManager.last_satisfaction_change = 5
	GameManager.save_game()
	get_tree().change_scene_to_file("res://success_screen.tscn")

func fail_game():
	GameManager.last_money_change = 0
	GameManager.last_satisfaction_change = -10
	GameManager.satisfaction -= 10
	if GameManager.satisfaction < 0:
		GameManager.satisfaction = 0
	GameManager.save_game()
	get_tree().change_scene_to_file("res://success_screen.tscn")

func _on_game_timer_timeout():
	time_left -= 1
	if time_left < 0:
		time_left = 0

	update_timer()

	if time_left == 0:
		fail_game()
