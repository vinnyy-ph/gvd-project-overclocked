extends Control

@onready var character_rect: TextureRect = $Character
@onready var text_label: Label = $BluePanelBtn/TextContentLabel
@onready var username_label: Label = $BluePanelBtn/UsernameLabel
@onready var blue_panel_btn: TextureButton = $BluePanelBtn

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

func _ready() -> void:
	blue_panel_btn.pressed.connect(_on_next_step)
	# Set initial state
	_update_ui()

func _on_next_step() -> void:
	if current_step < story_steps.size() - 1:
		current_step += 1
		_update_ui()
	else:
		# Final step or next scene logic
		print("Story finished")

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
