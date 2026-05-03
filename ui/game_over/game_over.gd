extends Control

@onready var stats_label = $CenterContainer/VBoxContainer/StatsLabel
@onready var menu_button = $CenterContainer/VBoxContainer/MenuButton

func _ready():
	# Update stats from SaveManager
	var days = GameManager.day - 1
	var money = SaveManager.current_money
	var lifetime = SaveManager.lifetime_money
	
	stats_label.text = "Days Survived: " + str(days) + \
					   "\nMoney Earned: \u20B1" + str(money) + \
					   "\nLifetime Earnings: \u20B1" + str(lifetime)
	
	# Update lifetime high scores if needed
	SaveManager.update_max_days(days)
	
	menu_button.pressed.connect(_on_menu_button_pressed)
	
	# Play game over sound if available (optional)
	# AudioManager.play_sfx("fail")

func _on_menu_button_pressed():
	# Reset run data before going back
	SaveManager.reset_run_data()
	get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn")
