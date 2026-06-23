extends StaticBody2D

const SPARKS := preload("res://Actual Game Folder/scenes/components/sparks.tscn")

@export var wall_id: String = "green_field_dungeon"
@export_multiline var dialogue: Array[String] = [
	"Yep, that's a Minnesota alright. Real solid, dontcha know.",
	"Reckon a good spin-dash'd crack 'er wide open, eh."
]

@onready var indicator: Label = $Indicator

func _ready() -> void:
	add_to_group("breakable")
	add_to_group("interactable")
	if Globals.is_wall_broken(wall_id):
		queue_free()

func show_indicator() -> void:
	if indicator:
		indicator.show()

func hide_indicator() -> void:
	if indicator:
		indicator.hide()

func break_wall() -> void:
	if Globals.is_wall_broken(wall_id):
		return
	Globals.mark_wall_broken(wall_id)
	var fx := SPARKS.instantiate()
	get_parent().add_child(fx)
	fx.global_position = global_position
	get_tree().create_timer(0.6).timeout.connect(fx.queue_free)
	queue_free()
