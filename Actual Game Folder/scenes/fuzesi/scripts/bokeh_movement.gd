extends Sprite2D

var speed : float = 5.0
@export var speed_min : float = 5.0
@export var speed_max : float = 30.0

var velocity: Vector2 = Vector2.ZERO
@onready var screen_size = get_viewport_rect().size

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	scale = scale*randf_range(0.7,2.0)
	speed = randf_range(speed_min, speed_max)
	#RANDOMIZE BOKEH SIZE AT START
	#AND SPEED TOO
	
	velocity = Vector2.RIGHT.rotated(randf_range(0, TAU)) * speed
	#START GOING IN A RANDOM DIRECTION

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position += velocity * delta
	#move
	
	
	if position.x < 0:
		velocity.x = -velocity.x
		if (randi_range(1,5)) == 1:
			velocity = Vector2.RIGHT.rotated(randf_range(0, TAU)) * speed
			#START GOING IN A RANDOM DIRECTION
			#20% OF THE TIME
	elif position.x > screen_size.x:
		velocity.x = -velocity.x
		if (randi_range(1,5)) == 1:
			velocity = Vector2.RIGHT.rotated(randf_range(0, TAU)) * speed
			#START GOING IN A RANDOM DIRECTION
			#20% OF THE TIME

	if position.y < 0:
		velocity.y = -velocity.y
		if (randi_range(1,5)) == 1:
			velocity = Vector2.RIGHT.rotated(randf_range(0, TAU)) * speed
			#START GOING IN A RANDOM DIRECTION
			#20% OF THE TIME
	elif position.y > screen_size.y:
		velocity.y = -velocity.y
		if (randi_range(1,5)) == 1:
			velocity = Vector2.RIGHT.rotated(randf_range(0, TAU)) * speed
			#START GOING IN A RANDOM DIRECTION
			#20% OF THE TIME
	#when you hit any edge, bounce back

#THESE LEGENDARY BOKEH DECORATIONS ARE ADDED BY

#SAILOR FÜZESI

#AKA, A SAILOR MOON FAN FROM HUNGARY!
#WILLOWTREEGAMES.ITCH.IO
