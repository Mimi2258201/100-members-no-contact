extends Player
class_name AutoTop

# Drives the beyblade with AI instead of a keyboard by overriding Player's three
# input hooks (_read_move_input / _wants_dash / _aim_dir). Every bit of physics
# and every ability is inherited from Player unchanged.

const COIN = preload("res://Actual Game Folder/scripts/auto_battle/coin.gd")

signal horde_killed
signal player_won
signal player_lost

@export var defensive_spin_ratio: float = 0.28 # below this, kite instead of charge
@export var cluster_count: int = 3             # enemies in dash range worth a dash
@export var coin_value: int = 1

var _battle_paused: bool = false
var _move_want: Vector2 = Vector2.ZERO
var _aim_want: Vector2 = Vector2.RIGHT
var _dash_want: bool = false

func _physics_process(delta: float) -> void:
	if not _battle_paused:
		_think()
	super._physics_process(delta)

# the whole AI: pick a target, decide charge-vs-kite, decide whether to dash
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
	if to_target.length() > 0.01:
		_aim_want = to_target.normalized()

	# spin nearly spent and no boss to commit to: peel away from the nearest
	# threat so a stray ram doesn't bleed the last of our stamina
	if boss == null and _spin_ratio() < defensive_spin_ratio:
		var threat := _nearest(enemies)
		if threat:
			var away := global_position - threat.global_position
			_move_want = away.normalized() if away.length() > 0.01 else _aim_want
		else:
			_move_want = Vector2.ZERO
	else:
		_move_want = _aim_want

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
