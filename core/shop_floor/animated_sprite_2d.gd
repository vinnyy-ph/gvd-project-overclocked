extends AnimatedSprite2D

var wander_speed = 100.0
var min_wait_time = 2.0
var max_wait_time = 5.0

# Bounded area for wandering (local coordinates relative to Background parent)
var min_pos = Vector2(-1200, -350)
var max_pos = Vector2(400, 450)

func _ready():
	play("default")
	_start_wandering()

func _start_wandering():
	# Pick a random point in the shop
	var target_pos = Vector2(
		randf_range(min_pos.x, max_pos.x),
		randf_range(min_pos.y, max_pos.y)
	)
	
	# Calculate duration based on distance to maintain constant speed
	var distance = position.distance_to(target_pos)
	var duration = distance / wander_speed
	
	# Flip sprite based on direction
	flip_h = target_pos.x < position.x
	
	play("default")
	
	var tween = create_tween()
	tween.tween_property(self, "position", target_pos, duration).set_trans(Tween.TRANS_LINEAR)
	tween.finished.connect(_on_reached_destination)

func _on_reached_destination():
	stop() # Pause animation while waiting
	var wait_time = randf_range(min_wait_time, max_wait_time)
	get_tree().create_timer(wait_time).timeout.connect(_start_wandering)
