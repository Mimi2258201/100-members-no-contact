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
@export var spin_speed: float = 12.0

#animations
var last_direction: Vector2 = Vector2.DOWN
@onready var sprite = $AnimatedSprite2D

#interactions
var near_enemy: Node2D = null
@onready var detector: Area2D = $InteractionDetector
#dialog
@onready var dialogue_box: Node2D = $Camera2D/DialogueBox
@onready var dialogue_text: RichTextLabel = $Camera2D/DialogueBox/DialogueBox/DialogueText
@onready var dialogue_blip: AudioStreamPlayer = $DialogBlip
var is_dialogue_active: bool = false
var dialogue_pages: Array[String] = []
var current_page: int = 0
var is_typing: bool = false
var _type_accum: float = 0.0
var _parsed_text: String = ""
var _voice_pitch: float = 1.0
const TYPE_SPEED := 35.0  # characters revealed per second

#sounds
@onready var roll_sound: AudioStreamPlayer2D = $RollSound
const LAUNCH_SFX := preload("res://Miscellanious Assets Dump/Audio/ripcord.mp3")

var is_launching: bool = false
var _reward_pending: bool = false

func _ready():
	# Signal Connections
	detector.body_entered.connect(_on_interaction_detector_body_entered)
	detector.body_exited.connect(_on_interaction_detector_body_exited)
	add_to_group("overworld_player")

func _physics_process(delta):
	if is_launching:
		velocity = Vector2.ZERO
		return

	if is_dialogue_active:
		velocity = Vector2.ZERO
		if is_typing:
			if Input.is_action_just_pressed("interact"):
				_reveal_full_page()
			else:
				_advance_typing(delta)
		elif Input.is_action_just_pressed("interact"):
			advance_dialogue()
		return
	
	if is_rolling:
		velocity = roll_direction * roll_speed
		sprite.rotation += spin_speed * delta * (1.0 if roll_direction.x >= 0.0 else -1.0)
		move_and_slide()
		_break_walls_hit()
		return

	if near_enemy and Input.is_action_just_pressed("interact"):
		start_dialog(_dialogue_for(near_enemy))
		return
		
	#Get the direction of movement!!!
	var input_direction = Vector2.ZERO
	input_direction.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	input_direction.y = Input.get_action_strength("down") - Input.get_action_strength("up")
	input_direction = input_direction.normalized()
	
	#They see me rolling! They hating
	if Globals.spin_dash and Input.is_action_just_pressed("roll") and input_direction != Vector2.ZERO:
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
	sprite.rotation = 0.0
	# What are trying to do man? keep rolling? get out of here!!!
	velocity = Vector2.ZERO

func _break_walls_hit() -> void:
	for i in get_slide_collision_count():
		var col: Object = get_slide_collision(i).get_collider()
		if col is Node and (col as Node).is_in_group("breakable") and (col as Node).has_method("break_wall"):
			(col as Node).call("break_wall")

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
	_voice_pitch = _voice_pitch_for(near_enemy)

	update_animations(Vector2.ZERO)
	
	dialogue_box.show()
	_show_page()

func advance_dialogue():
	current_page += 1
	if current_page < dialogue_pages.size():
		_show_page()
	else:
		finish_dialogue()

func _show_page():
	dialogue_text.text = dialogue_pages[current_page]
	_parsed_text = dialogue_text.get_parsed_text()
	dialogue_text.visible_characters = 0
	_type_accum = 0.0
	is_typing = true

func _advance_typing(delta: float):
	_type_accum += delta * TYPE_SPEED
	var total := dialogue_text.get_total_character_count()
	var target := mini(int(_type_accum), total)
	while dialogue_text.visible_characters < target:
		var idx := dialogue_text.visible_characters
		dialogue_text.visible_characters += 1
		_play_blip(idx)
	if dialogue_text.visible_characters >= total:
		is_typing = false

func _reveal_full_page():
	dialogue_text.visible_characters = -1
	is_typing = false

func _play_blip(idx: int):
	if idx < 0 or idx >= _parsed_text.length():
		return
	if _parsed_text[idx].strip_edges() == "":  # stay silent on spaces
		return
	dialogue_blip.pitch_scale = _voice_pitch * randf_range(0.97, 1.03)
	dialogue_blip.play()

# each speaker gets its own voice: an explicit voice_pitch if set, otherwise a
# stable pitch derived from their name so every NPC sounds distinct
func _voice_pitch_for(speaker) -> float:
	if speaker == null:
		return 1.0
	if "voice_pitch" in speaker and speaker.voice_pitch > 0.0:
		return speaker.voice_pitch
	var key := ""
	if "enemy_name" in speaker:
		key = str(speaker.enemy_name)
	else:
		key = speaker.name
	if key == "":
		return 1.0
	return 0.82 + float(abs(hash(key)) % 1000) / 1000.0 * 0.46  # ~0.82 .. 1.28

func finish_dialogue():
	is_dialogue_active = false
	is_typing = false
	dialogue_box.hide()
	dialogue_pages = []
	current_page = 0

	if _reward_pending:
		_reward_pending = false
		if near_enemy:
			if "defeated" in near_enemy:
				near_enemy.defeated = true
			if "enemy_id" in near_enemy and near_enemy.enemy_id != "":
				Globals.mark_enemy_defeated(near_enemy.enemy_id)
		return

	#Added a check to see if it's a mechanic and if so teleport to garage
	if near_enemy and "is_bad" in near_enemy and near_enemy.is_bad and not _is_defeated(near_enemy):
		print("We are entering the fight >:)))")
		_launch_into_battle(near_enemy.get_combat_data())
	elif near_enemy and "is_pickup" in near_enemy and near_enemy.is_pickup:
		_collect_pickup(near_enemy)
	elif near_enemy and "is_mechanic" in near_enemy and near_enemy.is_mechanic:
		print("It's a mechanic! :)")
		SceneManager.push_scene(SceneManager.SceneKey.GARAGE)

func _is_defeated(npc: Node2D) -> bool:
	return npc != null and "defeated" in npc and npc.defeated

func _dialogue_for(npc: Node2D) -> Array[String]:
	if _is_defeated(npc) and "post_defeat_dialogue" in npc and not npc.post_defeat_dialogue.is_empty():
		return npc.post_defeat_dialogue
	return npc.dialogue

func _collect_pickup(item: Node) -> void:
	Globals.has_beyblade = true
	if item == near_enemy:
		near_enemy = null
	item.queue_free()

func _launch_into_battle(data: Dictionary) -> void:
	is_launching = true
	velocity = Vector2.ZERO
	_play_launch_windup()
	AudioManager.play_sfx(LAUNCH_SFX, global_position)
	SceneManager.enter_battle(data)

func _play_launch_windup() -> void:
	var d := last_direction
	if abs(d.x) > abs(d.y):
		sprite.play("roll_right" if d.x > 0 else "roll_left")
	else:
		sprite.play("roll_down" if d.y > 0 else "roll_up")

func _on_return_from_battle() -> void:
	is_launching = false
	update_animations(Vector2.ZERO)
	var lines := SceneManager.take_reward_dialogue()
	if not lines.is_empty():
		await get_tree().create_timer(0.8).timeout
		_reward_pending = true
		start_dialog(lines)
