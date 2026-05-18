extends Sprite2D

class_name Customer

enum State { WAITING, MOVING_TO_PC, USING_PC, EXITING }

var current_state: State = State.WAITING
var assigned_pc_index: int = -1
var target_position: Vector2 = Vector2.ZERO
var chair_node: Node = null

@onready var sprite = self
var revenue_timer = Timer.new()
var session_timer = Timer.new()
var issue_timer = Timer.new()

signal arrived_at_pc
signal exited_pc
signal drag_started(customer)
signal drag_ended(customer, global_pos)

var is_dragging = false
var drag_offset = Vector2.ZERO
var original_waiting_position = Vector2.ZERO
var base_scale = Vector2.ONE
var drag_tween: Tween = null

# Physics-related variables
var last_mouse_pos: Vector2 = Vector2.ZERO
var drag_velocity: float = 0.0
var target_rotation: float = 0.0
var rotation_speed: float = 8.0

func _ready():
	base_scale = scale
	if not revenue_timer.get_parent():
		add_child(revenue_timer)
		revenue_timer.wait_time = 2.0
		revenue_timer.timeout.connect(_on_revenue_timeout)
	
	if not session_timer.get_parent():
		add_child(session_timer)
		session_timer.one_shot = true
		session_timer.timeout.connect(_on_session_timeout)
	
	if not issue_timer.get_parent():
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
		global_position = target_position
		
		# Subtle indication: quick scale bounce on the chair/desk
		if chair_node:
			var tween = create_tween()
			var original_scale = chair_node.scale
			tween.tween_property(chair_node, "scale", original_scale * 1.1, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(chair_node, "scale", original_scale, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		_on_arrival()
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
		"pos_x": global_position.x,
		"pos_y": global_position.y,
		"session_time": session_timer.time_left if current_state == State.USING_PC else session_timer.wait_time,
		"issue_time": issue_timer.time_left if current_state == State.USING_PC else issue_timer.wait_time
	}

func _on_arrival():
	current_state = State.USING_PC
	arrived_at_pc.emit()
	
	# Hide walking sprite
	sprite.visible = false
	# Desk texture change is handled by signal in shop_floor_scrollable
		
	revenue_timer.start()
	session_timer.start()
	issue_timer.start()

func _on_revenue_timeout():
	if current_state == State.USING_PC and GameManager.active_issues[assigned_pc_index] == "":
		var amount = GameManager.get_passive_income_reward()
		GameManager.money += amount
		# Pass Vector2.ZERO or a known flag so the main scene spawns it at the cashier
		GameManager.money_earned_visual.emit(amount, Vector2.ZERO)

func _on_session_timeout():
	exit_shop()

func _on_issue_timeout():
	if current_state == State.USING_PC and GameManager.active_issues[assigned_pc_index] == "":
		# Chance to trigger an issue (scaled by upgrades)
		var base_chance = 0.35
		var modified_chance = base_chance * GameManager.get_issue_spawn_chance_modifier()
		
		if randf() < modified_chance:
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
	
	# Instead of walking, we show a popup text and free immediately
	var label = Label.new()
	label.text = "FINISHED!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font = load("res://assets/fonts/ThaleahFat.ttf")
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 35)
	label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	
	if get_parent() != null:
		get_parent().add_child(label)
		label.global_position = global_position + Vector2(-50, -50)
		var tween = label.create_tween()
		tween.tween_property(label, "position:y", label.position.y - 80, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.2)
		tween.finished.connect(label.queue_free)
	
	queue_free()

signal customer_selected(customer)

# Handle selection
var is_selected = false
var selection_tween: Tween = null

func _input(event):
	if current_state != State.WAITING: return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if mouse is over sprite
				var local_pos = to_local(get_global_mouse_position())
				if texture:
					var size = texture.get_size()
					var rect = Rect2(-size/2, size)
					if rect.has_point(local_pos):
						var shop = get_tree().current_scene
						if shop.has_method("is_first_in_line") and not shop.is_first_in_line(self):
							shop.show_queue_warning(global_position)
							return
							
						is_dragging = true
						last_mouse_pos = get_global_mouse_position()
						_set_drag_visual(true)
						drag_offset = get_global_mouse_position() - global_position
						original_waiting_position = global_position
						customer_selected.emit(self)
						drag_started.emit(self)
						get_viewport().set_input_as_handled()
			elif is_dragging:
				is_dragging = false
				_set_drag_visual(false)
				drag_ended.emit(self, global_position)
				get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion and is_dragging:
		global_position = get_global_mouse_position() - drag_offset
		get_viewport().set_input_as_handled()
	
	elif event is InputEventScreenTouch:
		if event.pressed:
			var mouse_pos = get_canvas_transform().affine_inverse() * event.position
			var local_pos = to_local(mouse_pos)
			if texture:
				var size = texture.get_size()
				var rect = Rect2(-size/2, size)
				if rect.has_point(local_pos):
					var shop = get_tree().current_scene
					if shop.has_method("is_first_in_line") and not shop.is_first_in_line(self):
						shop.show_queue_warning(global_position)
						return
						
					is_dragging = true
					last_mouse_pos = mouse_pos
					_set_drag_visual(true)
					drag_offset = mouse_pos - global_position
					original_waiting_position = global_position
					customer_selected.emit(self)
					drag_started.emit(self)
					get_viewport().set_input_as_handled()
		elif is_dragging:
			is_dragging = false
			_set_drag_visual(false)
			drag_ended.emit(self, global_position)
			get_viewport().set_input_as_handled()
	
	elif event is InputEventScreenDrag and is_dragging:
		var mouse_pos = get_canvas_transform().affine_inverse() * event.position
		global_position = mouse_pos - drag_offset
		get_viewport().set_input_as_handled()

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

func _set_drag_visual(dragging: bool):
	if drag_tween:
		drag_tween.kill()
	drag_tween = create_tween().set_parallel(true)
	
	if dragging:
		# Lift effect: scale up and slight transparency
		drag_tween.tween_property(self, "scale", base_scale * 1.15, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		drag_tween.tween_property(self, "modulate:a", 0.7, 0.15)
		z_index = 100 # Bring to very front while dragging
	else:
		# Drop back
		drag_tween.tween_property(self, "scale", base_scale, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		drag_tween.tween_property(self, "modulate:a", 1.0, 0.15)
		z_index = 37 # Return to normal customer z-index

func _process(delta):
	if is_dragging:
		var current_mouse_pos = get_global_mouse_position()
		# Calculate horizontal velocity
		var dx = current_mouse_pos.x - last_mouse_pos.x
		
		# Update target rotation based on horizontal movement (tilt)
		# A little bit of sin time adds a "dangling" swing effect
		var swing = sin(Time.get_ticks_msec() * 0.01) * 0.05
		target_rotation = clamp(dx * 0.05, -0.4, 0.4) + swing
		
		last_mouse_pos = current_mouse_pos
	else:
		target_rotation = 0.0
	
	# Smoothly interpolate rotation
	rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)
