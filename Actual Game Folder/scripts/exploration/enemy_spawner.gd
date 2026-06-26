extends Node2D

@export var enemy_scene: PackedScene
@export var enemy_scenes: Array[PackedScene] = [] # if set, mix randomly; else use enemy_scene
# Progression: entry N unlocks on battle N, so each new battle adds one more type to the mix.
# Takes priority over enemy_scenes when set.
@export var enemy_unlock_order: Array[PackedScene] = []
@export var target_path: NodePath

@export var spawn_interval: float = 1.0
@export var max_enemies: int = 150
# Difficulty ramp: batch grows by 1 every ramp_seconds, capped at max_per_tick.
@export var base_batch: int = 2
@export var max_per_tick: int = 12
@export var ramp_seconds: float = 12.0
# How far beyond the visible edge enemies appear, so they stream in unseen.
@export var spawn_margin: float = 64.0

@export_category("Boss")
@export var boss_scene: PackedScene
@export var boss_kill_threshold: int = 20 # horde kills before the boss shows up

const SPAWNED_GROUP := "spawned_enemy"
const SPAWNER_GROUP := "enemy_spawner"

var _target: Node2D
var _elapsed: float = 0.0
var _timer: Timer
var _stopped: bool = false
var _boss_spawned: bool = false
var _kills: int = 0
var _pool: Array[PackedScene] = []

func _ready() -> void:
	add_to_group(SPAWNER_GROUP)
	_target = get_node_or_null(target_path) as Node2D
	_build_pool()

	_timer = Timer.new()
	_timer.wait_time = spawn_interval
	_timer.timeout.connect(_on_spawn_tick)
	add_child(_timer)
	_timer.start()

func stop() -> void:
	_stopped = true
	if _timer:
		_timer.stop()

func _process(delta: float) -> void:
	_elapsed += delta

func register_kill() -> void:
	if _stopped or _boss_spawned:
		return
	_kills += 1
	if _kills >= boss_kill_threshold:
		_spawn_boss()

func _spawn_boss() -> void:
	if _boss_spawned or boss_scene == null or _target == null:
		return
	_boss_spawned = true
	var boss := boss_scene.instantiate()
	boss.add_to_group(SPAWNED_GROUP)
	add_child(boss)
	boss.global_position = _offscreen_position(_target.global_position)

func _on_spawn_tick() -> void:
	if _target == null:
		return

	var alive := get_tree().get_nodes_in_group(SPAWNED_GROUP).size()
	var batch := mini(base_batch + int(_elapsed / ramp_seconds), max_per_tick)
	for _i in batch:
		if alive >= max_enemies:
			break
		var scene := _pick_enemy()
		if scene == null:
			break
		var enemy := scene.instantiate()
		enemy.add_to_group(SPAWNED_GROUP)
		add_child(enemy)
		enemy.global_position = _offscreen_position(_target.global_position)
		alive += 1

func _build_pool() -> void:
	if not enemy_unlock_order.is_empty():
		var unlocked := clampi(SceneManager.battle_number, 1, enemy_unlock_order.size())
		_pool = enemy_unlock_order.slice(0, unlocked)
	elif not enemy_scenes.is_empty():
		_pool = enemy_scenes
	elif enemy_scene != null:
		_pool = [enemy_scene]

func _pick_enemy() -> PackedScene:
	if _pool.is_empty():
		return null
	return _pool[randi() % _pool.size()]

func _offscreen_position(center: Vector2) -> Vector2:
	var half := _view_half_extents() + Vector2(spawn_margin, spawn_margin)
	var offset := Vector2.ZERO
	match randi() % 4:
		0: offset = Vector2(randf_range(-half.x, half.x), -half.y) # top
		1: offset = Vector2(randf_range(-half.x, half.x), half.y)  # bottom
		2: offset = Vector2(-half.x, randf_range(-half.y, half.y)) # left
		_: offset = Vector2(half.x, randf_range(-half.y, half.y))  # right
	return center + offset

func _view_half_extents() -> Vector2:
	var size := get_viewport().get_visible_rect().size
	var zoom := Vector2.ONE
	var cam := get_viewport().get_camera_2d()
	if cam:
		zoom = cam.zoom
	return (size / zoom) * 0.5
