extends Node2D

@onready var camera = $MainCamera
@onready var day_label = $CanvasLayer/HUD/DayLabel
@onready var money_label = $CanvasLayer/HUD/MoneyLabel
@onready var satisfaction_bar = $CanvasLayer/HUD/SatisfactionBar
@onready var time_label = $CanvasLayer/HUD/TimeLabel

# --- TUTORIAL NODES ---
@onready var tutorial_ui = $CanvasLayer/TutorialUI
@onready var tutorial_box = $CanvasLayer/TutorialUI/TutorialBox
@onready var tutorial_label = $CanvasLayer/TutorialUI/TutorialBox/TutorialLabel
@onready var tutorial_next_btn = $CanvasLayer/TutorialUI/TutorialBox/NextButton

@onready var issue_buttons: Array = []

var scroll_speed: float = 900.0
var dragging: bool = false
var last_drag_position: Vector2 = Vector2.ZERO

# --- MOBILE CAMERA VARIABLES ---
var touches: Dictionary = {}
var last_pinch_distance: float = -1.0
var min_zoom: float = 0.5
var max_zoom: float = 1.5
const SCENE_SIZE = Vector2(3064.0, 1408.0)

# --- ANIMATION & TUTORIAL VARIABLES ---
var base_positions: Array = []
var float_time: float = 0.0

enum TutorialStep { 
	INTRO, 
	HUD_TIME,
	HUD_DAY,
	HUD_MONEY,
	HUD_SATISFACTION,
	SHOP_DESK,
	SHOP_WAITING,
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

@onready var tutorial_dim = $CanvasLayer/TutorialUI/TutorialDim
@onready var satisfaction_bar_rect = $CanvasLayer/HUD/TextureRect

@onready var customer_container = $World/Background
@onready var waiting_area = $World/Background/CustomerWaiting

var highlighted_node: CanvasItem = null

func _highlight_node(node: CanvasItem, enabled: bool):
	if enabled:
		highlighted_node = node
		tutorial_dim.show()
		_update_highlight_shader()
	else:
		highlighted_node = null
		tutorial_dim.hide()

func _get_node_screen_rect(node: CanvasItem) -> Rect2:
	if not node: return Rect2()
	var rect = Rect2()
	var canvas_transform = node.get_global_transform_with_canvas()
	if node is Control:
		rect.position = canvas_transform.get_origin()
		rect.size = node.size * canvas_transform.get_scale()
	elif node is Sprite2D:
		if node.texture:
			var tex_size = node.texture.get_size()
			rect.size = tex_size * canvas_transform.get_scale()
			if node.centered:
				rect.position = canvas_transform.get_origin() - (rect.size / 2.0)
			else:
				rect.position = canvas_transform.get_origin()
	elif node is Button: # Sometimes identified as Button even if also Control
		rect.position = canvas_transform.get_origin()
		rect.size = node.size * canvas_transform.get_scale()
	return rect

func _update_highlight_shader():
	if not highlighted_node or not tutorial_dim.material: return
	
	var rect = _get_node_screen_rect(highlighted_node)
	# Add a small margin
	rect = rect.grow(10.0)
	
	var mat = tutorial_dim.material as ShaderMaterial
	mat.set_shader_parameter("hole_center", rect.get_center())
	mat.set_shader_parameter("hole_size", rect.size)

var selected_customer: Customer = null
signal customer_selected(customer)
var is_customer_dragging: bool = false

# Map slots to their desk visual nodes
var seat_nodes: Array = []
var seat_positions: Array = []
var issue_labels: Array = []
var original_issue_scales: Array = []

# Texture constants
const EMPTY_7 = preload("res://assets/images/shop_floor/empty_slot.png")
const OCCUPIED_7 = preload("res://assets/images/shop_floor/occupied_slot.png")
const EMPTY_13 = preload("res://assets/images/shop_floor/empty_slot_front.png")
const OCCUPIED_13 = preload("res://assets/images/shop_floor/occupied_slot_front.png")

const ANGRY_TEX = preload("res://assets/images/shop_floor/emotions/angry.png")
const HAPPY_TEX = preload("res://assets/images/shop_floor/emotions/happy.png")

func _ready():
	AudioManager.play_bgm("shop")
	PauseMenu.pause_button.visible = true
	randomize()
	
	# Initial camera setup
	camera.position = Vector2(1532, 704)
	initial_cam_pos = camera.position
	
	# Calculate dynamic min zoom to show the whole scene on any screen
	var vs = get_viewport_rect().size
	min_zoom = min(vs.x / SCENE_SIZE.x, vs.y / SCENE_SIZE.y)
	camera.zoom = Vector2(max(min_zoom, 0.5), max(min_zoom, 0.5))
	
	clamp_camera()

	customer_selected.connect(_on_customer_selected)

	satisfaction_bar.min_value = 0
	satisfaction_bar.max_value = 100
	satisfaction_bar.value = GameManager.satisfaction
	satisfaction_bar.custom_minimum_size = Vector2(300, 24)
	
	GameManager.money_changed_visual.connect(spawn_floating_money)
	GameManager.satisfaction_changed_visual.connect(spawn_floating_satisfaction)
	
	# Setup highlight shader
	var shader = load("res://core/shop_floor/tutorial_mask.gdshader")
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		tutorial_dim.material = mat

	var unlocked_slots = 1 # Force only one for the tutorial
	
	seat_nodes.resize(unlocked_slots)
	seat_positions.resize(unlocked_slots)
	issue_labels.resize(unlocked_slots)
	issue_buttons.resize(unlocked_slots)
	base_positions.resize(unlocked_slots)
	original_issue_scales.resize(unlocked_slots)

	# Setup Stations
	for slot_idx in range(unlocked_slots):
		var desk_num = slot_idx + 1
		var is_unlocked = true # In tutorial, slot 0 is always unlocked
		
		# Desk visuals - Updated path to World/Background/Sprite2D/Desk1
		var desk_node = get_node_or_null("World/Background/Sprite2D/Desk" + str(desk_num))
		if desk_node:
			desk_node.visible = is_unlocked
			seat_nodes[slot_idx] = desk_node
			seat_positions[slot_idx] = desk_node.global_position
			_setup_desk_click(desk_node, slot_idx)
			
			var btn = desk_node.get_node_or_null("Desk" + str(desk_num) + "IssueButton")
			if btn:
				issue_buttons[slot_idx] = btn
				base_positions[slot_idx] = btn.position
				original_issue_scales[slot_idx] = btn.scale
				btn.pivot_offset = btn.size / 2.0
				btn.visible = GameManager.active_issues[slot_idx] != ""
				if not btn.pressed.is_connected(_on_issue_clicked):
					btn.pressed.connect(_on_issue_clicked.bind(slot_idx))
		
		_setup_issue_label(slot_idx)
		_update_desk_texture(slot_idx)

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

func _update_desk_texture(slot_idx: int):
	var desk = seat_nodes[slot_idx]
	if not desk: return
	
	var desk_num = slot_idx + 1
	var is_occupied = GameManager.occupied_slots[slot_idx]
	
	# Match main shop floor logic for desk texture swapping
	if desk_num <= 7:
		desk.texture = OCCUPIED_7 if is_occupied else EMPTY_7
	else:
		desk.texture = OCCUPIED_13 if is_occupied else EMPTY_13
	
	# Static opacity indication: 1.0 if busy, 0.8 if free
	desk.modulate.a = 1.0 if is_occupied else 0.8

	# Handle Emotion Particles
	var particles = desk.get_node_or_null("EmotionParticles")
	if particles:
		particles.emitting = is_occupied
		if is_occupied:
			var has_issue = GameManager.active_issues[slot_idx] != ""
			particles.texture = ANGRY_TEX if has_issue else HAPPY_TEX

func _connect_customer_signals(customer: Customer, slot_idx: int):
	if not customer.arrived_at_pc.is_connected(_update_desk_texture):
		customer.arrived_at_pc.connect(_update_desk_texture.bind(slot_idx))
	if not customer.exited_pc.is_connected(_update_desk_texture):
		customer.exited_pc.connect(_update_desk_texture.bind(slot_idx))

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
		
		customer.customer_selected_signal.connect(_on_customer_selected)
		customer.drag_started.connect(_on_customer_drag_started)
		customer.drag_ended.connect(_on_customer_drag_ended)
		
		var pos = Vector2.ZERO
		if data.has("pos_x") and data.has("pos_y"):
			pos = Vector2(data["pos_x"], data["pos_y"])
		elif data.has("pos") and typeof(data["pos"]) == TYPE_STRING:
			var parts = data["pos"].replace("(", "").replace(")", "").split(",")
			if parts.size() == 2:
				pos = Vector2(parts[0].to_float(), parts[1].to_float())
		elif data.has("pos") and typeof(data["pos"]) == TYPE_VECTOR2:
			pos = data["pos"]
		
		if data["state"] == Customer.State.WAITING:
			customer.global_position = pos
		elif data["state"] == State.USING_PC:
			var idx = data["pc_index"]
			if idx < seat_nodes.size():
				_connect_customer_signals(customer, idx)
				customer.assign_to_pc(idx, seat_positions[idx], seat_nodes[idx], data)
				_update_desk_texture(idx)
	GameManager.persisted_customers.clear()

func save_state():
	_save_customers_state()

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
			var desk = seat_nodes[slot_idx]
			
			_connect_customer_signals(target_customer, slot_idx)
			target_customer.assign_to_pc(slot_idx, target_pos, desk)
			_show_station_assigned_feedback(slot_idx)
			AudioManager.play_sfx("assign")
			# No need to manually update visuals, signals handle it
			
			if highlighted_node: _highlight_node(highlighted_node, false)

			if target_customer == selected_customer:
				_deselect_customer()
			
			if current_tutorial_step == TutorialStep.ASSIGN_CUSTOMER:
				current_tutorial_step = TutorialStep.WAIT_FOR_ISSUE
				tutorial_label.text = "Success! The customer is now generating money every 2 seconds.\nNotice the PC is now fully opaque and the texture has changed. Let's wait for a technical issue..."
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
	
	# Check all desks for proximity to trigger assignment OR occupancy feedback
	for i in range(seat_nodes.size()):
		var desk = seat_nodes[i]
		if not desk: continue
		
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
	# Clear previous highlights
	if highlighted_node: _highlight_node(highlighted_node, false)

	if current_tutorial_step == TutorialStep.INTRO:
		current_tutorial_step = TutorialStep.HUD_TIME
		_highlight_node(time_label, true)
		tutorial_label.text = "This is the current TIME. Each day lasts for a limited duration. Manage your tasks efficiently!"
		tutorial_next_btn.show()
	elif current_tutorial_step == TutorialStep.HUD_TIME:
		current_tutorial_step = TutorialStep.HUD_DAY
		_highlight_node(day_label, true)
		tutorial_label.text = "This shows the current DAY. As you progress, more customers will arrive and new challenges will appear."
	elif current_tutorial_step == TutorialStep.HUD_DAY:
		current_tutorial_step = TutorialStep.HUD_MONEY
		_highlight_node(money_label, true)
		tutorial_label.text = "This is your total MONEY. You earn money by serving customers and fixing their issues. Don't go broke!"
	elif current_tutorial_step == TutorialStep.HUD_MONEY:
		current_tutorial_step = TutorialStep.HUD_SATISFACTION
		_highlight_node(satisfaction_bar, true)
		tutorial_label.text = "This is the SATISFACTION bar. If it reaches zero, it's Game Over! Keep it high by fixing issues quickly."
	elif current_tutorial_step == TutorialStep.HUD_SATISFACTION:
		current_tutorial_step = TutorialStep.SHOP_DESK
		_highlight_node(seat_nodes[0], true)
		tutorial_label.text = "This is a COMPUTER STATION. You'll assign customers here. Unlocked stations appear bright, while locked ones are dark."
	elif current_tutorial_step == TutorialStep.SHOP_DESK:
		current_tutorial_step = TutorialStep.SHOP_WAITING
		_highlight_node(waiting_area, true)
		waiting_area.visible = true # Temporarily show to explain
		tutorial_label.text = "This is the WAITING AREA. Customers will line up here. Only the customer at the front can be dragged!"
	elif current_tutorial_step == TutorialStep.SHOP_WAITING:
		waiting_area.visible = false # Hide back
		current_tutorial_step = TutorialStep.CAMERA_MOVE
		tutorial_label.text = "Swipe and drag the screen to look around your shop floor. Pinch to zoom in and out!"
		tutorial_next_btn.hide()
	elif current_tutorial_step == TutorialStep.CUSTOMER_ARRIVE:
		spawn_customer()
		spawn_customer()
		spawn_customer()
		current_tutorial_step = TutorialStep.QUEUE_INFO
		tutorial_label.text = "A line of customers has arrived! Notice they wait at the front of the line.\nYou must manage the queue in order—only the first person in line can be dragged!"
		tutorial_next_btn.show()
	elif current_tutorial_step == TutorialStep.QUEUE_INFO:
		current_tutorial_step = TutorialStep.DRAG_INFO
		tutorial_label.text = "Drag the customer to the PC slot. While they use the computer, they'll generate P1 every 2 seconds automatically!"
		tutorial_next_btn.show()
	elif current_tutorial_step == TutorialStep.DRAG_INFO:
		current_tutorial_step = TutorialStep.ASSIGN_CUSTOMER
		# Highlight both the first customer and the desk
		var waiting_customers = []
		for child in customer_container.get_children():
			if child is Customer and child.current_state == State.WAITING and child != waiting_area:
				waiting_customers.append(child)
		if waiting_customers.size() > 0:
			_highlight_node(waiting_customers[waiting_customers.size()-1], true)
		
		tutorial_label.text = "Now try it! Drag the first customer in line to the PC slot."
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
		var target_scale = original_issue_scales[target_index]
		btn.visible = true
		btn.scale = Vector2.ZERO
		var tween = create_tween()
		tween.tween_property(btn, "scale", target_scale * 1.2, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "scale", target_scale, 0.1)
		
		# Highlight the issue button
		_highlight_node(btn, true)
	
	tutorial_box.show()
	tutorial_next_btn.hide()
	var issue_name = GameManager.get_issue_title(issue_path)
	tutorial_label.text = "OH NO! THE CUSTOMER HAS A " + issue_name.to_upper() + "!\nTap the red alert icon above them to start the repair."

func spawn_customer():
	var waiting_count = 0
	for child in customer_container.get_children():
		if child is Customer and child.current_state == State.WAITING and child != waiting_area:
			waiting_count += 1
			
	var customer = waiting_area.duplicate()
	customer_container.add_child(customer)
	# Insert newest customer at index 1 (after the environment sprite)
	# This keeps them drawn behind older ones but in front of background
	customer_container.move_child(customer, 1)
	
	customer.process_mode = PROCESS_MODE_INHERIT
	customer.visible = true
	
	customer.customer_selected_signal.connect(_on_customer_selected)
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
		if child is Customer and child.current_state == State.WAITING and child != waiting_area:
			waiting_customers.append(child)
	# Order in children list is newest to oldest due to move_child(1)
	# So reverse gives oldest to newest
	waiting_customers.reverse()
	for i in range(waiting_customers.size()):
		var c = waiting_customers[i]
		var target_pos = waiting_area.global_position + Vector2(i * -70, i * -50)
		if c.global_position != target_pos:
			var tween = create_tween()
			tween.tween_property(c, "global_position", target_pos, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func is_first_in_line(customer: Customer) -> bool:
	# Block dragging entirely if we haven't reached the assignment part of the tutorial
	if current_tutorial_step < TutorialStep.ASSIGN_CUSTOMER:
		return false
		
	var waiting_customers = []
	for child in customer_container.get_children():
		if child is Customer and child.current_state == State.WAITING and child != waiting_area:
			waiting_customers.append(child)
	# Oldest (first in line) is at the end of the array due to move_child(1) logic
	if waiting_customers.size() > 0:
		return waiting_customers[waiting_customers.size() - 1] == customer
	return false

func show_queue_warning(pos: Vector2):
	var label = Label.new()
	if current_tutorial_step < TutorialStep.ASSIGN_CUSTOMER:
		label.text = "NOT YET!"
	else:
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
	# Clear highlight if any
	if highlighted_node: _highlight_node(highlighted_node, false)
	
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
	money_label.text = "Money: P" + str(GameManager.money)
	if GameManager.money <= 0:
		money_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		money_label.remove_theme_color_override("font_color")
	time_label.text = GameManager.get_formatted_time()
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

func spawn_floating_money(amount: int, start_pos: Vector2):
	var spawn_pos = start_pos
	if start_pos == Vector2.ZERO:
		var cashier = get_node_or_null("World/Background/CashierPerson")
		if cashier:
			spawn_pos = cashier.global_position + Vector2(0, -100)
		else:
			spawn_pos = camera.global_position # Fallback
			
	var label = Label.new()
	var text_prefix = "+" if amount > 0 else ""
	label.text = text_prefix + "P" + str(amount)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font = load("res://assets/fonts/ThaleahFat.ttf")
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 45)
	
	var color = Color(1.0, 0.9, 0.2) if amount > 0 else Color(1.0, 0.3, 0.3)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	
	$World/Background.add_child(label)
	label.global_position = spawn_pos + Vector2(-50, -50)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 120, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.2).set_delay(0.4)
	tween.finished.connect(label.queue_free)

func spawn_floating_satisfaction(amount: int, start_pos: Vector2):
	var spawn_pos = start_pos
	if start_pos == Vector2.ZERO:
		var cashier = get_node_or_null("World/Background/CashierPerson")
		if cashier:
			spawn_pos = cashier.global_position + Vector2(0, -150)
		else:
			spawn_pos = camera.global_position # Fallback
			
	var label = Label.new()
	var text_prefix = "+" if amount > 0 else ""
	label.text = text_prefix + str(amount) + "%"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font = load("res://assets/fonts/ThaleahFat.ttf")
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 45)
	
	var color = Color(0.3, 1.0, 0.3) if amount > 0 else Color(1.0, 0.3, 0.3)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	
	$World/Background.add_child(label)
	label.global_position = spawn_pos + Vector2(-50, -100) # Slightly offset from money
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 120, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.2).set_delay(0.4)
	tween.finished.connect(label.queue_free)

func _process(delta):
	# Keep highlight tracking the node
	if highlighted_node:
		_update_highlight_shader()

	float_time += delta
	for i in range(issue_buttons.size()):
		var btn = issue_buttons[i]
		if not btn: continue
		
		var issue_path = GameManager.active_issues[i]
		var desk = seat_nodes[i]
		var particles = desk.get_node_or_null("EmotionParticles") if desk else null
		
		if issue_path != "":
			btn.visible = true
			btn.position.y = base_positions[i].y + (sin(float_time * 4.0 + i) * 8.0)
			var label = issue_labels[i]
			if label:
				label.show()
				label.text = GameManager.get_issue_title(issue_path)
				label.global_position = btn.global_position + Vector2(-150, -45)
			
			if particles:
				particles.texture = ANGRY_TEX
		else:
			btn.visible = false
			if issue_labels[i]: issue_labels[i].hide()
			
			if particles and GameManager.occupied_slots[i]:
				particles.texture = HAPPY_TEX

	if current_tutorial_step == TutorialStep.CAMERA_MOVE:
		if camera.position.distance_to(initial_cam_pos) > 150:
			current_tutorial_step = TutorialStep.CUSTOMER_ARRIVE
			tutorial_label.text = "Great job! Now, let's wait for a customer to arrive.\nTap 'Next' to continue."
			tutorial_next_btn.show()

func _unhandled_input(event):
	handle_drag_and_zoom(event)

func handle_drag_and_zoom(event):
	if is_customer_dragging: return
	
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
			last_pinch_distance = -1.0
			
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if touches.size() == 1:
			# Single finger drag - move camera
			camera.position -= event.relative / camera.zoom
			clamp_camera()
			last_pinch_distance = -1.0
		elif touches.size() == 2:
			# Two finger pinch - zoom camera
			var keys = touches.keys()
			var pos1 = touches[keys[0]]
			var pos2 = touches[keys[1]]
			var current_dist = pos1.distance_to(pos2)
			var center_point = (pos1 + pos2) / 2.0
			
			if last_pinch_distance > 0:
				var zoom_factor = current_dist / last_pinch_distance
				_zoom_camera(zoom_factor, center_point)
			last_pinch_distance = current_dist

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_camera(1.1, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_camera(0.9, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			
	elif event is InputEventMouseMotion and dragging:
		camera.position -= event.relative / camera.zoom
		clamp_camera()

	elif event is InputEventMagnifyGesture:
		# Native gesture support (macOS/iOS)
		_zoom_camera(event.factor, get_viewport().get_mouse_position())

func _zoom_camera(factor: float, center_point: Vector2):
	var old_zoom = camera.zoom
	var new_zoom_val = clamp(old_zoom.x * factor, min_zoom, max_zoom)
	var new_zoom = Vector2(new_zoom_val, new_zoom_val)
	
	if old_zoom == new_zoom:
		return
		
	# Zoom towards the center point (cursor or pinch center)
	var vs = get_viewport_rect().size
	var center_offset = center_point - (vs / 2.0)
	
	var world_pos_before = camera.position + (center_offset / old_zoom)
	camera.zoom = new_zoom
	var world_pos_after = camera.position + (center_offset / new_zoom)
	
	camera.position += (world_pos_before - world_pos_after)
	clamp_camera()

func clamp_camera():
	var vs = get_viewport_rect().size
	# Effective size of viewport in world units
	var view_size = vs / camera.zoom
	
	# Center if zoom is too far out
	if view_size.x >= SCENE_SIZE.x:
		camera.position.x = SCENE_SIZE.x / 2.0
	else:
		var margin_x = view_size.x / 2.0
		camera.position.x = clamp(camera.position.x, margin_x, SCENE_SIZE.x - margin_x)
		
	if view_size.y >= SCENE_SIZE.y:
		camera.position.y = SCENE_SIZE.y / 2.0
	else:
		var margin_y = view_size.y / 2.0
		camera.position.y = clamp(camera.position.y, margin_y, SCENE_SIZE.y - margin_y)
