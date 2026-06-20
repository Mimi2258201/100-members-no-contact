extends RigidBody2D

# TODO:
# Add collision shape for the player

# Can be part of a power up later
# What's the mechanic like? I'm not sure about the core mechanic right now
# Is player going to control the beyblade? Against who? It could be speedrun type game.

@export var starting_move_strength:float = 30
@export var move_strength_decay:float = 2
#torque is the fancy physics term for rotational force
@export var starting_spin_torque:float = 10000
@export var spin_deceleration:float = 10
@export var sprite : Sprite2D

var move_force_magnitude: float = 20;
var remaining_move_strength: float = starting_move_strength
var spin_torque: float = 10000
var player_died: bool = false

func _physics_process(delta: float) -> void:

	var input_direction = Input.get_vector("left","right","up","down")

	spin_torque -= spin_deceleration
	if(spin_torque < 0):
		spin_torque = 0
		player_died = true
	var multiplier = 1 # counter-clockwise
	if(input_direction.x > 0 || input_direction.y > 0):
		multiplier = -1 # clockwise
	apply_torque(spin_torque * multiplier)

	if remaining_move_strength > 0:
		remaining_move_strength -= delta * move_strength_decay
	else:
		player_died = true
	
	
	
	var current_force = input_direction * move_force_magnitude

	apply_force(current_force * remaining_move_strength)

	pass
