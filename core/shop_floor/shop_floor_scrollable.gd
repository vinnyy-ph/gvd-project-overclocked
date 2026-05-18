extends Node2D

@onready var camera = $MainCamera
@onready var day_label = $CanvasLayer/HUD/DayLabel
@onready var money_label = $CanvasLayer/HUD/MoneyLabel
@onready var satisfaction_bar = $CanvasLayer/HUD/SatisfactionBar
@onready var time_label = $CanvasLayer/HUD/TimeLabel
@onready var multiplier_label = $CanvasLayer/HUD/MultiplierLabel

@onready var day_night_bg = $World/Day_NightEnvironment
@onready var day_night_bg_next = $World/Day_NightEnvironment_Next

var bg_textures = [
	preload("res://assets/images/shop_floor_bg/1.png"),
	preload("res://assets/images/shop_floor_bg/2.png"),
	preload("res://assets/images/shop_floor_bg/3.png"),
	preload("res://assets/images/shop_floor_bg/4.png")
]

@export var every_pc_unlocked: bool = false
@export var min_zoom: float = 0.35
@export var max_zoom: float = 1.5

@onready var issue_buttons: Array = []

var scroll_speed: float = 900.0
var dragging: bool = false
var last_drag_position: Vector2 = Vector2.ZERO

# --- ANIMATION VARIABLES ---
var base_positions: Array = []
var float_time: float = 0.0

@onready var customer_container = $World/Background/CustomerContainer
@onready var waiting_area = $World/Background/CustomerWaiting

var selected_customer: Customer = null
signal customer_selected(customer)

var is_customer_dragging: bool = false

# Map slots to their desk nodes and positions
var seat_nodes: Array = []
var seat_positions: Array = []
var original_desk_scales: Array = []
var issue_labels: Array = []

# Texture constants
const EMPTY_7 = preload("res://assets/images/shop_floor/empty_slot.png")
const OCCUPIED_7 = preload("res://assets/images/shop_floor/occupied_slot.png")
const EMPTY_13 = preload("res://assets/images/shop_floor/empty_slot_front.png")
const OCCUPIED_13 = preload("res://assets/images/shop_floor/occupied_slot_front.png")

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
	
	GameManager.money_earned_visual.connect(spawn_floating_money)

	var num_slots = 13
	var unlocked_slots = num_slots if every_pc_unlocked else GameManager.get_unlocked_slots()

	seat_nodes.resize(num_slots)
	seat_positions.resize(num_slots)
	original_desk_scales.resize(num_slots)
	issue_labels.resize(num_slots)
	issue_buttons.resize(num_slots)
	base_positions.resize(num_slots)

	# Setup desks and issue buttons
	for slot_idx in range(num_slots):
		var desk_num = slot_idx + 1
		var is_unlocked = slot_idx < unlocked_slots
		var modulate_color = Color.WHITE if is_unlocked else Color(0.2, 0.2, 0.2)
		
		var desk_node = get_node_or_null("World/Background/Desk" + str(desk_num))
		if desk_node:
			desk_node.modulate = modulate_color
			seat_nodes[slot_idx] = desk_node
			seat_positions[slot_idx] = desk_node.global_position
			original_desk_scales[slot_idx] = desk_node.scale
			
			if is_unlocked:
				_setup_desk_click(desk_node, slot_idx)
			
			var btn = desk_node.get_node_or_null("Desk" + str(desk_num) + "IssueButton")
			if btn:
				issue_buttons[slot_idx] = btn
				base_positions[slot_idx] = btn.position
				btn.pivot_offset = btn.size / 2.0
				btn.visible = GameManager.active_issues[slot_idx] != ""
				if not btn.pressed.is_connected(_on_issue_clicked):
					btn.pressed.connect(_on_issue_clicked.bind(slot_idx))
				
				# Use existing label child
				var label = btn.get_node_or_null("Label")
				if label:
					issue_labels[slot_idx] = label
					label.hide()
		
		# Initial visual state
		_update_desk_texture(slot_idx)

	# --- RESTORE PERSISTED CUSTOMERS ---
	if waiting_area:
		waiting_area.visible = false
		waiting_area.process_mode = PROCESS_MODE_DISABLED
		
	_restore_customers()
	update_hud()
	
	# Initialize spawn timer with dynamic interval
	$SpawnTimer.wait_time = GameManager.get_spawn_interval()
	$SpawnTimer.start()

func _update_desk_texture(slot_idx: int):
	var desk = seat_nodes[slot_idx]
	if not desk: return
	
	var desk_num = slot_idx + 1
	var is_occupied = GameManager.occupied_slots[slot_idx]
	
	if desk_num <= 7:
		desk.texture = OCCUPIED_7 if is_occupied else EMPTY_7
	else:
		desk.texture = OCCUPIED_13 if is_occupied else EMPTY_13
	
	# Static opacity indication: 1.0 if busy, 0.8 if free
	desk.modulate.a = 1.0 if is_occupied else 0.8

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
			_connect_customer_signals(customer, idx)
			customer.assign_to_pc(idx, seat_positions[idx], seat_nodes[idx], data)
			_update_desk_texture(idx)
	
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
		if not GameManager.occupied_slots[slot_idx]:
			var target_pos = seat_positions[slot_idx]
			var desk = seat_nodes[slot_idx]
			
			_connect_customer_signals(target_customer, slot_idx)
			target_customer.assign_to_pc(slot_idx, target_pos, desk)
			_show_station_assigned_feedback(slot_idx)
			AudioManager.play_sfx("assign")
			if target_customer == selected_customer:
				_deselect_customer()
		else:
			_show_station_occupied_feedback(slot_idx)

func _on_customer_drag_started(_customer: Customer):
	is_customer_dragging = true

func _on_customer_drag_ended(customer: Customer, _global_pos: Vector2):
	is_customer_dragging = false
	
	var best_dist = 180.0
	var best_slot = -1
	
	var drop_point = customer.global_position
	var unlocked_slots = 13 if every_pc_unlocked else GameManager.get_unlocked_slots()
	
	for i in range(seat_nodes.size()):
		var desk = seat_nodes[i]
		if not desk: continue
		
		var dist = drop_point.distance_to(desk.global_position)
		if dist < best_dist:
			best_dist = dist
			best_slot = i
			
	if best_slot != -1:
		if best_slot < unlocked_slots:
			if not GameManager.occupied_slots[best_slot]:
				_on_desk_clicked(best_slot, customer)
				_refresh_queue_positions()
			else:
				_show_station_occupied_feedback(best_slot)
				customer.return_to_waiting_position()
		else:
			_show_station_locked_feedback(best_slot)
			customer.return_to_waiting_position()
	else:
		customer.return_to_waiting_position()

func _connect_customer_signals(customer: Customer, slot_idx: int):
	if not customer.arrived_at_pc.is_connected(_update_desk_texture):
		customer.arrived_at_pc.connect(_update_desk_texture.bind(slot_idx))
	if not customer.exited_pc.is_connected(_update_desk_texture):
		customer.exited_pc.connect(_update_desk_texture.bind(slot_idx))

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

func _show_station_locked_feedback(slot_idx: int):
	var label = Label.new()
	label.text = "STATION LOCKED!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font = load("res://assets/fonts/ThaleahFat.ttf")
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0)) # Purple/Pink for locked
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

func _deselect_customer():
	if selected_customer:
		selected_customer.set_selection(false)
		selected_customer = null

# --- ANIMATION LOGIC ---

func _process(delta):
	_update_day_night_cycle(delta)
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
				label.text = GameManager.get_issue_title(issue_path).to_upper()
		else:
			btn.visible = false
			var label = issue_labels[i]
			if label: label.hide()
			
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
	if waiting_count < GameManager.get_max_waiting_customers():
		spawn_customer()
	
	# Randomize next interval slightly for "fairness" (organic feel)
	var base_interval = GameManager.get_spawn_interval()
	$SpawnTimer.wait_time = randf_range(base_interval * 0.8, base_interval * 1.2)

func spawn_customer():
	var waiting_count = 0
	for child in customer_container.get_children():
		if child is Customer and child.current_state == Customer.State.WAITING:
			waiting_count += 1
			
	var customer = waiting_area.duplicate()
	customer_container.add_child(customer)
	# Newest at the bottom of tree so they are drawn behind older ones
	customer_container.move_child(customer, 0)
	
	customer.process_mode = PROCESS_MODE_INHERIT
	customer.visible = true
	
	customer.customer_selected.connect(_on_customer_selected)
	customer.drag_started.connect(_on_customer_drag_started)
	customer.drag_ended.connect(_on_customer_drag_ended)
	
	if waiting_area:
		# Diagonal isometric offset (up and left)
		customer.global_position = waiting_area.global_position + Vector2(waiting_count * -70, waiting_count * -50)
		AudioManager.play_sfx("spawn")
		
		# Spawn animation: pop-in from scale 0
		var final_scale = customer.scale
		customer.scale = Vector2.ZERO
		var tween = create_tween()
		tween.tween_property(customer, "scale", final_scale, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _refresh_queue_positions():
	var waiting_customers = []
	for child in customer_container.get_children():
		if child is Customer and child.current_state == Customer.State.WAITING:
			waiting_customers.append(child)
	
	# Due to move_child(0), the oldest (front) is at the end of the array
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
	
	# Oldest is at the end of the container's children due to move_child(0)
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
	label.add_theme_color_override("font_color", Color(1, 0.8, 0.2)) # Yellow/Orange warning
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.custom_minimum_size = Vector2(400, 0)
	
	$World/Background.add_child(label)
	# Center the 400px wide label over the customer's position
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
	
	if GameManager.money <= 0:
		money_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		money_label.remove_theme_color_override("font_color")
		
	time_label.text = GameManager.get_formatted_time()
	satisfaction_bar.value = GameManager.satisfaction
	_apply_bar_style()
	
	# Update Multiplier Label
	var mult = GameManager.get_satisfaction_multiplier()
	multiplier_label.text = "Tips: x" + str(mult)
	if mult > 1.0:
		multiplier_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3)) # Green
	elif mult < 1.0:
		multiplier_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3)) # Red
	else:
		multiplier_label.add_theme_color_override("font_color", Color.WHITE)

func spawn_floating_money(amount: int, start_pos: Vector2):
	var label = Label.new()
	label.text = "+P" + str(amount)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font = load("res://assets/fonts/ThaleahFat.ttf")
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 45)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2)) # Gold-ish
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	
	$World/Background.add_child(label)
	label.global_position = start_pos + Vector2(-50, -50)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 120, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.2).set_delay(0.4)
	tween.finished.connect(label.queue_free)

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

func _update_day_night_cycle(_delta):
	if not day_night_bg or not day_night_bg_next: return
	
	var total_ticks = 60.0
	var elapsed_ticks = (total_ticks - GameManager.time_left) + (1.0 - $DayTimer.time_left)
	var progress = clamp(elapsed_ticks / total_ticks, 0.0, 1.0)
	
	# Mapping 9 AM to 6 PM (9 hours)
	var elapsed_hours = progress * 9.0
	
	# Texture mapping thresholds (hours from 9 AM):
	# 9 AM: T1 (0h)
	# 3 PM: T2 (6h) - T1 to T2 takes 6 hours
	# 4 PM: T3 (7h) - T2 to T3 takes 1 hour (Smooth transition)
	# 6 PM: T4 (9h) - T3 to T4 takes 2 hours
	var thresholds = [0.0, 6.0, 7.0, 9.0]
	
	var idx1 = 0
	var idx2 = 0
	var lerp_factor = 0.0
	
	for i in range(thresholds.size() - 1):
		if elapsed_hours >= thresholds[i] and elapsed_hours <= thresholds[i+1]:
			idx1 = i
			idx2 = min(i + 1, bg_textures.size() - 1)
			var segment_range = thresholds[i+1] - thresholds[i]
			if segment_range > 0:
				lerp_factor = (elapsed_hours - thresholds[i]) / segment_range
			break

	day_night_bg.texture = bg_textures[idx1]
	if idx1 != idx2:
		day_night_bg_next.visible = true
		day_night_bg_next.texture = bg_textures[idx2]
		day_night_bg_next.modulate.a = lerp_factor
	else:
		day_night_bg_next.modulate.a = 0.0
		day_night_bg_next.visible = false

func handle_drag_and_zoom(event):
	if is_customer_dragging: return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.zoom = Vector2(min(camera.zoom.x + 0.1, max_zoom), min(camera.zoom.y + 0.1, max_zoom))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.zoom = Vector2(max(camera.zoom.x - 0.1, min_zoom), max(camera.zoom.y - 0.1, min_zoom))
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if dragging: last_drag_position = event.position
		clamp_camera()
	elif event is InputEventMagnifyGesture:
		var new_zoom = camera.zoom * event.factor
		camera.zoom.x = clamp(new_zoom.x, min_zoom, max_zoom)
		camera.zoom.y = clamp(new_zoom.y, min_zoom, max_zoom)
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
