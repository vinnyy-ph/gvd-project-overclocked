extends Control

# --- UI Elements ---
@onready var timer_label = $Background/TopPanel/TimerLabel
@onready var link_status_label = $MonitorScreenArea/TerminalStatus/VBoxContainer/LinkStatusLabel
@onready var action_label = $MonitorScreenArea/TerminalStatus/VBoxContainer/ActionLabel
@onready var game_timer = $GameTimer
@onready var btn_diagnostic = $MonitorScreenArea/TerminalStatus/RunDiagnosticBtn

# --- Node Containers ---
@onready var cables_container = $MonitorScreenArea/NetworkCables
@onready var devices_container = $MonitorScreenArea/NetworkDevices

var time_left: int = 40
var game_active: bool = false

# --- PACKET TRACER VARIABLES ---
var active_source_node: TextureButton = null
var current_route_plan: Array = []
var current_step_index: int = 0

var color_connected = Color(0.1, 0.8, 0.1)    # Green
var color_error = Color(0.9, 0.1, 0.1)        # Red
var color_selected = Color(0.2, 0.6, 1.0)     # Blue

# --- RANDOM SCENARIOS ---
var scenarios = [
	{
		"desc": "> FAULT: Core Network Severed.\n> ROUTE REQ: CustomerPC -> SwitchL2 -> Router -> Firewall -> MainServer",
		"plan": ["CustomerPC", "SwitchL2", "Router", "Firewall", "MainServer"]
	},
	{
		"desc": "> FAULT: Database Unreachable.\n> ROUTE REQ: SwitchL2 -> Router -> MainServer -> DatabaseServer",
		"plan": ["SwitchL2", "Router", "MainServer", "DatabaseServer"]
	},
	{
		"desc": "> FAULT: Secure Direct Line Down.\n> ROUTE REQ: CustomerPC -> SwitchL2 -> Firewall -> DatabaseServer",
		"plan": ["CustomerPC", "SwitchL2", "Firewall", "DatabaseServer"]
	}
]
var current_scenario: Dictionary

func _ready():
	AudioManager.play_bgm("minigame")
	time_left += GameManager.get_hardware_time_bonus()
	# Timer Setup
	game_timer.wait_time = 1.0
	game_timer.one_shot = false 
	if not game_timer.timeout.is_connected(_on_timer_timeout):
		game_timer.timeout.connect(_on_timer_timeout)
	game_timer.start()
	timer_label.text = "TIME: " + str(time_left)

	# Connect the Diagnostic Button
	btn_diagnostic.pressed.connect(_on_diagnostic_pressed)

	# Dynamically connect EVERY device button inside NetworkDevices
	for child in devices_container.get_children():
		if child is TextureButton:
			child.pressed.connect(_on_device_pressed.bind(child))

	# Pick a random scenario right when the game starts
	randomize()
	current_scenario = scenarios[randi() % scenarios.size()]
	current_route_plan = current_scenario["plan"]

	link_status_label.text = "> FATAL ERROR: Topology Wiped."
	action_label.text = "> Action Required: Run Diagnostic to fetch routing table."

# --- DIAGNOSTIC PHASE ---
func _on_diagnostic_pressed():
	btn_diagnostic.visible = false
	link_status_label.text = "> FETCHING ROUTING TABLE..."
	action_label.text = "> Please wait..."
	
	# Simulate the ping test delay
	await get_tree().create_timer(1.0).timeout
	
	# Display the random scenario instructions on the terminal
	link_status_label.text = current_scenario["desc"]
	action_label.text = "> Action Req: Select Source Device to begin cabling."
	
	game_active = true

# --- MANUAL CABLING LOGIC ---
func _on_device_pressed(clicked_node: TextureButton):
	if not game_active: return
	
	# STEP 1: Select a Source
	if active_source_node == null:
		var expected_source_name = current_route_plan[current_step_index]
		
		if clicked_node.name == expected_source_name:
			active_source_node = clicked_node
			clicked_node.modulate = color_selected 
			link_status_label.text = "> SOURCE: " + clicked_node.name + " selected."
			action_label.text = "> Action Req: Select Destination Device."
		else:
			trigger_network_error("INVALID SOURCE: Expected " + expected_source_name)
			
	# STEP 2: Select a Destination (Target)
	else:
		# Cancel selection if they click the exact same device twice
		if clicked_node == active_source_node:
			active_source_node.modulate = Color.WHITE
			active_source_node = null
			link_status_label.text = "> Selection Cancelled."
			action_label.text = "> Action Req: Select Source Device."
			return
			
		var expected_dest_name = current_route_plan[current_step_index + 1]
		
		# Did they click the correct destination?
		if clicked_node.name == expected_dest_name:
			# SUCCESS! Draw the cable.
			draw_cable(active_source_node, clicked_node, color_connected)
			active_source_node.modulate = Color.WHITE 
			active_source_node = null
			
			current_step_index += 1
			
			# Check if the whole route is finished
			if current_step_index >= current_route_plan.size() - 1:
				win_game()
			else:
				link_status_label.text = "> LINK UP: " + expected_dest_name + " connected."
				action_label.text = "> Action Req: Route next hop."
				
		else:
			# FAILED! They plugged into a trap device or the wrong sequence
			active_source_node.modulate = Color.WHITE
			active_source_node = null
			trigger_network_error("ROUTING LOOP DETECTED! Bad connection to " + clicked_node.name)

# --- DYNAMIC LINE DRAWING ---
func draw_cable(node_a: TextureButton, node_b: TextureButton, color: Color):
	var line = Line2D.new()
	line.width = 4
	line.default_color = color
	var pos_a = node_a.position + (node_a.size / 2.0)
	var pos_b = node_b.position + (node_b.size / 2.0)
	
	line.add_point(pos_a)
	line.add_point(pos_b)
	cables_container.add_child(line)

# --- PENALTY SYSTEM ---
func trigger_network_error(msg: String):
	link_status_label.text = "> " + msg
	action_label.text = "> PENALTY: -5 SECONDS"
	
	time_left -= 5
	timer_label.text = "TIME: " + str(time_left)
	timer_label.modulate = color_error
	await get_tree().create_timer(0.5).timeout
	timer_label.modulate = Color.WHITE
	
	if time_left <= 0:
		game_over()

# --- GAME LOOP & TIMER ---
func _on_timer_timeout():
	time_left -= 1
	timer_label.text = "TIME: " + str(time_left)
	if time_left <= 0:
		game_over()

# --- WIN / LOSS INTEGRATED WITH GAME MANAGER ---
func win_game():
	game_active = false
	game_timer.stop()
	AudioManager.play_sfx("success")
	AudioManager.play_sfx("coin")
	
	link_status_label.text = "> Link Status: BGP ROUTES ESTABLISHED"
	action_label.text = "> Action Req: None. Network Restored!"
	
	GameManager.last_money_change = GameManager.get_money_reward(40) 
	GameManager.last_satisfaction_change = 20
	
	GameManager.satisfaction += GameManager.last_satisfaction_change
	if GameManager.satisfaction > 100: GameManager.satisfaction = 100
	GameManager.money += GameManager.last_money_change
	GameManager.save_game()
	
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://success_screen.tscn")

func game_over():
	game_active = false
	game_timer.stop()
	AudioManager.play_sfx("fail")
	
	link_status_label.text = "> CRITICAL ERROR"
	action_label.text = "> CONNECTION TIMEOUT"
	
	GameManager.last_money_change = 0
	GameManager.apply_satisfaction_penalty(15)
	GameManager.save_game()
	
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://shop_floor_scrollable.tscn")
