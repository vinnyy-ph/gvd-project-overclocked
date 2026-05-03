extends Control

@onready var money_label = $CenterContainer/MainVBox/MoneyLabel
@onready var thermal_paste_btn = $CenterContainer/MainVBox/UpgradeContainer/Upgrade1/ThermalPasteBtn
@onready var shop_decor_btn = $CenterContainer/MainVBox/UpgradeContainer/Upgrade2/ShopDecorBtn
@onready var next_day_button = $CenterContainer/MainVBox/NextDayButton

const THERMAL_PASTE_COST = 100
const SHOP_DECOR_COST = 150

func _ready():
	update_ui()
	thermal_paste_btn.pressed.connect(_on_thermal_paste_pressed)
	shop_decor_btn.pressed.connect(_on_shop_decor_pressed)
	next_day_button.pressed.connect(_on_next_day_pressed)

func update_ui():
	money_label.text = "Balance: \u20B1" + str(SaveManager.current_money)
	
	var tp_level = SaveManager.unlocked_upgrades.get("thermal_paste", 0)
	thermal_paste_btn.text = "Level " + str(tp_level) + " - Cost \u20B1" + str(THERMAL_PASTE_COST)
	
	var sd_level = SaveManager.unlocked_upgrades.get("shop_decor", 0)
	shop_decor_btn.text = "Level " + str(sd_level) + " - Cost \u20B1" + str(SHOP_DECOR_COST)
	
	# Disable if can't afford
	thermal_paste_btn.disabled = SaveManager.current_money < THERMAL_PASTE_COST
	shop_decor_btn.disabled = SaveManager.current_money < SHOP_DECOR_COST

func _on_thermal_paste_pressed():
	if SaveManager.current_money >= THERMAL_PASTE_COST:
		SaveManager.current_money -= THERMAL_PASTE_COST
		var current_level = SaveManager.unlocked_upgrades.get("thermal_paste", 0)
		SaveManager.unlocked_upgrades["thermal_paste"] = current_level + 1
		SaveManager.save_game()
		AudioManager.play_sfx("coin")
		update_ui()

func _on_shop_decor_pressed():
	if SaveManager.current_money >= SHOP_DECOR_COST:
		SaveManager.current_money -= SHOP_DECOR_COST
		var current_level = SaveManager.unlocked_upgrades.get("shop_decor", 0)
		SaveManager.unlocked_upgrades["shop_decor"] = current_level + 1
		SaveManager.save_game()
		AudioManager.play_sfx("coin")
		update_ui()

func _on_next_day_pressed():
	GameManager.start_next_day()
