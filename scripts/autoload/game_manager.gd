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
var is_tutorial: bool = false
var tutorial_minigame_done: bool = false

# --- SHUFFLED DECK ---
var minigame_deck: Array = []
var last_minigame: String = ""

# 1. Create a dedicated RNG for the manager
var rng = RandomNumberGenerator.new() 

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
		
		# 3. Custom Fisher-Yates shuffle to guarantee entropy
		for i in range(minigame_deck.size() - 1, 0, -1):
			var j = rng.randi_range(0, i)
			var temp = minigame_deck[i]
			minigame_deck[i] = minigame_deck[j]
			minigame_deck[j] = temp
			
		# Prevent the new deck from starting with the last minigame of the previous deck
		if minigame_deck.back() == last_minigame and minigame_deck.size() > 1:
			var swap_index = rng.randi_range(0, minigame_deck.size() - 2)
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

func _ready():
	# 2. Seed the RNG immediately when the Autoload boots
	rng.randomize() 
	
	# Listen for any new node entering the scene tree globally
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node):
	# Check if the newly added node is a button
	if node is BaseButton:
		setup_button_effect(node)

# ==========================================
# GLOBAL BUTTON EFFECTS
# ==========================================

func setup_button_effect(button: BaseButton):
	# Using call_deferred ensures the button has its final size before setting the pivot
	button.call_deferred("set_pivot_offset", button.size / 2.0)
	
	# Connect the signals. We check if they are already connected just in case
	if not button.button_down.is_connected(_on_button_down):
		button.button_down.connect(_on_button_down.bind(button))
	if not button.button_up.is_connected(_on_button_up):
		button.button_up.connect(_on_button_up.bind(button))

func _on_button_down(button: BaseButton):
	AudioManager.play_sfx("click")
	var tween = create_tween()
	# Optional: Set pause mode to process so it animates even if the game is paused
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) 
	tween.tween_property(button, "scale", Vector2(0.9, 0.9), 0.05).set_trans(Tween.TRANS_SINE)

func _on_button_up(button: BaseButton):
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
