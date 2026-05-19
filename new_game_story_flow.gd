extends Control

@onready var character_rect: TextureRect = $Character
@onready var text_label: Label = $BluePanelBtn/TextContentLabel
@onready var username_label: Label = $BluePanelBtn/UsernameLabel
@onready var blue_panel_btn: TextureButton = $BluePanelBtn

@onready var seal: TextureRect = $Seal
@onready var seal_button: TextureButton = $Seal/SealButton

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

var current_step = 0
var seal_tap_count = 0

func _ready() -> void:
	blue_panel_btn.pressed.connect(_on_next_step)
	seal_button.pressed.connect(_on_seal_pressed)
	
	# Initial state
	seal.visible = false
	seal.modulate.a = 0.0
	_update_ui()

func _on_next_step() -> void:
	if current_step < story_steps.size() - 1:
		current_step += 1
		_update_ui()
		
		# If we just reached the last step, show the seal
		if current_step == story_steps.size() - 1:
			_show_seal()
	else:
		# Story finished, but seal might still be there
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
	seal.visible = true
	# Set pivot to center for pop effect
	seal.pivot_offset = seal.size / 2
	seal.scale = Vector2(0.5, 0.5)
	seal.position.y += 50 # Start a bit lower to "fade up"
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(seal, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(seal, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(seal, "position:y", seal.position.y - 50, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_seal_pressed() -> void:
	seal_tap_count += 1
	
	# Feedback on tap (slight scale pulse)
	var pulse = create_tween()
	pulse.tween_property(seal_button, "scale", Vector2(1.1, 1.1), 0.05)
	pulse.tween_property(seal_button, "scale", Vector2(1.0, 1.0), 0.05)
	
	if seal_tap_count == 1:
		seal_button.texture_normal = load("res://assets/story/seal2.png")
	elif seal_tap_count == 2:
		seal_button.texture_normal = load("res://assets/story/seal3.png")
	elif seal_tap_count == 3:
		_hide_seal()

func _hide_seal() -> void:
	# Make button unclickable
	seal_button.disabled = true
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(seal, "modulate:a", 0.0, 0.3)
	tween.tween_property(seal, "scale", Vector2(1.2, 1.2), 0.3)
	tween.chain().tween_callback(func(): seal.visible = false)
	
	# After seal is gone, maybe advance to next part?
	# For now, just print
	print("Seal broken")
