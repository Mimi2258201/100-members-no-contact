extends CharacterBody2D

#Is the tileset made by us? if not we should credit it - Cube


#movements
@export var max_speed: float = 150.0
@export var acceleration: float = 1200.0
@export var friction: float = 1200.0
#rolling
@export var roll_speed: float = 500 
@export var roll_duration: float = 0.3     
var is_rolling: bool = false
var roll_direction: Vector2 = Vector2.DOWN

#animations
var last_direction: Vector2 = Vector2.DOWN
@onready var sprite = $AnimatedSprite2D

#interactions
var near_enemy: Node2D = null
@onready var detector: Area2D = $InteractionDetector
#dialog
@onready var dialogue_box: Node2D = $Camera2D/DialogueBox
@onready var dialogue_text: RichTextLabel = $Camera2D/DialogueBox/DialogueBox/DialogueText
var is_dialogue_active: bool = false
var dialogue_pages: Array[String] = []
var current_page: int = 0

#sounds
@onready var roll_sound: AudioStreamPlayer2D = $RollSound

func _ready():
	# Signal Connections
	detector.body_entered.connect(_on_interaction_detector_body_entered)
	detector.body_exited.connect(_on_interaction_detector_body_exited)

func _physics_process(delta):
	if is_dialogue_active:
		velocity = Vector2.ZERO
		if Input.is_action_just_pressed("interact"):
			advance_dialogue()
		return
	
	if is_rolling:
		velocity = roll_direction * roll_speed
		move_and_slide()
		return
		
	if near_enemy and Input.is_action_just_pressed("interact"):
		start_dialog(near_enemy.dialogue)
		return
		
	#Get the direction of movement!!!
	var input_direction = Vector2.ZERO
	input_direction.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	input_direction.y = Input.get_action_strength("down") - Input.get_action_strength("up")
	input_direction = input_direction.normalized()
	
	#They see me rolling! They hating
	if Input.is_action_just_pressed("roll") and input_direction != Vector2.ZERO:
		start_rolling(input_direction)
		return
	# Move
	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(input_direction * max_speed, acceleration * delta)
		last_direction = input_direction # Last direction we moved to
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	
	# Animations
	update_animations(input_direction)

func start_rolling(direction: Vector2):
	is_rolling = true
	roll_direction = direction
	
	print("Rolling (suggestion from K)")
	if roll_sound:
		roll_sound.play()
	
	if abs(roll_direction.x) > abs(roll_direction.y):
		if roll_direction.x > 0:
			sprite.play("roll_right")
		else:
			sprite.play("roll_left")
	else:
		if roll_direction.y > 0:
			sprite.play("roll_down")
		else:
			sprite.play("roll_up")
			
	await get_tree().create_timer(roll_duration).timeout
	end_rolling()

func end_rolling():
	is_rolling = false
	# What are trying to do man? keep rolling? get out of here!!!
	velocity = Vector2.ZERO

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
		
		if near_enemy.has_method("show_indicator"):
			near_enemy.show_indicator()

func _on_interaction_detector_body_exited(body):
	#See ya later aligator
	if body == near_enemy:
		if near_enemy.has_method("hide_indicator"):
			near_enemy.hide_indicator()
			
		near_enemy = null
		print("He is fleeing!!!")
	dialogue_box.visible = false
	
func start_dialog(lines: Array[String]):
	if lines.size() == 0: return
	
	is_dialogue_active = true
	dialogue_pages = lines
	current_page = 0
	
	update_animations(Vector2.ZERO)
	
	dialogue_box.show()
	dialogue_text.text = dialogue_pages[current_page]

func advance_dialogue():
	current_page += 1
	if current_page < dialogue_pages.size():
		dialogue_text.text = dialogue_pages[current_page]
	else:
		finish_dialogue()

func finish_dialogue():
	is_dialogue_active = false
	dialogue_box.hide()
	dialogue_pages = []
	current_page = 0
	
	#Added a check to see if it's a mechanic and if so teleport to garage
	if near_enemy and "is_bad" in near_enemy and near_enemy.is_bad:
		print("We are entering the fight >:)))")
		SceneManager.enter_battle(near_enemy.get_combat_data())
	elif near_enemy and "is_mechanic":
		print("It's a mechanic! :)")
		SceneManager.change_screen(SceneManager.SceneKey.GARAGE)
