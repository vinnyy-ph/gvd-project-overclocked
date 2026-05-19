extends Control

@onready var character_rect: TextureRect = $Character
@onready var text_label: Label = $BluePanelBtn/TextContentLabel
@onready var username_label: Label = $BluePanelBtn/UsernameLabel
@onready var blue_panel_btn: TextureButton = $BluePanelBtn

@onready var seal: TextureRect = $Seal
@onready var seal_button: TextureButton = $Seal/SealButton
@onready var line_guide: TextureRect = $Seal/LineGuide
@onready var hand_guide: TextureRect = $Seal/LineGuide/HandGuide
@onready var line_path: Path2D = $Seal/LineGuide/LinePath

@onready var letter: TextureRect = $Letter
@onready var next_button: Button = $Letter/NextButton
@onready var prev_button: Button = $Letter/PrevButton
@onready var start_button: Button = $Letter/StartButton
@onready var dimmer: ColorRect = $Dimmer

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
		"username": "NOTIFICATION:"
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
var current_letter_page = 0

func _ready() -> void:
	blue_panel_btn.pressed.connect(_on_next_step)
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
	
	_update_ui()

func _on_next_step() -> void:
	if is_swipe_phase or letter.visible: return # Block progression during interaction
	
	if current_step < story_steps.size() - 1:
		current_step += 1
		_update_ui()
		
		# If we just reached the last step, show the seal
		if current_step == story_steps.size() - 1:
			_show_seal()
	else:
		# Story finished logic
		pass

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

func _input(event: InputEvent) -> void:
	if not is_swipe_phase: return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_swiping = true
				swipe_start_pos = event.position
			else:
				is_swiping = false
				_check_swipe(event.position)

func _check_swipe(end_pos: Vector2) -> void:
	var swipe_vec = end_pos - swipe_start_pos
	if swipe_vec.length() > 100:
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
	print("START GAME TRIGGERED")
	# Logic to switch to the actual game scene
	# get_tree().change_scene_to_file("res://main_game.tscn")
