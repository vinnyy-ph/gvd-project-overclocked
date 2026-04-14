extends Control

@onready var timer_label = $TimerLabel
@onready var status_label = $StatusLabel

@onready var board_panel = $BoardArea/MotherboardPanel

@onready var cpu_slot = $BoardArea/MotherboardPanel/CpuSlot
@onready var ram_slot = $BoardArea/MotherboardPanel/RamSlot
@onready var gpu_slot = $BoardArea/MotherboardPanel/GpuSlot

@onready var cpu_part = $PartsArea/CpuPart
@onready var ram_part = $PartsArea/RamPart
@onready var gpu_part = $PartsArea/GpuPart

var time_left: int = 25
var dragging_node: ColorRect = null
var drag_offset: Vector2 = Vector2.ZERO

var start_positions := {}
var placed := {
	"cpu": false,
	"ram": false,
	"gpu": false
}

func _ready():
	start_positions["cpu"] = cpu_part.position
	start_positions["ram"] = ram_part.position
	start_positions["gpu"] = gpu_part.position

	update_timer()
	update_status()

func update_timer():
	timer_label.text = "Time: " + str(time_left)

func update_status():
	var total_placed = 0
	for key in placed.keys():
		if placed[key]:
			total_placed += 1
	status_label.text = "Placed: " + str(total_placed) + " / 3"

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drag()
			else:
				end_drag()

	elif event is InputEventMouseMotion:
		if dragging_node != null:
			var local_mouse = get_global_mouse_position()
			dragging_node.global_position = local_mouse - drag_offset

func start_drag():
	var mouse_pos = get_global_mouse_position()

	if not placed["cpu"] and is_point_inside_global_rect(mouse_pos, cpu_part):
		dragging_node = cpu_part
		drag_offset = mouse_pos - cpu_part.global_position
	elif not placed["ram"] and is_point_inside_global_rect(mouse_pos, ram_part):
		dragging_node = ram_part
		drag_offset = mouse_pos - ram_part.global_position
	elif not placed["gpu"] and is_point_inside_global_rect(mouse_pos, gpu_part):
		dragging_node = gpu_part
		drag_offset = mouse_pos - gpu_part.global_position

func end_drag():
	if dragging_node == null:
		return

	if dragging_node == cpu_part:
		check_connection("cpu", cpu_part, cpu_slot)
	elif dragging_node == ram_part:
		check_connection("ram", ram_part, ram_slot)
	elif dragging_node == gpu_part:
		check_connection("gpu", gpu_part, gpu_slot)

	dragging_node = null
	update_status()
	check_win()

func check_connection(part_name: String, part: ColorRect, slot: ColorRect):
	if global_rects_overlap(part, slot):
		part.global_position = slot.global_position
		placed[part_name] = true
	else:
		part.position = start_positions[part_name]

func is_point_inside_global_rect(point: Vector2, node: Control) -> bool:
	var rect = Rect2(node.global_position, node.size)
	return rect.has_point(point)

func global_rects_overlap(a: Control, b: Control) -> bool:
	var rect_a = Rect2(a.global_position, a.size)
	var rect_b = Rect2(b.global_position, b.size)
	return rect_a.intersects(rect_b)

func check_win():
	if placed["cpu"] and placed["ram"] and placed["gpu"]:
		GameManager.money += 15
		GameManager.satisfaction += 5
		if GameManager.satisfaction > 100:
			GameManager.satisfaction = 100

		GameManager.last_money_change = 15
		GameManager.last_satisfaction_change = 5
		GameManager.save_game()
		get_tree().change_scene_to_file("res://success_screen.tscn")

func fail_game():
	GameManager.satisfaction -= 10
	if GameManager.satisfaction < 0:
		GameManager.satisfaction = 0

	GameManager.last_money_change = 0
	GameManager.last_satisfaction_change = -10
	GameManager.save_game()
	get_tree().change_scene_to_file("res://success_screen.tscn")

func _on_game_timer_timeout():
	time_left -= 1
	if time_left < 0:
		time_left = 0

	update_timer()

	if time_left == 0:
		fail_game()
