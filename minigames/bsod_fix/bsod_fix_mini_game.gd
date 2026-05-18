extends Control

@onready var timer_label = $Background/TopPanel/TimerLabel
@onready var step_label = $Background/TopPanel/StepLabel
@onready var status_label = $Background/InstructionsPanel/InstructionsLabel
@onready var debugging_text = $DEBUGGINGPanel/DEBUGGINGText

@onready var choice_button_1 = $ChoicesArea/ChoiceButton1
@onready var choice_button_2 = $ChoicesArea/ChoiceButton2
@onready var choice_button_3 = $ChoicesArea/ChoiceButton3
@onready var choice_button_4 = $ChoicesArea/ChoiceButton4
@onready var game_timer = $GameTimer

var time_left: int = 60
var current_step: int = 0
var game_active: bool = true

# --- THE BUG HUNTER DATABASE ---
var bug_database = [
	{
		"code": "def say_hello():\n    print(\"Hello World\")\n\nsay_hello",
		"question": "The function isn't running. Why?",
		"correct": "Missing () to call it",
		"decoys": ["Missing a colon", "Incorrect indent", "Wrong function name"]
	},
	{
		"code": "for i in range(5)\n    print(i)",
		"question": "There is a Syntax Error here.",
		"correct": "Missing : after range(5)",
		"decoys": ["i is not defined", "Indent is too large", "Missing brackets"]
	},
	{
		"code": "score = 10\nif score = 10:\n    print(\"You win!\")",
		"question": "This code won't run. What's wrong?",
		"correct": "Use == for comparison",
		"decoys": ["Missing quotes", "Score is a string", "If needs a semicolon"]
	},
	{
		"code": "names = [\"Alice\", \"Bob\"]\nprint(names[2])",
		"question": "This crashes with an Index Error.",
		"correct": "Index 2 doesn't exist",
		"decoys": ["Alice is missing", "List is not defined", "Use round brackets"]
	},
	{
		"code": "x = \"5\"\ny = 10\nprint(x + y)",
		"question": "This causes a TypeError.",
		"correct": "Cannot add String + Int",
		"decoys": ["Variables are hidden", "Missing print space", "x is too small"]
	},
	{
		"code": "while True\n    print(\"Looping...\")",
		"question": "The loop won't start. Why?",
		"correct": "Missing : after True",
		"decoys": ["While must be capitalized", "Infinite loops are illegal", "Indent is wrong"]
	},
	{
		"code": "def add(a, b):\nreturn a + b",
		"question": "This throws an IndentationError.",
		"correct": "Return must be indented",
		"decoys": ["a and b not defined", "Missing colon", "Cannot return math"]
	},
	{
		"code": "items = [1, 2, 3]\nitems.append(4, 5)",
		"question": "This code crashes. Why?",
		"correct": "append() takes 1 argument",
		"decoys": ["List is full", "4 and 5 are strings", "Use .add() instead"]
	},
	{
		"code": "print(\"Hello world\"",
		"question": "Simple syntax error detected.",
		"correct": "Missing closing )",
		"decoys": ["Missing quotes", "Print is not a function", "World is capitalized"]
	},
	{
		"code": "x = 10\ny = 0\nresult = x / y",
		"question": "The program crashed!",
		"correct": "ZeroDivisionError",
		"decoys": ["x is too large", "y is not a number", "Result is a keyword"]
	},
	{
		"code": "import mathh\nprint(math.pi)",
		"question": "The first line failed.",
		"correct": "Module mathh not found",
		"decoys": ["pi is not in math", "Import must be at bottom", "Math is a string"]
	},
	{
		"code": "age = \"25\"\nif age > 18:\n    print(\"Adult\")",
		"question": "This throws a TypeError.",
		"correct": "Comparing String to Int",
		"decoys": ["Age is too old", "Missing colon", "If must use brackets"]
	},
	{
		"code": "user_data = {\"id\": 1}\nprint(user_data[\"name\"])",
		"question": "The console shows a KeyError.",
		"correct": "Key 'name' doesn't exist",
		"decoys": ["Dictionary is empty", "id is not an integer", "Use square brackets"]
	},
	{
		"code": "class Player\n    def __init__(self):",
		"question": "Class definition failed.",
		"correct": "Missing : after Player",
		"decoys": ["Self is not defined", "Init is misspelled", "Class must be lowercase"]
	},
	{
		"code": "x = 5\nprint(X)",
		"question": "The console says NameError.",
		"correct": "X is not defined (case)",
		"decoys": ["x is private", "Print cannot see x", "X is a reserved word"]
	},
	{
		"code": "def check():\n    pass\n  print(\"Done\")",
		"question": "What is the error here?",
		"correct": "Unindent doesn't match",
		"decoys": ["Pass is a bug", "Check is not running", "Print is inside pass"]
	},
	{
		"code": "val = int(\"abc\")",
		"question": "This throws a ValueError.",
		"correct": "abc is not a number",
		"decoys": ["Int cannot take strings", "Quotes are wrong", "abc is too long"]
	},
	{
		"code": "with open(\"data.txt\")\n    text = f.read()",
		"question": "Why did this fail?",
		"correct": "Missing : after open()",
		"decoys": ["data.txt is missing", "text is a keyword", "Indent is too small"]
	},
	{
		"code": "colors = (\"red\", \"blue\")\ncolors[0] = \"green\"",
		"question": "This crashes with a TypeError.",
		"correct": "Tuples cannot be changed",
		"decoys": ["Green is not a color", "Index 0 is occupied", "Use curly brackets"]
	},
	{
		"code": "result = 5 > \"3\"",
		"question": "What is the problem?",
		"correct": "Cannot compare Int and Str",
		"decoys": ["5 is smaller than 3", "Result is not defined", "Quotes are required"]
	}
]

var active_bug: Dictionary
var processing_input: bool = false

func _ready():
	AudioManager.play_bgm("minigame")
	randomize()
	
	# Load State if exists
	var state = SaveManager.game_state
	if state.has("bsod_time_left"):
		time_left = state["bsod_time_left"]
		current_step = state["bsod_current_step"]
		active_bug = state["bsod_active_bug"]
	else:
		time_left = GameManager.get_minigame_timer("bsod")
		time_left += GameManager.get_hardware_time_bonus()
		load_new_bug()
	
	# 1. Setup Timer
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

	# 3. Apply state visually
	if state.has("bsod_active_bug"):
		_display_current_bug()
	
	update_timer()
	update_step_ui()

func _display_current_bug():
	var code_text = "[color=#00ff44][b]>>> DEBUGGER CONSOLE[/b][/color]\n\n"
	code_text += "[color=#ffffff][i]# Analysing snippet...[/i][/color]\n"
	code_text += "[color=#00ff44]" + active_bug["code"] + "[/color]\n\n"
	code_text += "[color=#ffff00][b]QUESTION:[/b] " + active_bug["question"] + "[/color]"
	
	debugging_text.text = code_text
	status_label.text = "Select the correct fix to continue."
	generate_choices()

func load_new_bug():
	active_bug = bug_database[randi() % bug_database.size()]
	_display_current_bug()

func save_state():
	var state = SaveManager.game_state
	state["bsod_time_left"] = time_left
	state["bsod_current_step"] = current_step
	state["bsod_active_bug"] = active_bug

func clear_state():
	var state = SaveManager.game_state
	state.erase("bsod_time_left")
	state.erase("bsod_current_step")
	state.erase("bsod_active_bug")

func generate_choices():
	var options: Array = [active_bug["correct"]]
	options.append_array(active_bug["decoys"])
	options.shuffle()

	choice_button_1.text = options[0]
	choice_button_2.text = options[1]
	choice_button_3.text = options[2]
	choice_button_4.text = options[3]

func check_answer(selected_text: String):
	if not game_active or processing_input: return
	
	processing_input = true # LOCK input
	
	if selected_text == active_bug["correct"]:
		current_step += 1
		status_label.text = "Bug Fixed! Loading next..."
		
		if current_step >= 3: # Win after fixing 3 bugs
			win_game()
		else:
			update_step_ui()
			load_new_bug()
			processing_input = false # UNLOCK input for next bug
	else:
		# PENALTY: Failed the bug fix, but STAY on the same bug
		status_label.text = "WRONG FIX! -5 SECONDS | Try again..."
		time_left -= 5 
		if time_left < 0: time_left = 0
		update_timer()
		
		# Feedback: Flash the console red to show error
		var original_color = debugging_text.modulate
		debugging_text.modulate = Color(1, 0, 0, 1)
		await get_tree().create_timer(0.4).timeout
		debugging_text.modulate = original_color
		
		processing_input = false # UNLOCK input after animation
		
		if time_left <= 0:
			fail_game()

func update_timer():
	timer_label.text = "TIME: " + str(time_left)

func update_step_ui():
	step_label.text = "FIXED: " + str(current_step) + " / 3"

func _on_game_timer_timeout():
	if not game_active: return
	
	time_left -= 1
	if time_left <= 0:
		time_left = 0
		update_timer()
		fail_game()
	else:
		update_timer()

func win_game():
	game_active = false
	game_timer.stop()
	status_label.text = "ALL BUGS SQUASHED! SYSTEM STABLE."
	AudioManager.play_sfx("coin")
	
	choice_button_1.disabled = true
	choice_button_2.disabled = true
	choice_button_3.disabled = true
	choice_button_4.disabled = true
	
	GameManager.last_money_change = GameManager.get_minigame_reward("bsod")
	GameManager.last_satisfaction_change = GameManager.get_minigame_satisfaction_gain("bsod")
	GameManager.money += GameManager.last_money_change
	GameManager.satisfaction = min(GameManager.satisfaction + GameManager.last_satisfaction_change, 100)
	GameManager.save_game()
	
	clear_state()
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://ui/success_screen/success_screen.tscn")

func fail_game():
	game_active = false
	game_timer.stop()
	status_label.text = "CODE COLLAPSE. REPAIR FAILED."
	
	choice_button_1.disabled = true
	choice_button_2.disabled = true
	choice_button_3.disabled = true
	choice_button_4.disabled = true
	
	GameManager.last_money_change = -GameManager.get_minigame_deduction("bsod")
	GameManager.money += GameManager.last_money_change
	
	GameManager.last_satisfaction_change = -GameManager.get_minigame_satisfaction_loss("bsod")
	GameManager.satisfaction += GameManager.last_satisfaction_change
	GameManager.save_game()
	
	clear_state()
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://ui/success_screen/success_screen.tscn")
