extends Control

# --- UI Elements ---
@onready var timer_label = $TopPanel/TimerLabel
@onready var link_status_label = $MonitorFrame/MonitorScreenArea/TerminalStatus/VBoxContainer/LinkStatusLabel
@onready var action_label = $MonitorFrame/MonitorScreenArea/TerminalStatus/VBoxContainer/ActionLabel
@onready var game_timer = $GameTimer
@onready var btn_diagnostic = $MonitorFrame/MonitorScreenArea/TerminalStatus/RunDiagnosticBtn
@onready var btn_hint = $MonitorFrame/MonitorScreenArea/TerminalStatus/HintBtn

# --- Choice UI ---
@onready var protocol_choices = $MonitorFrame/MonitorScreenArea/TerminalStatus/ProtocolChoices
@onready var choice_a = $MonitorFrame/MonitorScreenArea/TerminalStatus/ProtocolChoices/ChoiceA
@onready var choice_b = $MonitorFrame/MonitorScreenArea/TerminalStatus/ProtocolChoices/ChoiceB
@onready var choice_c = $MonitorFrame/MonitorScreenArea/TerminalStatus/ProtocolChoices/ChoiceC

# --- Node Containers ---
@onready var cables_container = $MonitorFrame/MonitorScreenArea/NetworkCables
@onready var devices_container = $MonitorFrame/MonitorScreenArea/NetworkDevices

var time_left: int = 90
var game_active: bool = false
var waiting_for_config: bool = false

# --- REALISTIC SCENARIOS ---
# Each scenario has a series of unique steps with specific technical requirements.
var scenarios = [
	{
		"fault": "External clients cannot access the primary Web Portal.",
		"task": "Configure Perimeter DMZ and SSL stack.",
		"steps": [
			{"device": "Router", "req": "Static NAT", "decoys": ["BGP Peering", "DHCP Relay"]},
			{"device": "Firewall", "req": "Allow Port 443", "decoys": ["Allow Port 22", "Block All"]},
			{"device": "MainServer", "req": "SSL Certificate", "decoys": ["Root Login", "SQL Query"]}
		]
	},
	{
		"fault": "Sales PC cannot reach the internal Database for reporting.",
		"task": "Restore LAN access and Database Handshake.",
		"steps": [
			{"device": "CustomerPC", "req": "DHCP Lease", "decoys": ["Static IP", "Loopback"]},
			{"device": "SwitchL2", "req": "VLAN 10 (Sales)", "decoys": ["VLAN 20 (Guest)", "Trunking"]},
			{"device": "Router", "req": "Internal Gateway", "decoys": ["WAN Uplink", "VPN Tunnel"]},
			{"device": "DatabaseServer", "req": "Port 3306 (SQL)", "decoys": ["Port 80 (HTTP)", "Port 25 (SMTP)"]}
		]
	},
	{
		"fault": "Guest users are leaking into the Corporate file server.",
		"task": "Apply VLAN Isolation and Filtering.",
		"steps": [
			{"device": "GuestRouter", "req": "VLAN 50 (Guest)", "decoys": ["VLAN 10 (Prod)", "Native VLAN"]},
			{"device": "Firewall", "req": "Packet Filtering", "decoys": ["Port Forwarding", "DMZ Zone"]},
			{"device": "Router", "req": "ISP Gateway", "decoys": ["Local Bridge", "Static Route"]}
		]
	},
	{
		"fault": "Legacy Database records are timing out during transfer.",
		"task": "Bypass congested Hub and establish FTP path.",
		"steps": [
			{"device": "OldHub", "req": "Broadcast Sync", "decoys": ["Unicast", "IP Mask"]},
			{"device": "SwitchL2", "req": "Uplink Mode", "decoys": ["Access Mode", "PoE Enable"]},
			{"device": "MainServer", "req": "FTP Port 21", "decoys": ["SSH Port 22", "DNS Port 53"]}
		]
	},
	{
		"fault": "Administrator cannot remote into the core router.",
		"task": "Secure Admin Access (SSH) through Perimeter.",
		"steps": [
			{"device": "CustomerPC", "req": "SSH Client", "decoys": ["Telnet Client", "Web Browser"]},
			{"device": "Firewall", "req": "Allow Port 22", "decoys": ["Allow Port 80", "Port 3389"]},
			{"device": "Router", "req": "RSA Public Key", "decoys": ["Guest Login", "Cleartext Pass"]}
		]
	},
	{
		"fault": "Network is blind! DNS resolution is failing.",
		"task": "Route DNS traffic to Name Server.",
		"steps": [
			{"device": "CustomerPC", "req": "DNS 8.8.8.8", "decoys": ["IP 127.0.0.1", "Proxy 8080"]},
			{"device": "SwitchL2", "req": "Spanning Tree", "decoys": ["VLAN 99", "Half Duplex"]},
			{"device": "MainServer", "req": "Port 53 (DNS)", "decoys": ["Port 25 (SMTP)", "Port 110 (POP3)"]}
		]
	}
]

var current_scenario: Dictionary
var current_step_index: int = 0
var active_source_node: TextureButton = null
var pending_destination_node: TextureButton = null

var color_connected = Color(0.1, 1.0, 0.4)    
var color_error = Color(1.0, 0.2, 0.2)        
var color_selected = Color(0.2, 0.6, 1.0)     

func _ready():
	AudioManager.play_bgm("minigame")
	time_left += GameManager.get_hardware_time_bonus()
	
	game_timer.wait_time = 1.0
	game_timer.timeout.connect(_on_timer_timeout)
	game_timer.start()
	
	btn_diagnostic.pressed.connect(_on_diagnostic_pressed)
	btn_hint.pressed.connect(_on_hint_pressed)
	btn_hint.text = "GET HINT (-5 seconds)"
	
	choice_a.pressed.connect(func(): _on_config_selected(choice_a.text))
	choice_b.pressed.connect(func(): _on_config_selected(choice_b.text))
	choice_c.pressed.connect(func(): _on_config_selected(choice_c.text))

	for child in devices_container.get_children():
		if child is TextureButton:
			child.pressed.connect(_on_device_pressed.bind(child))

	randomize()
	current_scenario = scenarios[randi() % scenarios.size()]
	
	link_status_label.text = "[color=#ff4444][b]>>> SYSTEM ALERT: SERVICE DISRUPTION[/b][/color]"
	action_label.text = "> Action Required: Run Diagnostic to analyze network topology."

func _on_diagnostic_pressed():
	btn_diagnostic.visible = false
	btn_hint.visible = true
	link_status_label.text = "[color=#00ff44][b]>>> SCANNING OSI LAYERS...[/b][/color]"
	action_label.text = "> Running deep packet inspection..."
	
	await get_tree().create_timer(1.2).timeout
	
	link_status_label.text = "[color=#00ff44][b]FAULT:[/b] " + current_scenario["fault"] + "\n[b]TASK:[/b] " + current_scenario["task"] + "[/color]"
	var first_dev = current_scenario["steps"][0]["device"]
	action_label.text = "> Action Req: Select START device: [b]" + first_dev + "[/b]"
	
	game_active = true

func _on_device_pressed(clicked_node: TextureButton):
	if not game_active or waiting_for_config: return
	
	# Select current active node (the one we are configuring)
	var expected_dev = current_scenario["steps"][current_step_index]["device"]
	
	if clicked_node.name == expected_dev:
		active_source_node = clicked_node
		clicked_node.modulate = color_selected
		show_config_choices()
	else:
		trigger_network_error("MISALIGNMENT: Logic expects configuration on [b]" + expected_dev + "[/b]")

func show_config_choices():
	waiting_for_config = true
	protocol_choices.visible = true
	
	var step_data = current_scenario["steps"][current_step_index]
	action_label.text = "> CONFIG REQ for [b]" + step_data["device"] + "[/b]: Select correct parameter."
	
	var choices = [step_data["req"]] + step_data["decoys"]
	choices.shuffle()
	
	choice_a.text = choices[0]
	choice_b.text = choices[1]
	choice_c.text = choices[2]

func _on_config_selected(selected_text: String):
	if not waiting_for_config: return
	
	var step_data = current_scenario["steps"][current_step_index]
	
	if selected_text == step_data["req"]:
		# SUCCESS! Configuration applied
		active_source_node.modulate = Color.WHITE
		
		# If there is a next hop, draw a line
		if current_step_index < current_scenario["steps"].size() - 1:
			var next_node_name = current_scenario["steps"][current_step_index + 1]["device"]
			var next_node = devices_container.get_node(next_node_name)
			draw_cable(active_source_node, next_node, color_connected)
			
		active_source_node = null
		protocol_choices.visible = false
		waiting_for_config = false
		
		current_step_index += 1
		
		if current_step_index >= current_scenario["steps"].size():
			win_game()
		else:
			var next_dev = current_scenario["steps"][current_step_index]["device"]
			link_status_label.text = "[color=#00ff44][b]>>> CONFIG APPLIED.[/b] Link segment verified.[/color]"
			action_label.text = "> Action Req: Select next device: [b]" + next_dev + "[/b]"
	else:
		# WRONG CONFIG
		trigger_network_error("CONFIG REJECTED: [b]" + selected_text + "[/b] is invalid for this role.")
		_flash_red(choice_a if selected_text == choice_a.text else (choice_b if selected_text == choice_b.text else choice_c))

func _on_hint_pressed():
	if not game_active or not waiting_for_config: 
		action_label.text = "> HINT: Select the correct device first!"
		return
	
	var step_data = current_scenario["steps"][current_step_index]
	action_label.text = "> HINT: " + step_data["device"] + " requires [color=#ffff00]" + step_data["req"] + "[/color]"
	
	time_left -= 5
	if time_left < 0: time_left = 0
	timer_label.text = "TIME: " + str(time_left)
	_flash_red(timer_label)
	
	if time_left <= 0:
		game_over()

func draw_cable(node_a: TextureButton, node_b: TextureButton, color: Color):
	var line = Line2D.new()
	line.width = 6
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	
	var glow = Line2D.new()
	glow.width = 14
	glow.default_color = color
	glow.default_color.a = 0.2
	
	var pos_a = node_a.position + (node_a.size / 2.0)
	var pos_b = node_b.position + (node_b.size / 2.0)
	
	line.add_point(pos_a)
	line.add_point(pos_b)
	glow.add_point(pos_a)
	glow.add_point(pos_b)
	
	cables_container.add_child(glow)
	cables_container.add_child(line)

func trigger_network_error(msg: String):
	link_status_label.text = "[color=#ff4444]" + msg + "[/color]"
	action_label.text = "> PENALTY: -5 SECONDS"
	
	time_left -= 5
	if time_left < 0: time_left = 0
	timer_label.text = "TIME: " + str(time_left)
	_flash_red(timer_label)
	
	if time_left <= 0:
		game_over()

func _flash_red(node: Control):
	var orig = node.modulate
	node.modulate = Color(1, 0, 0, 1)
	await get_tree().create_timer(0.4).timeout
	node.modulate = orig

func _on_timer_timeout():
	if not game_active: return
	time_left -= 1
	timer_label.text = "TIME: " + str(time_left)
	if time_left <= 0:
		game_over()

func win_game():
	game_active = false
	game_timer.stop()
	AudioManager.play_sfx("coin")
	
	link_status_label.text = "[color=#00ff44][b]>>> HANDSHAKE COMPLETE: NETWORK STABILIZED[/b][/color]"
	action_label.text = "> All hops verified. Routing tables synchronized."
	
	GameManager.last_money_change = GameManager.get_money_reward(50) 
	GameManager.last_satisfaction_change = 30
	GameManager.money += GameManager.last_money_change
	GameManager.satisfaction = min(GameManager.satisfaction + 30, 100)
	GameManager.save_game()
	
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://ui/success_screen/success_screen.tscn")

func game_over():
	game_active = false
	game_timer.stop()
	link_status_label.text = "[color=#ff4444][b]>>> CRITICAL FAILURE: PACKET COLLAPSE[/b][/color]"
	action_label.text = "> Connection lost. Network out of sync."
	
	GameManager.last_money_change = 0
	GameManager.apply_satisfaction_penalty(20)
	GameManager.save_game()
	
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://ui/success_screen/success_screen.tscn")
