extends Control

signal confirmed
signal cancelled

@onready var price_label = $PriceLabel
@onready var yes_button = $TextureRect/Yes
@onready var no_button = $TextureRect/No

func _ready() -> void:
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)
	
	# Ensure the background covers everything
	$DimBackground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func set_price(price: String) -> void:
	price_label.text = price

func _on_yes_pressed() -> void:
	confirmed.emit()
	queue_free()

func _on_no_pressed() -> void:
	cancelled.emit()
	queue_free()
