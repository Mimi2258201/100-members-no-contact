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
#dialog
@onready var dialogue_box: Node2D = $Camera2D/DialogueBox
@onready var dialogue_text: RichTextLabel = $Camera2D/DialogueBox/DialogueBox/DialogueText
var is_dialogue_active: bool = false
var dialogue_pages: Array[String] = []
var current_page: int = 0


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
	if near_enemy and Input.is_action_just_pressed("interact"):
		start_dialog(near_enemy.dialogue)
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
	
	# Mostrar la caja de texto en pantalla
	dialogue_box.show()
	dialogue_text.text = dialogue_pages[current_page]

func advance_dialogue():
	current_page += 1
	
	# Si todavía quedan frases en la lista, mostramos la siguiente
	if current_page < dialogue_pages.size():
		dialogue_text.text = dialogue_pages[current_page]
	else:
		# Si ya no hay más frases, cerramos la caja y liberamos al jugador
		finish_dialogue()

func finish_dialogue():
	is_dialogue_active = false
	dialogue_box.hide()
	dialogue_pages = []
	current_page = 0
	
	if near_enemy and "is_bad" in near_enemy and near_enemy.is_bad:
		print("We are entering the fight >:)))")
		SceneManager.enter_battle(near_enemy.get_combat_data())
			
