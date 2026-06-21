extends CharacterBody2D
class_name HordeEnemy

# Base for horde enemies. New type: extends HordeEnemy, override a hook, give it a scene.

@onready var animator: AnimatedSprite2D = $AnimatedSprite2D

@export_category("Stats")
@export var move_speed: float = 90.0
@export var contact_damage: float = 6.0 # to player, per second
@export var contact_range: float = 26.0 # how close we must be to hurt the player
@export var max_health: float = 14.0
@export var knockback_decay: float = 8.0 # how fast a beyblade shove wears off

@export_category("Bounty")
@export var spin_reward: float = 5.0

@export_category("Hit Flash")
@export var flash_time: float = 0.12
@export var blink_interval: float = 0.05

@export_category("Damage Numbers")
@export var popup_interval: float = 0.15 # batch per-frame damage into one number this often
@export var big_hit: float = 18.0        # damage that reads as a full size/color popup

const PLAYER_GROUP := "player"
const ENEMY_GROUP := "horde_enemy"
const HIT_RED := Color(6, 0.5, 0.5)
const HIT_WHITE := Color(4, 4, 4)

var _player: Node2D
var _health: float
var _flash: float = 0.0
var _blink: float = 0.0
var _blink_red: bool = true
var _dmg_accum: float = 0.0
var _popup_t: float = 0.0
var _knock: Vector2 = Vector2.ZERO

func _ready() -> void:
	_health = max_health
	add_to_group(ENEMY_GROUP)
	if animator:
		animator.play("idle_down")

func _physics_process(delta: float) -> void:
	_update_flash(delta)
	_update_damage_numbers(delta)

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(PLAYER_GROUP)
		if _player == null:
			return

	_move(delta)
	_apply_contact_damage(delta)

func _move(delta: float) -> void:
	var toward := (_player.global_position - global_position).normalized() * move_speed
	velocity = toward + _knock
	_knock = _knock.lerp(Vector2.ZERO, clampf(knockback_decay * delta, 0.0, 1.0))
	if animator:
		animator.flip_h = velocity.x < 0.0
	move_and_slide()

func shove(dir: Vector2, force: float) -> void:
	_knock = dir * force

func _apply_contact_damage(delta: float) -> void:
	# Distance based: we clip through the player, so no physics contact to read.
	if global_position.distance_to(_player.global_position) <= contact_range and _player.has_method("take_damage"):
		_player.take_damage(contact_damage * delta)

func health_fraction() -> float:
	if max_health <= 0.0:
		return 0.0
	return clampf(_health / max_health, 0.0, 1.0)

# returns true if this hit killed us
func take_damage(amount: float) -> bool:
	if _health <= 0.0:
		return false
	_health -= amount
	_dmg_accum += amount
	_start_blink()
	_on_hit(amount)
	if _health <= 0.0:
		_die()
		return true
	return false

# subtype hooks
func _on_hit(_amount: float) -> void:
	pass

func _on_death() -> void:
	pass

func _die() -> void:
	if _dmg_accum >= 1.0:
		_spawn_damage_number(_dmg_accum)
		_dmg_accum = 0.0
	_on_death()
	queue_free()

func _update_damage_numbers(delta: float) -> void:
	if _dmg_accum < 1.0:
		return
	_popup_t -= delta
	if _popup_t <= 0.0:
		_popup_t = popup_interval
		_spawn_damage_number(_dmg_accum)
		_dmg_accum = 0.0

func _spawn_damage_number(value: float) -> void:
	var lbl := Label.new()
	lbl.text = str(roundi(value))
	lbl.z_index = 100
	var big := clampf(value / big_hit, 0.0, 1.0)
	lbl.add_theme_font_size_override("font_size", int(lerp(10, 24, big)))
	lbl.modulate = Color.WHITE.lerp(Color(1, 0.55, 0.1), big)
	get_parent().add_child(lbl)
	lbl.global_position = global_position + Vector2(randf_range(-6, 6), -8)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "global_position", lbl.global_position + Vector2(0, -28), 0.6)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6)
	tw.tween_callback(lbl.queue_free)

func poof() -> void:
	var p := CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 12
	p.lifetime = 0.4
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	get_parent().add_child(p)
	p.global_position = global_position
	p.finished.connect(p.queue_free)
	queue_free()

func _start_blink() -> void:
	_flash = flash_time
	_blink = blink_interval
	_blink_red = true
	if animator:
		animator.modulate = HIT_RED

func _update_flash(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash -= delta
	_blink -= delta
	if _blink <= 0.0:
		_blink = blink_interval
		_blink_red = not _blink_red
		if animator:
			animator.modulate = HIT_RED if _blink_red else HIT_WHITE
	if _flash <= 0.0 and animator:
		animator.modulate = Color.WHITE
