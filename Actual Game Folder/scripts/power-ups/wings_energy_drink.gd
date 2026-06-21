extends Node2D
class_name wings_energy_power_up
# made by a certain shadowrendkioll dude
# this is a power up thats all you need to know
# there is a little bug where the spin metre
# stays full for a whole three seconds even when moving
# after picking this up

@export var energy_amount: int
@export var player: RigidBody2D

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.has_method("gain_energy"):
		body.gain_energy(energy_amount)
	queue_free()
