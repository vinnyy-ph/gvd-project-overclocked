extends CanvasLayer

var is_paused: bool = false

@onready var dim_overlay = $DimOverlay
@onready var continue_button = $DimOverlay/PausePanel/VBoxContainer/ContinueButtonPause
@onready var quit_button = $DimOverlay/PausePanel/VBoxContainer/QuitButtonPause
@onready var pause_button = $PauseButton 

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128

	# Connect all buttons for logic
	continue_button.pressed.connect(_on_continue_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	pause_button.pressed.connect(toggle_pause) 
	
	# Connect the buttons to our new visual effects function
	setup_button_effect(continue_button)
	setup_button_effect(quit_button)
	setup_button_effect(pause_button)

	dim_overlay.visible = false

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause():
	is_paused = !is_paused
	get_tree().paused = is_paused
	dim_overlay.visible = is_paused

func _on_continue_pressed():
	toggle_pause() 

func _on_quit_pressed():
	is_paused = false
	get_tree().paused = false
	dim_overlay.visible = false
	get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn")

# ==========================================
# BUTTON PRESS EFFECTS
# ==========================================

func setup_button_effect(button: BaseButton):
	# Forces the button to scale from its center, rather than its top-left corner
	button.pivot_offset = button.size / 2.0
	
	# Hook into the raw down/up actions
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))

func _on_button_down(button: BaseButton):
	var tween = create_tween()
	# Shrink the button to 90% scale quickly when pressed
	tween.tween_property(button, "scale", Vector2(0.9, 0.9), 0.05).set_trans(Tween.TRANS_SINE)

func _on_button_up(button: BaseButton):
	var tween = create_tween()
	# Pop it back up to normal size with a snappy bounce when released
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
