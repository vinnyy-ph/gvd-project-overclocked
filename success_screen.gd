extends Control

# Updated paths based on the new scene tree
@onready var result_label = $ResultPanel/ResultLabel
@onready var money_label = $ResultPanel/MoneyLabel
@onready var satisfaction_label = $ResultPanel/SatisfactionLabel
@onready var continue_button = $ResultPanel/ContinueButton

# Hooking up the day counter
@onready var day_label = $Background/TopPanel/TimerLabel

# Variables to hold the final numbers we want to count up to
var target_money: int = 0
var target_satisfaction: int = 0

func _ready():
	# Update the day counter from the GameManager
	day_label.text = "DAY: " + str(GameManager.day)

	# Make everything transparent initially
	result_label.modulate.a = 0
	money_label.modulate.a = 0
	satisfaction_label.modulate.a = 0
	continue_button.modulate.a = 0
	
	target_money = GameManager.last_money_change
	target_satisfaction = GameManager.last_satisfaction_change

	setup_static_ui()
	animate_appearance()

func setup_static_ui():
	# Set text and color (keeping alpha at 0 for the fade-in)
	if target_satisfaction >= 0:
		result_label.text = "Issue Resolved!"
		result_label.modulate = Color(0.4, 1.0, 0.5, 0.0) 
		satisfaction_label.modulate = Color(0.4, 1.0, 0.5, 0.0)
	else:
		result_label.text = "Issue Failed"
		result_label.modulate = Color(1.0, 0.4, 0.4, 0.0)
		satisfaction_label.modulate = Color(1.0, 0.4, 0.4, 0.0)

	if target_money >= 0:
		money_label.modulate = Color(0.4, 1.0, 0.5, 0.0)
	else:
		money_label.modulate = Color(1.0, 0.4, 0.4, 0.0)
		
	# Initialize labels with 0 before the tween starts rolling them up
	update_money_text(0)
	update_satisfaction_text(0)

# These custom methods are called rapidly by the Tween to update the strings
func update_money_text(current_val: int):
	if target_money >= 0:
		money_label.text = "Money Earned: +₱" + str(current_val)
	else:
		money_label.text = "Money Earned: -₱" + str(abs(current_val))

func update_satisfaction_text(current_val: int):
	if target_satisfaction >= 0:
		satisfaction_label.text = "Satisfaction Change: +" + str(current_val)
	else:
		satisfaction_label.text = "Satisfaction Change: " + str(current_val)

func animate_appearance():
	# 1. Tween for fading elements in sequentially
	var fade_tween = create_tween().set_parallel(false)
	fade_tween.tween_property(result_label, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
	fade_tween.tween_property(money_label, "modulate:a", 1.0, 0.2)
	fade_tween.tween_property(satisfaction_label, "modulate:a", 1.0, 0.2)
	fade_tween.tween_interval(1.2) # Wait a bit for the numbers to finish rolling
	fade_tween.tween_property(continue_button, "modulate:a", 1.0, 0.3)
	
	# 2. Tween for rolling the numbers up simultaneously 
	var roll_tween = create_tween().set_parallel(true)
	
	# Start rolling slightly after the labels fade in (0.5s delay)
	# EASE_OUT makes the counter slow down satisfyingly as it reaches the target number
	roll_tween.tween_method(update_money_text, 0, target_money, 0.8).set_delay(0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	roll_tween.tween_method(update_satisfaction_text, 0, target_satisfaction, 0.8).set_delay(0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _on_continue_button_pressed():
	get_tree().change_scene_to_file("res://shop_floor_scrollable.tscn")
