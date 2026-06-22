extends Node2D
class_name Coin

# A coin the horde drops. The player banks it by sweeping the mouse near it; it
# gets pulled to the cursor (magnet) and collects on contact, or fades and is
# lost if left too long. Draws itself, so it needs no texture asset.

@export var value: int = 1
@export var magnet_radius: float = 110.0
@export var collect_radius: float = 26.0
@export var magnet_pull: float = 9.0 # higher = snappier sweep
@export var lifetime: float = 6.0
@export var fade_time: float = 1.2

const GOLD := Color(1.0, 0.84, 0.2)
const RING := Color(0.6, 0.42, 0.05)

var _life: float
var _collected: bool = false

func _ready() -> void:
	_life = lifetime
	add_to_group("coin")
	z_index = 50
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if _collected:
		return
	var mouse := get_global_mouse_position()
	var d := global_position.distance_to(mouse)
	if d <= collect_radius:
		_collect()
		return
	if d <= magnet_radius:
		global_position = global_position.lerp(mouse, clampf(magnet_pull * delta, 0.0, 1.0))
	_life -= delta
	if _life <= 0.0:
		queue_free()
	elif _life < fade_time:
		modulate.a = _life / fade_time

func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0, GOLD)
	draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 16, RING, 2.0)

func _collect() -> void:
	_collected = true
	get_tree().call_group("player", "collect_coin", value)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.8, 1.8), 0.15)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(queue_free)
