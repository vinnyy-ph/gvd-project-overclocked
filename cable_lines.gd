extends Node2D

@onready var root = $"../.."

func _draw():
	draw_single_cable("red", root.cable_red, Color(0.9, 0.2, 0.2), 6.0)
	draw_single_cable("blue", root.cable_blue, Color(0.2, 0.5, 1.0), 6.0)
	draw_single_cable("green", root.cable_green, Color(0.2, 0.9, 0.4), 6.0)

func draw_single_cable(color_name: String, cable_node: TextureRect, cable_color: Color, width: float):
	var start_point = root.get_left_anchor(color_name)
	var end_point = root.get_cable_tip(cable_node)
	draw_line(start_point, end_point, cable_color, width, true)
