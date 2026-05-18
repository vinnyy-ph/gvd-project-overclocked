extends Node

# SET TO TRUE FOR TESTING (Unlimited money, max satisfaction)
var dev_mode: bool = false 

var day: int:
	get:
		return SaveManager.current_day
	set(value):
		SaveManager.current_day = value
		SaveManager.save_game()

var money: int:
	get:
		return SaveManager.current_money
	set(value):
		var new_money = max(0, value)
		var diff = new_money - SaveManager.current_money
		
		# DEV MODE: Block any money deductions (expenses, purchases)
		if dev_mode and diff < 0:
			return 
			
		if diff > 0:
			last_day_revenue += diff
			SaveManager.lifetime_money += diff
		
		SaveManager.current_money = new_money
		SaveManager.save_game()

func start_next_day():
	day += 1
	time_left = 60
	last_day_revenue = 0
	for i in range(active_issues.size()):
		active_issues[i] = ""
	for i in range(occupied_slots.size()):
		occupied_slots[i] = false
	SaveManager.save_game()
	AudioManager.play_sfx("day_start")
	get_tree().change_scene_to_file("res://core/shop_floor/shop_floor_scrollable.tscn")

var last_day_expenses: int = 0

func get_unlocked_slots() -> int:
	return clamp(2 + SaveManager.unlocked_upgrades.get("shop_space", 0), 2, 13)

func end_day():
	# Daily Bill Tiers for Rent and Electricity:
	# Days 1-9: 100
	# Days 10-19: 550
	# Days 20-29: 1050
	# Day 30+: 1500
	var bill_tiers = [100, 550, 1050, 1500]
	var day_index = clamp(int((day - 1) / 10.0), 0, 3)
	
	last_day_expenses = bill_tiers[day_index]

	if money < last_day_expenses:
		money_before_bankruptcy = money
		money = 0
		trigger_game_over()
		return

	money -= last_day_expenses
	AudioManager.play_sfx("day_start")
	get_tree().change_scene_to_file("res://ui/daily_summary/daily_summary.tscn")

var satisfaction: int = 100:
	set(value):
		# DEV MODE: Lock satisfaction to 100
		if dev_mode:
			satisfaction = 100
			return
			
		satisfaction = clamp(value, 0, 100)
		if satisfaction <= 0:
			trigger_game_over()

var satisfaction_accumulator: float = 0.0

func _process(delta):
	# DEV MODE: Stop the satisfaction decay timer entirely
	if dev_mode:
		return
		
	# Only decay satisfaction if we are on the shop floor and there are active issues
	if get_tree().current_scene and (get_tree().current_scene.name == "ShopFloorScrollable" or get_tree().current_scene.name == "TutorialFloor"):
		var active_count = 0
		for issue in active_issues:
			if issue != "": active_count += 1
		
		if active_count > 0:
			# Decay 0.2 points per second per active issue
			satisfaction_accumulator += delta * 0.2 * active_count
			if satisfaction_accumulator >= 1.0:
				var decay = int(satisfaction_accumulator)
				satisfaction -= decay
				satisfaction_accumulator -= decay

func trigger_game_over():
	# Transition to game over scene
	# We might want to clear active issues or other state
	get_tree().change_scene_to_file("res://ui/gameover/game_over.tscn")

signal money_changed_visual(amount: int, position: Vector2)
signal satisfaction_changed_visual(amount: int, position: Vector2)

# Helper methods to emit visual signals from within the class (resolves UNUSED_SIGNAL warnings)
func emit_money_change(amount: int, pos: Vector2):
	money_changed_visual.emit(amount, pos)

func emit_satisfaction_change(amount: int, pos: Vector2):
	satisfaction_changed_visual.emit(amount, pos)

var save_path: String = "user://savegame.json"
var previous_scene: String = ""
var money_before_bankruptcy: int = 0
var last_money_change: int = 0
var last_satisfaction_change: int = 0
var minigame_just_finished: bool = false
var minigame_result: bool = false # true = success, false = fail
var in_tutorial: bool = false
var time_left: int = 60
var active_issues: Array = ["", "", "", "", "", "", "", "", "", "", "", "", ""]
var occupied_slots: Array = [false, false, false, false, false, false, false, false, false, false, false, false, false]
var is_tutorial: bool = false
var tutorial_minigame_index: int = 0
var tutorial_minigame_done: bool = false
var last_day_revenue: int = 0
var persisted_customers: Array = [] # Stores customer data when changing scenes

func get_formatted_time() -> String:
	var total_ticks = 60
	var elapsed_ticks = total_ticks - time_left
	
	var start_hour = 9 # 9 AM
	var minutes_per_tick = 9 # 9 hours (540 mins) / 60 ticks = 9 mins/tick
	
	var total_minutes = elapsed_ticks * minutes_per_tick
	var current_hour = start_hour + int(total_minutes / 60.0)
	var current_minute = total_minutes % 60
	
	var am_pm = "AM" if current_hour < 12 else "PM"
	var display_hour = current_hour
	if display_hour > 12:
		display_hour -= 12
	elif display_hour == 0:
		display_hour = 12
		
	return "%02d:%02d %s" % [display_hour, current_minute, am_pm]

func get_satisfaction_multiplier() -> float:
	if satisfaction >= 80:
		return 1.2 # Tip bonus
	elif satisfaction >= 40:
		return 1.0 # Standard
	else:
		return 0.8 # Penalty

func get_money_reward(base_amount: int) -> int:
	var bonus = get_satisfaction_multiplier()
	if SaveManager.unlocked_upgrades.get("graphics_upgrade", 0) > 0:
		bonus += 0.10 # +10% payment
	return int(base_amount * bonus)

func get_passive_income_reward() -> int:
	# Passive Income Tiers:
	# Day 1-5: 1
	# Day 6-10: 3
	# Day 11-15: 5
	# Day 16-20: 10
	# Day 21-25: 15
	# Day 26+: 20
	var day_index = clamp(int((day - 1) / 5.0), 0, 5)
	var passive_tiers = [1, 3, 5, 10, 15, 20]
	var base = float(passive_tiers[day_index])
	
	var multiplier = get_satisfaction_multiplier()
	return int(base * multiplier)

func get_spawn_interval() -> float:
	var unlocked = get_unlocked_slots()
	# Base interval starts slower and gets faster as you have more slots
	# 2 slots -> ~6.5s
	# 13 slots -> ~3.5s
	var base_interval = lerp(6.5, 3.5, float(unlocked - 2) / 11.0)
	
	# Day multiplier: gets slightly faster each day
	# Day 1: 100%, Day 10: 73% (faster)
	var day_mult = max(0.6, 1.0 - (day - 1) * 0.03)
	
	return base_interval * day_mult

func get_max_waiting_customers() -> int:
	var unlocked = get_unlocked_slots()
	# 2 slots -> 2 waiting
	# 13 slots -> 5 waiting
	return int(lerp(2.0, 5.0, float(unlocked - 2) / 11.0))

func get_issue_spawn_chance_modifier() -> float:
	# Power strip and cable kit reduce overall issue frequency
	var power_strip = SaveManager.unlocked_upgrades.get("premium_power_strip", 0)
	var cable_kit = SaveManager.unlocked_upgrades.get("cable_management_kit", 0)
	# Cap the reduction so it never reaches 0 (minimum 20% of base rate)
	return max(0.2, 1.0 - (float(power_strip) * 0.1) - (float(cable_kit) * 0.05))

func get_hardware_time_bonus() -> int:
	# Each level of CPU upgrade adds 5 seconds to mini-games
	return SaveManager.unlocked_upgrades.get("mid_range_cpu", 0) * 5

func get_satisfaction_penalty(base_penalty: int) -> int:
	# Flat monitors reduce satisfaction penalty
	var level = SaveManager.unlocked_upgrades.get("flat_monitors", 0)
	var reduction = level * 2
	return max(5, base_penalty - reduction)

func apply_satisfaction_penalty(base_penalty: int):
	last_satisfaction_change = -get_satisfaction_penalty(base_penalty)
	satisfaction += last_satisfaction_change

# --- MINIGAME CRITERIA ---
const MINIGAME_DATA = {
	"login": {
		"timer": 20,
		"success_satisfaction": 5,
		"fail_satisfaction": 10,
		"success_payment": [10.0, 20.0, 30.0, 40.0],
		"fail_deduction": [5.0, 10.0, 15.0, 20.0]
	},
	"malware": {
		"timer": 90,
		"success_satisfaction": 25,
		"fail_satisfaction": 30,
		"success_payment": [30.0, 60.0, 90.0, 120.0],
		"fail_deduction": [15.0, 30.0, 45.0, 60.0]
	},
	"motherboard": {
		"timer": 15,
		"success_satisfaction": 10,
		"fail_satisfaction": 15,
		"success_payment": [15.0, 30.0, 45.0, 60.0],
		"fail_deduction": [12.50, 25.0, 37.50, 30.0]
	},
	"cable": {
		"timer": 20,
		"success_satisfaction": 20,
		"fail_satisfaction": 25,
		"success_payment": [25.0, 50.0, 75.0, 100.0],
		"fail_deduction": [12.50, 25.0, 37.50, 50.0]
	},
	"bsod": {
		"timer": 60,
		"success_satisfaction": 20,
		"fail_satisfaction": 25,
		"success_payment": [25.0, 50.0, 75.0, 100.0],
		"fail_deduction": [7.50, 15.0, 22.50, 50.0]
	},
	"network": {
		"timer": 90,
		"success_satisfaction": 30,
		"fail_satisfaction": 35,
		"success_payment": [35.0, 70.0, 105.0, 140.0],
		"fail_deduction": [17.50, 35.0, 52.50, 70.0]
	}
}

func get_minigame_reward(game_id: String) -> int:
	if not MINIGAME_DATA.has(game_id): return 0
	var data = MINIGAME_DATA[game_id]
	var day_index = clamp(int((day - 1) / 10.0), 0, 3)
	return int(data["success_payment"][day_index])

func get_minigame_deduction(game_id: String) -> int:
	if not MINIGAME_DATA.has(game_id): return 0
	var data = MINIGAME_DATA[game_id]
	var day_index = clamp(int((day - 1) / 10.0), 0, 3)
	return int(data["fail_deduction"][day_index])

func get_minigame_timer(game_id: String) -> int:
	if not MINIGAME_DATA.has(game_id): return 20
	return MINIGAME_DATA[game_id]["timer"]

func get_minigame_satisfaction_gain(game_id: String) -> int:
	if not MINIGAME_DATA.has(game_id): return 5
	return MINIGAME_DATA[game_id]["success_satisfaction"]

func get_minigame_satisfaction_loss(game_id: String) -> int:
	if not MINIGAME_DATA.has(game_id): return 10
	return MINIGAME_DATA[game_id]["fail_satisfaction"]

# --- SHUFFLED DECK ---
var minigame_deck: Array = []
var last_minigame: String = ""

# 1. Create a dedicated RNG for the manager
var rng = RandomNumberGenerator.new() 

const ALL_MINIGAMES: Array = [
	"res://minigames/login/login_minigame.tscn",
	"res://minigames/malware/malware_minigame.tscn",
	"res://minigames/cable_management/cable_management_mini_game.tscn",
	"res://minigames/network_troubleshooting/network_troubleshooting_mini_game.tscn",
	"res://minigames/bsod_fix/bsod_fix_mini_game.tscn",
	"res://minigames/motherboard_assembly/motherboard_assembly_mini_game.tscn"
]

const MINIGAME_TITLES = {
	"res://minigames/login/login_minigame.tscn": "Login Support",
	"res://minigames/malware/malware_minigame.tscn": "Malware Removal",
	"res://minigames/cable_management/cable_management_mini_game.tscn": "Cable Management",
	"res://minigames/network_troubleshooting/network_troubleshooting_mini_game.tscn": "Network Issue",
	"res://minigames/bsod_fix/bsod_fix_mini_game.tscn": "DEBUGGING Repair",
	"res://minigames/motherboard_assembly/motherboard_assembly_mini_game.tscn": "Hardware Assembly"
}

func get_issue_title(path: String) -> String:
	return MINIGAME_TITLES.get(path, "Technical Issue")

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
	SaveManager.reset_run_data()
	SaveManager.current_day = 1
	satisfaction = 100
	time_left = 60
	in_tutorial = false
	is_tutorial = false
	tutorial_minigame_index = 0
	tutorial_minigame_done = false
	last_money_change = 0
	last_satisfaction_change = 0
	active_issues = ["", "", "", "", "", "", "", "", "", "", "", "", ""]
	occupied_slots = [false, false, false, false, false, false, false, false, false, false, false, false, false]
	persisted_customers = []
	minigame_deck = []
	last_minigame = ""
	SaveManager.save_game()

func save_game():
	SaveManager.save_game()

func capture_and_save_state():
	if get_tree().current_scene:
		var path = get_tree().current_scene.scene_file_path
		if path in ["res://ui/main_menu_v2/MainMenuV2.tscn", "res://ui/profile_selection/profile_selection.tscn", "res://ui/leaderboard/leaderboard.tscn"]:
			return # Do not save state when in menus
			
		if get_tree().current_scene.has_method("save_state"):
			get_tree().current_scene.save_state()
		SaveManager.saved_scene = path
		
	var state = SaveManager.game_state
	state["time_left"] = time_left
	state["satisfaction"] = satisfaction
	state["active_issues"] = active_issues.duplicate()
	state["occupied_slots"] = occupied_slots.duplicate()
	state["minigame_deck"] = minigame_deck.duplicate()
	state["last_minigame"] = last_minigame
	state["persisted_customers"] = persisted_customers.duplicate()
	state["is_tutorial"] = is_tutorial
	state["tutorial_minigame_index"] = tutorial_minigame_index
	state["tutorial_minigame_done"] = tutorial_minigame_done
	state["last_money_change"] = last_money_change
	state["last_satisfaction_change"] = last_satisfaction_change
	state["last_day_revenue"] = last_day_revenue
	state["last_day_expenses"] = last_day_expenses
	
	SaveManager.save_game()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not SaveManager.player_name.is_empty(): # only if in a profile
			capture_and_save_state()

func load_game():
	SaveManager.load_game()
	
	var state = SaveManager.game_state
	if not state.is_empty():
		time_left = state.get("time_left", 60)
		satisfaction = state.get("satisfaction", 100)
		active_issues = state.get("active_issues", ["", "", "", "", "", "", "", "", "", "", "", "", ""])
		occupied_slots = state.get("occupied_slots", [false, false, false, false, false, false, false, false, false, false, false, false, false])
		minigame_deck = state.get("minigame_deck", [])
		last_minigame = state.get("last_minigame", "")
		persisted_customers = state.get("persisted_customers", [])
		is_tutorial = state.get("is_tutorial", false)
		tutorial_minigame_index = state.get("tutorial_minigame_index", 0)
		tutorial_minigame_done = state.get("tutorial_minigame_done", false)
		last_money_change = state.get("last_money_change", 0)
		last_satisfaction_change = state.get("last_satisfaction_change", 0)
		last_day_revenue = state.get("last_day_revenue", 0)
		last_day_expenses = state.get("last_day_expenses", 0)
	else:
		satisfaction = 100 # Reset satisfaction for new load or keep it?
	return true

func _ready():
	# 2. Seed the RNG immediately when the Autoload boots
	rng.randomize() 
	
	# Listen for any new node entering the scene tree globally
	get_tree().node_added.connect(_on_node_added)
	
	# DEV MODE: Inject a million dollars so you can afford anything instantly
	if dev_mode:
		SaveManager.current_money = 9999999

func _on_node_added(node: Node):
	# Check if the newly added node is a button
	if node is BaseButton:
		setup_button_effect(node)

# ==========================================
# GLOBAL BUTTON EFFECTS
# ==========================================

func setup_button_effect(button: BaseButton):
	# Store the original scale to restore it later
	if not button.has_meta("original_scale"):
		button.set_meta("original_scale", button.scale)
	
	# Using call_deferred ensures the button has its final size before setting the pivot
	button.call_deferred("set_pivot_offset", button.size / 2.0)
	
	# Connect the signals. We check if they are already connected just in case
	if not button.button_down.is_connected(_on_button_down):
		button.button_down.connect(_on_button_down.bind(button))
	if not button.button_up.is_connected(_on_button_up):
		button.button_up.connect(_on_button_up.bind(button))

func _on_button_down(button: BaseButton):
	AudioManager.play_sfx("click")
	var original_scale = button.get_meta("original_scale", Vector2.ONE)
	var tween = create_tween()
	# Optional: Set pause mode to process so it animates even if the game is paused
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) 
	tween.tween_property(button, "scale", original_scale * 0.9, 0.05).set_trans(Tween.TRANS_SINE)

func _on_button_up(button: BaseButton):
	var original_scale = button.get_meta("original_scale", Vector2.ONE)
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(button, "scale", original_scale, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
