extends Control

@onready var timer_label = $TimerLabel
@onready var status_label = $StatusLabel
@onready var line_layer = $DiagramArea/LineLayer

@onready var link_ra = $DiagramArea/LinkButtonsArea/LinkRA
@onready var link_ab = $DiagramArea/LinkButtonsArea/LinkAB
@onready var link_bp2 = $DiagramArea/LinkButtonsArea/LinkBP2
@onready var link_rp1 = $DiagramArea/LinkButtonsArea/LinkRP1
@onready var link_ap1 = $DiagramArea/LinkButtonsArea/LinkAP1

var time_left: int = 20

var active_links := {
	"RA": false,
	"AB": false,
	"BP2": false,
	"RP1": false,
	"AP1": false
}

func _ready():
	link_ra.pressed.connect(func(): toggle_link("RA"))
	link_ab.pressed.connect(func(): toggle_link("AB"))
	link_bp2.pressed.connect(func(): toggle_link("BP2"))
	link_rp1.pressed.connect(func(): toggle_link("RP1"))
	link_ap1.pressed.connect(func(): toggle_link("AP1"))

	update_timer()
	update_status()
	update_button_colors()
	line_layer.queue_redraw()

func toggle_link(link_name: String):
	active_links[link_name] = !active_links[link_name]
	update_status()
	update_button_colors()
	line_layer.queue_redraw()
	check_win()

func update_timer():
	timer_label.text = "Time: " + str(time_left)

func update_status():
	status_label.text = "Goal: Activate the correct route from Router to PC-2"

func update_button_colors():
	set_button_state(link_ra, active_links["RA"])
	set_button_state(link_ab, active_links["AB"])
	set_button_state(link_bp2, active_links["BP2"])
	set_button_state(link_rp1, active_links["RP1"])
	set_button_state(link_ap1, active_links["AP1"])

func set_button_state(button: Button, active: bool):
	if active:
		button.modulate = Color(0.35, 1.0, 0.45, 1.0)
	else:
		button.modulate = Color(1.0, 1.0, 1.0, 1.0)

func check_win():
	if active_links["RA"] and active_links["AB"] and active_links["BP2"] \
	and not active_links["RP1"] and not active_links["AP1"]:
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
