extends RigidBody2D
class_name Player

# TODO:
# Add collision shape for the player

# Can be part of a power up later
# What's the mechanic like? I'm not sure about the core mechanic right now
# Is player going to control the B0yblade? Against who? It could be speedrun type game.

# export these values to make it easier to adjust
# we can tweek these until the game feels fun
const SPARKS_SCENE = preload("res://Actual Game Folder/scenes/components/sparks.tscn")


@export_category("Statistics")
@export var starting_spin_velocity:float = 40
@export var default_velocity: float = 20
@export var spin_velocity_drop_on_collision: float = 1
@export var spin_velocity_drop_over_time: float = 1.5
@export var collision_shake_trauma: float = 0.3
@export var spin_floor: float = 12.0
@export var spin_cap: float = 80.0

@export_category("Resources")
@export var launch_sfx_stream : AudioStream
@export var collision_sfx_stream : AudioStream
@onready var spin_bar: ProgressBar = $CanvasLayer/SpinBar

@export_category("Survival")
@export var max_health: float = 100.0
@export var enemy_damage_factor: float = 1.5 # x spin = dmg/sec
@export var blade_radius: float = 40.0
# dmg also scales with speed (ramming), so standing still barely hurts
@export var ram_full_speed: float = 80.0
@export var min_ram_mult: float = 0.1
@export var plow_resistance: float = 1.2 # drag force per enemy plowed
@export var knockback_factor: float = 0.6 # enemy shove = our speed x this
@export var survive_time: float = 30.0

const HORDE_GROUP := "horde_enemy"

var current_velocity: Vector2 = Vector2(0, 0)
var spin_velocity: float = starting_spin_velocity
var player_died: bool = false

var _health: float
var _dead: bool = false
var _won: bool = false
var _survive_left: float = 0.0
var _hp_label: Label
var _timer_label: Label
var _gameover_label: Label
var _victory_label: Label

func _ready() -> void:
	AudioManager.play_sfx(launch_sfx_stream,global_position)

	max_contacts_reported = 16

	_health = max_health
	_survive_left = survive_time
	_setup_hud()

func _physics_process(delta: float) -> void:
	if _dead or _won:
		return

	_survive_left = max(_survive_left - delta, 0.0)
	_update_timer_label()
	if _survive_left <= 0.0:
		_win()
		return

	$Sprite2D.rotate(spin_velocity * delta)

	spin_velocity = clamp(spin_velocity - spin_velocity_drop_over_time * delta, spin_floor, spin_cap)

	current_velocity = Vector2(0, 0);

	spin_bar.value = (spin_velocity / spin_cap) * 100.0

	if Input.is_action_pressed("left"):
		current_velocity[0] -= default_velocity;

	if Input.is_action_pressed("right"):
		current_velocity[0] += default_velocity;

	if Input.is_action_pressed("up"):
		current_velocity[1] -= default_velocity;

	if Input.is_action_pressed("down"):
		current_velocity[1] += default_velocity;

	apply_force(current_velocity * spin_velocity) #Just proprtional to spin velocity rn, some physics guy please make cleaner logic idk how beyblades work

	_shred_horde(delta)

	pass

# radius shred (not physics contact, which was unreliable), scaled by spin and speed
func _shred_horde(delta: float) -> void:
	var speed := linear_velocity.length()
	var ram := clampf(speed / ram_full_speed, min_ram_mult, 1.0)
	var attack := spin_velocity * enemy_damage_factor * ram * delta
	var reach_sq := blade_radius * blade_radius
	var plowed := 0
	for enemy in get_tree().get_nodes_in_group(HORDE_GROUP):
		var e := enemy as Node2D
		if e == null:
			continue
		if global_position.distance_squared_to(e.global_position) > reach_sq:
			continue
		plowed += 1
		if e.has_method("shove"):
			var dir := e.global_position - global_position
			if dir.length() < 0.01:
				dir = Vector2.RIGHT
			e.shove(dir.normalized(), speed * knockback_factor)
		if e.has_method("take_damage") and e.take_damage(attack):
			_on_enemy_killed(e)
	# resistance: plowing a crowd drags us, denser = slower
	if plowed > 0:
		apply_central_force(-linear_velocity * plow_resistance * float(mini(plowed, 8)))

func _on_enemy_killed(enemy: Node) -> void:
	var spin_reward := 5.0
	var heal_reward := 4.0
	if enemy is HordeEnemy:
		spin_reward = enemy.spin_reward
		heal_reward = enemy.heal_reward
	spin_velocity = clampf(spin_velocity + spin_reward, spin_floor, spin_cap)
	_health = minf(_health + heal_reward, max_health)
	_update_hp_label()

# slightly lower spin velocity every time there is a collision with another rigid body
# we can add ways to increase your spin later to give the player more control
func _on_body_entered(body: Node) -> void:
	# horde contact handled in _shred_horde; skip to avoid spin/shake/sfx spam
	if body and body.is_in_group(HORDE_GROUP):
		return

	spin_velocity -= spin_velocity_drop_on_collision

	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(collision_shake_trauma)

	if(body is Node2D):
		var body2D = body as Node2D
		AudioManager.play_sfx(collision_sfx_stream, body2D.global_position)
	pass

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var contact_count = get_contact_count()
	if contact_count > 0:
		for i in range(contact_count):
			var sparks = SPARKS_SCENE.instantiate()
			sparks.global_position = state.get_contact_local_position(i)
			get_parent().add_child(sparks)
			get_tree().create_timer(0.1).timeout.connect(sparks.queue_free)

# this is used to give the player a buff
# feel free to use it as much as you want in other scripts
# its pretty self explanatory
func gain_energy(amount):
	spin_velocity = clamp(spin_velocity + amount, spin_floor, spin_cap)

func take_damage(amount: float) -> void:
	if _dead or _won:
		return
	_health = max(_health - amount, 0.0)
	_update_hp_label()
	if _health <= 0.0:
		_die()

func _die() -> void:
	_dead = true
	player_died = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_gameover_label.visible = true
	_stop_spawners()

func _win() -> void:
	if _won or _dead:
		return
	_won = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_victory_label.visible = true
	_clear_horde()
	get_tree().create_timer(2.0).timeout.connect(SceneManager.end_battle)

func _stop_spawners() -> void:
	for s in get_tree().get_nodes_in_group("enemy_spawner"):
		if s.has_method("stop"):
			s.stop()

func _clear_horde() -> void:
	_stop_spawners()
	for enemy in get_tree().get_nodes_in_group(HORDE_GROUP):
		if enemy.has_method("poof"):
			enemy.poof()

func _setup_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	_hp_label = Label.new()
	_hp_label.position = Vector2(16, 44) # below SpinBar
	hud.add_child(_hp_label)
	_update_hp_label()

	_timer_label = Label.new()
	_timer_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_timer_label.offset_top = 8.0
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(_timer_label)
	_update_timer_label()

	_gameover_label = Label.new()
	_gameover_label.text = "GAME OVER"
	_gameover_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gameover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gameover_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gameover_label.visible = false
	hud.add_child(_gameover_label)

	_victory_label = Label.new()
	_victory_label.text = "VICTORY!"
	_victory_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_victory_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_victory_label.visible = false
	hud.add_child(_victory_label)

func _update_hp_label() -> void:
	_hp_label.text = "HP: %d" % ceil(_health)

func _update_timer_label() -> void:
	_timer_label.text = "SURVIVE: %d" % ceil(_survive_left)
