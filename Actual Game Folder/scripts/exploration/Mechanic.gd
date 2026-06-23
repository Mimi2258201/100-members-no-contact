extends CharacterBody2D

#This the mechanic where you equip your beyblade for battle (Please change sprite)
@onready var indicator: Label = $Indicator

#Soon!
@export_multiline var dialogue: Array[String] = [
	"Welcome to the Garage™",
	"Here on the Garage™ you can upgrade your Spinblade to become stronger",
	"Lets get to it!"
	]
	
@export var is_bad: bool = false
@export var is_mechanic: bool = true
@export_file("*.tscn") var next_scene: String = "res://Actual Game Folder/scenes/garage.tscn"

@export var enemy_name: String = "Mechanic"
@export var enemy_level: int = 1

	
func show_indicator():
	if indicator:
		indicator.show()

func hide_indicator():
	if indicator:
		indicator.hide()
		
func get_combat_data() -> Dictionary:
	return {
		"name": enemy_name,
		"level": enemy_level,
		"enemy_position": global_position
	}
