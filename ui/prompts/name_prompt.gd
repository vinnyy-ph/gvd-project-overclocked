extends Control

signal confirmed(name: String, gender: String)
signal cancelled

@onready var line_edit: LineEdit = $LineEdit
@onready var yes_button: TextureButton = $TextureRect/Yes
@onready var no_button: TextureButton = $TextureRect/No
@onready var male_btn: TextureButton = $MaleBtn
@onready var female_btn: TextureButton = $FemaleBtn

var original_y: float = 0.0
var _slide_tween: Tween
var _regex := RegEx.new()
var current_gender: String = "male"

func _ready() -> void:
	_regex.compile("^[a-zA-Z0-9_]*$")
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)
	male_btn.pressed.connect(_on_male_pressed)
	female_btn.pressed.connect(_on_female_pressed)
	
	line_edit.text_submitted.connect(_on_text_submitted)
	line_edit.text_changed.connect(_on_text_changed)
	
	line_edit.focus_entered.connect(_on_keyboard_opened)
	line_edit.focus_exited.connect(_on_keyboard_closed)
	
	original_y = position.y
	_update_gender_ui()
	
	# Ensure the background covers everything
	$DimBackground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _on_male_pressed() -> void:
	current_gender = "male"
	_update_gender_ui()

func _on_female_pressed() -> void:
	current_gender = "female"
	_update_gender_ui()

func _update_gender_ui() -> void:
	if current_gender == "male":
		male_btn.modulate = Color(1, 1, 1, 1)
		female_btn.modulate = Color(1, 1, 1, 0.4)
	else:
		male_btn.modulate = Color(1, 1, 1, 0.4)
		female_btn.modulate = Color(1, 1, 1, 1)

func grab_focus_to_edit() -> void:
	line_edit.grab_focus()

func set_initial_text(text: String) -> void:
	line_edit.text = text

func _on_text_changed(_new_text: String) -> void:
	# Reset placeholder color and text when user starts typing
	line_edit.add_theme_color_override("font_placeholder_color", Color(0, 0, 0, 0.6))
	line_edit.placeholder_text = "Input your name"

func _on_yes_pressed() -> void:
	var player_name = line_edit.text.strip_edges()
	
	if player_name == "":
		_show_error("Name required!")
		return
		
	if not _is_valid_name(player_name):
		_show_error("Alphanumeric & _ only!")
		return
		
	confirmed.emit(player_name, current_gender)
	queue_free()

func _is_valid_name(text: String) -> bool:
	return _regex.search(text) != null

func _show_error(msg: String) -> void:
	line_edit.text = ""
	line_edit.placeholder_text = msg
	line_edit.add_theme_color_override("font_placeholder_color", Color(1, 0, 0, 1)) # Red
	line_edit.grab_focus()

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
