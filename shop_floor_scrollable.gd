extends Node2D

@onready var camera = $MainCamera
@onready var day_label = $CanvasLayer/HUD/DayLabel
@onready var money_label = $CanvasLayer/HUD/MoneyLabel
@onready var satisfaction_label = $CanvasLayer/HUD/SatisfactionLabel
@onready var time_label = $CanvasLayer/HUD/TimeLabel

var scroll_speed: float = 900.0
var time_left: int = 30

var dragging: bool = false
var last_drag_position: Vector2 = Vector2.ZERO

func _ready():
	camera.position = Vector2(1100, 724)
	update_hud()
	clamp_camera()

func _process(delta):
	handle_keyboard_scroll(delta)

func _input(event):
	handle_touch_drag(event)

func handle_keyboard_scroll(delta):
	var move_dir := 0.0

	if Input.is_action_pressed("ui_left"):
		move_dir -= 1.0
	if Input.is_action_pressed("ui_right"):
		move_dir += 1.0

	camera.position.x += move_dir * scroll_speed * delta
	clamp_camera()

func handle_touch_drag(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			dragging = true
			last_drag_position = event.position
		else:
			dragging = false

	elif event is InputEventScreenDrag and dragging:
		var delta_x = event.position.x - last_drag_position.x
		camera.position.x -= delta_x * camera.zoom.x
		last_drag_position = event.position
		clamp_camera()

func clamp_camera():
	var half_screen_width = (get_viewport_rect().size.x * camera.zoom.x) / 2.0
	var min_x = half_screen_width
	var max_x = 3152.0 - half_screen_width
	camera.position.x = clamp(camera.position.x, min_x, max_x)

func update_hud():
	day_label.text = "Day: " + str(GameManager.day)
	money_label.text = "Money: ₱" + str(GameManager.money)
	satisfaction_label.text = "Satisfaction: " + str(GameManager.satisfaction) + "%"
	time_label.text = "Time: " + str(time_left)
