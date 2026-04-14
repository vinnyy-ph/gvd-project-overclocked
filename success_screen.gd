extends Control

@onready var result_label = $ResultPanel/ResultLabel
@onready var money_label = $ResultPanel/MoneyLabel
@onready var satisfaction_label = $ResultPanel/SatisfactionLabel
@onready var continue_button = $ResultPanel/ContinueButton

func _ready():
	update_result_ui()

func update_result_ui():
	var money_change = GameManager.last_money_change
	var satisfaction_change = GameManager.last_satisfaction_change

	if satisfaction_change >= 0:
		result_label.text = "Issue Resolved!"
		result_label.modulate = Color(0.4, 1.0, 0.5, 1.0)
	else:
		result_label.text = "Issue Failed"
		result_label.modulate = Color(1.0, 0.4, 0.4, 1.0)

	if money_change >= 0:
		money_label.text = "Money Earned: +₱" + str(money_change)
		money_label.modulate = Color(0.4, 1.0, 0.5, 1.0)
	else:
		money_label.text = "Money Earned: -₱" + str(abs(money_change))
		money_label.modulate = Color(1.0, 0.4, 0.4, 1.0)

	if satisfaction_change >= 0:
		satisfaction_label.text = "Satisfaction Change: +" + str(satisfaction_change)
		satisfaction_label.modulate = Color(0.4, 1.0, 0.5, 1.0)
	else:
		satisfaction_label.text = "Satisfaction Change: " + str(satisfaction_change)
		satisfaction_label.modulate = Color(1.0, 0.4, 0.4, 1.0)

func _on_continue_button_pressed():
	get_tree().change_scene_to_file("res://shop_floor_scrollable.tscn")
