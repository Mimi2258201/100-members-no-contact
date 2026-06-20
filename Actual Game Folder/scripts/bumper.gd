extends Area2D

func _on_body_entered(body: Node2D) -> void:
	var bump_dir = (body.position - position).normalized()
	# Colliding with the bumper sends you back in the opposite direction 
	# the harder you move towards the bumper, the stronger the force in the opposite direction
	body.apply_impulse((-1.2 * body.linear_velocity.dot(bump_dir) + 10) * bump_dir)
