extends Camera2D
class_name EditableCamera2D

## Signal emitted when the camera finishes zooming
signal zoom_finished

@export_group("Limits")
@export var scene_size: Vector2 = Vector2(3064.0, 1408.0)

@export_group("Zoom")
@export var min_zoom: float = 0.35
@export var max_zoom: float = 1.5
@export var zoom_speed: float = 0.2
@export var zoom_duration: float = 0.2

@export_group("Smoothing")
@export var drag_speed: float = 1.0

@export_group("Shake")
@export var max_shake_offset: Vector2 = Vector2(20.0, 15.0)
@export var max_shake_roll: float = 2.0
@export var shake_decay: float = 1.5

# Internal State
var _target_zoom: float = 1.0
var _zoom_tween: Tween
var _touches: Dictionary = {}
var _last_pinch_distance: float = -1.0
var _trauma: float = 0.0
var _noise: FastNoiseLite
var _noise_time: float = 0.0

func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.seed = randi()
	
	# Calculate min_zoom to ensure we never show outside the scene
	var vs = get_viewport_rect().size
	min_zoom = max(vs.x / scene_size.x, vs.y / scene_size.y)
	
	# Initial zoom setup
	var initial_zoom = max(zoom.x, min_zoom)
	zoom = Vector2(initial_zoom, initial_zoom)
	_target_zoom = initial_zoom
	
	# Initial clamp
	clamp_camera()

func _process(delta: float) -> void:
	_handle_shake(delta)

func _handle_shake(delta: float) -> void:
	if _trauma <= 0.0:
		offset = Vector2.ZERO
		rotation = 0.0
		return

	_trauma = maxf(_trauma - shake_decay * delta, 0.0)
	_noise_time += delta * 60.0

	var shake = _trauma * _trauma
	offset.x = max_shake_offset.x * shake * _noise.get_noise_2d(_noise_time, 0.0)
	offset.y = max_shake_offset.y * shake * _noise.get_noise_2d(0.0, _noise_time)
	rotation = deg_to_rad(max_shake_roll) * shake * _noise.get_noise_2d(_noise_time, _noise_time)

func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)

func handle_input(event: InputEvent) -> void:
	# Mobile Touch
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
			_last_pinch_distance = -1.0
			
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			# Single finger drag
			position -= event.relative / zoom
			clamp_camera()
			_last_pinch_distance = -1.0
		elif _touches.size() == 2:
			# Pinch to zoom
			var keys = _touches.keys()
			var current_dist = _touches[keys[0]].distance_to(_touches[keys[1]])
			var center_point = (_touches[keys[0]] + _touches[keys[1]]) / 2.0
			if _last_pinch_distance > 0:
				var zoom_factor = current_dist / _last_pinch_distance
				_zoom_at_point(zoom_factor, center_point, true) # true = instant for pinch
			_last_pinch_distance = current_dist

	# Mouse / Desktop
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at_point(1.0 + zoom_speed, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at_point(1.0 - zoom_speed, event.position)
			
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _touches.size() == 0:
			position -= event.relative / zoom
			clamp_camera()

func _zoom_at_point(factor: float, screen_point: Vector2, instant: bool = false) -> void:
	var old_zoom = zoom.x
	var new_zoom_val = clamp(old_zoom * factor, min_zoom, max_zoom)
	
	if old_zoom == new_zoom_val: return
	
	if instant:
		_apply_zoom(new_zoom_val, screen_point)
	else:
		if _zoom_tween: _zoom_tween.kill()
		_zoom_tween = create_tween().set_parallel(true)
		_zoom_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		# We need to tween the zoom value and handle the position offset accordingly
		# A simpler way to animate "zoom to point" is to tween a custom property
		_zoom_tween.tween_method(
			func(z): _apply_zoom(z, screen_point),
			old_zoom,
			new_zoom_val,
			zoom_duration
		)
		_zoom_tween.finished.connect(func(): zoom_finished.emit())

func _apply_zoom(new_z: float, screen_point: Vector2) -> void:
	var old_z = zoom.x
	var vs = get_viewport_rect().size
	var center_offset = screen_point - (vs / 2.0)
	
	# World position before zoom
	var world_pos_before = position + (center_offset / Vector2(old_z, old_z))
	
	# Update zoom
	zoom = Vector2(new_z, new_z)
	
	# World position after zoom
	var world_pos_after = position + (center_offset / Vector2(new_z, new_z))
	
	# Adjust position to keep screen_point under the same world position
	position += (world_pos_before - world_pos_after)
	clamp_camera()

func clamp_camera() -> void:
	var vs = get_viewport_rect().size
	var view_size = vs / zoom
	
	if view_size.x >= scene_size.x:
		position.x = scene_size.x / 2.0
	else:
		var margin_x = view_size.x / 2.0
		position.x = clamp(position.x, margin_x, scene_size.x - margin_x)
		
	if view_size.y >= scene_size.y:
		position.y = scene_size.y / 2.0
	else:
		var margin_y = view_size.y / 2.0
		position.y = clamp(position.y, margin_y, scene_size.y - margin_y)
