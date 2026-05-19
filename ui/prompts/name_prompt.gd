extends Control

signal confirmed(name: String)
signal cancelled

@onready var line_edit: LineEdit = $LineEdit
@onready var yes_button: TextureButton = $TextureRect/Yes
@onready var no_button: TextureButton = $TextureRect/No

var original_y: float = 0.0
var _slide_tween: Tween

func _ready() -> void:
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)
	line_edit.text_submitted.connect(_on_text_submitted)
	
	line_edit.focus_entered.connect(_on_keyboard_opened)
	line_edit.focus_exited.connect(_on_keyboard_closed)
	
	original_y = position.y
	
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

# ── Mobile Keyboard Slide ─────────────────────────────────────────────────────
func _on_keyboard_opened() -> void:
	if not OS.has_feature("mobile"): return
	if _slide_tween: _slide_tween.kill()
	_slide_tween = create_tween()
	_slide_tween.tween_property(self, "position:y", original_y - 250, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_keyboard_closed() -> void:
	if not OS.has_feature("mobile"): return
	if _slide_tween: _slide_tween.kill()
	_slide_tween = create_tween()
	_slide_tween.tween_property(self, "position:y", original_y, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
