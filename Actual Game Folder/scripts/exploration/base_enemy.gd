extends CharacterBody2D

@onready var animator: AnimatedSprite2D = $AnimatedSprite2D

#Soon!
@export_multiline var dialog: String = "YOU!!! Come here!!!!"

func _ready():
	animator.play("idle_down")
