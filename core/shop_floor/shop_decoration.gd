extends Sprite2D

signal confirmed(decoration)
signal cancelled(decoration)
signal returned_to_inventory(decoration)
signal drag_started(decoration)
signal drag_ended(decoration)

var decoration_data: Dictionary = {}
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var is_placed: bool = false

@onready var confirm_btn: Button = $UI/MarginContainer/Buttons/ConfirmButton
@onready var cancel_btn: Button = $UI/MarginContainer/Buttons/CancelButton
@onready var inventory_btn: Button = $UI/MarginContainer/Buttons/InventoryButton
@onready var ui_container: Control = $UI

func _ready() -> void:
	# UI should be resolution independent if possible, but for now we just put it on top
	ui_container.hide()
	
	# Add a touch area if not already present
	var area = Button.new()
	area.flat = true
	area.name = "TouchArea"
	add_child(area)
	
	update_touch_area()
	
	area.button_down.connect(_on_touch_down)
	area.button_up.connect(_on_touch_up)

func update_touch_area() -> void:
	var area = get_node_or_null("TouchArea")
	if area and texture:
		area.size = texture.get_size()
		area.position = -area.size / 2.0
		call_deferred("update_ui_position")

func update_ui_position() -> void:
	ui_container.reset_size()
	if texture:
		ui_container.position = Vector2(-ui_container.size.x/2, -texture.get_size().y/2 - 100)

var original_position: Vector2 = Vector2.ZERO
var was_placed: bool = false

func _process(_delta: float) -> void:
	if is_dragging:
		var mouse_pos = get_global_mouse_position()
		global_position = mouse_pos + drag_offset

func start_editing() -> void:
	was_placed = is_placed
	if was_placed:
		original_position = global_position
		inventory_btn.show()
	else:
		inventory_btn.hide()
	
	is_placed = false
	ui_container.show()
	modulate.a = 0.7
	z_index = 100 # Show on top while editing
	call_deferred("update_ui_position")

func stop_editing() -> void:
	is_placed = true
	was_placed = true
	ui_container.hide()
	modulate.a = 1.0
	z_index = 2 # Default for decorations

func _on_touch_down() -> void:
	if is_placed:
		# If already placed, start relocating
		start_editing()
	
	is_dragging = true
	drag_offset = global_position - get_global_mouse_position()
	drag_started.emit(self)

func _on_touch_up() -> void:
	is_dragging = false
	drag_ended.emit(self)
	# Show UI when dropped if not already confirmed
	if not is_placed:
		ui_container.show()
		call_deferred("update_ui_position")

func _on_confirm_pressed() -> void:
	confirmed.emit(self)

func _on_cancel_pressed() -> void:
	if was_placed:
		global_position = original_position
		stop_editing()
		cancelled.emit(self)
	else:
		cancelled.emit(self)
		queue_free()

func _on_inventory_pressed() -> void:
	returned_to_inventory.emit(self)
	queue_free()
