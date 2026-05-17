extends Control

@onready var money_label = %MoneyLabel

# Hardware
@onready var monitors_btn = %MonitorsBtn
@onready var cpu_btn = %CPUBtn
@onready var graphics_btn = %GraphicsBtn

# Management/Space
@onready var power_strip_btn = %PowerStripBtn
@onready var cable_kit_btn = %CableKitBtn
@onready var shop_space_btn = %ShopSpaceBtn

@onready var next_day_button = %NextDayButton

const COSTS = {
	"flat_monitors": 5000,
	"mid_range_cpu": 7500,
	"graphics_upgrade": 9000,
	"premium_power_strip": 3000,
	"cable_management_kit": 4500,
	"shop_space": 2000
}

func _ready():
	update_ui()
	monitors_btn.pressed.connect(_on_upgrade_pressed.bind("flat_monitors"))
	cpu_btn.pressed.connect(_on_upgrade_pressed.bind("mid_range_cpu"))
	graphics_btn.pressed.connect(_on_upgrade_pressed.bind("graphics_upgrade"))
	power_strip_btn.pressed.connect(_on_upgrade_pressed.bind("premium_power_strip"))
	cable_kit_btn.pressed.connect(_on_upgrade_pressed.bind("cable_management_kit"))
	shop_space_btn.pressed.connect(_on_upgrade_pressed.bind("shop_space"))
	next_day_button.pressed.connect(_on_next_day_pressed)

func update_ui():
	if not money_label: return # Safety check
	
	# DEV MODE: Show unlimited balance visually
	if GameManager.dev_mode:
		money_label.text = "Balance: P UNLIMITED (DEV MODE)"
	else:
		money_label.text = "Balance: P" + str(GameManager.money)
	
	_update_btn(monitors_btn, "flat_monitors")
	_update_btn(cpu_btn, "mid_range_cpu")
	_update_btn(graphics_btn, "graphics_upgrade")
	_update_btn(power_strip_btn, "premium_power_strip")
	_update_btn(cable_kit_btn, "cable_management_kit")
	_update_btn(shop_space_btn, "shop_space")

func _update_btn(btn: Button, upgrade_id: String):
	if not btn: return # Safety check
	var level = SaveManager.unlocked_upgrades.get(upgrade_id, 0)
	var cost = COSTS[upgrade_id]
	
	var display_name = upgrade_id.replace("_", " ").capitalize()
	btn.text = display_name + " (Lvl " + str(level) + ") - ₱" + str(cost)
	
	# DEV MODE: Never disable buttons due to cost if Dev Mode is active
	if GameManager.dev_mode:
		btn.disabled = false
	else:
		btn.disabled = GameManager.money < cost
	
	if upgrade_id == "shop_space" and level >= 6:
		btn.text = "Shop Space (MAX)"
		btn.disabled = true

func _on_upgrade_pressed(upgrade_id: String):
	var cost = COSTS[upgrade_id]
	
	# Check GameManager for funds OR if Dev Mode is active
	if GameManager.dev_mode or GameManager.money >= cost:
		
		# Deducting from GameManager routes it through the dev_mode blocker safely
		GameManager.money -= cost 
		
		var current_level = SaveManager.unlocked_upgrades.get(upgrade_id, 0)
		SaveManager.unlocked_upgrades[upgrade_id] = current_level + 1
		SaveManager.save_game()
		AudioManager.play_sfx("coin")
		update_ui()

func _on_next_day_pressed():
	GameManager.start_next_day()
