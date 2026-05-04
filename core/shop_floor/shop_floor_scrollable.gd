extends Node2D

@onready var camera = $MainCamera
@onready var day_label = $CanvasLayer/HUD/DayLabel
@onready var money_label = $CanvasLayer/HUD/MoneyLabel
@onready var satisfaction_bar = $CanvasLayer/HUD/SatisfactionBar
@onready var time_label = $CanvasLayer/HUD/TimeLabel

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

# --- ANIMATION VARIABLES ---
var base_positions: Array = []
var float_time: float = 0.0

func _ready():
	AudioManager.play_bgm("shop")
	PauseMenu.pause_button.visible = true
	randomize()
	camera.position = Vector2(1532, 704)
	clamp_camera()

	satisfaction_bar.min_value = 0
	satisfaction_bar.max_value = 100
	satisfaction_bar.value = GameManager.satisfaction
	satisfaction_bar.custom_minimum_size = Vector2(300, 24)

	var unlocked_slots = 2 + SaveManager.unlocked_upgrades.get("shop_space", 0)

	# Handle 16 desks (even though we only have 8 issue buttons for now)
	for i in range(16):
		var desk_node = get_node_or_null("World/Background/Desk" + str(i+1))
		if desk_node:
			if i < unlocked_slots:
				desk_node.modulate = Color.WHITE
			else:
				desk_node.modulate = Color(0.2, 0.2, 0.2)

	for i in range(issue_buttons.size()):
		var btn = issue_buttons[i]
		base_positions.append(btn.position)
		btn.pivot_offset = btn.size / 2.0
		
		if i < unlocked_slots:
			btn.visible = GameManager.active_issues[i]
		else:
			btn.visible = false
			GameManager.active_issues[i] = false

		if not btn.pressed.is_connected(_on_issue_clicked):
			btn.pressed.connect(_on_issue_clicked.bind(i))

	update_hud()

# --- SATISFACTION BAR COLOR ---

func _get_bar_color(value: int) -> Color:
	if value > 60:
		return Color(0.2, 0.85, 0.3)
	elif value > 30:
		return Color(1.0, 0.75, 0.0)
	else:
		return Color(0.9, 0.15, 0.15)

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

# --- ANIMATION LOGIC ---

func _process(delta):
	float_time += delta

	for i in range(issue_buttons.size()):
		if GameManager.active_issues[i]:
			var btn = issue_buttons[i]
			btn.position.y = base_positions[i].y + (sin(float_time * 4.0 + i) * 8.0)

	handle_keyboard_scroll(delta)

# --- SIMULATION LOGIC ---

func _on_day_timer_timeout():
	if GameManager.time_left > 0:
		GameManager.time_left -= 1
		update_hud()
		if GameManager.time_left <= 0:
			end_day()

func _on_spawn_timer_timeout():
	if GameManager.time_left <= 0: return
	
	# Only spawn if RNG rolls below the modifier
	if randf() > GameManager.get_issue_spawn_chance_modifier():
		return

	var unlocked_slots = 2 + SaveManager.unlocked_upgrades.get("shop_space", 0)
	var inactive_indices = []
	for i in range(unlocked_slots):
		if not GameManager.active_issues[i]:
			inactive_indices.append(i)

	if inactive_indices.size() > 0:
		AudioManager.play_sfx("alert")
		var random_index = inactive_indices[randi() % inactive_indices.size()]
		GameManager.active_issues[random_index] = true

		var btn = issue_buttons[random_index]
		btn.visible = true

		btn.scale = Vector2.ZERO
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)

func _on_issue_clicked(pc_index: int):
	if not GameManager.active_issues[pc_index]: return

	GameManager.active_issues[pc_index] = false
	GameManager.save_game()

	get_tree().change_scene_to_file(GameManager.get_next_minigame())

func end_day():
	GameManager.end_day()

func update_hud():
	day_label.text = "Day: " + str(GameManager.day)
	money_label.text = "Money: P" + str(GameManager.money)
	time_label.text = "Time: " + str(GameManager.time_left)
	satisfaction_bar.value = GameManager.satisfaction
	_apply_bar_style()

# --- CAMERA LOGIC ---

func _input(event):
	handle_drag_and_zoom(event)

func handle_keyboard_scroll(delta):
	var move_dir := Vector2.ZERO
	if Input.is_action_pressed("ui_left"): move_dir.x -= 1.0
	if Input.is_action_pressed("ui_right"): move_dir.x += 1.0
	if Input.is_action_pressed("ui_up"): move_dir.y -= 1.0
	if Input.is_action_pressed("ui_down"): move_dir.y += 1.0
	if move_dir != Vector2.ZERO:
		move_dir = move_dir.normalized()
		camera.position += move_dir * scroll_speed * delta
		clamp_camera()

func handle_drag_and_zoom(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.zoom = Vector2(min(camera.zoom.x + 0.1, 1.5), min(camera.zoom.y + 0.1, 1.5))
			clamp_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.zoom = Vector2(max(camera.zoom.x - 0.1, 0.5), max(camera.zoom.y - 0.1, 0.5))
			clamp_camera()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if dragging: last_drag_position = event.position
	elif event is InputEventMagnifyGesture:
		var new_zoom = camera.zoom * event.factor
		camera.zoom.x = clamp(new_zoom.x, 0.5, 1.5)
		camera.zoom.y = clamp(new_zoom.y, 0.5, 1.5)
		clamp_camera()
	elif event is InputEventMouseMotion and dragging:
		camera.position.x -= (event.position.x - last_drag_position.x) / camera.zoom.x
		camera.position.y -= (event.position.y - last_drag_position.y) / camera.zoom.y
		last_drag_position = event.position
		clamp_camera()
	elif event is InputEventScreenTouch:
		dragging = event.pressed
		if dragging: last_drag_position = event.position
	elif event is InputEventScreenDrag and dragging:
		camera.position.x -= (event.position.x - last_drag_position.x) / camera.zoom.x
		camera.position.y -= (event.position.y - last_drag_position.y) / camera.zoom.y
		last_drag_position = event.position
		clamp_camera()

func clamp_camera():
	var vs = get_viewport_rect().size
	var hw = (vs.x / camera.zoom.x) / 2.0
	var hh = (vs.y / camera.zoom.y) / 2.0
	if (vs.x / camera.zoom.x) > 3064.0: camera.position.x = 3064.0 / 2.0
	else: camera.position.x = clamp(camera.position.x, hw, 3064.0 - hw)
	if (vs.y / camera.zoom.y) > 1408.0: camera.position.y = 1408.0 / 2.0
	else: camera.position.y = clamp(camera.position.y, hh, 1408.0 - hh)
