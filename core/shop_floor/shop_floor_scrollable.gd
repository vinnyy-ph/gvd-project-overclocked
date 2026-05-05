extends Node2D

@onready var camera = $MainCamera
@onready var day_label = $CanvasLayer/HUD/DayLabel
@onready var money_label = $CanvasLayer/HUD/MoneyLabel
@onready var satisfaction_bar = $CanvasLayer/HUD/SatisfactionBar
@onready var time_label = $CanvasLayer/HUD/TimeLabel

@onready var issue_buttons = [
	$World/Background/IssueButton2, # Slot 0
	$World/Background/IssueButton3, # Slot 1
	$World/Background/IssueButton4, # Slot 2
	$World/Background/IssueButton1, # Slot 3
	$World/Background/IssueButton6, # Slot 4
	$World/Background/IssueButton7, # Slot 5
	$World/Background/IssueButton8, # Slot 6
	$World/Background/IssueButton5  # Slot 7
]

var scroll_speed: float = 900.0
var dragging: bool = false
var last_drag_position: Vector2 = Vector2.ZERO

# --- ANIMATION VARIABLES ---
var base_positions: Array = []
var float_time: float = 0.0

@onready var customer_container = $World/Background/CustomerContainer
@onready var waiting_area = $World/Background/WaitingArea
@onready var customer_scene = preload("res://assets/sprites/walking_person.tscn")

var selected_customer: Customer = null
signal customer_selected(customer)

# Map slots to their chair placeholder nodes
var seat_nodes: Array = []
var seat_positions: Array = []
var issue_labels: Array = []

func _ready():
	AudioManager.play_bgm("shop")
	PauseMenu.pause_button.visible = true
	randomize()
	camera.position = Vector2(1532, 704)
	clamp_camera()

	customer_selected.connect(_on_customer_selected)

	satisfaction_bar.min_value = 0
	satisfaction_bar.max_value = 100
	satisfaction_bar.value = GameManager.satisfaction
	satisfaction_bar.custom_minimum_size = Vector2(300, 24)

	var unlocked_slots = GameManager.get_unlocked_slots()

	# Explicit mapping of logical slots to desk sprite numbers in the scene
	var slot_to_desks = {
		0: [1, 2],
		1: [3, 4],
		2: [5, 6],
		3: [7, 8],
		4: [9, 14],
		5: [10, 15],
		6: [11, 16],
		7: [12, 13]
	}
	
	# Explicit mapping of logical slots to chair placeholder nodes (TextureRects)
	var slot_to_chair_names = {
		0: "TextureRect2",
		1: "TextureRect3",
		2: "TextureRect4",
		3: "TextureRect",
		4: "TextureRect8",
		5: "TextureRect7",
		6: "TextureRect6",
		7: "TextureRect5"
	}

	seat_nodes.resize(8)
	seat_positions.resize(8)
	issue_labels.resize(8)

	# Sync visual modulation and setup target positions
	for slot_idx in range(8):
		var is_unlocked = slot_idx < unlocked_slots
		var modulate_color = Color.WHITE if is_unlocked else Color(0.2, 0.2, 0.2)
		
		# Desk visuals
		for desk_num in slot_to_desks[slot_idx]:
			var desk_node = get_node_or_null("World/Background/Desk" + str(desk_num))
			if desk_node:
				desk_node.modulate = modulate_color
				if is_unlocked:
					_setup_desk_click(desk_node, slot_idx)
		
		# Seat positions and nodes
		var chair_name = slot_to_chair_names[slot_idx]
		var chair_node = get_node_or_null("World/Background/" + chair_name)
		if chair_node:
			chair_node.visible = false
			seat_nodes[slot_idx] = chair_node
			seat_positions[slot_idx] = chair_node.global_position + (chair_node.size / 2.0)
		
		# Setup issue labels
		_setup_issue_label(slot_idx)

	for i in range(issue_buttons.size()):
		var btn = issue_buttons[i]
		base_positions.append(btn.position)
		btn.pivot_offset = btn.size / 2.0
		btn.visible = GameManager.active_issues[i] != ""
		if not btn.pressed.is_connected(_on_issue_clicked):
			btn.pressed.connect(_on_issue_clicked.bind(i))

	# --- RESTORE PERSISTED CUSTOMERS ---
	_restore_customers()
	update_hud()

func _setup_issue_label(slot_idx: int):
	var label = Label.new()
	label.name = "IssueLabel_" + str(slot_idx)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Load theme font
	var font = load("res://assets/fonts/ThaleahFat.ttf")
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 48) # Increased font size
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	
	$World/Background.add_child(label)
	label.hide()
	issue_labels[slot_idx] = label

func _restore_customers():
	for data in GameManager.persisted_customers:
		var customer = customer_scene.instantiate()
		customer_container.add_child(customer)
		customer.customer_selected.connect(_on_customer_selected)
		
		if data["state"] == Customer.State.WAITING:
			customer.global_position = data["pos"]
		elif data["state"] == Customer.State.USING_PC:
			var idx = data["pc_index"]
			customer.assign_to_pc(idx, seat_positions[idx], seat_nodes[idx], data)
	
	GameManager.persisted_customers.clear()

func _save_customers_state():
	GameManager.persisted_customers.clear()
	for child in customer_container.get_children():
		if child is Customer:
			GameManager.persisted_customers.append(child.get_data())

func _setup_desk_click(desk: Sprite2D, slot_idx: int):
	var btn = Button.new()
	btn.flat = true
	btn.name = "ClickArea"
	btn.custom_minimum_size = Vector2(200, 200)
	btn.position = -btn.custom_minimum_size / 2.0
	desk.add_child(btn)
	btn.pressed.connect(_on_desk_clicked.bind(slot_idx))

func _on_desk_clicked(slot_idx: int):
	if selected_customer != null:
		if not GameManager.occupied_slots[slot_idx]:
			var target_pos = seat_positions[slot_idx]
			var chair = seat_nodes[slot_idx]
			selected_customer.assign_to_pc(slot_idx, target_pos, chair)
			_deselect_customer()
		else:
			_show_station_occupied_feedback(slot_idx)

func _show_station_occupied_feedback(slot_idx: int):
	var label = Label.new()
	label.text = "STATION OCCUPIED!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font = load("res://assets/fonts/ThaleahFat.ttf")
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	
	$World/Background.add_child(label)
	label.global_position = seat_positions[slot_idx] + Vector2(-100, -100)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 50, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.2)
	tween.finished.connect(label.queue_free)

func _on_customer_selected(customer: Customer):
	if selected_customer == customer:
		_deselect_customer()
	else:
		_deselect_customer()
		selected_customer = customer
		selected_customer.set_selection(true)

func _deselect_customer():
	if selected_customer:
		selected_customer.set_selection(false)
		selected_customer = null

# --- ANIMATION LOGIC ---

func _process(delta):
	float_time += delta
	for i in range(issue_buttons.size()):
		var issue_path = GameManager.active_issues[i]
		if issue_path != "":
			var btn = issue_buttons[i]
			btn.visible = true
			btn.position.y = base_positions[i].y + (sin(float_time * 4.0 + i) * 8.0)
			
			var label = issue_labels[i]
			label.show()
			label.text = GameManager.get_issue_title(issue_path)
			# Center the label relative to the button and move it closer
			var label_x_offset = -150 # Adjust based on average label width
			label.global_position = btn.global_position + Vector2(label_x_offset, -45)
		else:
			issue_buttons[i].visible = false
			if issue_labels[i]: issue_labels[i].hide()
			
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
	var waiting_count = 0
	for child in customer_container.get_children():
		if child is Customer and child.current_state == Customer.State.WAITING:
			waiting_count += 1
	if waiting_count < 3:
		spawn_customer()

func spawn_customer():
	var customer = customer_scene.instantiate()
	customer_container.add_child(customer)
	var waiting_count = 0
	for child in customer_container.get_children():
		if child is Customer and child.current_state == Customer.State.WAITING:
			waiting_count += 1
	var base_pos = waiting_area.global_position
	var spacing = 180.0
	customer.global_position = base_pos + Vector2((waiting_count - 1) * spacing, 0)
	customer.customer_selected.connect(_on_customer_selected)

func _on_issue_clicked(pc_index: int):
	var issue_path = GameManager.active_issues[pc_index]
	if issue_path == "": return
	
	GameManager.active_issues[pc_index] = ""
	_save_customers_state()
	GameManager.save_game()
	get_tree().change_scene_to_file(issue_path)

func end_day():
	GameManager.persisted_customers.clear()
	GameManager.end_day()

func _get_bar_color(value: int) -> Color:
	if value > 60: return Color(0.2, 0.85, 0.3)
	elif value > 30: return Color(1.0, 0.75, 0.0)
	else: return Color(0.9, 0.15, 0.15)

func _apply_bar_style():
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = _get_bar_color(GameManager.satisfaction)
	fill_style.set_corner_radius_all(4)
	satisfaction_bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	bg_style.set_corner_radius_all(4)
	satisfaction_bar.add_theme_stylebox_override("background", bg_style)
	satisfaction_bar.add_theme_color_override("font_color", Color.WHITE)

func update_hud():
	day_label.text = "Day: " + str(GameManager.day)
	money_label.text = "Money: P" + str(GameManager.money)
	time_label.text = "Time: " + str(GameManager.time_left)
	satisfaction_bar.value = GameManager.satisfaction
	_apply_bar_style()

# --- CAMERA LOGIC ---

func _unhandled_input(event):
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
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.zoom = Vector2(max(camera.zoom.x - 0.1, 0.5), max(camera.zoom.y - 0.1, 0.5))
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if dragging: last_drag_position = event.position
		clamp_camera()
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
