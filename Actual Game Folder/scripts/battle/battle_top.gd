extends Player
class_name BattleTop

# The battle arena top: the player steers it with the mouse (it follows the cursor
# with momentum, keeping all of Player's physics) and the horde drops coins you
# sweep up with the cursor. Drives Player by overriding its three input hooks.

const COIN = preload("res://Actual Game Folder/scripts/battle/coin.gd")

@export var follow_deadzone: float = 14.0   # cursor this close: coast and settle
@export var follow_ramp: float = 130.0      # cursor distance that reaches full throttle
@export var mouse_button_dash: bool = true  # left-click dashes toward the cursor
@export var precession_amount: float = 0.3  # curve added to driving (player.gd's drift knob)
@export var coin_value: int = 1

var _prev_click: bool = false
var _coins: int = 0
var _coins_label: Label

func _ready() -> void:
	super()
	# the blade's natural drift so the chase curves instead of tracking straight
	precession = precession_amount
	precession_sign = 1.0
	idle_wander = 0.0
	_build_coin_hud()

# --- mouse-follow control (guide-on-a-string: force toward the cursor) ---
func _read_move_input() -> Vector2:
	var to_mouse := get_global_mouse_position() - global_position
	var dist := to_mouse.length()
	if dist <= follow_deadzone:
		return Vector2.ZERO
	return (to_mouse / dist) * clampf((dist - follow_deadzone) / follow_ramp, 0.0, 1.0)

func _aim_dir() -> Vector2:
	var to_mouse := get_global_mouse_position() - global_position
	return to_mouse.normalized() if to_mouse.length() > 0.01 else super._aim_dir()

func _wants_dash() -> bool:
	var click := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var click_dash := mouse_button_dash and click and not _prev_click
	_prev_click = click
	return click_dash or Input.is_action_just_pressed("dash")

# --- coins: drop one per non-boss kill, collect via the cursor ---
func _on_enemy_killed(enemy: Node) -> void:
	var was_boss := enemy is HordeBoss
	super._on_enemy_killed(enemy)
	if was_boss or not (enemy is Node2D):
		return
	var coin := COIN.new()
	coin.value = coin_value
	get_parent().add_child(coin)
	coin.global_position = (enemy as Node2D).global_position

func collect_coin(value: int) -> void:
	_coins += value
	_refresh_coins()

func _build_coin_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_coins_label = Label.new()
	_coins_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_coins_label.offset_left = 16.0
	_coins_label.offset_top = 44.0
	_coins_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(_coins_label)
	_refresh_coins()

func _refresh_coins() -> void:
	_coins_label.text = "COINS  %d" % _coins
