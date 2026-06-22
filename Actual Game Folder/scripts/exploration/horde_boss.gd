extends HordeEnemy
class_name HordeBoss

enum State { REPOSITION, WINDUP, LUNGE, STAGGER }

const SPIN_BLUR_SHADER = preload("res://Actual Game Folder/shaders/spin_blur.gdshader")

@export var spin_speed: float = 7.0

@export_category("Spin Blur")
@export var spin_blur_strength: float = 1.0
@export var spin_blur_max_angle: float = 0.6
@export var spin_blur_min_spin: float = 2.0
@export_range(2, 24) var spin_blur_samples: int = 10

@export_category("Aggression")
@export var reposition_speed: float = 95.0
@export var lunge_speed: float = 360.0
@export var lunge_windup: float = 0.28
@export var lunge_duration: float = 0.4
@export var lunge_recover_min: float = 0.45
@export var lunge_recover_max: float = 1.3
@export var preferred_distance: float = 120.0
@export var lunge_damage: float = 28.0
@export var stagger_time: float = 0.55

var _state: int = State.REPOSITION
var _state_t: float = 0.0
var _phase_len: float = 1.0
var _orbit_sign: float = 1.0
var _lunge_dir: Vector2 = Vector2.RIGHT
var _lunge_hit: bool = false
var _wobble_t: float = 0.0
var _blade_material: ShaderMaterial

func _ready() -> void:
	super()
	if animator:
		_blade_material = ShaderMaterial.new()
		_blade_material.shader = SPIN_BLUR_SHADER
		_blade_material.set_shader_parameter("samples", spin_blur_samples)
		_blade_material.set_shader_parameter("blur_angle", 0.0)
		animator.material = _blade_material

func _physics_process(delta: float) -> void:
	super(delta)
	if animator:
		animator.rotation += spin_speed * delta
	if _blade_material:
		var arc := 0.0
		if spin_speed > spin_blur_min_spin:
			arc = minf((spin_speed - spin_blur_min_spin) * delta * spin_blur_strength, spin_blur_max_angle)
		_blade_material.set_shader_parameter("blur_angle", arc)

func _move(delta: float) -> void:
	if _player == null:
		return
	_wobble_t += delta
	_state_t += delta
	var decay := knockback_decay
	match _state:
		State.REPOSITION:
			velocity = _reposition_dir() * reposition_speed + _knock
			if _state_t >= _phase_len:
				_enter(State.WINDUP)
		State.WINDUP:
			velocity = _knock
			if _state_t >= lunge_windup:
				_lunge_dir = _aim_at_player()
				_enter(State.LUNGE)
		State.LUNGE:
			velocity = _lunge_dir * lunge_speed + _knock
			if _state_t >= lunge_duration:
				_phase_len = randf_range(lunge_recover_min, lunge_recover_max)
				_orbit_sign = 1.0 if randf() < 0.5 else -1.0
				_enter(State.REPOSITION)
		State.STAGGER:
			velocity = _knock
			decay = 3.0
			if _state_t >= stagger_time:
				_phase_len = randf_range(lunge_recover_min, lunge_recover_max)
				_enter(State.REPOSITION)
	_knock = _knock.lerp(Vector2.ZERO, clampf(decay * delta, 0.0, 1.0))
	move_and_slide()

func stagger(dir: Vector2, force: float) -> void:
	_knock = dir * force
	_enter(State.STAGGER)

func _enter(s: int) -> void:
	_state = s
	_state_t = 0.0
	if s == State.LUNGE:
		_lunge_hit = false

func _reposition_dir() -> Vector2:
	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player / dist if dist > 0.01 else Vector2.RIGHT
	var tangent := Vector2(-dir.y, dir.x) * _orbit_sign
	var radial := dir * clampf((dist - preferred_distance) / preferred_distance, -1.0, 1.0)
	var weave := tangent * (0.7 + 0.3 * sin(_wobble_t * 6.0))
	return (radial + weave).normalized()

func _aim_at_player() -> Vector2:
	var to_player := _player.global_position - global_position
	return to_player.normalized() if to_player.length() > 0.01 else Vector2.RIGHT

func _apply_contact_damage(delta: float) -> void:
	super(delta)
	if _state != State.LUNGE or _lunge_hit:
		return
	if global_position.distance_to(_player.global_position) <= contact_range and _player.has_method("take_damage"):
		_player.take_damage(lunge_damage)
		_lunge_hit = true

func _on_death() -> void:
	var p := CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 48
	p.lifetime = 0.7
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 220.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.color = Color(1.0, 0.25, 0.2)
	get_parent().add_child(p)
	p.global_position = global_position
	p.finished.connect(p.queue_free)
