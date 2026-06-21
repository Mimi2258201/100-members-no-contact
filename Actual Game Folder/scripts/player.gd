extends RigidBody2D
class_name Player

# TODO:
# Add collision shape for the player

# Can be part of a power up later
# What's the mechanic like? I'm not sure about the core mechanic right now
# Is player going to control the beyblade? Against who? It could be speedrun type game.

# export these values to make it easier to adjust
# we can tweek these until the game feels fun
const SPARKS_SCENE = preload("res://Actual Game Folder/scenes/components/sparks.tscn")


@export var starting_spin_velocity:float = 30
@export var default_velocity: float = 20
@export var spin_velocity_drop_on_collision: float = 1
@export var spin_velocity_drop_over_time: float = 1

@onready var spin_bar: ProgressBar = $CanvasLayer/SpinBar


var current_velocity: Vector2 = Vector2(0, 0)
var spin_velocity: float = starting_spin_velocity
var player_died: bool = false

func _ready() -> void:
	# this is necessary for _on_body_entered, 1 is technically enough for just the player but with multiple bayblades we might need to increase this value.
	max_contacts_reported = 5

func _physics_process(delta: float) -> void:

	$Sprite2D.rotate(spin_velocity * delta)

	if spin_velocity > 0:
		spin_velocity -= spin_velocity_drop_over_time * delta
	else:
		player_died = true
		spin_velocity = 0 # prevents slight backspin on player death
	
	current_velocity = Vector2(0, 0);

	spin_bar.value = (spin_velocity / starting_spin_velocity) * 100.0

	if Input.is_action_pressed("left"):
		current_velocity[0] -= default_velocity;

	if Input.is_action_pressed("right"):
		current_velocity[0] += default_velocity;

	if Input.is_action_pressed("up"):
		current_velocity[1] -= default_velocity;

	if Input.is_action_pressed("down"):
		current_velocity[1] += default_velocity;

	apply_force(current_velocity * spin_velocity) #Just proprtional to spin velocity rn, some physics guy please make cleaner logic idk how beyblades work

	pass

# slightly lower spin velocity every time there is a collision with another rigid body
# we can add ways to increase your spin later to give the player more control
func _on_body_entered(_body: Node) -> void:
	spin_velocity -= spin_velocity_drop_on_collision
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
	spin_velocity += amount
	
