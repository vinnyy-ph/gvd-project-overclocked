extends Control

@onready var timer_label = $Background/TopPanel/TimerLabel
@onready var step_label = $Background/TopPanel/StepLabel
@onready var status_label = $Background/InstructionsPanel/InstructionsLabel

@onready var choice_button_1 = $ChoicesArea/ChoiceButton1
@onready var choice_button_2 = $ChoicesArea/ChoiceButton2
@onready var choice_button_3 = $ChoicesArea/ChoiceButton3
@onready var choice_button_4 = $ChoicesArea/ChoiceButton4

var time_left: int = 20
var current_step: int = 0

var correct_steps = [
	"Restart the PC",
	"Run diagnostics",
	"Remove faulty driver"
]

var choice_pool = [
	"Restart the PC",
	"Run diagnostics",
	"Remove faulty driver",
	"Install random software update",
	"Ignore the error",
	"Unplug monitor",
	"Delete system files"
]

func _ready():
	randomize()

	choice_button_1.pressed.connect(func(): check_answer(choice_button_1.text))
	choice_button_2.pressed.connect(func(): check_answer(choice_button_2.text))
	choice_button_3.pressed.connect(func(): check_answer(choice_button_3.text))
	choice_button_4.pressed.connect(func(): check_answer(choice_button_4.text))

	update_timer()
	update_step_ui()
	generate_choices()

func update_timer():
	timer_label.text = "Time: " + str(time_left)

func update_step_ui():
	step_label.text = "Step " + str(current_step + 1) + " of " + str(correct_steps.size())

func generate_choices():
	var current_correct = correct_steps[current_step]
	var options: Array = [current_correct]

	while options.size() < 4:
		var random_choice = choice_pool[randi() % choice_pool.size()]
		if not options.has(random_choice):
			options.append(random_choice)

	options.shuffle()

	choice_button_1.text = options[0]
	choice_button_2.text = options[1]
	choice_button_3.text = options[2]
	choice_button_4.text = options[3]

func check_answer(selected_text: String):
	if selected_text == correct_steps[current_step]:
		current_step += 1

		if current_step >= correct_steps.size():
			win_game()
			return

		status_label.text = "Correct step!"
		generate_choices()
		update_step_ui()
	else:
		fail_game()

func win_game():
	GameManager.money += 15
	GameManager.satisfaction += 5
	if GameManager.satisfaction > 100:
		GameManager.satisfaction = 100

	GameManager.last_money_change = 15
	GameManager.last_satisfaction_change = 5
	GameManager.save_game()
	get_tree().change_scene_to_file("res://success_screen.tscn")

func fail_game():
	GameManager.satisfaction -= 10
	if GameManager.satisfaction < 0:
		GameManager.satisfaction = 0

	GameManager.last_money_change = 0
	GameManager.last_satisfaction_change = -10
	GameManager.save_game()
	get_tree().change_scene_to_file("res://success_screen.tscn")

func _on_game_timer_timeout():
	time_left -= 1
	if time_left < 0:
		time_left = 0

	update_timer()

	#if time_left == 0:
		#fail_game()
