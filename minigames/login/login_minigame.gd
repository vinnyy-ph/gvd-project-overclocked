extends Control

@onready var timer_label = $TopPanel/TimerLabel
@onready var progress_label = $TopPanel/ProgressLabel
@onready var status_label = $ScrollContainer/MainPanel/StatusLabel
@onready var request_label = $ScrollContainer/MainPanel/RequestLabel
@onready var input_box = $ScrollContainer/MainPanel/InputBox
@onready var submit_button = $ScrollContainer/MainPanel/SubmitButton
@onready var hint_button_1 = $ScrollContainer/MainPanel/HintButton1
@onready var hint_button_2 = $ScrollContainer/MainPanel/HintButton2
@onready var hint_button_3 = $ScrollContainer/MainPanel/HintButton3
@onready var game_timer = $GameTimer

# ── Tuning ────────────────────────────────────────────────────────────────────
const BASE_TIME: int         = 35
const TOKENS_TO_WIN: int     = 3
const SCRAMBLE_DURATION: float = 0.9   # seconds the token shows scrambled
const SCRAMBLE_INTERVAL: float = 0.08  # how fast letters cycle during scramble
const MAX_LIVES: int         = 3

# Leet substitution map — applied only at difficulty 2+
const LEET_MAP: Dictionary = {
	"O": "0", "I": "1", "S": "5", "E": "3", "A": "4", "T": "7"
}

# ── State ─────────────────────────────────────────────────────────────────────
var time_left: int        = BASE_TIME
var solved_count: int     = 0
var lives: int            = MAX_LIVES
var current_code: String  = ""
var reversed_code: String = ""
var display_code: String  = ""   # what the player actually sees (may be leet-ified)
var game_active: bool     = true
var token_locked: bool    = false  # true while scramble animation is playing
var wrong_streak: int     = 0      # consecutive wrong answers
var original_y: float     = 0.0

# ── Scramble tween refs ───────────────────────────────────────────────────────
var _scramble_timer: float = 0.0
var _scramble_tick: float  = 0.0
var _is_scrambling: bool   = false
var _scramble_tween: Tween = null

func _ready():
	AudioManager.play_bgm("minigame")
	randomize()
	time_left += GameManager.get_hardware_time_bonus()
	original_y = position.y

	game_timer.wait_time = 1.0
	game_timer.one_shot  = false
	if not game_timer.timeout.is_connected(_on_game_timer_timeout):
		game_timer.timeout.connect(_on_game_timer_timeout)
	game_timer.start()

	submit_button.pressed.connect(check_code)
	hint_button_1.pressed.connect(auto_reverse_tool)
	hint_button_2.pressed.connect(clear_input)
	hint_button_3.pressed.connect(skip_token_tool)
	input_box.text_submitted.connect(func(_t): check_code())
	input_box.focus_entered.connect(_on_keyboard_opened)
	input_box.focus_exited.connect(_on_keyboard_closed)

	hint_button_1.text = "AUTO-REVERSE (-3s)"
	hint_button_2.text = "CLEAR INPUT"
	hint_button_3.text = "SKIP TOKEN (-2s)"

	_refresh_lives_display()
	generate_new_code()
	update_timer()
	update_progress()

# ── Process (drives scramble animation) ──────────────────────────────────────
func _process(delta: float):
	if not _is_scrambling or not game_active:
		return

	_scramble_timer += delta
	_scramble_tick  += delta

	# Rapidly cycle random-looking characters to mimic decryption static
	if _scramble_tick >= SCRAMBLE_INTERVAL:
		_scramble_tick = 0.0
		request_label.text = "TOKEN: " + _make_noise_string(current_code.length())

	# After SCRAMBLE_DURATION, reveal the real token and unlock input
	if _scramble_timer >= SCRAMBLE_DURATION:
		_is_scrambling = false
		token_locked   = false
		request_label.text = "TOKEN: " + display_code
		status_label.text  = "> SECURITY: ENTER TOKEN BACKWARDS."
		input_box.editable = true
		input_box.grab_focus()

func _make_noise_string(length: int) -> String:
	var noise_chars = "ABCDEFGHJKLMNPQRSTUVWXYZ0123456789!@#$%"
	var result = ""
	for i in range(length):
		if current_code[i] == "-":
			result += "-"
		else:
			result += noise_chars[randi() % noise_chars.length()]
	return result

# ── Difficulty ────────────────────────────────────────────────────────────────
func get_difficulty() -> int:
	# 0 = easy, 1 = medium, 2 = hard
	return min(solved_count, 2)

func get_time_for_round() -> int:
	# Each solved token shaves 5 seconds off the clock
	return BASE_TIME - (solved_count * 5)

# ── Code Generation ───────────────────────────────────────────────────────────
func random_letter() -> String:
	var letters = "ABCDEFGHJKLMNPQRSTUVWXYZ"
	return letters[randi() % letters.length()]

func random_digit() -> String:
	return str(randi() % 10)

func create_temp_code() -> String:
	# Difficulty 2: longer token (add one extra segment)
	if get_difficulty() >= 2:
		return random_letter() + random_digit() + "-" + random_letter() + random_digit() + random_letter() + random_digit()
	return random_letter() + random_digit() + "-" + random_letter() + random_digit() + random_letter()

func apply_leet_substitution(s: String) -> String:
	# At difficulty 1+, randomly swap 1 character using leet map
	# At difficulty 2+, swap up to 2 characters
	var swaps = get_difficulty()
	var result = s
	var keys = LEET_MAP.keys()
	var swapped = 0
	# Iterate characters, probabilistically replace
	for i in range(result.length()):
		if swapped >= swaps:
			break
		var ch = result[i]
		if ch in LEET_MAP and randi() % 3 == 0:
			result[i] = LEET_MAP[ch]
			swapped += 1
	return result

func reverse_string(s: String) -> String:
	var rev = ""
	for i in range(s.length() - 1, -1, -1):
		rev += s[i]
	return rev

func generate_new_code():
	token_locked  = true
	input_box.editable = false
	input_box.text     = ""
	wrong_streak       = 0

	current_code = create_temp_code()

	# Apply leet substitution to what the player sees (difficulty 1+)
	if get_difficulty() >= 1:
		display_code = apply_leet_substitution(current_code)
	else:
		display_code = current_code

	# The correct answer is the reverse of display_code (what's shown)
	reversed_code = reverse_string(display_code)

	status_label.text = "> DECRYPTING TOKEN... STAND BY."
	request_label.text = "TOKEN: --------"

	# Kick off the scramble phase
	_scramble_timer = 0.0
	_scramble_tick  = 0.0
	_is_scrambling  = true

# ── Support Tools ─────────────────────────────────────────────────────────────
func auto_reverse_tool():
	if not game_active or token_locked: return
	apply_time_penalty(3)
	request_label.text = "DECRYPTED: " + reversed_code
	status_label.text  = "> SYSTEM OVERRIDE APPLIED."

func clear_input():
	input_box.text = ""
	input_box.grab_focus()

func skip_token_tool():
	if not game_active or token_locked: return
	apply_time_penalty(2)
	status_label.text = "> TOKEN REJECTED. GENERATING NEW..."
	generate_new_code()

# ── Interaction Logic ─────────────────────────────────────────────────────────
func check_code():
	if not game_active or token_locked: return

	input_box.release_focus()
	var user_input = input_box.text.strip_edges().to_upper()

	if user_input == reversed_code:
		# ── SUCCESS ──────────────────────────────────────────────────────────
		solved_count += 1
		wrong_streak  = 0
		update_progress()

		if solved_count >= TOKENS_TO_WIN:
			win_game()
		else:
			# Harder next round: reset timer to the new (lower) value
			time_left = get_time_for_round()
			update_timer()
			status_label.text = "> LOGIN APPROVED. ESCALATING SECURITY..."
			generate_new_code()
	else:
		# ── FAILURE ───────────────────────────────────────────────────────────
		wrong_streak += 1
		lives        -= 1
		_refresh_lives_display()

		# Extra time penalty for repeat failures
		var extra_penalty = max(0, wrong_streak - 1)
		if extra_penalty > 0:
			apply_time_penalty(extra_penalty)
			status_label.text = "> ERROR x%d! -%ds PENALTY!" % [wrong_streak, extra_penalty]
		else:
			status_label.text = "> INCORRECT! BACKWARDS! (%d LIVES LEFT)" % lives

		input_box.text = ""

		# Flash red
		_flash_red(timer_label)

		if lives <= 0:
			await get_tree().create_timer(0.4).timeout
			fail_game()

func _refresh_lives_display():
	# Reuse the progress label area or append to status — using progress_label here
	var hearts = ""
	for i in range(MAX_LIVES):
		hearts += ("♥ " if i < lives else "♡ ")
	progress_label.text = "SOLVED: %d / %d   %s" % [solved_count, TOKENS_TO_WIN, hearts]

func _flash_red(node: Control):
	node.modulate = Color(1, 0, 0, 1)
	await get_tree().create_timer(0.3).timeout
	node.modulate = Color(1, 1, 1, 1)

func apply_time_penalty(seconds: int):
	time_left -= seconds
	if time_left < 0: time_left = 0
	update_timer()
	_flash_red(timer_label)
	if time_left <= 0:
		fail_game()

func update_timer():
	timer_label.text = "TIME: " + str(time_left)

	# Color-code urgency
	if time_left <= 10:
		timer_label.modulate = Color(1, 0.3, 0.3, 1)
	elif time_left <= 20:
		timer_label.modulate = Color(1, 0.8, 0.2, 1)
	else:
		timer_label.modulate = Color(1, 1, 1, 1)

func update_progress():
	_refresh_lives_display()

func _on_game_timer_timeout():
	if not game_active: return
	time_left -= 1
	if time_left <= 0:
		time_left = 0
		update_timer()
		fail_game()
	else:
		update_timer()

# ── Mobile Keyboard Slide ─────────────────────────────────────────────────────
func _on_keyboard_opened():
	var tween = create_tween()
	tween.tween_property(self, "position:y", original_y - 250, 0.3).set_trans(Tween.TRANS_SINE)

func _on_keyboard_closed():
	var tween = create_tween()
	tween.tween_property(self, "position:y", original_y, 0.3).set_trans(Tween.TRANS_SINE)

# ── Win / Loss ────────────────────────────────────────────────────────────────
func win_game():
	game_active = false
	game_timer.stop()
	status_label.text = "> ALL AUTHENTICATIONS VERIFIED. WELL DONE."
	AudioManager.play_sfx("coin")

	GameManager.last_money_change        = GameManager.get_money_reward(20)
	GameManager.last_satisfaction_change = 10
	GameManager.money       += GameManager.last_money_change
	GameManager.satisfaction = min(GameManager.satisfaction + GameManager.last_satisfaction_change, 100)
	GameManager.save_game()

	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://ui/success_screen/success_screen.tscn")

func fail_game():
	if not game_active: return  # guard against double-trigger
	game_active = false
	game_timer.stop()
	_is_scrambling     = false
	input_box.editable = false
	status_label.text  = "> AUTHENTICATION TIMEOUT. ACCESS DENIED."

	GameManager.last_money_change        = 0
	GameManager.apply_satisfaction_penalty(10)
	GameManager.save_game()

	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://ui/success_screen/success_screen.tscn")
