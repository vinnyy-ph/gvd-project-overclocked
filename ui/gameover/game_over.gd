extends Control

@onready var day_label = $TextureRect/DaySurvivedLabel
@onready var money_label = $TextureRect/MoneyEarnedLabel
@onready var days_count_label = $TextureRect/DaysSurvivedLabel
@onready var yes_button = $TextureRect/Yes

func _ready():
	# 1. Capture data
	var days = GameManager.day - 1
	var money = SaveManager.current_money
	var lifetime = SaveManager.lifetime_money
	var player_name = SaveManager.player_name
	var pc_slots = 2 + SaveManager.unlocked_upgrades.get("shop_space", 0)
	var active_slot = SaveManager.active_profile_id
	
	# 2. Populate Labels
	day_label.text = "DAY " + str(days + 1)
	money_label.text = "P%.0f" % float(money)
	days_count_label.text = str(days) + " days"
	
	# 3. Submit to Leaderboard
	LeaderboardManager.add_entry(player_name, days, float(money), pc_slots)
	
	# 4. Delete the current save profile
	SaveManager.delete_profile(active_slot)
	
	# 5. Connect Button
	yes_button.pressed.connect(_on_yes_pressed)

func _on_yes_pressed():
	# Reset global states
	GameManager.new_game()
	get_tree().change_scene_to_file("res://ui/main_menu_v2/MainMenuV2.tscn")
