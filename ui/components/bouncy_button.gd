class_name BouncyButton
extends Button # (Change to TextureButton if you are using TextureButtons)

func _ready():
	pivot_offset = size / 2.0
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

func _on_button_down():
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.05).set_trans(Tween.TRANS_SINE)

func _on_button_up():
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
