extends CharacterBody2D

@onready var indicator: Label = $Indicator

@export_multiline var dialogue: Array[String] = [
	"My trusty Beyblade. Better not leave home without it."
]

@export var is_pickup: bool = true

func show_indicator():
	if indicator:
		indicator.show()

func hide_indicator():
	if indicator:
		indicator.hide()
