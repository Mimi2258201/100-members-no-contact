extends CharacterBody2D

#movements
@export var max_speed: float = 150.0
@export var acceleration: float = 1200.0
@export var friction: float = 1200.0

#animations
var last_direction: Vector2 = Vector2.DOWN
@onready var sprite = $AnimatedSprite2D

#interactions
var near_enemy: Node2D = null
@onready var detector: Area2D = $InteractionDetector

func _ready():
	# Signal Connections
	detector.body_entered.connect(_on_interaction_detector_body_entered)
	detector.body_exited.connect(_on_interaction_detector_body_exited)

func _physics_process(delta):
	#
	if near_enemy and Input.is_action_just_pressed("interact"):
		show_dialog(near_enemy.dialog)
		return
		
	#Get the direction of movement!!!
	var input_direction = Vector2.ZERO
	input_direction.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	input_direction.y = Input.get_action_strength("down") - Input.get_action_strength("up")
	input_direction = input_direction.normalized()

	# Move
	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(input_direction * max_speed, acceleration * delta)
		last_direction = input_direction # Last direction we moved to
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	
	# Animations
	update_animations(input_direction)

# Character Animations Manager
func update_animations(direction: Vector2):
	if direction != Vector2.ZERO:
		#moving
		if abs(direction.x) > abs(direction.y):
			if direction.x > 0:
				sprite.play("walk_right")
			else:
				sprite.play("walk_left")
		else:
			if direction.y > 0:
				sprite.play("walk_down")
			else:
				sprite.play("walk_up")
	else:
		# not moving
		if abs(last_direction.x) > abs(last_direction.y):
			if last_direction.x > 0:
				sprite.play("idle_right")
			else:
				sprite.play("idle_left")
		else:
			if last_direction.y > 0:
				sprite.play("idle_down")
			else:
				sprite.play("idle_up")

func _on_interaction_detector_body_entered(body):
	#Are you interactuable?
	if body.is_in_group("interactable"):
		near_enemy = body
		print("Press E") 
		

func _on_interaction_detector_body_exited(body):
	#See ya later aligator
	if body == near_enemy:
		near_enemy = null
		print("He is fleeing!!!")

func show_dialog(text: String):
	# Stop moving Bro fr
	velocity = Vector2.ZERO
	
	if abs(last_direction.x) > abs(last_direction.y):
		sprite.play("idle_right" if last_direction.x > 0 else "idle_left")
	else:
		sprite.play("idle_down" if last_direction.y > 0 else "idle_up")
		
	print("Dialog: ", text)
