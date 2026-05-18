extends TextureButton

@onready var rank_label = $RankLabel
@onready var rank_label2 = $RankLabel2
@onready var name_label = $NameClipper/ProfileNameLabel
@onready var progress_label = $ProgressLabel
@onready var money_label = $MoneyLabel
@onready var unit_label = $TimeSurvivedLabel # Reusing the label from mockup

func set_data(rank: int, data: Dictionary):
	if rank >= 10:
		rank_label.visible = false
		rank_label2.visible = true
		rank_label2.text = "#" + str(rank)
	else:
		rank_label.visible = true
		rank_label2.visible = false
		rank_label.text = "#" + str(rank)
	
	name_label.text = str(data.get("name", "UNKNOWN")).to_upper()
	progress_label.text = "DAY " + str(data.get("day", 1))
	money_label.text = "P%.1f" % float(data.get("money", 0))
	unit_label.text = str(data.get("pc_slots", 0)) + " UNITs"
