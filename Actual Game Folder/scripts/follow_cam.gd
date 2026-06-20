extends Camera2D

@export var target : Node2D
@export var follow_magnitude : float = 2
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	global_position = global_position.lerp(target.global_position,follow_magnitude * delta)
