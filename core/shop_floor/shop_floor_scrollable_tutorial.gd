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
	get_node_or_null("World/Background/IssueButton2"), # Slot 0
	get_node_or_null("World/Background/IssueButton3"), # Slot 1
	get_node_or_null("World/Background/IssueButton4"), # Slot 2
	get_node_or_null("World/Background/IssueButton1"), # Slot 3
	get_node_or_null("World/Background/IssueButton6"), # Slot 4
	get_node_or_null("World/Background/IssueButton7"), # Slot 5
	get_node_or_null("World/Background/IssueButton8"), # Slot 6
	get_node_or_null("World/Background/IssueButton5")  # Slot 7
]

var scroll_speed: float = 900.0
var dragging: bool = false
var last_drag_position: Vector2 = Vector2.ZERO

# --- ANIMATION & TUTORIAL VARIABLES ---
var base_positions: Array = []
var float_time: float = 0.0

enum TutorialStep { 
	INTRO, 
	CAMERA_MOVE, 
	CUSTOMER_ARRIVE,
	QUEUE_INFO,
	DRAG_INFO, 
	ASSIGN_CUSTOMER, 
	WAIT_FOR_ISSUE, 
	CLICK_ISSUE, 
	POST_MINIGAME, 
	DONE 
}
var current_tutorial_step: TutorialStep = TutorialStep.INTRO
var initial_cam_pos: Vector2

@onready var customer_container = $World/Background/CustomerContainer
@onready var waiting_area = $World/Background/CustomerWaiting

var selected_customer: Customer = null
signal customer_selected(customer)
var is_customer_dragging: bool = false

# Map slots to their desk visual nodes
var seat_nodes: Array = []
var seat_positions: Array = []
var issue_labels: Array = []

func _ready():
	AudioManager.play_bgm("shop")
	PauseMenu.pause_button.visible = true
	randomize()
	camera.position = Vector2(1532, 704)
	initial_cam_pos = camera.position
	clamp_camera()

	customer_selected.connect(_on_customer_selected)

	satisfaction_bar.min_value = 0
	satisfaction_bar.max_value = 100
	satisfaction_bar.value = GameManager.satisfaction
	satisfaction_bar.custom_minimum_size = Vector2(300, 24)

	var unlocked_slots = 1 # Force only one for the tutorial
	
	# Explicit mapping for tutorial desk setup
	var slot_to_desks = { 0: [1, 2] }
	var slot_to_chair_names = { 0: "ChairSlot0" }

	seat_nodes.resize(8)
	seat_positions.resize(8)
	issue_labels.resize(8)

	# Setup Stations
	for slot_idx in range(8):
		var is_unlocked = slot_idx < unlocked_slots
		
		# Desk visuals
		var desks = slot_to_desks.get(slot_idx, [])
		for desk_num in desks:
			var desk_node = get_node_or_null("World/Background/Desk" + str(desk_num))
			if desk_node:
				desk_node.visible = is_unlocked
				if is_unlocked:
					seat_nodes[slot_idx] = desk_node # Reference for opacity/animations
					_setup_desk_click(desk_node, slot_idx)
		
		# Position for arrival
		var chair_name = slot_to_chair_names.get(slot_idx, "")
		var chair_node = get_node_or_null("World/Background/" + chair_name) if chair_name != "" else null
		if chair_node:
			chair_node.visible = false
			# Store the chair itself as the target node for assignment visuals
			# But we'll use its position for the customer snap
			seat_positions[slot_idx] = chair_node.global_position + (chair_node.size / 2.0)
		
		_setup_issue_label(slot_idx)
		_update_desk_visuals(slot_idx)

	# Setup Issue Buttons
	for i in range(issue_buttons.size()):
		var btn = issue_buttons[i]
		if btn:
			base_positions.append(btn.position)
			btn.pivot_offset = btn.size / 2.0
			btn.visible = GameManager.active_issues[i] != ""
			if not btn.pressed.is_connected(_on_issue_clicked):
				btn.pressed.connect(_on_issue_clicked.bind(i))
		else:
			base_positions.append(Vector2.ZERO)

	# --- HIDE TEMPLATE ---
	if waiting_area:
		waiting_area.visible = false
		waiting_area.process_mode = PROCESS_MODE_DISABLED

	_restore_customers()
	update_hud()
	
	if not tutorial_next_btn.pressed.is_connected(_on_tutorial_next_pressed):
		tutorial_next_btn.pressed.connect(_on_tutorial_next_pressed)

	$DayTimer.stop()
	$SpawnTimer.stop()
	
	if GameManager.tutorial_minigame_done:
		finish_tutorial_sequence()
	elif GameManager.tutorial_minigame_index > 0:
		resume_minigame_sequence()
	else:
		start_tutorial()

func _update_desk_visuals(slot_idx: int):
	var desk = seat_nodes[slot_idx]
	if not desk: return
	
	var is_occupied = GameManager.occupied_slots[slot_idx]
	# Aesthetic rule: 1.0 if busy, 0.8 if free
	desk.modulate.a = 1.0 if is_occupied else 0.8

func resume_minigame_sequence():
	tutorial_ui.show()
	tutorial_box.show()
	current_tutorial_step = TutorialStep.WAIT_FOR_ISSUE
	var progress = GameManager.tutorial_minigame_index
	var total = GameManager.ALL_MINIGAMES.size()
	tutorial_label.text = "Great job! You've fixed " + str(progress) + " of " + str(total) + " issues.\nLet's try another one!\nTap 'Next' to continue."
	tutorial_next_btn.show()

func _setup_issue_label(slot_idx: int):
	var label = Label.new()
	label.name = "IssueLabel_" + str(slot_idx)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font = load("res://assets/fonts/ThaleahFat.ttf")
	if font: label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	$World/Background.add_child(label)
	label.hide()
	issue_labels[slot_idx] = label

func _restore_customers():
	for data in GameManager.persisted_customers:
		var customer = waiting_area.duplicate()
		customer_container.add_child(customer)
		customer.process_mode = PROCESS_MODE_INHERIT
		customer.visible = true
		
		customer.customer_selected.connect(_on_customer_selected)
		customer.drag_started.connect(_on_customer_drag_started)
		customer.drag_ended.connect(_on_customer_drag_ended)
		
		if data["state"] == Customer.State.WAITING:
			customer.global_position = data["pos"]
		elif data["state"] == Customer.State.USING_PC:
			var idx = data["pc_index"]
			if idx < seat_positions.size():
				var chair = get_node_or_null("World/Background/ChairSlot" + str(idx))
				customer.assign_to_pc(idx, seat_positions[idx], chair, data)
				_update_desk_visuals(idx)
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

func _on_desk_clicked(slot_idx: int, customer: Customer = null):
	var target_customer = customer if customer else selected_customer
	if target_customer != null:
		if slot_idx < GameManager.occupied_slots.size() and not GameManager.occupied_slots[slot_idx]:
			var target_pos = seat_positions[slot_idx]
			var chair = get_node_or_null("World/Background/ChairSlot" + str(slot_idx))
			
			target_customer.assign_to_pc(slot_idx, target_pos, chair)
			_show_station_assigned_feedback(slot_idx)
			AudioManager.play_sfx("assign")
			_update_desk_visuals(slot_idx)
			
			if target_customer == selected_customer:
				_deselect_customer()
			
			if current_tutorial_step == TutorialStep.ASSIGN_CUSTOMER:
				current_tutorial_step = TutorialStep.WAIT_FOR_ISSUE
				tutorial_label.text = "Success! The customer is now generating money every 2 seconds.\nNotice the PC is now fully opaque. Let's wait for a technical issue..."
				tutorial_next_btn.show()
		else:
			_show_station_occupied_feedback(slot_idx)

func _show_station_occupied_feedback(slot_idx: int):
	var label = Label.new()
	label.text = "STATION OCCUPIED!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font = load("res://assets/fonts/ThaleahFat.ttf")
	if font: label.add_theme_font_override("font", font)
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

func _show_station_assigned_feedback(slot_idx: int):
	var label = Label.new()
	label.text = "STATION ASSIGNED!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font = load("res://assets/fonts/ThaleahFat.ttf")
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	
	$World/Background.add_child(label)
	label.global_position = seat_positions[slot_idx] + Vector2(-150, -120)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 60, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.2)
	tween.finished.connect(label.queue_free)

func _on_customer_selected(customer: Customer):
	if selected_customer == customer:
		_deselect_customer()
	else:
		_deselect_customer()
		selected_customer = customer
		selected_customer.set_selection(true)
		if current_tutorial_step == TutorialStep.ASSIGN_CUSTOMER:
			tutorial_label.text = "Customer selected! Now drag them to the PC slot."

func _deselect_customer():
	if selected_customer:
		selected_customer.set_selection(false)
		selected_customer = null

func _on_customer_drag_started(_customer: Customer):
	is_customer_dragging = true

func _on_customer_drag_ended(customer: Customer, _global_pos: Vector2):
	is_customer_dragging = false
	var best_dist = 180.0
	var best_slot = -1
	var drop_point = customer.global_position
	
	# Only slot 0 is unlocked in tutorial
	for i in range(1):
		var desk = seat_nodes[i]
		if not desk: continue
		if GameManager.occupied_slots[i]: continue
		
		var dist = drop_point.distance_to(desk.global_position)
		if dist < best_dist:
			best_dist = dist
			best_slot = i
			
	if best_slot != -1:
		_on_desk_clicked(best_slot, customer)
		_refresh_queue_positions()
	else:
		customer.return_to_waiting_position()

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
		tutorial_next_btn.hide()
	elif current_tutorial_step == TutorialStep.CUSTOMER_ARRIVE:
		spawn_customer()
		current_tutorial_step = TutorialStep.QUEUE_INFO
		tutorial_label.text = "A customer has arrived! Notice they wait at the front of the line.\nYou must manage the queue in order—only the first person in line can be dragged!"
		tutorial_next_btn.show()
	elif current_tutorial_step == TutorialStep.QUEUE_INFO:
		current_tutorial_step = TutorialStep.DRAG_INFO
		tutorial_label.text = "Drag the customer to the PC slot. While they use the computer, they'll generate P1 every 2 seconds automatically!"
		tutorial_next_btn.hide()
	elif current_tutorial_step == TutorialStep.WAIT_FOR_ISSUE:
		tutorial_box.hide()
		force_tutorial_issue()
	elif current_tutorial_step == TutorialStep.POST_MINIGAME:
		GameManager.is_tutorial = false
		GameManager.tutorial_minigame_done = false
		GameManager.tutorial_minigame_index = 0
		get_tree().change_scene_to_file("res://core/shop_floor/shop_floor_scrollable.tscn")

func force_tutorial_issue():
	current_tutorial_step = TutorialStep.CLICK_ISSUE
	var target_index = 0
	
	var issue_path = "res://minigames/cable_management/cable_management_mini_game.tscn"
	if GameManager.tutorial_minigame_index < GameManager.ALL_MINIGAMES.size():
		issue_path = GameManager.ALL_MINIGAMES[GameManager.tutorial_minigame_index]
	
	GameManager.active_issues[target_index] = issue_path
	var btn = issue_buttons[target_index]
	if btn:
		btn.visible = true
		btn.scale = Vector2.ZERO
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	
	tutorial_box.show()
	tutorial_next_btn.hide()
	var issue_name = GameManager.get_issue_title(issue_path)
	tutorial_label.text = "OH NO! THE CUSTOMER HAS A " + issue_name.to_upper() + "!\nTap the red alert icon above them to start the repair."

func spawn_customer():
	var waiting_count = 0
	for child in customer_container.get_children():
		if child is Customer and child.current_state == Customer.State.WAITING:
			waiting_count += 1
			
	var customer = waiting_area.duplicate()
	customer_container.add_child(customer)
	customer_container.move_child(customer, 0)
	
	customer.process_mode = PROCESS_MODE_INHERIT
	customer.visible = true
	
	customer.customer_selected.connect(_on_customer_selected)
	customer.drag_started.connect(_on_customer_drag_started)
	customer.drag_ended.connect(_on_customer_drag_ended)
	
	if waiting_area:
		customer.global_position = waiting_area.global_position + Vector2(waiting_count * -70, waiting_count * -50)
		AudioManager.play_sfx("spawn")
		var final_scale = customer.scale
		customer.scale = Vector2.ZERO
		var tween = create_tween()
		tween.tween_property(customer, "scale", final_scale, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _refresh_queue_positions():
	var waiting_customers = []
	for child in customer_container.get_children():
		if child is Customer and child.current_state == Customer.State.WAITING:
			waiting_customers.append(child)
	waiting_customers.reverse()
	for i in range(waiting_customers.size()):
		var c = waiting_customers[i]
		var target_pos = waiting_area.global_position + Vector2(i * -70, i * -50)
		if c.global_position != target_pos:
			var tween = create_tween()
			tween.tween_property(c, "global_position", target_pos, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func is_first_in_line(customer: Customer) -> bool:
	var waiting_customers = []
	for child in customer_container.get_children():
		if child is Customer and child.current_state == Customer.State.WAITING:
			waiting_customers.append(child)
	if waiting_customers.size() > 0:
		return waiting_customers[waiting_customers.size() - 1] == customer
	return false

func show_queue_warning(pos: Vector2):
	var label = Label.new()
	label.text = "WAIT YOUR TURN!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font = load("res://assets/fonts/ThaleahFat.ttf")
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 35)
	label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.custom_minimum_size = Vector2(400, 0)
	$World/Background.add_child(label)
	label.global_position = pos + Vector2(-200, -180)
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 40, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.finished.connect(label.queue_free)

func _on_issue_clicked(pc_index: int):
	var issue_path = GameManager.active_issues[pc_index]
	if issue_path == "": return
	GameManager.active_issues[pc_index] = ""
	_save_customers_state()
	GameManager.save_game()
	if current_tutorial_step == TutorialStep.CLICK_ISSUE:
		GameManager.is_tutorial = true
		get_tree().change_scene_to_file(issue_path)

func update_hud():
	day_label.text = "Day: " + str(GameManager.day)
	money_label.text = "Money: ₱" + str(GameManager.money)
	if GameManager.money <= 0:
		money_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		money_label.remove_theme_color_override("font_color")
	time_label.text = "Time: " + str(GameManager.time_left)
	satisfaction_bar.value = GameManager.satisfaction
	_apply_bar_style()

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

func _process(delta):
	float_time += delta
	for i in range(issue_buttons.size()):
		var btn = issue_buttons[i]
		if not btn: continue
		
		var issue_path = GameManager.active_issues[i]
		if issue_path != "":
			btn.visible = true
			btn.position.y = base_positions[i].y + (sin(float_time * 4.0 + i) * 8.0)
			var label = issue_labels[i]
			if label:
				label.show()
				label.text = GameManager.get_issue_title(issue_path)
				label.global_position = btn.global_position + Vector2(-150, -45)
		else:
			btn.visible = false
			if issue_labels[i]: issue_labels[i].hide()

	if current_tutorial_step == TutorialStep.CAMERA_MOVE:
		if camera.position.distance_to(initial_cam_pos) > 150:
			current_tutorial_step = TutorialStep.CUSTOMER_ARRIVE
			tutorial_label.text = "Great job! Now, let's wait for a customer to arrive.\nTap 'Next' to continue."
			tutorial_next_btn.show()

func _unhandled_input(event):
	handle_drag_and_zoom(event)

func handle_drag_and_zoom(event):
	if is_customer_dragging: return
	
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		dragging = event.pressed
		if dragging: last_drag_position = event.position
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
