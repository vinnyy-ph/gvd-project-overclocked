extends Label

func _ready() -> void:
	# Start animation if text is already set
	if text != "":
		display_text(text)

func display_text(new_text: String) -> void:
	text = new_text
	visible_ratio = 0.0
	var tween := create_tween()
	var duration := text.length() * 0.05 # 20 characters per second
	tween.tween_property(self, "visible_ratio", 1.0, duration)
