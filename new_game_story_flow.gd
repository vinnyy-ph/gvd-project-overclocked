extends Control

@onready var character_rect: TextureRect = $Character
@onready var text_label: Label = $BluePanelBtn/TextContentLabel
@onready var username_label: Label = $BluePanelBtn/UsernameLabel
@onready var blue_panel_btn: TextureButton = $BluePanelBtn

@onready var seal: TextureRect = $Seal
@onready var seal_button: TextureButton = $Seal/SealButton
@onready var line_guide: TextureRect = $Seal/LineGuide
@onready var hand_guide: TextureRect = $Seal/LineGuide/HandGuide
@onready var line_path: Path2D = $Seal/LineGuide/HandLinePath
@onready var seal_particles: CPUParticles2D = $Seal/SealParticles

@onready var letter: TextureRect = $Letter
@onready var next_button: Button = $Letter/NextButton
@onready var prev_button: Button = $Letter/PrevButton
@onready var start_button: Button = $Letter/StartButton
@onready var dimmer: ColorRect = $Dimmer

@onready var phone: TextureRect = $Phone

@onready var last_bg: TextureRect = $lastbg
@onready var jeepney_path_follow: PathFollow2D = $lastbg/JeepneyLinePath/PathFollow2D

var story_steps = [
	{
		"text": "Ugh... College is so tiring...",
		"texture": "res://assets/story/1.png",
		"username": "USERNAME"
	},
	{
		"text": "I want to pass my time but still put my knowledge to use.",
		"texture": "res://assets/story/2.png",
		"username": "USERNAME"
	},
	{
		"text": "LBC: Dear Customer! You just received a package!",
		"texture": "res://assets/story/3.png",
		"username": "NOTIFICATION:",
		"show_phone": true
	},
	{
		"text": "Huh? Is this a letter from Grandpa?",
		"texture": "res://assets/story/4.png",
		"username": "USERNAME"
	}
]

var letter_textures = [
	"res://assets/story/letter1.png",
	"res://assets/story/letter2.png",
	"res://assets/story/letter3.png"
]

var current_step = 0
var seal_tap_count = 0
var is_swipe_phase = false
var is_swiping = false
var swipe_start_pos = Vector2.ZERO
var hand_tween: Tween
var phone_vibrate_tween: Tween
var current_letter_page = 0
var is_final_sequence = false

# Anti-spam and flow control
var last_tap_time: int = 0
const TAP_THRESHOLD_MS: int = 300

func _ready() -> void:
	blue_panel_btn.pressed.connect(_on_tap_received)
	seal_button.pressed.connect(_on_seal_pressed)
	next_button.pressed.connect(_on_next_letter)
	prev_button.pressed.connect(_on_prev_letter)
	start_button.pressed.connect(_start_game)
	
	# Initial state
	seal.visible = false
	seal.modulate.a = 0.0
	line_guide.visible = false
	line_guide.modulate.a = 0.0
	letter.visible = false
	letter.modulate.a = 0.0
	dimmer.visible = false
	dimmer.modulate.a = 0.0
	last_bg.visible = false
	last_bg.modulate.a = 0.0
	phone.visible = false
	phone.modulate.a = 0.0
	
	# Fix Jeepney jump
	jeepney_path_follow.progress_ratio = 0.0
	
	_update_ui()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if is_swipe_phase:
				is_swiping = true
				swipe_start_pos = event.position
			elif not letter.visible and not is_final_sequence:
				_on_tap_received()
		else:
			if is_swiping:
				is_swiping = false
				_check_swipe(event.position)

func _on_tap_received() -> void:
	var now = Time.get_ticks_msec()
	if now - last_tap_time < TAP_THRESHOLD_MS:
		return
	last_tap_time = now
	
	if "is_animating" in text_label and text_label.is_animating:
		text_label.skip_animation()
	else:
		_advance_story()

func _advance_story() -> void:
	# Hide phone if it was showing
	if phone.visible:
		_hide_phone()
		
	if current_step < story_steps.size() - 1:
		current_step += 1
		_update_ui()
		
		var step = story_steps[current_step]
		if step.get("show_phone", false):
			_show_phone()
		
		# If we just reached the last step, show the seal
		if current_step == story_steps.size() - 1:
			_show_seal()

func _update_ui() -> void:
	var step = story_steps[current_step]
	
	if step.has("texture"):
		character_rect.texture = load(step.texture)
	
	if step.has("username"):
		username_label.text = step.username
		
	if text_label.has_method("display_text"):
		text_label.display_text(step.text)
	else:
		text_label.text = step.text

func _show_phone() -> void:
	phone.visible = true
	phone.pivot_offset = phone.size / 2
	phone.scale = Vector2(0.8, 0.8)
	phone.modulate.a = 0.0
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(phone, "modulate:a", 1.0, 0.3)
	tween.tween_property(phone, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(_start_phone_vibration)

func _start_phone_vibration() -> void:
	if phone_vibrate_tween: phone_vibrate_tween.kill()
	
	phone_vibrate_tween = create_tween().set_loops()
	var original_pos = phone.position
	
	# Suble pixel-aesthetic vibration (snapping to small offsets)
	phone_vibrate_tween.tween_callback(func(): 
		if OS.has_feature("mobile"):
			Input.vibrate_handheld(150)
	)
	phone_vibrate_tween.tween_property(phone, "position", original_pos + Vector2(2, 0), 0.05)
	phone_vibrate_tween.tween_property(phone, "position", original_pos + Vector2(-2, 0), 0.05)
	phone_vibrate_tween.tween_property(phone, "position", original_pos + Vector2(0, 2), 0.05)
	phone_vibrate_tween.tween_property(phone, "position", original_pos + Vector2(0, -2), 0.05)
	phone_vibrate_tween.tween_property(phone, "position", original_pos, 0.05)
	phone_vibrate_tween.tween_interval(0.2) # Short pause between vibration bursts

func _hide_phone() -> void:
	if phone_vibrate_tween: phone_vibrate_tween.kill()
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(phone, "modulate:a", 0.0, 0.2)
	tween.tween_property(phone, "scale", Vector2(0.8, 0.8), 0.2)
	tween.chain().tween_callback(func(): phone.visible = false)

func _show_seal() -> void:
	dimmer.visible = true
	seal.visible = true
	seal.pivot_offset = seal.size / 2
	seal.scale = Vector2(0.5, 0.5)
	seal.position.y += 50
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(dimmer, "modulate:a", 1.0, 0.5)
	tween.tween_property(seal, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(seal, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(seal, "position:y", seal.position.y - 50, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_seal_pressed() -> void:
	if is_swipe_phase: return
	
	seal_tap_count += 1
	
	# Stronger Haptic for Seal
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(80)
	
	# Trigger particles
	if seal_particles:
		seal_particles.position = seal_button.position + (seal_button.size / 2)
		seal_particles.restart()
		seal_particles.emitting = true
	
	# Feedback on tap
	var pulse = create_tween()
	pulse.tween_property(seal_button, "scale", Vector2(1.1, 1.1), 0.05)
	pulse.tween_property(seal_button, "scale", Vector2(1.0, 1.0), 0.05)
	
	if seal_tap_count == 1:
		seal_button.texture_normal = load("res://assets/story/seal2.png")
	elif seal_tap_count == 2:
		seal_button.texture_normal = load("res://assets/story/seal3.png")
	elif seal_tap_count == 3:
		_start_swipe_phase()

func _start_swipe_phase() -> void:
	is_swipe_phase = true
	seal_button.visible = false
	
	line_guide.visible = true
	var tween = create_tween()
	tween.tween_property(line_guide, "modulate:a", 1.0, 0.5)
	
	_animate_hand_guide()

func _animate_hand_guide() -> void:
	if hand_tween: hand_tween.kill()
	
	hand_tween = create_tween().set_loops()
	hand_tween.tween_method(
		func(t: float): 
			hand_guide.position = line_path.curve.sample_baked(t * line_path.curve.get_baked_length()),
		0.0, 1.0, 1.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _check_swipe(end_pos: Vector2) -> void:
	var swipe_vec = end_pos - swipe_start_pos
	if swipe_vec.length() > 80:
		_complete_swipe()

func _complete_swipe() -> void:
	is_swipe_phase = false
	if hand_tween: hand_tween.kill()
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(line_guide, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(func(): 
		line_guide.visible = false
		_hide_seal()
	)

func _hide_seal() -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(seal, "modulate:a", 0.0, 0.3)
	tween.tween_property(seal, "scale", Vector2(1.2, 1.2), 0.3)
	tween.chain().tween_callback(func(): 
		seal.visible = false
		_show_letter()
	)

func _show_letter() -> void:
	letter.visible = true
	letter.pivot_offset = letter.size / 2
	letter.scale = Vector2(0.5, 0.5)
	letter.modulate.a = 0.0
	
	current_letter_page = 0
	_update_letter_ui()
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(letter, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(letter, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_letter_ui() -> void:
	letter.texture = load(letter_textures[current_letter_page])
	
	prev_button.visible = current_letter_page > 0
	
	var is_last_page = current_letter_page == letter_textures.size() - 1
	next_button.visible = !is_last_page
	start_button.visible = is_last_page

func _on_next_letter() -> void:
	if current_letter_page < letter_textures.size() - 1:
		current_letter_page += 1
		_update_letter_ui()

func _on_prev_letter() -> void:
	if current_letter_page > 0:
		current_letter_page -= 1
		_update_letter_ui()

func _start_game() -> void:
	is_final_sequence = true
	
	# Fade out letter and dimmer
	var tween = create_tween().set_parallel(true)
	tween.tween_property(letter, "modulate:a", 0.0, 0.5)
	tween.tween_property(dimmer, "modulate:a", 0.0, 0.5)
	
	# Show last background
	last_bg.visible = true
	tween.tween_property(last_bg, "modulate:a", 1.0, 0.5)
	
	tween.chain().tween_callback(_on_final_background_ready)

func _on_final_background_ready() -> void:
	letter.visible = false
	dimmer.visible = false
	
	# Update character and text
	character_rect.texture = load("res://assets/story/3.png")
	if text_label.has_method("display_text"):
		text_label.display_text("It’s nice to be back. Let’s start this new journey!")
	else:
		text_label.text = "It’s nice to be back. Let’s start this new journey!"
	
	# Fix Jeepney jump
	jeepney_path_follow.progress_ratio = 0.0
	
	# Animate Jeepney using PathFollow2D
	var jeepney_tween = create_tween()
	jeepney_tween.tween_property(jeepney_path_follow, "progress_ratio", 1.0, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	jeepney_tween.tween_callback(func(): print("Final sequence complete"))
