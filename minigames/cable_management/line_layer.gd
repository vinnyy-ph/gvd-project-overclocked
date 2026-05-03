extends Node2D

@onready var root = $"../.."

func _draw():
	draw_link(Vector2(110, 125), Vector2(370, 65), root.active_links["RA"])
	draw_link(Vector2(370, 65), Vector2(650, 175), root.active_links["AB"])
	draw_link(Vector2(650, 175), Vector2(970, 185), root.active_links["BP2"])
	draw_link(Vector2(110, 125), Vector2(970, 65), root.active_links["RP1"])
	draw_link(Vector2(370, 65), Vector2(970, 65), root.active_links["AP1"])

func draw_link(start_point: Vector2, end_point: Vector2, active: bool):
	var color = Color(0.45, 0.45, 0.45, 1.0)
	var width = 5.0

	if active:
		color = Color(0.2, 1.0, 0.4, 1.0)
		width = 8.0

	draw_line(start_point, end_point, color, width, true)
