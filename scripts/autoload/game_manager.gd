extends Node

var day:int = 1
var money:int = 0
var satisfaction:int = 100
var save_path:String = "user://savegame.json"
var last_money_change:int = 0
var last_satisfaction_change:int = 0
var in_tutorial:bool = false

func new_game():
	day = 1
	money = 0
	satisfaction = 100
	save_game()

func save_game():
	var data = {
		"day": day,
		"money": money,
		"satisfaction": satisfaction
	}
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))

func load_game():
	if not FileAccess.file_exists(save_path):
		return false
	var file = FileAccess.open(save_path, FileAccess.READ)
	var text = file.get_as_text()
	var data = JSON.parse_string(text)
	if typeof(data) == TYPE_DICTIONARY:
		day = data.get("day", 1)
		money = data.get("money", 0)
		satisfaction = data.get("satisfaction", 100)
		return true
	return false
