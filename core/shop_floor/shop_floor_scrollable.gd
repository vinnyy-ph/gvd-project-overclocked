extends Node2D

@onready var camera = $MainCamera
@onready var day_label = $CanvasLayer/HUD/DayLabel
@onready var money_label = $CanvasLayer/HUD/MoneyLabel
@onready var satisfaction_bar = $CanvasLayer/HUD/SatisfactionBar
@onready var time_label = $CanvasLayer/HUD/TimeLabel
@onready var multiplier_label = $CanvasLayer/HUD/MultiplierLabel
@onready var decorations_container = $World/Background/DecorationsContainer

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

# --- MOBILE CAMERA VARIABLES ---
var touches: Dictionary = {}
var last_pinch_distance: float = -1.0
const SCENE_SIZE = Vector2(3683.0, 2071.688)
const SCENE_OFFSET = Vector2(-319.0, -335.0)

# --- ANIMATION VARIABLES ---
var base_positions: Array = []
var float_time: float = 0.0

@onready var customer_container = $World/Background/CustomerContainer
@onready var waiting_area = $World/Background/CustomerWaiting

@onready var confetti_particles = $CanvasLayer/ConfettiParticles
@onready var failure_overlay = $CanvasLayer/FailureOverlay
@onready var minigame_indicator = $CanvasLayer/HUD/MiniGameIndicator

const RESOLVE_TEX = preload("res://assets/images/ui/minigameindicator/issueresolve.png")
const FAIL_TEX = preload("res://assets/images/ui/minigameindicator/isseufail.png")

var selected_customer: Customer = null
signal customer_selected(customer)

var is_customer_dragging: bool = false
var active_cashier: Sprite2D = null

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

const ANGRY_TEX = preload("res://assets/images/shop_floor/emotions/angry.png")
const HAPPY_TEX = preload("res://assets/images/shop_floor/emotions/happy.png")

func _ready():
	AudioManager.play_bgm("shop")
	PauseMenu.pause_button.visible = true
	
	# Ensure background and full-screen UI don't block camera dragging
	if day_night_bg: day_night_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if day_night_bg_next: day_night_bg_next.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_node("CanvasLayer/HUD"): $CanvasLayer/HUD.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Fade-in from black
	if has_node("CanvasLayer"):
		var fade_rect = ColorRect.new()
		fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fade_rect.color = Color.BLACK
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$CanvasLayer.add_child(fade_rect)
		var tween = create_tween()
		tween.tween_property(fade_rect, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
		tween.finished.connect(fade_rect.queue_free)
		
	randomize()
	
	# Initial camera setup - Center of the environment
	camera.position = SCENE_OFFSET + (SCENE_SIZE / 2.0)
	
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
	
	_setup_confetti()
	_handle_minigame_result()
	_apply_environment_customizations()
	_spawn_placed_decorations()
	_setup_cashier()

func _setup_cashier():
	var male = get_node_or_null("World/Background/CashierPerson")
	var female = get_node_or_null("World/Background/CashierPersonFemale")
	
	if SaveManager.player_gender == "female":
		if male: male.hide()
		if female: 
			female.show()
			active_cashier = female
	else:
		if female: female.hide()
		if male: 
			male.show()
			active_cashier = male

func _apply_environment_customizations():
	var floor_node = get_node_or_null("World/Background/Floor")
	var wall_node = get_node_or_null("World/Background/Floor2")
	
	if floor_node:
		if SaveManager.current_floor != "":
			var tex_path = GameManager.get_actual_environment_path(SaveManager.current_floor)
			floor_node.texture = load(tex_path)
			floor_node.show()
		else:
			floor_node.hide()
			
	if wall_node:
		if SaveManager.current_wall != "":
			var tex_path = GameManager.get_actual_environment_path(SaveManager.current_wall)
			wall_node.texture = load(tex_path)
			wall_node.show()
		else:
			wall_node.hide()

func _spawn_placed_decorations():
	if not decorations_container: return
	for data in SaveManager.placed_decorations:
		var decoration = Sprite2D.new()
		decorations_container.add_child(decoration)
		var actual_path = GameManager.get_actual_decoration_path(data["path"])
		decoration.texture = load(actual_path)
		decoration.global_position = str_to_var(data["pos"])
		decoration.z_index = 3 # Match editable floor default

func _setup_confetti():
	if not confetti_particles: return
	confetti_particles.emitting = false
	confetti_particles.one_shot = true
	confetti_particles.amount = 150
	confetti_particles.lifetime = 2.0
	confetti_particles.explosiveness = 0.9
	confetti_particles.lifetime_randomness = 0.5
	confetti_particles.position = Vector2(640, 360) # Center of screen
	confetti_particles.direction = Vector2(0, -1) # Upwards
	confetti_particles.spread = 180
	confetti_particles.gravity = Vector2(0, 600) # Strong gravity down
	confetti_particles.initial_velocity_min = 300
	confetti_particles.initial_velocity_max = 600
	confetti_particles.scale_amount_min = 4
	confetti_particles.scale_amount_max = 10
	
	# Create a colorful ramp for variety
	var gradient = Gradient.new()
	gradient.set_color(0, Color.YELLOW)
	gradient.add_point(0.2, Color.RED)
	gradient.add_point(0.4, Color.MAGENTA)
	gradient.add_point(0.6, Color.BLUE)
	gradient.add_point(0.8, Color.GREEN)
	gradient.set_color(gradient.get_point_count() - 1, Color.CYAN)
	
	confetti_particles.color_ramp = gradient
	confetti_particles.color = Color.WHITE # Reset base color
	confetti_particles.hue_variation_min = 0.0
	confetti_particles.hue_variation_max = 0.0

func _handle_minigame_result():
	if not GameManager.minigame_just_finished:
		return
		
	GameManager.minigame_just_finished = false
	
	# Delay slightly for the scene transition to settle
	await get_tree().create_timer(0.3).timeout
	
	if GameManager.minigame_result:
		_play_success_feedback()
	else:
		_play_fail_feedback()

func _play_success_feedback():
	minigame_indicator.texture = RESOLVE_TEX
	_animate_indicator()
	if confetti_particles:
		confetti_particles.emitting = true
		AudioManager.play_sfx("success_subtle")

func _play_fail_feedback():
	minigame_indicator.texture = FAIL_TEX
	_animate_indicator()
	_animate_failure_overlay()
	AudioManager.play_sfx("fail_subtle")

func _animate_indicator():
	if not minigame_indicator: return
	
	# Reset state
	minigame_indicator.visible = true
	minigame_indicator.modulate.a = 0
	minigame_indicator.scale = Vector2.ZERO
	
	# Update size and pivot to match texture, but keep it a reasonable size
	if minigame_indicator.texture:
		var tex_size = minigame_indicator.texture.get_size()
		var target_width = 600.0
		var ratio = tex_size.y / tex_size.x
		minigame_indicator.size = Vector2(target_width, target_width * ratio)
	
	minigame_indicator.pivot_offset = minigame_indicator.size / 2.0
	# Center horizontally and set vertical position
	minigame_indicator.position.x = 640 - (minigame_indicator.size.x / 2.0)
	minigame_indicator.position.y = 200
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(minigame_indicator, "modulate:a", 1.0, 0.4)
	tween.tween_property(minigame_indicator, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Shine effect (subtle scale pulse)
	tween.set_parallel(false)
	tween.tween_property(minigame_indicator, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(minigame_indicator, "scale", Vector2.ONE, 0.1)
	
	tween.tween_interval(1.5)
	
	tween.set_parallel(true)
	tween.tween_property(minigame_indicator, "modulate:a", 0.0, 0.5)
	tween.tween_property(minigame_indicator, "position:y", minigame_indicator.position.y - 50, 0.5)
	tween.finished.connect(func(): minigame_indicator.visible = false)

func _animate_failure_overlay():
	if not failure_overlay: return
	failure_overlay.modulate.a = 0
	failure_overlay.visible = true
	var tween = create_tween()
	tween.tween_property(failure_overlay, "modulate:a", 1.0, 0.1)
	tween.tween_property(failure_overlay, "modulate:a", 0.0, 0.8).set_delay(0.2)

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

	# Handle Emotion Particles
	var particles = desk.get_node_or_null("EmotionParticles")
	if particles:
		particles.emitting = is_occupied
		if is_occupied:
			var has_issue = GameManager.active_issues[slot_idx] != ""
			particles.texture = ANGRY_TEX if has_issue else HAPPY_TEX
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
		elif data["state"] == Customer.State.USING_PC:
			var idx = data["pc_index"]
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
		var desk = seat_nodes[i]
		var particles = desk.get_node_or_null("EmotionParticles") if desk else null
		
		if issue_path != "":
			btn.visible = true
			btn.position.y = base_positions[i].y + (sin(float_time * 4.0 + i) * 8.0)
			
			var label = issue_labels[i]
			if label:
				label.show()
				label.text = GameManager.get_issue_title(issue_path).to_upper()
			
			if particles:
				particles.texture = ANGRY_TEX
		else:
			btn.visible = false
			var label = issue_labels[i]
			if label: label.hide()
			
			if particles and GameManager.occupied_slots[i]:
				particles.texture = HAPPY_TEX
			
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
	
	customer.customer_selected_signal.connect(_on_customer_selected)
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
	if pc_index < 0 or pc_index >= GameManager.active_issues.size():
		push_error("Invalid PC index clicked: " + str(pc_index))
		return
		
	var issue_path = GameManager.active_issues[pc_index]
	if issue_path == "": 
		push_warning("Clicked issue button but no issue path found for PC " + str(pc_index))
		return
	
	print("Transitioning to minigame: ", issue_path, " for PC ", pc_index)
	
	# Clear the issue from the global state so it's not triggered again
	GameManager.active_issues[pc_index] = ""
	
	# Save state before transition
	_save_customers_state()
	GameManager.save_game()
	
	# Transition to minigame
	var err = get_tree().change_scene_to_file(issue_path)
	if err != OK:
		push_error("Failed to transition to minigame at " + issue_path + ". Error: " + str(err))
		# Restore the issue so it's not lost
		GameManager.active_issues[pc_index] = issue_path

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
	var spawn_pos = start_pos
	if start_pos == Vector2.ZERO:
		if active_cashier:
			spawn_pos = active_cashier.global_position + Vector2(0, -100)
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
		if active_cashier:
			spawn_pos = active_cashier.global_position + Vector2(0, -150)
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
	
	var world_min = SCENE_OFFSET
	var world_max = SCENE_OFFSET + SCENE_SIZE
	
	# Center if zoom is too far out
	if view_size.x >= SCENE_SIZE.x:
		camera.position.x = world_min.x + (SCENE_SIZE.x / 2.0)
	else:
		var margin_x = view_size.x / 2.0
		camera.position.x = clamp(camera.position.x, world_min.x + margin_x, world_max.x - margin_x)
		
	if view_size.y >= SCENE_SIZE.y:
		camera.position.y = world_min.y + (SCENE_SIZE.y / 2.0)
	else:
		var margin_y = view_size.y / 2.0
		camera.position.y = clamp(camera.position.y, world_min.y + margin_y, world_max.y - margin_y)
