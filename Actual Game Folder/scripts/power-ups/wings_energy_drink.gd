extends Node2D
class_name wings_energy_power_up
# --- summary ---
# made by a certain shadowrendkioll dude
# this is a power up thats all you need to know
# make the variables be exported for ease of use

# ----bugs------
# there is a little bug where the spin metre
# stays full for a whole three seconds even when moving
# after picking this up

@export var spin_speed: float
@export var energy_amount: int
@export var player: RigidBody2D

func _physics_process(delta: float) -> void:
	rotation += spin_speed * delta

# sees if the body has the ability to gain energy
# can be used to stop objects from taking the energy meant for the player
# it would be cool to see enemies taking this energy powerup as well 
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.has_method("gain_energy"):
		body.gain_energy(energy_amount)
	queue_free()
