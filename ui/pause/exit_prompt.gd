extends Control

signal confirmed
signal cancelled

@onready var yes_button: TextureButton = $TextureRect/Yes
@onready var no_button: TextureButton = $TextureRect/No

func _ready() -> void:
	# Connect signals
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)
	
	# Apply effects
	if GameManager.has_method("setup_button_effect"):
		GameManager.setup_button_effect(yes_button)
		GameManager.setup_button_effect(no_button)
	
	# Ensure the dimmed background fills the screen
	if has_node("DimBackground"):
		$DimBackground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _on_yes_pressed() -> void:
	confirmed.emit()
	get_tree().quit()

func _on_no_pressed() -> void:
	cancelled.emit()
	queue_free()
