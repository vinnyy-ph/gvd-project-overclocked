extends Control


@onready var max_days_label = $CenterContainer/VBoxContainer/MaxDaysLabel
@onready var lifetime_money_label = $CenterContainer/VBoxContainer/LifetimeMoneyLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	max_days_label.text = "Max Days Survived: " + str(SaveManager.max_days_survived)
	lifetime_money_label.text = "Lifetime Earnings: \u20B1" + str(SaveManager.lifetime_money)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn")
