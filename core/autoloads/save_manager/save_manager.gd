extends Node

const SAVE_PATH_TEMPLATE = "user://save_slot_{id}.json"

var active_profile_id: int = 0
var player_name: String = "Player"
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
	pass

func get_save_path(id: int) -> String:
	return SAVE_PATH_TEMPLATE.format({"id": id})

func save_game():
	var data = {
		"player_name": player_name,
		"current_money": current_money,
		"lifetime_money": lifetime_money,
		"max_days_survived": max_days_survived,
		"current_day": current_day,
		"unlocked_upgrades": unlocked_upgrades
	}
	
	var json_string = JSON.stringify(data)
	
	# Save to user directory
	var file = FileAccess.open(get_save_path(active_profile_id), FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()

func load_game(id: int = -1):
	if id != -1:
		active_profile_id = id
		
	var path = get_save_path(active_profile_id)
	if not FileAccess.file_exists(path):
		return false
		
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var data = json.data
			if typeof(data) == TYPE_DICTIONARY:
				player_name = data.get("player_name", "Player")
				current_money = int(data.get("current_money", 0))
				lifetime_money = int(data.get("lifetime_money", 0))
				max_days_survived = int(data.get("max_days_survived", 0))
				current_day = int(data.get("current_day", 1))
				
				var saved_upgrades = data.get("unlocked_upgrades", {})
				if typeof(saved_upgrades) == TYPE_DICTIONARY:
					for key in saved_upgrades:
						if unlocked_upgrades.has(key):
							unlocked_upgrades[key] = int(saved_upgrades[key])
			return true
	return false

func get_profile_data(id: int):
	var path = get_save_path(id)
	if not FileAccess.file_exists(path):
		return null
		
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		if json.parse(json_string) == OK:
			return json.data
	return null

func get_all_profiles() -> Array:
	var profiles = []
	for i in range(3):
		profiles.append(get_profile_data(i))
	return profiles

func create_new_profile(id: int, name: String):
	active_profile_id = id
	player_name = name
	current_money = 100 # Starting money
	lifetime_money = 0
	max_days_survived = 0
	current_day = 1
	for key in unlocked_upgrades:
		unlocked_upgrades[key] = 0
	save_game()

func delete_profile(id: int):
	var path = get_save_path(id)
	if FileAccess.file_exists(path):
		OS.move_to_trash(ProjectSettings.globalize_path(path))

func reset_run_data():
	# Keep lifetime stats but reset current run and upgrades
	current_money = 100
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
