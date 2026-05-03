extends Node2D

@onready var camera = $MainCamera
@onready var day_label = $CanvasLayer/HUD/DayLabel
@onready var money_label = $CanvasLayer/HUD/MoneyLabel
@onready var satisfaction_bar = $CanvasLayer/HUD/SatisfactionBarContainer/SatisfactionBar
@onready var time_label = $CanvasLayer/HUD/TimeLabel

# --- TUTORIAL NODES ---
@onready var tutorial_ui = $CanvasLayer/TutorialUI
@onready var tutorial_box = $CanvasLayer/TutorialUI/TutorialBox
@onready var tutorial_label = $CanvasLayer/TutorialUI/TutorialBox/TutorialLabel
@onready var tutorial_next_btn = $CanvasLayer/TutorialUI/TutorialBox/NextButton

@onready var issue_buttons = [
	$World/Background/IssueButton1,
	$World/Background/IssueButton2,
	$World/Background/IssueButton3,
	$World/Background/IssueButton4,
	$World/Background/IssueButton5,
	$World/Background/IssueButton6,
	$World/Background/IssueButton7,
	$World/Background/IssueButton8
]

var scroll_speed: float = 900.0
var dragging: bool = false
var last_drag_position: Vector2 = Vector2.ZERO

# --- ANIMATION & TUTORIAL VARIABLES ---
var base_positions: Array = []
var float_time: float = 0.0

enum TutorialStep { INTRO, CAMERA_MOVE, WAIT_FOR_ISSUE, CLICK_ISSUE, POST_MINIGAME, DONE }
var current_tutorial_step: TutorialStep = TutorialStep.INTRO
var initial_cam_pos: Vector2

func _ready():
	PauseMenu.pause_button.visible = true
	randomize()
	camera.position = Vector2(1532, 704)
	initial_cam_pos = camera.position
	clamp_camera()

	satisfaction_bar.min_value = 0
	satisfaction_bar.max_value = 100
	satisfaction_bar.value = GameManager.satisfaction
	satisfaction_bar.custom_minimum_size = Vector2(300, 24)

	for i in range(issue_buttons.size()):
		var btn = issue_buttons[i]
		base_positions.append(btn.position)
		btn.pivot_offset = btn.size / 2.0
		# Hide all issues initially for the tutorial
		GameManager.active_issues[i] = false 
		btn.visible = false
		if not btn.pressed.is_connected(_on_issue_clicked):
			btn.pressed.connect(_on_issue_clicked.bind(i))

	update_hud()
	
	# Connect tutorial button
	if not tutorial_next_btn.pressed.is_connected(_on_tutorial_next_pressed):
		tutorial_next_btn.pressed.connect(_on_tutorial_next_pressed)

	# Stop standard simulation timers during tutorial onboarding
	$DayTimer.stop()
	$SpawnTimer.stop()
	
	# --- CHECK IF RETURNING FROM MINIGAME ---
	if GameManager.tutorial_minigame_done:
		finish_tutorial_sequence()
	else:
		start_tutorial()

# --- TUTORIAL LOGIC ---

func start_tutorial():
	tutorial_ui.show()
	current_tutorial_step = TutorialStep.INTRO
	tutorial_label.text = "Welcome to your new Computer Shop!\nYou'll need to keep customers happy by fixing their technical issues."
	tutorial_next_btn.show()

func finish_tutorial_sequence():
	tutorial_ui.show()
	tutorial_box.show()
	current_tutorial_step = TutorialStep.POST_MINIGAME
	tutorial_label.text = "Congratulations! You fixed your first issue.\nKeep fixing issues to improve your shop and earn money!\nTap 'Next' to start your first real day."
	tutorial_next_btn.show()

func _on_tutorial_next_pressed():
	if current_tutorial_step == TutorialStep.INTRO:
		current_tutorial_step = TutorialStep.CAMERA_MOVE
		tutorial_label.text = "Swipe and drag the screen to look around your shop floor. Pinch to zoom in and out!"
		tutorial_next_btn.hide() # Hide next button; they must move the camera to progress
		
	elif current_tutorial_step == TutorialStep.WAIT_FOR_ISSUE:
		tutorial_box.hide()
		force_tutorial_issue()
		
	elif current_tutorial_step == TutorialStep.POST_MINIGAME:
		# Clean up tutorial flags and launch the real game
		GameManager.is_tutorial = false
		GameManager.tutorial_minigame_done = false
		get_tree().change_scene_to_file("res://shop_floor_scrollable.tscn")

func force_tutorial_issue():
	current_tutorial_step = TutorialStep.CLICK_ISSUE
	
	# Force spawn an issue on the first PC
	var target_index = 0
	GameManager.active_issues[target_index] = true
	var btn = issue_buttons[target_index]
	btn.visible = true

	# Pop-in animation
	btn.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Show tutorial instructions
	tutorial_box.show()
	tutorial_next_btn.hide()
	tutorial_label.text = "A CUSTOMER HAS A PROBLEM!\nTap the alert to assist them. You'll need to beat mini-games like Cable Management, Hardware Plug-in, Network Routing, or Virus Removal!"

# --- SATISFACTION BAR COLOR ---

func _get_bar_color(value: int) -> Color:
	if value > 60: return Color(0.2, 0.85, 0.3)
	elif value > 30: return Color(1.0, 0.75, 0.0)
	else: return Color(0.9, 0.15, 0.15)

func _apply_bar_style():
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = _get_bar_color(GameManager.satisfaction)
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	satisfaction_bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	satisfaction_bar.add_theme_stylebox_override("background", bg_style)
	satisfaction_bar.add_theme_color_override("font_color", Color.WHITE)

# --- ANIMATION & PROCESS LOGIC ---

func _process(delta):
	float_time += delta

	# Float active issue buttons
	for i in range(issue_buttons.size()):
		if GameManager.active_issues[i]:
			var btn = issue_buttons[i]
			btn.position.y = base_positions[i].y + (sin(float_time * 4.0 + i) * 8.0)

	# Tutorial Event Checkers
	if current_tutorial_step == TutorialStep.CAMERA_MOVE:
		if camera.position.distance_to(initial_cam_pos) > 150:
			current_tutorial_step = TutorialStep.WAIT_FOR_ISSUE
			tutorial_label.text = "Great job! Now, let's wait for a customer to need help.\nTap 'Next' to continue."
			tutorial_next_btn.show()

# --- SIMULATION LOGIC ---

func _on_day_timer_timeout():
	pass # Disabled entirely for tutorial

func _on_spawn_timer_timeout():
	pass # Disabled entirely for tutorial

func _on_issue_clicked(pc_index: int):
	if not GameManager.active_issues[pc_index]: return

	GameManager.active_issues[pc_index] = false
	GameManager.save_game()

	if current_tutorial_step == TutorialStep.CLICK_ISSUE:
		GameManager.is_tutorial = true
		# Force the cable management minigame directly for the tutorial
		get_tree().change_scene_to_file("res://cable_management_mini_game.tscn") 

func update_hud():
	day_label.text = "Day: " + str(GameManager.day)
	money_label.text = "Money: ₱" + str(GameManager.money)
	time_label.text = "Time: " + str(GameManager.time_left)
	satisfaction_bar.value = GameManager.satisfaction
	_apply_bar_style()

# --- CAMERA LOGIC ---

func _input(event):
	handle_drag_and_zoom(event)

func handle_drag_and_zoom(event):
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		dragging = event.pressed
		if dragging: 
			last_drag_position = event.position
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and dragging):
		camera.position.x -= (event.position.x - last_drag_position.x) / camera.zoom.x
		camera.position.y -= (event.position.y - last_drag_position.y) / camera.zoom.y
		last_drag_position = event.position
		clamp_camera()
	elif event is InputEventMagnifyGesture:
		var new_zoom = camera.zoom * event.factor
		camera.zoom.x = clamp(new_zoom.x, 0.5, 1.5)
		camera.zoom.y = clamp(new_zoom.y, 0.5, 1.5)
		clamp_camera()

func clamp_camera():
	var vs = get_viewport_rect().size
	var hw = (vs.x / camera.zoom.x) / 2.0
	var hh = (vs.y / camera.zoom.y) / 2.0
	if (vs.x / camera.zoom.x) > 3064.0: camera.position.x = 3064.0 / 2.0
	else: camera.position.x = clamp(camera.position.x, hw, 3064.0 - hw)
	if (vs.y / camera.zoom.y) > 1408.0: camera.position.y = 1408.0 / 2.0
	else: camera.position.y = clamp(camera.position.y, hh, 1408.0 - hh)
