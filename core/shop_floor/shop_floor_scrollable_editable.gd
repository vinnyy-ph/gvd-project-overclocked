extends Node2D

@onready var camera: Camera2D = $MainCamera
@onready var item_list: ItemList = $CanvasLayer/ItemList
@onready var decorations_container: Node2D = $World/Background/DecorationsContainer

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

func _ready() -> void:
	# Initial camera setup
	camera.position = Vector2(1532, 704)
	var vs = get_viewport_rect().size
	min_zoom = min(vs.x / SCENE_SIZE.x, vs.y / SCENE_SIZE.y)
	camera.zoom = Vector2(max(min_zoom, 0.5), max(min_zoom, 0.5))
	clamp_camera()

	# Populate ItemList
	populate_item_list()
	
	# Connect ItemList signals
	item_list.gui_input.connect(_on_item_list_gui_input)

func populate_item_list() -> void:
	item_list.clear()
	decorations_data = get_all_decorations()
	
	for data in decorations_data:
		var idx = item_list.add_icon_item(load(data["icon"]))
		item_list.set_item_metadata(idx, data)
		item_list.set_item_tooltip(idx, data["name"])

func get_all_decorations() -> Array:
	var list = []
	var base_path = "res://assets/images/shop_decorations/"
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
							var actual_path = find_actual_sprite(category, file_name)
							list.append({
								"name": file_name.replace(".png", ""),
								"icon": icon_path,
								"actual": actual_path
							})
						file_name = cat_dir.get_next()
			category = dir.get_next()
	return list

func find_actual_sprite(category: String, file_name: String) -> String:
	var actual_base = "res://assets/images/shop_decorations_actual/"
	var cat_map = {
		"cashier_decos": "cashier_actual",
		"chair_decos": "chair_decos_actual",
		"misc_decos": "misc_decos",
		"wall_decos": "wall_decos"
	}
	
	var mapped_cat = cat_map.get(category, category)
	var path = actual_base + mapped_cat + "/" + file_name
	if FileAccess.file_exists(path):
		return path
	
	return "res://assets/images/shop_decorations/" + category + "/" + file_name

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
	var decoration = DECORATION_SCENE.instantiate()
	decorations_container.add_child(decoration)
	decoration.texture = load(data["actual"])
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
	if not decoration.drag_started.is_connected(_on_decoration_drag_started):
		decoration.drag_started.connect(_on_decoration_drag_started)
	if not decoration.drag_ended.is_connected(_on_decoration_drag_ended):
		decoration.drag_ended.connect(_on_decoration_drag_ended)

func _on_decoration_confirmed(decoration) -> void:
	is_dragging_item = false
	active_decoration = null
	# Ensure the decoration is properly set up if it was a new one
	_setup_decoration_signals(decoration)

func _on_decoration_cancelled(_decoration) -> void:
	is_dragging_item = false
	active_decoration = null

func _on_decoration_drag_started(decoration) -> void:
	is_dragging_item = true
	active_decoration = decoration

func _on_decoration_drag_ended(_decoration) -> void:
	# Note: we don't set is_dragging_item = false here 
	# because the user might still be in "editing mode" (confirm/cancel visible)
	# and we might want to block camera movement during that.
	# But if we want to allow camera movement between drags of the same item, 
	# we could set it to false.
	# The user said "Confirm will place that item ... while cancel will make the items return"
	# So while Confirm/Cancel are visible, it's still "active".
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
