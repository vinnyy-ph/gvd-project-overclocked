extends Control

class_name Customer

enum State { WAITING, MOVING_TO_PC, USING_PC, EXITING }

var current_state: State = State.WAITING
var assigned_pc_index: int = -1
var target_position: Vector2 = Vector2.ZERO
var chair_node: Node = null

@onready var sprite = $Sprite2D
@onready var revenue_timer = Timer.new()
@onready var session_timer = Timer.new()
@onready var issue_timer = Timer.new()

signal arrived_at_pc
signal exited_pc
signal drag_started(customer)
signal drag_ended(customer, global_pos)

var is_dragging = false
var drag_offset = Vector2.ZERO
var original_waiting_position = Vector2.ZERO

func _ready():
	add_child(revenue_timer)
	revenue_timer.wait_time = 2.0
	revenue_timer.timeout.connect(_on_revenue_timeout)
	
	add_child(session_timer)
	session_timer.one_shot = true
	session_timer.timeout.connect(_on_session_timeout)
	
	add_child(issue_timer)
	issue_timer.wait_time = randf_range(10.0, 20.0)
	issue_timer.timeout.connect(_on_issue_timeout)

	# Randomize session duration (15 to 40 seconds)
	session_timer.wait_time = randf_range(15.0, 40.0)

func return_to_waiting_position():
	var tween = create_tween()
	tween.tween_property(self, "global_position", original_waiting_position, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func assign_to_pc(pc_index: int, pos, chair: Node, resume_data: Dictionary = {}):
	if pos == null:
		pos = global_position # Stay where we are if no valid pos
		
	assigned_pc_index = pc_index
	target_position = pos
	chair_node = chair
	current_state = State.MOVING_TO_PC
	
	if resume_data.is_empty():
		GameManager.occupied_slots[pc_index] = true
		var tween = create_tween()
		tween.tween_property(self, "global_position", target_position, 2.0).set_trans(Tween.TRANS_SINE)
		tween.finished.connect(_on_arrival)
	else:
		# Resume with exact state
		global_position = target_position
		session_timer.wait_time = max(0.1, resume_data.get("session_time", 10.0))
		issue_timer.wait_time = max(0.1, resume_data.get("issue_time", 5.0))
		_on_arrival()

func get_data() -> Dictionary:
	return {
		"state": current_state,
		"pc_index": assigned_pc_index,
		"pos": global_position,
		"session_time": session_timer.time_left if current_state == State.USING_PC else session_timer.wait_time,
		"issue_time": issue_timer.time_left if current_state == State.USING_PC else issue_timer.wait_time
	}

func _on_arrival():
	current_state = State.USING_PC
	arrived_at_pc.emit()
	
	# Hide walking sprite and show the sitting placeholder (chair)
	sprite.visible = false
	if chair_node is Control:
		chair_node.visible = true
		
	revenue_timer.start()
	session_timer.start()
	issue_timer.start()

func _on_revenue_timeout():
	if current_state == State.USING_PC and GameManager.active_issues[assigned_pc_index] == "":
		GameManager.money += 1 # +1 money every 2 seconds

func _on_session_timeout():
	exit_shop()

func _on_issue_timeout():
	if current_state == State.USING_PC and GameManager.active_issues[assigned_pc_index] == "":
		# Chance to trigger an issue
		if randf() < 0.35: # 35% chance every check
			GameManager.active_issues[assigned_pc_index] = GameManager.get_next_minigame()
			AudioManager.play_sfx("alert")
		else:
			# Reset check timer if no issue spawned
			issue_timer.start(randf_range(8.0, 15.0))

func exit_shop():
	if current_state == State.EXITING: return
	
	current_state = State.EXITING
	if assigned_pc_index != -1:
		GameManager.occupied_slots[assigned_pc_index] = false
		GameManager.active_issues[assigned_pc_index] = ""
		exited_pc.emit()
		
	revenue_timer.stop()
	issue_timer.stop()
	
	# Show walking sprite again and hide sitting placeholder
	sprite.visible = true
	if chair_node is Control:
		chair_node.visible = false
	
	var exit_pos = global_position + Vector2(1200, 200) # Default fallback
	# Correct pathing to ExitPoint marker
	if get_parent() and get_parent().has_node("../ExitPoint"):
		exit_pos = get_parent().get_node("../ExitPoint").global_position
		
	var tween = create_tween()
	tween.tween_property(self, "global_position", exit_pos, 2.5).set_trans(Tween.TRANS_SINE)
	tween.finished.connect(func(): queue_free())

signal customer_selected(customer)

# Handle selection
var is_selected = false
var selection_tween: Tween = null

func _gui_input(event):
	if current_state != State.WAITING: return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_offset = get_global_mouse_position() - global_position
				original_waiting_position = global_position
				drag_started.emit(self)
				accept_event()
			elif is_dragging:
				is_dragging = false
				drag_ended.emit(self, get_global_mouse_position())
				accept_event()
	
	elif event is InputEventMouseMotion and is_dragging:
		global_position = get_global_mouse_position() - drag_offset
		accept_event()
	
	elif event is InputEventScreenTouch:
		if event.pressed:
			is_dragging = true
			drag_offset = get_global_mouse_position() - global_position
			original_waiting_position = global_position
			drag_started.emit(self)
			accept_event()
		elif is_dragging:
			is_dragging = false
			drag_ended.emit(self, get_global_mouse_position())
			accept_event()
	
	elif event is InputEventScreenDrag and is_dragging:
		global_position = get_global_mouse_position() - drag_offset
		accept_event()

func set_selection(selected: bool):
	is_selected = selected
	if selection_tween:
		selection_tween.kill()
		selection_tween = null

	if is_selected:
		# Visual cue: Pulsing effect
		selection_tween = create_tween().set_loops()
		selection_tween.tween_property(sprite, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.5)
		selection_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)
	else:
		# Reset visual cue
		sprite.modulate = Color.WHITE

func _process(_delta):
	pass
