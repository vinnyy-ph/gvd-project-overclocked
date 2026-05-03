extends Control

@onready var timer_label = $Background/TopPanel/TimerLabel
@onready var status_label = $Background/TopPanel/StatusLabel
@onready var game_timer = $GameTimer

@onready var parts_container = $BuildArea/Parts
@onready var slots_container = $BuildArea/Slots

var time_left: int = 20
var placed_count: int = 0
var total_parts: int = 3
var game_active: bool = true

# Drag and drop variables
var dragged_part: ColorRect = null
var drag_offset: Vector2 = Vector2.ZERO
var original_positions: Dictionary = {}

func _ready():
	AudioManager.play_bgm("minigame")
	# Timer Setup
	game_timer.wait_time = 1.0
	game_timer.one_shot = false 
	if not game_timer.timeout.is_connected(_on_game_timer_timeout):
		game_timer.timeout.connect(_on_game_timer_timeout)
	game_timer.start()
	update_timer()
	update_status()

	# Initialize parts
	for part in parts_container.get_children():
		if part is ColorRect:
			# Store starting position so we can snap back if dropped wrong
			original_positions[part] = part.position
			
			# Ensure parts process mouse input
			part.mouse_filter = Control.MOUSE_FILTER_PASS 
			part.gui_input.connect(_on_part_gui_input.bind(part))

func update_timer():
	timer_label.text = "TIME: " + str(time_left)

func update_status():
	status_label.text = "PLACED: " + str(placed_count) + " / " + str(total_parts)

func _on_game_timer_timeout():
	if not game_active: return
	
	time_left -= 1
	if time_left <= 0:
		time_left = 0
		update_timer()
		fail_game()
	else:
		update_timer()

# --- DRAG AND DROP LOGIC ---

func _on_part_gui_input(event: InputEvent, part: ColorRect):
	if not game_active: return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start dragging
			dragged_part = part
			# Calculate offset so the part doesn't snap to the top-left corner of the mouse
			drag_offset = part.global_position - get_global_mouse_position()
			# Bring the dragged part to the front
			part.move_to_front()
		else:
			# Stop dragging
			if dragged_part != null:
				check_drop(dragged_part)
				dragged_part = null

func _process(_delta):
	if dragged_part != null:
		# Update position while dragging
		dragged_part.global_position = get_global_mouse_position() + drag_offset

func check_drop(part: ColorRect):
	var dropped_correctly = false
	
	# We expect the slot name to end with "_Slot" and the part name to end with "_Part"
	# E.g., "CPU_Part" matches "CPU_Slot"
	var expected_slot_name = part.name.replace("_Part", "_Slot")
	
	for slot in slots_container.get_children():
		if slot.name == expected_slot_name:
			# Calculate distance between centers
			var part_center = part.global_position + (part.size / 2.0)
			var slot_center = slot.global_position + (slot.size / 2.0)
			
			# If the distance is small enough (e.g., within 40 pixels), consider it a match
			if part_center.distance_to(slot_center) < 40:
				# Snap to slot
				part.global_position = slot.global_position
				
				# Disable further dragging
				part.mouse_filter = Control.MOUSE_FILTER_IGNORE
				
				dropped_correctly = true
				placed_count += 1
				update_status()
				
				# Give visual feedback (e.g., turn the slot green)
				slot.color = Color(0.1, 0.8, 0.1, 0.5) 
				
				if placed_count >= total_parts:
					win_game()
				break

	if not dropped_correctly:
		# Snap back to original position
		part.position = original_positions[part]


# --- WIN / LOSS INTEGRATED WITH GAME MANAGER ---

func win_game():
	game_active = false
	game_timer.stop()
	AudioManager.play_sfx("success")
	AudioManager.play_sfx("coin")
	
	GameManager.last_money_change = 25
	GameManager.last_satisfaction_change = 10
	
	GameManager.money += GameManager.last_money_change
	GameManager.satisfaction += GameManager.last_satisfaction_change
	if GameManager.satisfaction > 100: GameManager.satisfaction = 100
	GameManager.save_game()
	
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://success_screen.tscn")

func fail_game():
	game_active = false
	game_timer.stop()
	AudioManager.play_sfx("fail")
	
	GameManager.last_money_change = 0
	GameManager.last_satisfaction_change = -10
	
	GameManager.satisfaction += GameManager.last_satisfaction_change
	if GameManager.satisfaction < 0: GameManager.satisfaction = 0
	GameManager.save_game()
	
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://shop_floor_scrollable.tscn")
