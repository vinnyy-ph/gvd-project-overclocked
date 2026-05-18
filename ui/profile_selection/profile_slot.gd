extends TextureButton

@onready var name_label = $NameClipper/ProfileNameLabel
@onready var progress_label = $ProgressLabel
@onready var money_label = $MoneyLabel
@onready var slots_label = $PCSlotsLabel

func set_data(data: Dictionary):
	if not data.is_empty():
		name_label.text = str(data.get("player_name", "EMPTY")).to_upper()
		progress_label.text = "DAY " + str(int(data.get("current_day", 1)))
		money_label.text = "P%.1f" % float(data.get("current_money", 0))
		
		var upgrades = data.get("unlocked_upgrades", {})
		var slots = 2 + upgrades.get("shop_space", 0)
		slots_label.text = str(int(slots)) + " UNITs"
	else:
		name_label.text = "EMPTY SLOT"
		progress_label.text = ""
		money_label.text = ""
		slots_label.text = ""

func set_empty():
	name_label.text = "EMPTY SLOT"
	progress_label.text = ""
	money_label.text = ""
	slots_label.text = ""
