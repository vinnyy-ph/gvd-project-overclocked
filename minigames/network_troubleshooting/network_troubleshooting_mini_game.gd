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
		"fault": "External BGP session is flapping, causing intermittent Web Portal outages.",
		"task": "Re-establish BGP adjacency and propagate SSL route.",
		"steps": [
			{"device": "CustomerPC", "req": "BGP Peer Check", "decoys": ["DHCP Renew", "DNS Flush"]},
			{"device": "OldHub", "req": "Link Stability", "decoys": ["Filter Packets", "Auto-Negotiate"]},
			{"device": "SwitchL2", "req": "VLAN 443 Trunk", "decoys": ["VLAN 10", "STP Block"]},
			{"device": "GuestRouter", "req": "BGP Multi-hop", "decoys": ["NAT Bridge", "WPA3"]},
			{"device": "Router", "req": "BGP Neighbor UP", "decoys": ["Default Route", "RIPv2"]},
			{"device": "Firewall", "req": "Permit TCP 179", "decoys": ["Permit UDP 53", "Block ICMP"]},
			{"device": "MainServer", "req": "SSL Certificate", "decoys": ["Root Login", "SQL Query"]}
		]
	},
	{
		"fault": "The Accounting Department's DB access is blocked by an MTU mismatch.",
		"task": "Standardize MTU and establish MSS Clamping.",
		"steps": [
			{"device": "CustomerPC", "req": "MTU 1500 (Set)", "decoys": ["MTU 9000", "Renew IP"]},
			{"device": "OldHub", "req": "Segment Sync", "decoys": ["Hub Filter", "Repeater"]},
			{"device": "SwitchL2", "req": "VLAN 20 (Acc)", "decoys": ["VLAN 1", "VLAN 50"]},
			{"device": "GuestRouter", "req": "MSS Clamping", "decoys": ["SSID Hide", "WLAN Bridge"]},
			{"device": "Router", "req": "VTI Interface", "decoys": ["LAN Static", "Loopback"]},
			{"device": "Firewall", "req": "PMTUD Allow", "decoys": ["Drop All", "ICMP Block"]},
			{"device": "MainServer", "req": "DB Proxy Sync", "decoys": ["Web Host", "Mail Sync"]},
			{"device": "DatabaseServer", "req": "Port 3306 (SQL)", "decoys": ["Port 80", "Port 22"]}
		]
	},
	{
		"fault": "The Guest WiFi RADIUS server is timing out during authentication.",
		"task": "Route RADIUS traffic through the secure VPN tunnel.",
		"steps": [
			{"device": "CustomerPC", "req": "RADIUS Client", "decoys": ["Web Browser", "FTP Client"]},
			{"device": "GuestRouter", "req": "AAA Config", "decoys": ["AP Bridge", "Static IP"]},
			{"device": "SwitchL2", "req": "RADIUS VLAN 1812", "decoys": ["Data VLAN", "Voice VLAN"]},
			{"device": "OldHub", "req": "Physical Carrier", "decoys": ["Logical Hub", "Broadcast"]},
			{"device": "Router", "req": "IPsec S-to-S", "decoys": ["Default Gateway", "HSRP"]},
			{"device": "Firewall", "req": "Permit UDP 1812", "decoys": ["Permit TCP 80", "Block All"]},
			{"device": "DatabaseServer", "req": "Auth Database", "decoys": ["File Server", "Log Server"]}
		]
	},
	{
		"fault": "High-priority SIP traffic is being dropped by the legacy Hub collisions.",
		"task": "Isolate Voice VLAN and enable DSCP tagging.",
		"steps": [
			{"device": "CustomerPC", "req": "SIP Softphone", "decoys": ["Web Browser", "Terminal"]},
			{"device": "OldHub", "req": "Duplex Upgrade", "decoys": ["Hub Filter", "Auto-MDX"]},
			{"device": "SwitchL2", "req": "DSCP EF (Voice)", "decoys": ["DSCP AF", "Best Effort"]},
			{"device": "GuestRouter", "req": "QoS Reserved", "decoys": ["Rate Limit", "SSID Hide"]},
			{"device": "Router", "req": "Traffic Shaping", "decoys": ["Static Path", "NAT Pool"]},
			{"device": "Firewall", "req": "RTP Port Range", "decoys": ["Block UDP", "Allow HTTP"]},
			{"device": "MainServer", "req": "PBX Handshake", "decoys": ["DNS Query", "FTP Transfer"]}
		]
	},
	{
		"fault": "A rogue DHCP server on the Guest network is causing IP conflicts.",
		"task": "Enable DHCP Snooping and prune untrusted ports.",
		"steps": [
			{"device": "CustomerPC", "req": "IP Conflict Fix", "decoys": ["Flush DNS", "Check Mouse"]},
			{"device": "GuestRouter", "req": "Trusted Interface", "decoys": ["Open Bridge", "DHCP Off"]},
			{"device": "OldHub", "req": "Port Isolation", "decoys": ["Broadcast", "Passive Link"]},
			{"device": "SwitchL2", "req": "DHCP Snooping", "decoys": ["VLAN 1", "STP Protocol"]},
			{"device": "Router", "req": "DHCP Relay (IP)", "decoys": ["Static Route", "BGP Path"]},
			{"device": "Firewall", "req": "DHCP Guard", "decoys": ["MAC Allow", "ICMP Allow"]},
			{"device": "MainServer", "req": "DHCP Master", "decoys": ["Web Master", "Log Master"]}
		]
	},
	{
		"fault": "The primary Database Cluster is unreachable from the DMZ segment.",
		"task": "Configure Cluster VIP and ACL permissions.",
		"steps": [
			{"device": "CustomerPC", "req": "VIP Handshake", "decoys": ["Manual IP", "Loopback"]},
			{"device": "OldHub", "req": "Active Tap", "decoys": ["Drop Tap", "Passive Link"]},
			{"device": "SwitchL2", "req": "LACP Aggreg", "decoys": ["Single Link", "Access Port"]},
			{"device": "GuestRouter", "req": "DMZ Passthrough", "decoys": ["Internal Route", "Captive Portal"]},
			{"device": "Router", "req": "Inter-VLAN Route", "decoys": ["Null Route", "BGP Peer"]},
			{"device": "Firewall", "req": "ACL: Permit DMZ", "decoys": ["ACL: Deny All", "Log Only"]},
			{"device": "DatabaseServer", "req": "Cluster Node 1", "decoys": ["Standalone", "Backup Node"]},
			{"device": "MainServer", "req": "Sync Health", "decoys": ["File Export", "Mail Check"]}
		]
	},
	{
		"fault": "The internal Wiki is failing DNS resolution for mobile VPN users.",
		"task": "Apply DNS Split-Horizon and verify CNAME records.",
		"steps": [
			{"device": "CustomerPC", "req": "Lookup Wiki.int", "decoys": ["Ping 8.8.8.8", "Check IP"]},
			{"device": "GuestRouter", "req": "DNS Forwarding", "decoys": ["DNS Blocking", "WPA3"]},
			{"device": "SwitchL2", "req": "VLAN 53 (DNS)", "decoys": ["VLAN 80", "VLAN 443"]},
			{"device": "OldHub", "req": "Packet Repeat", "decoys": ["Packet Drop", "Collision"]},
			{"device": "Router", "req": "Recursive Lookup", "decoys": ["Static Route", "Default path"]},
			{"device": "Firewall", "req": "DNS Inspect On", "decoys": ["DNS Block", "No Inspect"]},
			{"device": "MainServer", "req": "Split-Horizon", "decoys": ["Public DNS", "No DNS"]}
		]
	},
	{
		"fault": "Legacy POS systems on the Old Hub are triggering broadcast storms.",
		"task": "Isolate legacy hardware and apply storm control.",
		"steps": [
			{"device": "CustomerPC", "req": "POS Handshake", "decoys": ["Web Search", "Email"]},
			{"device": "OldHub", "req": "Half-Duplex Fix", "decoys": ["Full-Duplex", "Auto-MDX"]},
			{"device": "SwitchL2", "req": "Storm Control", "decoys": ["VLAN Trunk", "Mirror Port"]},
			{"device": "GuestRouter", "req": "Legacy Tunnel", "decoys": ["Modern Tunnel", "No Tunnel"]},
			{"device": "Router", "req": "ARP Timeout (High)", "decoys": ["ARP Low", "No ARP"]},
			{"device": "Firewall", "req": "Broadcast Deny", "decoys": ["Broadcast Allow", "ICMP Deny"]},
			{"device": "DatabaseServer", "req": "Legacy DB Sync", "decoys": ["Cloud Sync", "No Sync"]}
		]
	},
	{
		"fault": "The ISP is rate-limiting outbound SMTP traffic on Port 25.",
		"task": "Shift Mail traffic to Port 587 with STARTTLS.",
		"steps": [
			{"device": "MainServer", "req": "SMTP Port 587", "decoys": ["Port 25", "Port 110"]},
			{"device": "DatabaseServer", "req": "User Auth DB", "decoys": ["Root Login", "File Fetch"]},
			{"device": "SwitchL2", "req": "Mail VLAN Prune", "decoys": ["VLAN Allow All", "STP Off"]},
			{"device": "OldHub", "req": "Physical Sync", "decoys": ["Logical Sync", "Broadcast"]},
			{"device": "GuestRouter", "req": "Policy Routing", "decoys": ["Default Path", "WPA2"]},
			{"device": "Firewall", "req": "STARTTLS Inspect", "decoys": ["Plaintext Allow", "Block All"]},
			{"device": "Router", "req": "Outbound Relay", "decoys": ["Inbound Relay", "DNS Relay"]}
		]
	},
	{
		"fault": "VLAN leakage detected between Corporate and IoT segments.",
		"task": "Enforce VLAN Pruning and VTP password sync.",
		"steps": [
			{"device": "CustomerPC", "req": "IoT Scan", "decoys": ["Web Scan", "User Login"]},
			{"device": "GuestRouter", "req": "IoT Isolation", "decoys": ["IoT Bridge", "SSID"]},
			{"device": "OldHub", "req": "Link Isolate", "decoys": ["Link Bridge", "Hub Repeat"]},
			{"device": "SwitchL2", "req": "VTP Password", "decoys": ["VTP Off", "Cleartext"]},
			{"device": "Router", "req": "Sub-Interface", "decoys": ["Loopback", "Null 0"]},
			{"device": "Firewall", "req": "Inter-Zone Deny", "decoys": ["Inter-Zone Allow", "Log All"]},
			{"device": "DatabaseServer", "req": "IoT Data DB", "decoys": ["User DB", "Root DB"]}
		]
	},
	{
		"fault": "External users report SSL handshake failures for the App Server.",
		"task": "Verify Certificate Chain and Load Balancer health.",
		"steps": [
			{"device": "CustomerPC", "req": "HTTPS Request", "decoys": ["HTTP Request", "FTP"]},
			{"device": "Router", "req": "NAT Overload", "decoys": ["Static NAT", "No NAT"]},
			{"device": "Firewall", "req": "TLS Termination", "decoys": ["TLS Pass-thru", "Block TLS"]},
			{"device": "SwitchL2", "req": "LB Health Check", "decoys": ["Port Security", "VLAN 10"]},
			{"device": "OldHub", "req": "Monitor Link", "decoys": ["Link Filter", "Hub Repeat"]},
			{"device": "GuestRouter", "req": "External VIP", "decoys": ["Internal IP", "WPA3"]},
			{"device": "MainServer", "req": "Cert Chain Fix", "decoys": ["Self-Signed", "No Cert"]}
		]
	},
	{
		"fault": "The SAN storage is experiencing high latency across the network.",
		"task": "Configure iSCSI offload and enable Jumbo Frames.",
		"steps": [
			{"device": "DatabaseServer", "req": "iSCSI Target", "decoys": ["SMB Target", "NFS"]},
			{"device": "SwitchL2", "req": "Jumbo Frames On", "decoys": ["MTU 1500", "VLAN 1"]},
			{"device": "OldHub", "req": "Carrier Sync", "decoys": ["Carrier Drop", "Manual"]},
			{"device": "Router", "req": "10G SFP+ Uplink", "decoys": ["1G Copper", "Fast Ethernet"]},
			{"device": "Firewall", "req": "Permit TCP 3260", "decoys": ["Permit TCP 80", "Block All"]},
			{"device": "MainServer", "req": "Storage Mount", "decoys": ["Local Disk", "Cloud Drive"]}
		]
	},
	{
		"fault": "A Spanning Tree loop has crashed the main access layer.",
		"task": "Enable BPDU Guard and set the Root Bridge priority.",
		"steps": [
			{"device": "CustomerPC", "req": "Network Reset", "decoys": ["Log Out", "Check Mouse"]},
			{"device": "OldHub", "req": "Collision Fix", "decoys": ["Broadcast Fix", "Filter On"]},
			{"device": "SwitchL2", "req": "Root Bridge (0)", "decoys": ["Root Bridge (32k)", "STP Off"]},
			{"device": "GuestRouter", "req": "Edge Port Guard", "decoys": ["Bridge Mode", "AP Mode"]},
			{"device": "Router", "req": "VLAN Gateway", "decoys": ["Static Route", "DNS Relay"]},
			{"device": "Firewall", "req": "BPDU Filter", "decoys": ["BPDU Allow", "Log Traffic"]}
		]
	},
	{
		"fault": "Remote admin cannot access the switch via SSH console.",
		"task": "Enable VTY lines and apply RSA keys.",
		"steps": [
			{"device": "CustomerPC", "req": "SSH Client (v2)", "decoys": ["Telnet Client", "Browser"]},
			{"device": "Router", "req": "VTY Access List", "decoys": ["Deny All", "NAT Pool"]},
			{"device": "Firewall", "req": "Allow TCP 22", "decoys": ["Allow UDP 22", "Allow TCP 80"]},
			{"device": "GuestRouter", "req": "Mgmt Gateway", "decoys": ["User Gateway", "WPA2"]},
			{"device": "SwitchL2", "req": "Crypto RSA Key", "decoys": ["Plaintext Pass", "No Key"]},
			{"device": "MainServer", "req": "Mgmt Log Server", "decoys": ["Web Server", "DB Server"]}
		]
	},
	{
		"fault": "The ISP changed the default gateway for the leased line.",
		"task": "Update the Static Route and flush the ARP cache.",
		"steps": [
			{"device": "CustomerPC", "req": "Arp -d *", "decoys": ["Ping 8.8.8.8", "DHCP Renew"]},
			{"device": "OldHub", "req": "Link Reset", "decoys": ["Link Sync", "No Change"]},
			{"device": "GuestRouter", "req": "GW Update (IP)", "decoys": ["SSID Update", "WPA3"]},
			{"device": "Router", "req": "Static Route (0.0.0.0)", "decoys": ["BGP Route", "RIP Route"]},
			{"device": "Firewall", "req": "WAN ACL Update", "decoys": ["LAN ACL", "ICMP Allow"]},
			{"device": "SwitchL2", "req": "Gateway VLAN Fix", "decoys": ["VLAN 10", "VLAN 20"]},
			{"device": "MainServer", "req": "External DNS", "decoys": ["Internal DNS", "No DNS"]}
		]
	},
	{
		"fault": "Corporate users cannot reach the HR portal from the Guest WiFi.",
		"task": "Setup Inter-VLAN routing with stick-on-a-router.",
		"steps": [
			{"device": "CustomerPC", "req": "HR Portal Auth", "decoys": ["Public Search", "Email"]},
			{"device": "GuestRouter", "req": "WiFi Subnet (10.x)", "decoys": ["192.x Subnet", "Bridge"]},
			{"device": "Router", "req": "Router-on-a-Stick", "decoys": ["Bridge-on-Stick", "NAT"]},
			{"device": "SwitchL2", "req": "VLAN 100 (HR)", "decoys": ["VLAN 1", "VLAN 20"]},
			{"device": "OldHub", "req": "Repeater Mode", "decoys": ["Filter Mode", "Off"]},
			{"device": "Firewall", "req": "Zone-Based FW", "decoys": ["Static FW", "No FW"]},
			{"device": "MainServer", "req": "HR Web Node", "decoys": ["Public Node", "DNS Node"]}
		]
	},
	{
		"fault": "The main file share is slow due to NIC teaming failure.",
		"task": "Re-configure LACP and verify Port Channel.",
		"steps": [
			{"device": "MainServer", "req": "NIC Teaming (ON)", "decoys": ["Single NIC", "Cloud"]},
			{"device": "SwitchL2", "req": "Port Channel 1", "decoys": ["Port 1", "VLAN 1"]},
			{"device": "OldHub", "req": "Passive Path", "decoys": ["Active Path", "Broadcast"]},
			{"device": "Router", "req": "High-BW Route", "decoys": ["Low-BW Route", "Default"]},
			{"device": "Firewall", "req": "Allow File Port", "decoys": ["Block Port", "Allow Web"]},
			{"device": "DatabaseServer", "req": "Storage DB Link", "decoys": ["User DB", "Root DB"]}
		]
	},
	{
		"fault": "High-frequency trading app is jittery across segments.",
		"task": "Enable Precision Time Protocol (PTP) sync.",
		"steps": [
			{"device": "CustomerPC", "req": "Trade Client UP", "decoys": ["Web Client", "No Client"]},
			{"device": "OldHub", "req": "Nano-Sync", "decoys": ["Milli-Sync", "No Sync"]},
			{"device": "SwitchL2", "req": "PTP Boundary Clock", "decoys": ["NTP Clock", "Manual"]},
			{"device": "GuestRouter", "req": "Low-Latency Path", "decoys": ["Standard Path", "WPA3"]},
			{"device": "Router", "req": "PTP Master Clock", "decoys": ["Slave Clock", "Manual Time"]},
			{"device": "Firewall", "req": "Permit UDP 319", "decoys": ["Block All", "Permit HTTP"]},
			{"device": "DatabaseServer", "req": "Atomic Time DB", "decoys": ["Local Time", "NTP"]}
		]
	},
	{
		"fault": "Internal server farm is visible to the public internet.",
		"task": "Establish NAT Hairpinning and private addressing.",
		"steps": [
			{"device": "CustomerPC", "req": "Public IP Check", "decoys": ["Private IP", "No IP"]},
			{"device": "Router", "req": "NAT Hairpinning", "decoys": ["NAT Bridge", "Loopback"]},
			{"device": "Firewall", "req": "Strict PAT", "decoys": ["Permit Any", "Deny ICMP"]},
			{"device": "GuestRouter", "req": "Proxy ARP Off", "decoys": ["Proxy ARP On", "SSID Hide"]},
			{"device": "OldHub", "req": "Isolate Segment", "decoys": ["Bridge Segment", "Broadcast"]},
			{"device": "SwitchL2", "req": "Private VLAN", "decoys": ["Community VLAN", "Promiscuous"]},
			{"device": "MainServer", "req": "Internal Node Only", "decoys": ["Public Node", "Cloud"]}
		]
	},
	{
		"fault": "The network core is experiencing packet loss during failover.",
		"task": "Update HSRP priorities and Preempt settings.",
		"steps": [
			{"device": "CustomerPC", "req": "Virtual Gateway", "decoys": ["Physical GW", "No GW"]},
			{"device": "Router", "req": "HSRP Priority 110", "decoys": ["Priority 100", "RIP"]},
			{"device": "Firewall", "req": "Stateful Sync", "decoys": ["Stateless", "No Sync"]},
			{"device": "SwitchL2", "req": "Trunk Load Balance", "decoys": ["Single Trunk", "STP Block"]},
			{"device": "OldHub", "req": "Active Link UP", "decoys": ["Standby Link", "Passive"]},
			{"device": "GuestRouter", "req": "Failover Monitor", "decoys": ["Standard AP", "Bridge"]},
			{"device": "DatabaseServer", "req": "Replicated Node", "decoys": ["Standalone", "No Sync"]}
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
	
	game_timer.wait_time = 1.0
	game_timer.timeout.connect(_on_timer_timeout)
	
	btn_diagnostic.pressed.connect(_on_diagnostic_pressed)
	btn_hint.pressed.connect(_on_hint_pressed)
	btn_hint.text = "GET HINT (-5 seconds)"
	
	choice_a.pressed.connect(func(): _on_config_selected(choice_a.text))
	choice_b.pressed.connect(func(): _on_config_selected(choice_b.text))
	choice_c.pressed.connect(func(): _on_config_selected(choice_c.text))

	for child in devices_container.get_children():
		if child is TextureButton:
			child.pressed.connect(_on_device_pressed.bind(child))

	var state = SaveManager.game_state
	if state.has("net_time_left"):
		time_left = state["net_time_left"]
		current_scenario = state["net_scenario"]
		current_step_index = state["net_step_index"]
		game_active = state["net_game_active"]
		waiting_for_config = state["net_waiting"]
		
		# Restore cables
		for i in range(current_step_index):
			if i < current_scenario["steps"].size() - 1:
				var node_a = devices_container.get_node(current_scenario["steps"][i]["device"])
				var node_b = devices_container.get_node(current_scenario["steps"][i+1]["device"])
				draw_cable(node_a, node_b, color_connected)
				
		if waiting_for_config:
			btn_diagnostic.visible = false
			btn_hint.visible = true
			active_source_node = devices_container.get_node(current_scenario["steps"][current_step_index]["device"])
			active_source_node.modulate = color_selected
			
			var step_data = current_scenario["steps"][current_step_index]
			action_label.text = "> CONFIG REQ for [b]" + step_data["device"] + "[/b]: Select correct parameter."
			link_status_label.text = "[color=#00ff44][b]FAULT:[/b] " + current_scenario["fault"] + "\n[b]TASK:[/b] " + current_scenario["task"] + "[/color]"
			
			protocol_choices.visible = true
			# We don't save the randomized choices order, so we recreate it
			var choices = [step_data["req"]] + step_data["decoys"]
			choices.shuffle()
			choice_a.text = choices[0]
			choice_b.text = choices[1]
			choice_c.text = choices[2]
		elif game_active:
			btn_diagnostic.visible = false
			btn_hint.visible = true
			var next_dev = current_scenario["steps"][current_step_index]["device"]
			link_status_label.text = "[color=#00ff44][b]FAULT:[/b] " + current_scenario["fault"] + "\n[b]TASK:[/b] " + current_scenario["task"] + "[/color]"
			action_label.text = "> Action Req: Select next device: [b]" + next_dev + "[/b]"
		else:
			link_status_label.text = "[color=#ff4444][b]>>> SYSTEM ALERT: SERVICE DISRUPTION[/b][/color]"
			action_label.text = "> Action Required: Run Diagnostic to analyze network topology."
			
		game_timer.start()
	else:
		time_left = GameManager.get_minigame_timer("network")
		time_left += GameManager.get_hardware_time_bonus()
		randomize()
		current_scenario = scenarios[randi() % scenarios.size()]
		link_status_label.text = "[color=#ff4444][b]>>> SYSTEM ALERT: SERVICE DISRUPTION[/b][/color]"
		action_label.text = "> Action Required: Run Diagnostic to analyze network topology."
		game_timer.start()

func save_state():
	var state = SaveManager.game_state
	state["net_time_left"] = time_left
	state["net_scenario"] = current_scenario
	state["net_step_index"] = current_step_index
	state["net_game_active"] = game_active
	state["net_waiting"] = waiting_for_config

func clear_state():
	var state = SaveManager.game_state
	state.erase("net_time_left")
	state.erase("net_scenario")
	state.erase("net_step_index")
	state.erase("net_game_active")
	state.erase("net_waiting")

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
	
	GameManager.last_money_change = GameManager.get_minigame_reward("network") 
	GameManager.last_satisfaction_change = GameManager.get_minigame_satisfaction_gain("network")
	GameManager.money += GameManager.last_money_change
	GameManager.satisfaction = min(GameManager.satisfaction + GameManager.last_satisfaction_change, 100)
	GameManager.save_game()
	
	clear_state()
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://ui/success_screen/success_screen.tscn")

func game_over():
	game_active = false
	game_timer.stop()
	link_status_label.text = "[color=#ff4444][b]>>> CRITICAL FAILURE: PACKET COLLAPSE[/b][/color]"
	action_label.text = "> Connection lost. Network out of sync."
	
	GameManager.last_money_change = -GameManager.get_minigame_deduction("network")
	GameManager.money += GameManager.last_money_change
	
	GameManager.last_satisfaction_change = -GameManager.get_minigame_satisfaction_loss("network")
	GameManager.satisfaction += GameManager.last_satisfaction_change
	GameManager.save_game()
	
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://ui/success_screen/success_screen.tscn")
