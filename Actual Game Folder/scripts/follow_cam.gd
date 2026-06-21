extends Camera2D

@export var target : Node2D
@export var follow_magnitude : float = 2
@export var shake_decay : float = 5.0
@export var shake_max_offset : float = 14.0

var trauma : float = 0.0

func _ready() -> void:
	if target:
		global_position = target.global_position

func _process(delta: float) -> void:
	if target:
		# clamp weight so a first-frame delta spike cant extrapolate past the target
		var t := clampf(follow_magnitude * delta, 0.0, 1.0)
		global_position = global_position.lerp(target.global_position, t)

	if trauma > 0.0:
		trauma = max(trauma - shake_decay * delta, 0.0)
		var amount := trauma
		offset = Vector2(
			randf_range(-1.0, 1.0) * shake_max_offset * amount,
			randf_range(-1.0, 1.0) * shake_max_offset * amount
		)
	else:
		offset = Vector2.ZERO

func add_trauma(amount: float) -> void:
	trauma = min(trauma + amount, 1.0)
