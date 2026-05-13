extends Label

@export var scroll_speed: float = 30.0
@export var pause_duration: float = 2.0

var original_pos: Vector2
var scrolling: bool = false
var timer: float = 0.0
var state: int = 0 # 0: Waiting, 1: Scrolling, 2: Resetting

func _ready():
	original_pos = Vector2.ZERO
	position = original_pos
	
	# Ensure the label doesn't truncate its own text
	autowrap_mode = TextServer.AUTOWRAP_OFF
	text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

func _process(delta):
	var font = get_theme_font("font")
	var font_size = get_theme_font_size("font_size")
	if not font: return
	
	var text_width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	
	# The parent should be the clipping window
	var parent = get_parent()
	if not parent is Control:
		return
		
	var view_width = parent.size.x
	
	# Adjust our own size to fit the text so it renders fully
	size.x = text_width
	
	if text_width <= view_width:
		position = original_pos
		scrolling = false
		return

	if not scrolling:
		scrolling = true
		timer = pause_duration
		state = 0
		return

	match state:
		0: # Waiting at start
			timer -= delta
			if timer <= 0:
				state = 1
		1: # Scrolling
			position.x -= scroll_speed * delta
			# Scroll until the end of the text is visible
			if position.x <= -(text_width - view_width) - 20:
				timer = pause_duration
				state = 2
		2: # Waiting at end
			timer -= delta
			if timer <= 0:
				position = original_pos
				state = 0
