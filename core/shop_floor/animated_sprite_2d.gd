extends AnimatedSprite2D

# Set this to the position of the desk you want him to walk to
var target_pc_position = Vector2(240, 310) 

func _ready():
	walk_to_pc()

func walk_to_pc():
	# We removed the '$' because the script IS the AnimatedSprite2D
	play("default") 
	
	var tween = create_tween()
	# We move 'self' because this node is the character
	tween.tween_property(self, "position", target_pc_position, 2.5)
	tween.finished.connect(_on_arrival)

func _on_arrival():
	stop()
	print("Customer has arrived!")
