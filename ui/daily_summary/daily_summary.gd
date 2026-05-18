extends Control

@onready var title_label = $CenterContainer/VBoxContainer/TitleLabel
@onready var stats_label = $CenterContainer/VBoxContainer/StatsLabel
@onready var shop_button = $ViewUpgradeShopButton
@onready var next_day_button = $NextDayButton
@onready var day_label = $Background2/TopPanel/TimerLabel

func _ready():
	# Update labels
	title_label.text = "DAY " + str(SaveManager.current_day) + " SUMMARY"
	day_label.text = "Day: " + str(SaveManager.current_day)
	
	var revenue = GameManager.last_day_revenue
	var expenses = GameManager.last_day_expenses
	var net = revenue - expenses
	
	stats_label.text = "Revenue: \u20B1" + str(revenue) + \
					   "\nExpenses (Rent/Elec): -\u20B1" + str(expenses) + \
					   "\nNet Profit: \u20B1" + str(net)
					
	shop_button.pressed.connect(_on_shop_pressed)
	next_day_button.pressed.connect(_on_next_day_pressed)

func _on_shop_pressed():
	get_tree().change_scene_to_file("res://ui/shop/shop_scene.tscn")

func _on_next_day_pressed():
	GameManager.start_next_day()
