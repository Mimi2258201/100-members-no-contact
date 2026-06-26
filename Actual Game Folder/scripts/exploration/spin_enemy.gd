extends HordeEnemy
class_name SpinEnemy

# Rival beyblade: each instance rolls a random sprite AND a movement style, so the swarm
# doesn't read as one homing blob. All styles still close on the player, just by different paths.

enum Style { CHASE, WEAVE, SPIRAL, DART }

@export var blade_textures: Array[Texture2D] = []
@export var spin_speed: float = 12.0
@export var weave_strength: float = 0.75 # how hard WEAVE blades snake side to side

var _style: int = Style.CHASE
var _wobble_t: float = 0.0
var _side: float = 1.0
var _dart_t: float = 0.0
var _dart_rush: bool = false

func _ready() -> void:
	super()
	_style = randi() % Style.size()
	_side = 1.0 if randf() < 0.5 else -1.0
	_wobble_t = randf() * TAU # desync the weave so neighbors don't snake in lockstep
	spin_speed *= randf_range(0.7, 1.4) * _side # vary spin rate and direction blade-to-blade
	if animator and not blade_textures.is_empty():
		var sf := SpriteFrames.new()
		sf.add_animation(&"idle_down")
		sf.add_frame(&"idle_down", blade_textures[randi() % blade_textures.size()])
		animator.sprite_frames = sf
		animator.play(&"idle_down")

func _physics_process(delta: float) -> void:
	super(delta)
	if animator:
		animator.rotation += spin_speed * delta

func _move(delta: float) -> void:
	if _player == null:
		return
	_wobble_t += delta
	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player / dist if dist > 0.01 else Vector2.RIGHT
	var tangent := Vector2(-dir.y, dir.x) * _side
	var heading := dir
	var speed := move_speed
	match _style:
		Style.WEAVE:
			heading = (dir + tangent * weave_strength * sin(_wobble_t * 5.0)).normalized()
		Style.SPIRAL:
			# swoop in sideways from afar, straighten out as it closes
			heading = (dir + tangent * 1.3 * clampf(dist / 220.0, 0.0, 1.0)).normalized()
		Style.DART:
			_dart_t -= delta
			if _dart_t <= 0.0:
				_dart_rush = not _dart_rush
				_dart_t = randf_range(0.2, 0.55)
			speed = move_speed * (1.9 if _dart_rush else 0.45)
	velocity = heading * speed + _knock
	_knock = _knock.lerp(Vector2.ZERO, clampf(knockback_decay * delta, 0.0, 1.0))
	move_and_slide()
