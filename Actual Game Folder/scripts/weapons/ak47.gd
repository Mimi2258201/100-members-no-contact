extends Sprite2D


var target_node = null
var target_poll_timer = 0.0
var fire_wait = 0.35
var flash_duration = 0.05
var fire_timer = 0.0
var flash_timer = 0.0
var last_flash = 0
var dadi: Node2D = null

const FIRE_RANGE = 400.0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	dadi = get_parent()
	dadi.tree_exiting.connect(func():
		queue_free()
	)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:

	# Find target
	if target_node == null:
		if target_poll_timer > 0.0:
			target_poll_timer -= delta
			return
		target_poll_timer = randf_range(0.2, 0.3)
		target_node = SceneManager.player_beyblade
		if target_node == null:
			return

	# Point at target
	var target_pos: Vector2 = target_node.global_position
	var target_vec := target_pos - global_position
	rotation = atan2(target_vec.y, target_vec.x)

	# Sprite mirroring, fix offsets
	var yoffset = -1.3
	flip_v = false
	if rotation > PI/2.0 && rotation < PI/2.0 * 3.0:
		yoffset = 0.7
		flip_v = true
	$flash1.position.y = yoffset
	$flash2.position.y = yoffset
	$flash3.position.y = yoffset
	$bullet_spawn.position.y = yoffset

	# Turn off flash
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			$flash1.visible = false
			$flash2.visible = false
			$flash3.visible = false

	# Load next bullet
	fire_timer -= delta

	# Target too far?
	if target_vec.length() >= FIRE_RANGE:
		return

	# Weapon ready?
	if fire_timer > 0.0:
		return

	_fire(target_vec)


func _fire(target_vec: Vector2) -> void:
	fire_timer = fire_wait
	var bullet = preload("res://Actual Game Folder/scenes/components/exploration/bullet.tscn").instantiate()
	var tn := target_vec.normalized()
	bullet.direction = tn.rotated(randf_range(-0.1, 0.1))
	bullet.transform = $bullet_spawn.global_transform
	SceneManager.bullet_container.add_child(bullet)

	dadi.shove(-tn.rotated(randf_range(-PI/4.0, PI/4.0)), 180.0)

	# SFX
	$sfx.stop()
	$sfx.play()

	# Flash
	flash_timer = flash_duration
	last_flash = (last_flash + 1 + randi() % 2) % 3
	match (last_flash):
		0:
			$flash1.visible = true
		1:
			$flash2.visible = true
		2:
			$flash3.visible = true
