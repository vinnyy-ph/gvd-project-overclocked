extends Label

signal animation_finished

var is_animating: bool = false
var _current_tween: Tween

func _ready() -> void:
	# Start animation if text is already set
	if text != "":
		display_text(text)

func display_text(new_text: String) -> void:
	text = new_text
	visible_ratio = 0.0
	is_animating = true
	
	if _current_tween:
		_current_tween.kill()
		
	_current_tween = create_tween()
	var duration := text.length() * 0.05 # 20 characters per second
	_current_tween.tween_property(self, "visible_ratio", 1.0, duration)
	_current_tween.finished.connect(_on_animation_finished)

func skip_animation() -> void:
	if not is_animating: return
	
	if _current_tween:
		_current_tween.kill()
	
	visible_ratio = 1.0
	_on_animation_finished()

func _on_animation_finished() -> void:
	is_animating = false
	animation_finished.emit()
