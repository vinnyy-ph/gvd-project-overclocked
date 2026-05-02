extends Node

var day: int = 1
var money: int = 0
var satisfaction: int = 100
var save_path: String = "user://savegame.json"
var last_money_change: int = 0
var last_satisfaction_change: int = 0
var in_tutorial: bool = false
var time_left: int = 60
var active_issues: Array = [false, false, false, false, false, false, false, false]

# --- SHUFFLED DECK ---
var minigame_deck: Array = []
var last_minigame: String = ""

const ALL_MINIGAMES: Array = [
	"res://login_minigame.tscn",
	"res://malware_minigame.tscn",
	"res://cable_management_mini_game.tscn",
	"res://network_troubleshooting_mini_game.tscn",
	"res://bsod_fix_mini_game.tscn",
	"res://motherboard_assembly_mini_game.tscn"
]

func get_next_minigame() -> String:
	if minigame_deck.is_empty():
		minigame_deck = ALL_MINIGAMES.duplicate()
		minigame_deck.shuffle()
		if minigame_deck.back() == last_minigame and minigame_deck.size() > 1:
			var swap_index = randi() % (minigame_deck.size() - 1)
			var tmp = minigame_deck[swap_index]
			minigame_deck[swap_index] = minigame_deck.back()
			minigame_deck[minigame_deck.size() - 1] = tmp
	last_minigame = minigame_deck.back()
	return minigame_deck.pop_back()

func new_game():
	day = 1
	money = 0
	satisfaction = 100
	time_left = 60
	in_tutorial = false
	last_money_change = 0
	last_satisfaction_change = 0
	active_issues = [false, false, false, false, false, false, false, false]
	minigame_deck = []
	last_minigame = ""
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
