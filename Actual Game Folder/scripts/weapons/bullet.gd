extends Sprite2D

var direction: Vector2 = Vector2(1.0, 0.0)
var velocity = 240.0
var lifetime = 2.0
var lifetime_timer = 0.0
var damage = 4.0

func _physics_process(delta: float) -> void:

	# Aint nuthin last foreva
	lifetime_timer += delta
	if lifetime_timer >= lifetime:
		queue_free()
		return

	# Query space for collisions
	var dss := get_world_2d().direct_space_state
	var pms := PhysicsRayQueryParameters2D.new()
	pms.from = position
	pms.to = position + direction * velocity * delta
	var res := dss.intersect_ray(pms)

	# No collisions, advance
	if res.is_empty():
		position = pms.to
		return

	# Collisions
	queue_free() # This for sure unless you want piercing, bouncing, forking...

	var collider = res["collider"]

	# If it's a player
	if collider.is_in_group("player"):
		collider.take_damage(damage)

	# If it's an enemy
	if collider.is_in_group("horde_enemy"):
		collider.take_damage(damage)
