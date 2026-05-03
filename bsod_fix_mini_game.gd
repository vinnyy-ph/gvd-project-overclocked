extends Control

@onready var timer_label = $Background/TopPanel/TimerLabel
@onready var step_label = $Background/TopPanel/StepLabel
@onready var status_label = $Background/InstructionsPanel/InstructionsLabel
@onready var bsod_text = $BSODPanel/BSODText

@onready var choice_button_1 = $ChoicesArea/ChoiceButton1
@onready var choice_button_2 = $ChoicesArea/ChoiceButton2
@onready var choice_button_3 = $ChoicesArea/ChoiceButton3
@onready var choice_button_4 = $ChoicesArea/ChoiceButton4
@onready var game_timer = $GameTimer

var time_left: int = 30 # Increased slightly for reading time
var current_step: int = 0
var game_active: bool = true

# --- THE DIAGNOSTIC DATABASE ---
# Each error has a specific Stop Code and a unique 3-step solution.
var bsod_database = [
	{
		"error_code": "STOP: 0x0000001A (MEMORY_MANAGEMENT)",
		"desc": "A critical memory allocation failed. Physical RAM may be compromised.",
		"steps": ["Boot into BIOS", "Run MemTest86", "Reseat RAM Sticks"]
	},
	{
		"error_code": "STOP: 0x116 (VIDEO_TDR_FAILURE)",
		"desc": "The display driver failed to respond and did not recover in time.",
		"steps": ["Boot in Safe Mode", "Use DDU to Wipe Drivers", "Install Clean GPU Driver"]
	},
	{
		"error_code": "STOP: 0x0000007B (INACCESSIBLE_BOOT_DEVICE)",
		"desc": "The OS lost access to the system partition during startup.",
		"steps": ["Open Command Prompt", "Run chkdsk /f /r", "Rebuild BCD"]
	}
]

var active_bsod: Dictionary
var current_correct_steps: Array

# Random bad options to fill out the remaining buttons
var decoy_pool = [
	"Install random software update",
	"Ignore the error",
	"Unplug monitor",
	"Delete System32",
	"Smack the tower",
	"Download more RAM",
	"Restart the PC",
	"Run antivirus scan"
]

func _ready():
	AudioManager.play_bgm("minigame")
	randomize()
	
	# 1. Setup Timer correctly
	game_timer.wait_time = 1.0
	game_timer.one_shot = false
	if not game_timer.timeout.is_connected(_on_game_timer_timeout):
		game_timer.timeout.connect(_on_game_timer_timeout)
	game_timer.start()

	# 2. Connect Buttons
	choice_button_1.pressed.connect(func(): check_answer(choice_button_1.text))
	choice_button_2.pressed.connect(func(): check_answer(choice_button_2.text))
	choice_button_3.pressed.connect(func(): check_answer(choice_button_3.text))
	choice_button_4.pressed.connect(func(): check_answer(choice_button_4.text))

	# 3. Pick a random BSOD for this session
	active_bsod = bsod_database[randi() % bsod_database.size()]
	current_correct_steps = active_bsod["steps"]
	
	# Display the scary blue screen text
	bsod_text.text = ":(\n\nYour PC ran into a problem.\n\n" + active_bsod["error_code"] + "\n\n" + active_bsod["desc"]

	update_timer()
	update_step_ui()
	generate_choices()
	status_label.text = "Analyze the Stop Code to begin repairs."

func update_timer():
	timer_label.text = "TIME: " + str(time_left)

func update_step_ui():
	step_label.text = "STEP " + str(current_step + 1) + " OF 3"

func generate_choices():
	if not game_active: return
	
	var current_correct = current_correct_steps[current_step]
	var options: Array = [current_correct]

	# Fill the rest with random decoys
	var temp_decoys = decoy_pool.duplicate()
	temp_decoys.shuffle()
	
	while options.size() < 4:
		var random_choice = temp_decoys.pop_back()
		if not options.has(random_choice):
			options.append(random_choice)

	# Shuffle the 4 options so the correct answer isn't always button 1
	options.shuffle()

	choice_button_1.text = options[0]
	choice_button_2.text = options[1]
	choice_button_3.text = options[2]
	choice_button_4.text = options[3]

# --- INTERACTION LOGIC ---

func check_answer(selected_text: String):
	if not game_active: return
	
	if selected_text == current_correct_steps[current_step]:
		# SUCCESS! Advance to the next step
		current_step += 1

		if current_step >= current_correct_steps.size():
			win_game()
			return

		status_label.text = "> Step Applied. Continuing sequence..."
		update_step_ui()
		generate_choices()
		
	else:
		# PENALTY: Failed the repair tree!
		status_label.text = "> FATAL: WRONG FIX APPLIED! BOOT LOOPING..."
		
		# Time penalty
		time_left -= 4 
		if time_left < 0: time_left = 0
		update_timer()
		
		# Reset the entire sequence back to step 1
		current_step = 0 
		update_step_ui()
		generate_choices()
		
		# Flash screen red for damage feedback
		var original_color = bsod_text.modulate
		bsod_text.modulate = Color(1, 0, 0, 1) # Flash text red
		timer_label.modulate = Color(1, 0, 0, 1)
		await get_tree().create_timer(0.4).timeout
		bsod_text.modulate = original_color
		timer_label.modulate = Color(1, 1, 1, 1)
		
		if time_left <= 0:
			fail_game()

func _on_game_timer_timeout():
	if not game_active: return
	
	time_left -= 1
	if time_left <= 0:
		time_left = 0
		update_timer()
		fail_game()
	else:
		update_timer()

# --- WIN / LOSS INTEGRATED WITH GAME MANAGER ---

func win_game():
	game_active = false
	game_timer.stop()
	status_label.text = "> OS RECOVERED SUCCESSFULLY."
	AudioManager.play_sfx("success")
	AudioManager.play_sfx("coin")
	
	# Disable buttons so they can't spam click
	choice_button_1.disabled = true
	choice_button_2.disabled = true
	choice_button_3.disabled = true
	choice_button_4.disabled = true
	
	GameManager.last_money_change = 25
	GameManager.last_satisfaction_change = 10
	
	GameManager.money += GameManager.last_money_change
	GameManager.satisfaction += GameManager.last_satisfaction_change
	if GameManager.satisfaction > 100: GameManager.satisfaction = 100
	GameManager.save_game()
	
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://success_screen.tscn")

func fail_game():
	game_active = false
	game_timer.stop()
	status_label.text = "> SYSTEM BRICKED. REPAIR FAILED."
	AudioManager.play_sfx("fail")
	
	choice_button_1.disabled = true
	choice_button_2.disabled = true
	choice_button_3.disabled = true
	choice_button_4.disabled = true
	
	GameManager.last_money_change = 0
	GameManager.last_satisfaction_change = -15
	
	GameManager.satisfaction += GameManager.last_satisfaction_change
	if GameManager.satisfaction < 0: GameManager.satisfaction = 0
	GameManager.save_game()
	
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://shop_floor_scrollable.tscn")
