extends Control

@onready var day_label = $TextureRect/DaySurvivedLabel
@onready var money_label = $TextureRect/MoneyEarnedLabel
@onready var days_count_label = $TextureRect/DaysSurvivedLabel
@onready var yes_button = $TextureRect/Yes
@onready var tip_label = $DailyTip/MarginContainer/DailyTipText

var financial_tips = [
	"Bankruptcy! Since you only have P%d and the daily bill is P%d, you failed to keep the shop running. Manage your expenses better!",
	"Out of funds! You couldn't pay the daily expenses of P%d since you only have P%d left. Try upgrading your shop to earn more passive income and tips!",
	"Game Over! The bills caught up to you. You needed P%d but only had P%d. Remember that having more unlocked PC slots increases your daily fee."
]

var satisfaction_tips = [
	"Your satisfaction dropped to zero! Always remember to accommodate customers with issues quickly.",
	"Customers left angry! Failing too many mini-games heavily penalizes your satisfaction. Take your time to diagnose and fix the issue correctly.",
	"Shop reputation ruined! Don't let technical issues sit for too long. Active issues constantly drain your satisfaction over time.",
	"You lost all customer trust! Remember that failing a repair drops your customer satisfaction drastically. Use hints if you're stuck!",
	"Zero satisfaction reached! Upgrading your shop equipment can help reduce the frequency of customer issues."
]

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
	money_label.text = "P%.0f" % float(lifetime)
	days_count_label.text = str(days) + " days"
	
	# Determine game over reason and set tip
	randomize()
	if GameManager.satisfaction <= 0:
		tip_label.text = ">_ Gameplay tip !\n" + satisfaction_tips[randi() % satisfaction_tips.size()]
	else:
		var tip = financial_tips[randi() % financial_tips.size()]
		# financial_tips expects money_before_bankruptcy and last_day_expenses depending on format
		# Format string depending on which tip is chosen.
		if "since you only have" in tip and "daily bill is" in tip:
			tip_label.text = ">_ Gameplay tip !\n" + (tip % [GameManager.money_before_bankruptcy, GameManager.last_day_expenses])
		elif "since you only have" in tip:
			tip_label.text = ">_ Gameplay tip !\n" + (tip % [GameManager.last_day_expenses, GameManager.money_before_bankruptcy])
		else:
			tip_label.text = ">_ Gameplay tip !\n" + (tip % [GameManager.last_day_expenses, GameManager.money_before_bankruptcy])

	# 3. Submit to Leaderboard
	LeaderboardManager.add_entry(player_name, days, float(lifetime), pc_slots)
	
	# Update max days survived
	SaveManager.update_max_days(days)
	
	# 5. Connect Button
	yes_button.pressed.connect(_on_yes_pressed)

func _on_yes_pressed():
	# Reset global states
	GameManager.new_game()
	get_tree().change_scene_to_file("res://ui/leaderboard/leaderboard.tscn")
