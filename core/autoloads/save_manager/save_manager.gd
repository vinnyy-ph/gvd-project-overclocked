extends Node

const SAVE_PATH = "user://savegame.json"

var current_money: int = 0
var lifetime_money: int = 0
var max_days_survived: int = 0
var current_day: int = 1
var unlocked_upgrades: Dictionary = {
	"flat_monitors": 0,
	"mid_range_cpu": 0,
	"graphics_upgrade": 0,
	"premium_power_strip": 0,
	"cable_management_kit": 0,
	"shop_space": 0
}

func _ready():
	load_game()

func save_game():
	var data = {
		"current_money": current_money,
		"lifetime_money": lifetime_money,
		"max_days_survived": max_days_survived,
		"current_day": current_day,
		"unlocked_upgrades": unlocked_upgrades
	}
	
	var json_string = JSON.stringify(data)
	
	# Save to user directory
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
	
	# Also save to project's saved_checkpoints folder
	var checkpoint_path = "res://saved_checkpoints/savegame.json"
	var checkpoint_file = FileAccess.open(checkpoint_path, FileAccess.WRITE)
	if checkpoint_file:
		checkpoint_file.store_string(json_string)
		checkpoint_file.close()

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var data = json.data
			if typeof(data) == TYPE_DICTIONARY:
				current_money = int(data.get("current_money", 0))
				lifetime_money = int(data.get("lifetime_money", 0))
				max_days_survived = int(data.get("max_days_survived", 0))
				current_day = int(data.get("current_day", 1))
				
				var saved_upgrades = data.get("unlocked_upgrades", {})
				if typeof(saved_upgrades) == TYPE_DICTIONARY:
					for key in saved_upgrades:
						if unlocked_upgrades.has(key):
							unlocked_upgrades[key] = int(saved_upgrades[key])

func reset_run_data():
	# Keep lifetime stats but reset current run and upgrades
	current_money = 0
	current_day = 1
	for key in unlocked_upgrades:
		unlocked_upgrades[key] = 0
	save_game()

func update_max_days(days: int):
	if days > max_days_survived:
		max_days_survived = days
		save_game()

func add_money(amount: int):
	current_money += amount
	if amount > 0:
		lifetime_money += amount
	save_game()
