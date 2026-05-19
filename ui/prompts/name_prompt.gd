extends Control

signal confirmed(name: String)
signal cancelled

@onready var line_edit: LineEdit = $LineEdit
@onready var yes_button: TextureButton = $TextureRect/Yes
@onready var no_button: TextureButton = $TextureRect/No

func _ready() -> void:
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)
	line_edit.text_submitted.connect(_on_text_submitted)
	
	# Ensure the background covers everything
	$DimBackground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func grab_focus_to_edit() -> void:
	line_edit.grab_focus()

func set_initial_text(text: String) -> void:
	line_edit.text = text

func _on_yes_pressed() -> void:
	confirmed.emit(line_edit.text)
	queue_free()

func _on_no_pressed() -> void:
	cancelled.emit()
	queue_free()

func _on_text_submitted(_new_text: String) -> void:
	_on_yes_pressed()
