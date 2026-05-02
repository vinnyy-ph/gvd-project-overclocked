extends Control

# --- UI Elements ---
@onready var timer_label = $Background/TopPanel/TimerLabel
@onready var link_status_label = $MonitorScreenArea/TerminalStatus/VBoxContainer/LinkStatusLabel
@onready var action_label = $MonitorScreenArea/TerminalStatus/VBoxContainer/ActionLabel
@onready var game_timer = $GameTimer
@onready var btn_diagnostic = $MonitorScreenArea/RunDiagnosticBtn

# --- Cables (Line2D) ---
@onready var line_pc_sw = $MonitorScreenArea/NetworkCables/Line_PC_SW
@onready var line_sw_rt = $MonitorScreenArea/NetworkCables/Line_SW_RT
@onready var line_rt_fw = $MonitorScreenArea/NetworkCables/Line_RT_FW
@onready var line_fw_sv = $MonitorScreenArea/NetworkCables/Line_FW_SV
@onready var line_sv_db = $MonitorScreenArea/NetworkCables/Line_SV_DB

# --- Devices (TextureButtons) ---
@onready var btn_pc = $MonitorScreenArea/NetworkDevices/CustomerPC
@onready var btn_switch = $MonitorScreenArea/NetworkDevices/SwitchL2
@onready var btn_router = $MonitorScreenArea/NetworkDevices/Router
@onready var btn_firewall = $MonitorScreenArea/NetworkDevices/Firewall
@onready var btn_server = $MonitorScreenArea/NetworkDevices/MainServer
@onready var btn_db = $MonitorScreenArea/NetworkDevices/DatabaseServer

# --- GAME LOGIC VARIABLES ---
var time_left: int = 30 # Increased time because the network is larger!
var diagnostics_run: bool = false
var active_selection: String = ""
var device_clicks_left: int = 3 

# Colors
var color_unknown = Color(0.4, 0.4, 0.4)      # Gray
var color_disconnected = Color(0.8, 0.1, 0.1) # Red
var color_connected = Color(0.1, 0.8, 0.1)    # Green

# --- FAULT SYSTEM ---
enum FaultType {
	CABLE_ROUTER_FIREWALL,
	CABLE_SERVER_DB,
	FIREWALL_BLOCK,
	ROUTER_HANG
}
var current_fault: int

func _ready():
	# 1. Timer Setup
	game_timer.wait_time = 1.0
	game_timer.one_shot = false 
	if not game_timer.timeout.is_connected(_on_timer_timeout):
		game_timer.timeout.connect(_on_timer_timeout)
	game_timer.start()
	timer_label.text = "TIME: " + str(time_left)

	# 2. Set all lines to gray initially
	line_pc_sw.default_color = color_unknown
	line_sw_rt.default_color = color_unknown
	line_rt_fw.default_color = color_unknown
	line_fw_sv.default_color = color_unknown
	line_sv_db.default_color = color_unknown

	# 3. Connect the Diagnostic Button
	btn_diagnostic.pressed.connect(_on_diagnostic_pressed)

	# 4. Connect all devices using advanced Godot 4 .bind()
	# This sends the name of the device directly to the function when clicked!
	btn_pc.pressed.connect(_on_device_pressed.bind("PC"))
	btn_switch.pressed.connect(_on_device_pressed.bind("SWITCH"))
	btn_router.pressed.connect(_on_device_pressed.bind("ROUTER"))
	btn_firewall.pressed.connect(_on_device_pressed.bind("FIREWALL"))
	btn_server.pressed.connect(_on_device_pressed.bind("SERVER"))
	btn_db.pressed.connect(_on_device_pressed.bind("DATABASE"))

	# 5. Generate Random Scenario
	randomize()
	current_fault = randi() % 4
	
	link_status_label.text = "> SYSTEM STATUS: UNKNOWN"
	action_label.text = "> Action Required: Run Ping Diagnostic."

# --- DIAGNOSTIC PHASE ---
func _on_diagnostic_pressed():
	btn_diagnostic.visible = false
	link_status_label.text = "> TRACEROUTE INITIATED..."
	action_label.text = "> Please wait. Pinging nodes..."
	
	# Simulate network scan sweep (Async await)
	await get_tree().create_timer(0.5).timeout
	line_pc_sw.default_color = color_connected
	line_sw_rt.default_color = color_connected
	
	await get_tree().create_timer(0.5).timeout
	
	# Reveal the specific fault
	if current_fault == FaultType.CABLE_ROUTER_FIREWALL:
		line_rt_fw.default_color = color_disconnected
		line_fw_sv.default_color = color_unknown
		line_sv_db.default_color = color_unknown
		link_status_label.text = "> PING: Request timed out at Router."
		action_label.text = "> DIAGNOSTIC: Cable severed between Router and Firewall."
		
	elif current_fault == FaultType.CABLE_SERVER_DB:
		line_rt_fw.default_color = color_connected
		line_fw_sv.default_color = color_connected
		line_sv_db.default_color = color_disconnected
		link_status_label.text = "> PING: Database unreachable from Main Server."
		action_label.text = "> DIAGNOSTIC: Cable severed between Main Server and DB."
		
	elif current_fault == FaultType.FIREWALL_BLOCK:
		line_rt_fw.default_color = color_connected
		line_fw_sv.default_color = color_connected
		line_sv_db.default_color = color_connected
		link_status_label.text = "> PING: Packets dropped by Security Gateway."
		action_label.text = "> DIAGNOSTIC: Firewall ports locked. Click Firewall x3 to flush rules."
		
	elif current_fault == FaultType.ROUTER_HANG:
		line_rt_fw.default_color = color_connected
		line_fw_sv.default_color = color_connected
		line_sv_db.default_color = color_connected
		link_status_label.text = "> PING: Router CPU at 100% (Kernel Panic)."
		action_label.text = "> DIAGNOSTIC: Router frozen. Click Router x3 to hard reboot."

	diagnostics_run = true # Unlocks the devices so the player can fix it


# --- INTERACTION LOGIC ---
func _on_device_pressed(device: String):
	# Don't let them click anything until the diagnostic is finished!
	if not diagnostics_run: return
	
	match current_fault:
		
		# FAULT 1: Broken Router -> Firewall Cable
		FaultType.CABLE_ROUTER_FIREWALL:
			if active_selection == "" and device == "ROUTER":
				active_selection = "ROUTER"
				link_status_label.text = "> Link Status: Router Selected"
				action_label.text = "> Action Required: Click FIREWALL to route new cable."
			elif active_selection == "ROUTER" and device == "FIREWALL":
				line_rt_fw.default_color = color_connected
				win_game()
			else:
				active_selection = "" # Reset on wrong click
				
		# FAULT 2: Broken Server -> Database Cable
		FaultType.CABLE_SERVER_DB:
			if active_selection == "" and device == "SERVER":
				active_selection = "SERVER"
				link_status_label.text = "> Link Status: Main Server Selected"
				action_label.text = "> Action Required: Click DATABASE to route new cable."
			elif active_selection == "SERVER" and device == "DATABASE":
				line_sv_db.default_color = color_connected
				win_game()
			else:
				active_selection = ""
				
		# FAULT 3: Firewall Block
		FaultType.FIREWALL_BLOCK:
			if device == "FIREWALL":
				device_clicks_left -= 1
				if device_clicks_left <= 0:
					win_game()
				else:
					link_status_label.text = "> FLUSHING RULES... (" + str(3 - device_clicks_left) + "/3)"
			
		# FAULT 4: Router Hang
		FaultType.ROUTER_HANG:
			if device == "ROUTER":
				device_clicks_left -= 1
				if device_clicks_left <= 0:
					win_game()
				else:
					link_status_label.text = "> REBOOTING ROUTER... (" + str(3 - device_clicks_left) + "/3)"

# --- GAME LOOP & TIMER ---
func _on_timer_timeout():
	time_left -= 1
	timer_label.text = "TIME: " + str(time_left)
	if time_left <= 0:
		game_over()

# --- WIN / LOSS INTEGRATED WITH GAME MANAGER ---
func win_game():
	game_timer.stop()
	diagnostics_run = false # Locks devices so they can't be clicked anymore
	
	link_status_label.text = "> Link Status: ALL SYSTEMS NOMINAL"
	action_label.text = "> Action Required: None. Network Restored!"
	
	GameManager.last_money_change = 30
	GameManager.last_satisfaction_change = 15
	
	GameManager.satisfaction += GameManager.last_satisfaction_change
	if GameManager.satisfaction > 100: GameManager.satisfaction = 100
	GameManager.money += GameManager.last_money_change
	GameManager.save_game()
	
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://success_screen.tscn")

func game_over():
	game_timer.stop()
	diagnostics_run = false
	
	link_status_label.text = "> CRITICAL ERROR"
	action_label.text = "> CONNECTION TIMEOUT"
	
	GameManager.last_money_change = 0
	GameManager.last_satisfaction_change = -15
	
	GameManager.satisfaction += GameManager.last_satisfaction_change
	if GameManager.satisfaction < 0: GameManager.satisfaction = 0
	GameManager.save_game()
	
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://shop_floor_scrollable.tscn")
