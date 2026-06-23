extends CharacterBody2D

@onready var animator: AnimatedSprite2D = $AnimatedSprite2D
@onready var indicator: Label = $Indicator

#Soon!
@export_multiline var dialogue: Array[String] = [
	"YOU!!! Come here!!!!", 
	"WOAH, You are using comic SANS?!", 
	"NICE", 
	"LET'S FIGHT!!!"
	]
	
@export var is_bad: bool = true
@export_file("*.tscn") var next_scene : String = "res://Actual Game Folder/scenes/gameplay.tscn"

@export var enemy_name: String = "Bird Defaultson"
@export var enemy_level: int = 1
@export var reward: String = ""
# 0 = auto (derive a distinct pitch from the name); >0 overrides the dialog voice
@export var voice_pitch: float = 0.0

@export_multiline var post_defeat_dialogue: Array[String] = [
	"You already beat me. Leave me alone."
]
@export var enemy_id: String = ""
var defeated: bool = false

func _ready():
	if animator:
		animator.play("idle_down")
	if enemy_id != "" and Globals.is_enemy_defeated(enemy_id):
		defeated = true
	
func show_indicator():
	if indicator:
		indicator.show()

func hide_indicator():
	if indicator:
		indicator.hide()
		
func get_combat_data() -> Dictionary:
	return {
		"name" : enemy_name,
		"level" : enemy_level,
		"enemy_position": global_position,
		"reward": reward
	}
