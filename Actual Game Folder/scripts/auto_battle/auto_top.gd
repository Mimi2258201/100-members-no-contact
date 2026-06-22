extends Player
class_name AutoTop

# Drives the beyblade with AI instead of a keyboard by overriding Player's three
# input hooks (_read_move_input / _wants_dash / _aim_dir). Every bit of physics
# and every ability is inherited from Player unchanged.

const COIN = preload("res://Actual Game Folder/scripts/auto_battle/coin.gd")

signal horde_killed
signal player_won
signal player_lost

@export var defensive_spin_ratio: float = 0.28 # below this, orbit wide instead of closing in
@export var cluster_count: int = 3             # enemies in dash range worth a dash
@export var coin_value: int = 1

@export_category("Beyblade Feel")
@export var engage_distance: float = 180.0  # within this it circles; beyond it closes in
@export var wander_amount: float = 0.28      # organic drift mixed into steering
@export var wander_speed: float = 1.7
@export var orbit_flip_interval: float = 2.6 # how often the circling direction reverses
@export var precession_amount: float = 0.4   # curve added to driving (player.gd's drift knob)

var _battle_paused: bool = false
var _move_want: Vector2 = Vector2.ZERO
var _aim_want: Vector2 = Vector2.RIGHT
var _dash_want: bool = false
var _orbit_sign: float = 1.0
var _drift_phase: float = 0.0
var _orbit_t: float = 0.0

func _ready() -> void:
	super()
	_orbit_sign = 1.0 if randf() < 0.5 else -1.0
	# turn on the blade's natural drift so driving curves instead of tracking straight
	precession = precession_amount
	precession_sign = _orbit_sign
	idle_wander = 0.0

func _physics_process(delta: float) -> void:
	if not _battle_paused:
		_drift_phase += delta * wander_speed
		_orbit_t += delta
		if _orbit_t >= orbit_flip_interval:
			_orbit_t = 0.0
			_orbit_sign = -_orbit_sign
			precession_sign = _orbit_sign
		_think()
	super._physics_process(delta)

# the AI: spiral toward a target and glance off it like a spinning top, rather
# than tracking it down in a straight line. The committed dash still strikes in.
func _think() -> void:
	if _dead or _won or _launching:
		_move_want = Vector2.ZERO
		_dash_want = false
		return

	var boss := get_tree().get_first_node_in_group(BOSS_GROUP) as Node2D
	var enemies := get_tree().get_nodes_in_group(HORDE_GROUP)
	var target: Node2D = boss if boss else _nearest(enemies)

	if target == null:
		_move_want = Vector2.ZERO
		_dash_want = false
		return

	var to_target := target.global_position - global_position
	var dist := maxf(to_target.length(), 0.01)
	var dir := to_target / dist
	_aim_want = dir

	# blend "close in" (radial) with "circle around" (tangential): far away it
	# mostly approaches, up close it mostly orbits, so it spirals into contact
	var tangent := Vector2(-dir.y, dir.x) * _orbit_sign
	var closeness := clampf(dist / engage_distance, 0.0, 1.0)
	var radial_w := lerpf(0.3, 1.0, closeness)
	var tangent_w := lerpf(1.0, 0.35, closeness)

	# low on spin with no boss to commit to: widen the orbit so a hard ram
	# doesn't bleed the last of our stamina
	if boss == null and _spin_ratio() < defensive_spin_ratio:
		radial_w *= 0.2
		tangent_w = 1.0

	var steer := dir * radial_w + tangent * tangent_w
	steer += Vector2.from_angle(_drift_phase) * wander_amount
	_move_want = steer.normalized() if steer.length() > 0.01 else dir

	_dash_want = _good_dash(boss, enemies)

# dash on the boss when in reach, or into any worthwhile horde cluster
func _good_dash(boss: Node2D, enemies: Array) -> bool:
	if boss and global_position.distance_to(boss.global_position) <= dash_radius * 1.5:
		return true
	var near := 0
	var reach_sq := dash_radius * dash_radius
	for e in enemies:
		var n := e as Node2D
		if n and global_position.distance_squared_to(n.global_position) <= reach_sq:
			near += 1
	return near >= cluster_count

func _nearest(nodes: Array) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for e in nodes:
		var n := e as Node2D
		if n == null:
			continue
		var d := global_position.distance_squared_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best

# --- input hook overrides ---
func _read_move_input() -> Vector2:
	return _move_want

func _wants_dash() -> bool:
	return _dash_want

func _aim_dir() -> Vector2:
	return _aim_want

# --- coins + wave-flow signals ---
func _on_enemy_killed(enemy: Node) -> void:
	var was_boss := enemy is HordeBoss
	super._on_enemy_killed(enemy)
	if was_boss:
		return
	horde_killed.emit()
	if enemy is Node2D:
		_drop_coin((enemy as Node2D).global_position)

func _drop_coin(pos: Vector2) -> void:
	var coin := COIN.new()
	coin.value = coin_value
	get_parent().add_child(coin)
	coin.global_position = pos

# relaunch each wave so the top fights at full spin (and patches some HP)
func relaunch(heal_fraction: float) -> void:
	spin_velocity = spin_cap
	heal(max_health * heal_fraction)

func set_battle_paused(paused: bool) -> void:
	_battle_paused = paused
	freeze = paused
	if paused:
		linear_velocity = Vector2.ZERO
		_move_want = Vector2.ZERO
		_dash_want = false

func _win() -> void:
	if _won or _dead:
		return
	super._win()
	player_won.emit()

func _die() -> void:
	if _dead:
		return
	super._die()
	player_lost.emit()
