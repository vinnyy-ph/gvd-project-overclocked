extends Node2D

@onready var camera: Camera2D = $MainCamera
@onready var item_list: ItemList = $CanvasLayer/ItemList
@onready var decorations_container: Node2D = $World/Background/DecorationsContainer
@onready var safe_zone: Polygon2D = $World/Background/SafeZoneShopFloor
@onready var safe_zone_wall_left: Polygon2D = $World/Background/SafeZoneShopFloor2
@onready var safe_zone_wall_right: Polygon2D = $World/Background/SafeZoneShopFloor3
@onready var back_button: Button = $CanvasLayer/Button

# Constants for Camera
const SCENE_SIZE = Vector2(3064.0, 1408.0)
@export var min_zoom: float = 0.35
@export var max_zoom: float = 1.5
var scroll_speed: float = 900.0
var dragging_camera: bool = false
var touches: Dictionary = {}
var last_pinch_distance: float = -1.0

# Decoration Logic
const DECORATION_SCENE = preload("res://core/shop_floor/shop_decoration.tscn")
var decorations_data: Array = []
var active_decoration: Sprite2D = null
var is_dragging_item: bool = false
var placed_decorations: Array = []

func _ready() -> void:
	# Initial camera setup
	camera.position = Vector2(1532, 704)
	var vs = get_viewport_rect().size
	min_zoom = min(vs.x / SCENE_SIZE.x, vs.y / SCENE_SIZE.y)
	camera.zoom = Vector2(max(min_zoom, 0.5), max(min_zoom, 0.5))
	clamp_camera()

	# Ensure safe zones are semi-transparent cyan
	var highlight_color = Color(0, 1, 1, 0.25)
	safe_zone.color = highlight_color
	safe_zone_wall_left.color = highlight_color
	safe_zone_wall_right.color = highlight_color
	hide_all_safe_zones()

	# Initial scan of owned decorations
	_load_owned_inventory()
	_spawn_placed_decorations()
	
	# Connect ItemList signals
	item_list.gui_input.connect(_on_item_list_gui_input)
	
	back_button.pressed.connect(_on_back_pressed)

func _load_owned_inventory():
	decorations_data.clear()
	# Only items in SaveManager.owned_decorations that are NOT in SaveManager.placed_decorations
	var placed_paths = []
	for p in SaveManager.placed_decorations:
		placed_paths.append(p["path"])
		
	for path in SaveManager.owned_decorations:
		if path in placed_paths:
			# If it's already placed, don't show it in inventory
			# Find index in placed_paths and remove it so we can handle duplicates correctly
			placed_paths.erase(path)
			continue
			
		decorations_data.append({
			"path": path,
			"icon": path,
			"actual": GameManager.get_actual_decoration_path(path),
			"category": _get_category_from_path(path),
			"name": path.get_file().replace(".png", "")
		})
	populate_item_list()

func _spawn_placed_decorations():
	for data in SaveManager.placed_decorations:
		var decoration = DECORATION_SCENE.instantiate()
		decorations_container.add_child(decoration)
		var actual_path = GameManager.get_actual_decoration_path(data["path"])
		decoration.texture = load(actual_path)
		decoration.decoration_data = {
			"path": data["path"],
			"icon": data["path"],
			"actual": actual_path,
			"category": data["category"],
			"name": data["path"].get_file().replace(".png", "")
		}
		decoration.global_position = str_to_var(data["pos"])
		decoration.update_touch_area()
		_setup_decoration_signals(decoration)
		decoration.is_placed = true
		decoration.was_placed = true
		placed_decorations.append(decoration)

func _get_category_from_path(path: String) -> String:
	if "cashier_decos" in path: return "cashier_decos"
	if "pc_decos" in path: return "pc_decos"
	if "chair_decos" in path: return "chair_decos_actual"
	if "floors" in path: return "floors"
	if "walls" in path: return "walls"
	if "wall_decos" in path: return "wall_decos"
	if "misc_decos" in path: return "misc_decos"
	return "misc_decos"

func populate_item_list() -> void:
	item_list.clear()
	for data in decorations_data:
		var icon_path = data.get("icon", data.get("path", ""))
		if icon_path == "": continue
		var idx = item_list.add_icon_item(load(icon_path))
		item_list.set_item_metadata(idx, data)
		item_list.set_item_tooltip(idx, data["name"])

func _on_back_pressed():
	_save_placements()
	# Point back button to daily summary as requested
	get_tree().change_scene_to_file("res://ui/daily_summary/daily_summary.tscn")

func _save_placements():
	var save_data = []
	for deco in placed_decorations:
		if is_instance_valid(deco):
			save_data.append({
				"path": deco.decoration_data["path"],
				"pos": var_to_str(deco.global_position),
				"category": deco.decoration_data["category"]
			})
	SaveManager.placed_decorations = save_data
	SaveManager.save_game()

func save_state():
	_save_placements()

func _finish_active_decoration():
	if not is_dragging_item or not active_decoration: return
	
	var deco = active_decoration
	deco.is_dragging = false # Ensure it stops following the mouse
	
	if is_inside_safe_zone(deco):
		# Auto-confirm
		deco.stop_editing()
		if not deco in placed_decorations:
			placed_decorations.append(deco)
		_save_placements()
	else:
		# Auto-cancel if invalid spot
		if deco.was_placed:
			deco.global_position = deco.original_position
			deco.stop_editing()
			_on_decoration_cancelled(deco)
		else:
			_on_decoration_cancelled(deco)
			deco.queue_free()
	
	is_dragging_item = false
	active_decoration = null
	hide_all_safe_zones()

# --- INPUT HANDLING ---

func _unhandled_input(event: InputEvent) -> void:
	if is_dragging_item: return
	handle_camera_input(event)

func _on_item_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var item_idx = item_list.get_item_at_position(event.position)
			if item_idx != -1:
				if is_dragging_item:
					_finish_active_decoration()
				start_dragging_from_list(item_idx)

func start_dragging_from_list(item_idx: int) -> void:
	var data = item_list.get_item_metadata(item_idx)
	
	# Remove from available data
	decorations_data.remove_at(item_idx)
	populate_item_list()
	
	var decoration = DECORATION_SCENE.instantiate()
	decorations_container.add_child(decoration)
	decoration.texture = load(data["actual"])
	decoration.decoration_data = data
	decoration.update_touch_area() # Update size based on texture
	decoration.global_position = get_global_mouse_position()
	
	_setup_decoration_signals(decoration)
	decoration.start_editing()
	# Manually trigger the first drag
	decoration._on_touch_down()

func _setup_decoration_signals(decoration) -> void:
	if not decoration.confirmed.is_connected(_on_decoration_confirmed):
		decoration.confirmed.connect(_on_decoration_confirmed)
	if not decoration.cancelled.is_connected(_on_decoration_cancelled):
		decoration.cancelled.connect(_on_decoration_cancelled)
	if not decoration.returned_to_inventory.is_connected(_on_decoration_returned):
		decoration.returned_to_inventory.connect(_on_decoration_returned)
	if not decoration.drag_started.is_connected(_on_decoration_drag_started):
		decoration.drag_started.connect(_on_decoration_drag_started)
	if not decoration.drag_ended.is_connected(_on_decoration_drag_ended):
		decoration.drag_ended.connect(_on_decoration_drag_ended)

func _on_decoration_confirmed(decoration) -> void:
	# STRICT PLACEMENT CHECK
	if not is_inside_safe_zone(decoration):
		_show_error_feedback(decoration.global_position, "OUTSIDE SAFE ZONE!")
		is_dragging_item = true
		active_decoration = decoration
		return

	decoration.stop_editing()
	is_dragging_item = false
	active_decoration = null
	hide_all_safe_zones()
	if not decoration in placed_decorations:
		placed_decorations.append(decoration)
	
	_save_placements()

func _on_decoration_cancelled(decoration) -> void:
	is_dragging_item = false
	active_decoration = null
	hide_all_safe_zones()
	
	# If it was never placed (newly dragged from list), return to inventory
	if not decoration.was_placed:
		_on_decoration_returned(decoration)
	else:
		_save_placements()

func _on_decoration_returned(decoration) -> void:
	is_dragging_item = false
	active_decoration = null
	hide_all_safe_zones()
	if decoration in placed_decorations:
		placed_decorations.erase(decoration)
	
	# Add back to available data
	decorations_data.append(decoration.decoration_data)
	populate_item_list()
	_save_placements()

func is_inside_safe_zone(decoration) -> bool:
	var category = decoration.decoration_data.get("category", "")
	var global_pos = decoration.global_position
	
	if category == "wall_decos":
		return _is_point_in_polygon_node(global_pos, safe_zone_wall_left) or \
			   _is_point_in_polygon_node(global_pos, safe_zone_wall_right)
	elif category == "chair_decos_actual" or category == "misc_decos":
		return _is_point_in_polygon_node(global_pos, safe_zone)
	
	return _is_point_in_polygon_node(global_pos, safe_zone)

func _is_point_in_polygon_node(global_pos: Vector2, polygon_node: Polygon2D) -> bool:
	if not polygon_node: return true
	var local_pos = polygon_node.to_local(global_pos)
	return Geometry2D.is_point_in_polygon(local_pos, polygon_node.polygon)

func hide_all_safe_zones() -> void:
	safe_zone.hide()
	safe_zone_wall_left.hide()
	safe_zone_wall_right.hide()

func _show_error_feedback(pos: Vector2, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font = load("res://assets/fonts/ThaleahFat.ttf")
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	
	add_child(label)
	label.global_position = pos + Vector2(-150, -150)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 60, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.2).set_delay(0.4)
	tween.finished.connect(label.queue_free)

func _on_decoration_drag_started(decoration) -> void:
	if is_dragging_item and active_decoration != decoration:
		_finish_active_decoration()
		
	is_dragging_item = true
	active_decoration = decoration
	
	var category = decoration.decoration_data.get("category", "")
	if category == "wall_decos":
		safe_zone_wall_left.show()
		safe_zone_wall_right.show()
	elif category == "chair_decos_actual" or category == "misc_decos":
		safe_zone.show()
	else:
		safe_zone.show()

func _on_decoration_drag_ended(_decoration) -> void:
	pass

# --- CAMERA LOGIC (COPIED FROM MAIN) ---

func handle_camera_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
			last_pinch_distance = -1.0
			
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if touches.size() == 1:
			camera.position -= event.relative / camera.zoom
			clamp_camera()
			last_pinch_distance = -1.0
		elif touches.size() == 2:
			var keys = touches.keys()
			var current_dist = touches[keys[0]].distance_to(touches[keys[1]])
			var center_point = (touches[keys[0]] + touches[keys[1]]) / 2.0
			if last_pinch_distance > 0:
				_zoom_camera(current_dist / last_pinch_distance, center_point)
			last_pinch_distance = current_dist

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_camera(1.1, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_camera(0.9, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging_camera = event.pressed
			
	elif event is InputEventMouseMotion and dragging_camera:
		camera.position -= event.relative / camera.zoom
		clamp_camera()

func _zoom_camera(factor: float, center_point: Vector2) -> void:
	var old_zoom = camera.zoom
	var new_zoom_val = clamp(old_zoom.x * factor, min_zoom, max_zoom)
	var new_zoom = Vector2(new_zoom_val, new_zoom_val)
	if old_zoom == new_zoom: return
	
	var vs = get_viewport_rect().size
	var center_offset = center_point - (vs / 2.0)
	var world_pos_before = camera.position + (center_offset / old_zoom)
	camera.zoom = new_zoom
	var world_pos_after = camera.position + (center_offset / new_zoom)
	camera.position += (world_pos_before - world_pos_after)
	clamp_camera()

func clamp_camera() -> void:
	var vs = get_viewport_rect().size
	var view_size = vs / camera.zoom
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
