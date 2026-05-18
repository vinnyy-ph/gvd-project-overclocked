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
	
	# Visual effects are now handled globally by GameManager via node_added signal

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
	get_tree().change_scene_to_file("res://ui/main_menu_v2/MainMenuV2.tscn")
