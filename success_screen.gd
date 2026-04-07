extends Control

@onready var money_label = $Panel/MoneyLabel
@onready var satisfaction_label = $Panel/SatisfactionLabel

func _ready():
	money_label.text = "Money Earned: +₱" + str(GameManager.last_money_change)
	satisfaction_label.text = "Satisfaction Change: " + str(GameManager.last_satisfaction_change)

func _on_continue_button_pressed():
	get_tree().change_scene_to_file("res://shop_floor.tscn")
