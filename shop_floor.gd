extends Control

@onready var day_label = $HUD/DayLabel
@onready var money_label = $HUD/MoneyLabel
@onready var satisfaction_label = $HUD/SatisfactionLabel
@onready var timer_label = $HUD/TimerLabel
@onready var info_label = $InfoLabel
@onready var issue_button = $PCArea/IssueButton
@onready var pause_overlay = $PauseOverlay

var time_left:int = 30
var issue_resolved:bool = false
var is_paused_menu_open:bool = false

func _ready():
	randomize()
	update_hud()
	pause_overlay.visible = false

func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		toggle_pause_menu()

func update_hud():
	day_label.text = "Day: " + str(GameManager.day)
	money_label.text = "Money: ₱" + str(GameManager.money)
	satisfaction_label.text = "Satisfaction: " + str(GameManager.satisfaction) + "%"
	timer_label.text = "Time: " + str(time_left)

func _on_day_timer_timeout():
	if is_paused_menu_open:
		return

	time_left -= 1

	if time_left <= 0:
		time_left = 0
		end_day()

	update_hud()

func _on_issue_button_pressed():
	if is_paused_menu_open:
		return

	var issues = [
		"res://login_minigame.tscn",
		"res://malware_minigame.tscn"
	]

	var chosen_issue = issues[randi() % issues.size()]
	get_tree().change_scene_to_file(chosen_issue)

func end_day():
	GameManager.day += 1
	GameManager.money -= 20
	if GameManager.money < 0:
		GameManager.money = 0
	GameManager.save_game()
	time_left = 30
	info_label.text = "Day ended. Electricity bill paid. New day started."
	update_hud()

func toggle_pause_menu():
	is_paused_menu_open = !is_paused_menu_open
	pause_overlay.visible = is_paused_menu_open
	get_tree().paused = is_paused_menu_open

func _on_resume_button_pressed():
	toggle_pause_menu()

func _on_save_button_pressed():
	GameManager.save_game()
	info_label.text = "Game saved."

func _on_main_menu_button_pressed():
	get_tree().paused = false
	is_paused_menu_open = false
	pause_overlay.visible = false
	GameManager.save_game()
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_quit_button_pressed():
	get_tree().quit()
