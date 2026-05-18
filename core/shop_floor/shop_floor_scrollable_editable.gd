extends Node2D

@onready var camera: Camera2D = $MainCamera
@onready var item_list: ItemList = $CanvasLayer/ItemList
@onready var decorations_container: Node2D = $World/Background/DecorationsContainer
@onready var safe_zone: Polygon2D = $World/Background/SafeZoneShopFloor
@onready var safe_zone_wall_left: Polygon2D = $World/Background/SafeZoneShopFloor2
@onready var safe_zone_wall_right: Polygon2D = $World/Background/SafeZoneShopFloor3

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

	# Initial scan of all decorations
	decorations_data = get_all_decorations()
	populate_item_list()
	
	# Connect ItemList signals
	item_list.gui_input.connect(_on_item_list_gui_input)

func populate_item_list() -> void:
	item_list.clear()
	for data in decorations_data:
		var idx = item_list.add_icon_item(load(data["icon"]))
		item_list.set_item_metadata(idx, data)
		item_list.set_item_tooltip(idx, data["name"])

func get_all_decorations() -> Array:
	var list = []
	var base_path = "res://assets/images/shop_decorations_actual/"
	var dir = DirAccess.open(base_path)
	if dir:
		dir.list_dir_begin()
		var category = dir.get_next()
		while category != "":
			if dir.current_is_dir() and category != "." and category != "..":
				var category_path = base_path + category + "/"
				var cat_dir = DirAccess.open(category_path)
				if cat_dir:
					cat_dir.list_dir_begin()
					var file_name = cat_dir.get_next()
					while file_name != "":
						if file_name.ends_with(".png") and not file_name.ends_with(".import"):
							var icon_path = category_path + file_name
							list.append({
								"name": file_name.replace(".png", ""),
								"icon": icon_path,
								"actual": icon_path,
								"category": category
							})
						file_name = cat_dir.get_next()
			category = dir.get_next()
	return list

# --- INPUT HANDLING ---

func _unhandled_input(event: InputEvent) -> void:
	if is_dragging_item: return
	handle_camera_input(event)

func _on_item_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var item_idx = item_list.get_item_at_position(event.position)
			if item_idx != -1:
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

func _on_decoration_cancelled(decoration) -> void:
	is_dragging_item = false
	active_decoration = null
	hide_all_safe_zones()
	
	# If it was never placed (newly dragged from list), return to inventory
	if not decoration.was_placed:
		_on_decoration_returned(decoration)

func _on_decoration_returned(decoration) -> void:
	is_dragging_item = false
	active_decoration = null
	hide_all_safe_zones()
	if decoration in placed_decorations:
		placed_decorations.erase(decoration)
	
	# Add back to available data
	decorations_data.append(decoration.decoration_data)
	populate_item_list()

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
