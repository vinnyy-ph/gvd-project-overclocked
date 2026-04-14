extends Control

@onready var timer_label = $TimerLabel
@onready var status_label = $StatusLabel
@onready var cable_area = $CableArea
@onready var cable_lines = $CableArea/CableLines

@onready var cable_red = $CableArea/CableRed
@onready var cable_blue = $CableArea/CableBlue
@onready var cable_green = $CableArea/CableGreen

@onready var port_red = $CableArea/PortRed
@onready var port_blue = $CableArea/PortBlue
@onready var port_green = $CableArea/PortGreen

var time_left: int = 20
var dragging_node: ColorRect = null
var drag_offset: Vector2 = Vector2.ZERO

var start_positions := {}
var connected := {
	"red": false,
	"blue": false,
	"green": false
}

func _ready():
	start_positions["red"] = cable_red.position
	start_positions["blue"] = cable_blue.position
	start_positions["green"] = cable_green.position

	update_timer()
	update_status()

func update_timer():
	timer_label.text = "Time: " + str(time_left)

func update_status():
	var total_connected = 0
	for key in connected.keys():
		if connected[key]:
			total_connected += 1
	status_label.text = "Connected: " + str(total_connected) + " / 3"

func _process(_delta):
	cable_lines.queue_redraw()

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drag()
			else:
				end_drag()

	elif event is InputEventMouseMotion:
		if dragging_node != null:
			var local_mouse = cable_area.get_local_mouse_position()
			dragging_node.position = local_mouse - drag_offset
			cable_lines.queue_redraw()

func start_drag():
	var local_mouse = cable_area.get_local_mouse_position()

	if not connected["red"] and is_point_inside_rect(local_mouse, cable_red.position, cable_red.size):
		dragging_node = cable_red
		drag_offset = local_mouse - cable_red.position
	elif not connected["blue"] and is_point_inside_rect(local_mouse, cable_blue.position, cable_blue.size):
		dragging_node = cable_blue
		drag_offset = local_mouse - cable_blue.position
	elif not connected["green"] and is_point_inside_rect(local_mouse, cable_green.position, cable_green.size):
		dragging_node = cable_green
		drag_offset = local_mouse - cable_green.position

func end_drag():
	if dragging_node == null:
		return

	if dragging_node == cable_red:
		check_connection("red", cable_red, port_red)
	elif dragging_node == cable_blue:
		check_connection("blue", cable_blue, port_blue)
	elif dragging_node == cable_green:
		check_connection("green", cable_green, port_green)

	dragging_node = null
	update_status()
	check_win()
	cable_lines.queue_redraw()

func check_connection(color_name: String, cable: ColorRect, port: ColorRect):
	if rects_overlap(cable, port):
		cable.position = port.position
		connected[color_name] = true
	else:
		cable.position = start_positions[color_name]

func rects_overlap(a: ColorRect, b: ColorRect) -> bool:
	var rect_a = Rect2(a.position, a.size)
	var rect_b = Rect2(b.position, b.size)
	return rect_a.intersects(rect_b)

func is_point_inside_rect(point: Vector2, rect_pos: Vector2, rect_size: Vector2) -> bool:
	return point.x >= rect_pos.x and point.x <= rect_pos.x + rect_size.x \
		and point.y >= rect_pos.y and point.y <= rect_pos.y + rect_size.y

func get_left_anchor(color_name: String) -> Vector2:
	var pos = start_positions[color_name]
	return pos + Vector2(-30, 20)

func get_cable_tip(cable: ColorRect) -> Vector2:
	return cable.position + Vector2(cable.size.x, cable.size.y / 2.0)

func check_win():
	if connected["red"] and connected["blue"] and connected["green"]:
		GameManager.money += 15
		GameManager.satisfaction += 5
		if GameManager.satisfaction > 100:
			GameManager.satisfaction = 100

		GameManager.last_money_change = 15
		GameManager.last_satisfaction_change = 5
		GameManager.save_game()
		get_tree().change_scene_to_file("res://success_screen.tscn")

func _on_game_timer_timeout():
	time_left -= 1
	if time_left < 0:
		time_left = 0

	update_timer()

	if time_left == 0:
		GameManager.satisfaction -= 10
		if GameManager.satisfaction < 0:
			GameManager.satisfaction = 0

		GameManager.last_money_change = 0
		GameManager.last_satisfaction_change = -10
		GameManager.save_game()
		get_tree().change_scene_to_file("res://success_screen.tscn")
