extends Control

@onready var timer_label = $Background/TopPanel/TimerLabel
@onready var status_label = $Background/TopPanel/StatusLabel
@onready var cable_area = $CableArea

# Sources
@onready var hdmi_source = $CableArea/cable_hdmi
@onready var vga_source = $CableArea/cable_vga
@onready var mic_source = $CableArea/cable_mic
@onready var line_in_source = $CableArea/cable_line_in
@onready var line_out_source = $CableArea/cable_line_out
@onready var power_source = $CableArea/cable_power
@onready var ethernet_source = $CableArea/cable_ethernet

# Heads
@onready var hdmi_head = $CableArea/hdmi_head
@onready var vga_head = $CableArea/vga_head
@onready var mic_head = $CableArea/mic_head
@onready var line_in_head = $CableArea/line_in_head
@onready var line_out_head = $CableArea/line_out_head
@onready var power_head = $CableArea/power_head
@onready var ethernet_head = $CableArea/ethernet_head

# Ports
@onready var port_hdmi = $CableArea/port_hdmi
@onready var port_vga = $CableArea/port_vga
@onready var port_mic = $CableArea/port_mic
@onready var port_line_in = $CableArea/port_line_in
@onready var port_line_out = $CableArea/port_line_out
@onready var port_power = $CableArea/port_power
@onready var port_ethernet = $CableArea/port_ethernet

# Wire Visuals (Inside Folders)
@onready var wire_visual = $CableArea/WireVisuals/WireVisual
@onready var wire_glow = $CableArea/WireGlows/WireGlow
@onready var vga_wire_visual = $CableArea/WireVisuals/VGA_WireVisual
@onready var vga_wire_glow = $CableArea/WireGlows/VGA_WireGlow
@onready var mic_wire_visual = $CableArea/WireVisuals/Mic_WireVisual
@onready var mic_wire_glow = $CableArea/WireGlows/Mic_WireGlow
@onready var line_in_wire_visual = $CableArea/WireVisuals/LineIn_WireVisual
@onready var line_in_wire_glow = $CableArea/WireGlows/LineIn_WireGlow
@onready var line_out_wire_visual = $CableArea/WireVisuals/LineOut_WireVisual
@onready var line_out_wire_glow = $CableArea/WireGlows/LineOut_WireGlow
@onready var power_wire_visual = $CableArea/WireVisuals/Power_WireVisual
@onready var power_wire_glow = $CableArea/WireGlows/Power_WireGlow
@onready var ethernet_wire_visual = $CableArea/WireVisuals/Ethernet_WireVisual
@onready var ethernet_wire_glow = $CableArea/WireGlows/Ethernet_WireGlow

var time_left: int = 30
var dragging_node: Control = null 
var game_active: bool = true

# Dictionary to store data for each cable type
var cable_data = {
	"hdmi": { "source": null, "head": null, "port": null, "visual": null, "glow": null, "connected": false, "source_center": Vector2.ZERO, "head_start_pos": Vector2.ZERO },
	"vga": { "source": null, "head": null, "port": null, "visual": null, "glow": null, "connected": false, "source_center": Vector2.ZERO, "head_start_pos": Vector2.ZERO },
	"mic": { "source": null, "head": null, "port": null, "visual": null, "glow": null, "connected": false, "source_center": Vector2.ZERO, "head_start_pos": Vector2.ZERO },
	"line_in": { "source": null, "head": null, "port": null, "visual": null, "glow": null, "connected": false, "source_center": Vector2.ZERO, "head_start_pos": Vector2.ZERO },
	"line_out": { "source": null, "head": null, "port": null, "visual": null, "glow": null, "connected": false, "source_center": Vector2.ZERO, "head_start_pos": Vector2.ZERO },
	"power": { "source": null, "head": null, "port": null, "visual": null, "glow": null, "connected": false, "source_center": Vector2.ZERO, "head_start_pos": Vector2.ZERO },
	"ethernet": { "source": null, "head": null, "port": null, "visual": null, "glow": null, "connected": false, "source_center": Vector2.ZERO, "head_start_pos": Vector2.ZERO }
}

func _ready():
	AudioManager.play_bgm("minigame")
	
	var state = SaveManager.game_state
	if state.has("cable_time_left"):
		time_left = state["cable_time_left"]
	else:
		time_left += GameManager.get_hardware_time_bonus()
	
	# Link All nodes to dictionary
	cable_data["hdmi"]["source"] = hdmi_source
	cable_data["hdmi"]["head"] = hdmi_head
	cable_data["hdmi"]["port"] = port_hdmi
	cable_data["hdmi"]["visual"] = wire_visual
	cable_data["hdmi"]["glow"] = wire_glow
	
	cable_data["vga"]["source"] = vga_source
	cable_data["vga"]["head"] = vga_head
	cable_data["vga"]["port"] = port_vga
	cable_data["vga"]["visual"] = vga_wire_visual
	cable_data["vga"]["glow"] = vga_wire_glow
	
	cable_data["mic"]["source"] = mic_source
	cable_data["mic"]["head"] = mic_head
	cable_data["mic"]["port"] = port_mic
	cable_data["mic"]["visual"] = mic_wire_visual
	cable_data["mic"]["glow"] = mic_wire_glow
	
	cable_data["line_in"]["source"] = line_in_source
	cable_data["line_in"]["head"] = line_in_head
	cable_data["line_in"]["port"] = port_line_in
	cable_data["line_in"]["visual"] = line_in_wire_visual
	cable_data["line_in"]["glow"] = line_in_wire_glow
	
	cable_data["line_out"]["source"] = line_out_source
	cable_data["line_out"]["head"] = line_out_head
	cable_data["line_out"]["port"] = port_line_out
	cable_data["line_out"]["visual"] = line_out_wire_visual
	cable_data["line_out"]["glow"] = line_out_wire_glow
	
	cable_data["power"]["source"] = power_source
	cable_data["power"]["head"] = power_head
	cable_data["power"]["port"] = port_power
	cable_data["power"]["visual"] = power_wire_visual
	cable_data["power"]["glow"] = power_wire_glow
	
	cable_data["ethernet"]["source"] = ethernet_source
	cable_data["ethernet"]["head"] = ethernet_head
	cable_data["ethernet"]["port"] = port_ethernet
	cable_data["ethernet"]["visual"] = ethernet_wire_visual
	cable_data["ethernet"]["glow"] = ethernet_wire_glow
	
	# Initialize All
	for key in cable_data.keys():
		var data = cable_data[key]
		data["source_center"] = data["source"].position + (data["source"].size / 2.0)
		data["head_start_pos"] = data["head"].position
		
		# Restore connection status if it exists in state
		if state.has("cable_" + key + "_connected"):
			data["connected"] = state["cable_" + key + "_connected"]
			if data["connected"]:
				data["head"].position = data["port"].position + (data["port"].size / 2.0) - data["head"].get_node("TipMarker").position
	
	update_timer()
	update_status()

func save_state():
	var state = SaveManager.game_state
	state["cable_time_left"] = time_left
	for key in cable_data.keys():
		state["cable_" + key + "_connected"] = cable_data[key]["connected"]

func clear_state():
	var state = SaveManager.game_state
	state.erase("cable_time_left")
	for key in cable_data.keys():
		state.erase("cable_" + key + "_connected")

func _process(_delta):
	if not game_active: return
	for key in cable_data.keys():
		update_wire_geometry(key)

func update_wire_geometry(key: String):
	var data = cable_data[key]
	var p0 = data["source_center"]
	var p3 = data["head"].position + data["head"].get_node("TipMarker").position
	
	var p1: Vector2
	var p2: Vector2
	
	if data["connected"]:
		p1 = p0.lerp(p3, 0.33)
		p2 = p0.lerp(p3, 0.66)
	else:
		var dist = p0.distance_to(p3)
		var sag = dist * 0.45
		p1 = p0 + Vector2(dist * 0.25, sag)
		p2 = p3 + Vector2(-dist * 0.25, sag)
	
	var points = PackedVector2Array()
	var steps = 30
	for i in range(steps + 1):
		var t = float(i) / steps
		var q0 = p0.lerp(p1, t)
		var q1 = p1.lerp(p2, t)
		var q2 = p2.lerp(p3, t)
		var r0 = q0.lerp(q1, t)
		var r1 = q1.lerp(q2, t)
		var p = r0.lerp(r1, t)
		points.append(p)
	
	data["visual"].points = points
	data["glow"].points = points

func update_timer():
	timer_label.text = "Time: " + str(time_left)

func update_status():
	var connected_count = 0
	for key in cable_data.keys():
		if cable_data[key]["connected"]:
			connected_count += 1
	status_label.text = "Connected: " + str(connected_count) + " / " + str(cable_data.size())

func _input(event):
	if not game_active: return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drag()
			else:
				end_drag()

	elif event is InputEventMouseMotion:
		if dragging_node != null:
			var local_mouse = cable_area.get_local_mouse_position()
			dragging_node.position = local_mouse - (dragging_node.size / 2.0)

func start_drag():
	var local_mouse = cable_area.get_local_mouse_position()

	for key in cable_data.keys():
		var data = cable_data[key]
		if not data["connected"] and is_point_inside_rect(local_mouse, data["head"].position, data["head"].size):
			dragging_node = data["head"]
			dragging_node.scale = Vector2(1.1, 1.1)
			dragging_node.z_index = 10
			return

func end_drag():
	if dragging_node == null: return

	var current_key = ""
	for key in cable_data.keys():
		if cable_data[key]["head"] == dragging_node:
			current_key = key
			break
	
	var data = cable_data[current_key]
	var tip_pos = dragging_node.position + dragging_node.get_node("TipMarker").position
	var port_rect = Rect2(data["port"].position, data["port"].size).grow(40)
	
	if port_rect.has_point(tip_pos):
		data["connected"] = true
		dragging_node.position = data["port"].position + (data["port"].size / 2.0) - dragging_node.get_node("TipMarker").position
		dragging_node.z_index = 0
		AudioManager.play_sfx("click")
		check_win()
	else:
		var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(dragging_node, "position", data["head_start_pos"], 0.3)
		dragging_node.z_index = 0
	
	dragging_node.scale = Vector2(1.0, 1.0)
	dragging_node = null
	update_status()

func is_point_inside_rect(point: Vector2, rect_pos: Vector2, rect_size: Vector2) -> bool:
	return Rect2(rect_pos, rect_size).has_point(point)

func check_win():
	var all_done = true
	for key in cable_data.keys():
		if not cable_data[key]["connected"]:
			all_done = false
			break
			
	if all_done:
		game_active = false
		AudioManager.play_sfx("coin")
		
		GameManager.last_money_change = GameManager.get_minigame_reward("cable")
		GameManager.last_satisfaction_change = GameManager.get_minigame_satisfaction_gain("cable")
		GameManager.money += GameManager.last_money_change
		GameManager.satisfaction = min(GameManager.satisfaction + GameManager.last_satisfaction_change, 100)
		GameManager.save_game()
		
		clear_state()
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://ui/success_screen/success_screen.tscn")

func _on_game_timer_timeout():
	if not game_active: return
	time_left -= 1
	if time_left < 0: time_left = 0
	update_timer()

	if time_left == 0:
		game_active = false
		
		GameManager.last_money_change = -GameManager.get_minigame_deduction("cable")
		GameManager.money += GameManager.last_money_change
		
		GameManager.last_satisfaction_change = -GameManager.get_minigame_satisfaction_loss("cable")
		GameManager.satisfaction += GameManager.last_satisfaction_change
		GameManager.save_game()
		clear_state()
		get_tree().change_scene_to_file("res://ui/success_screen/success_screen.tscn")
