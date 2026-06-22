extends Node2D

# Auto-battler director. The AI top (AutoTop) fights on its own; the player only
# sweeps the mouse to bank the coins the horde drops. Flow: escalating horde
# waves, a shop between each, then a final boss. Killing the boss wins the run
# (handled by Player._win); the top dying loses it (Player._die).

const HORDE_SCENE = preload("res://Actual Game Folder/scenes/components/exploration/horde_enemy.tscn")
const BOSS_SCENE = preload("res://Actual Game Folder/scenes/components/exploration/horde_boss.tscn")
const ENEMY_GROUP := "horde_enemy"

@export var horde_waves: int = 6
@export var base_quota: int = 8
@export var quota_step: int = 4
@export var wave_heal_fraction: float = 0.25
@export var spawn_interval: float = 0.9
@export var base_batch: int = 2
@export var batch_step: int = 1
@export var max_alive: int = 28
@export var spawn_margin: float = 80.0
@export var final_boss_health: float = 240.0

const UPGRADES := [
	{"id": "flywheel", "name": "Heavier Flywheel", "desc": "+10 max spin", "cost": 6},
	{"id": "motor", "name": "Faster Motor", "desc": "+60 top speed", "cost": 6},
	{"id": "blade", "name": "Sharper Blade", "desc": "+0.3 dmg, +12 dash", "cost": 8},
	{"id": "frame", "name": "Reinforced Frame", "desc": "+25 max HP, heal 25", "cost": 8},
	{"id": "repair", "name": "Field Repair", "desc": "Heal to full", "cost": 5},
]

@onready var _top: AutoTop = $AutoTop

var _wave: int = 0
var _kills: int = 0
var _kills_needed: int = 0
var _alive_cap: int = 0
var _batch: int = 0
var _spawning: bool = false
var _coins: int = 0
var _bought: Dictionary = {}
var _spawn_timer: Timer

var _coin_label: Label
var _wave_label: Label
var _banner: Label
var _shop: Control
var _shop_balance: Label
var _shop_rows: Array = []

func _ready() -> void:
	add_to_group("auto_battle")
	_build_hud()
	_top.horde_killed.connect(_on_horde_killed)
	_top.player_won.connect(_on_player_won)
	_top.player_lost.connect(_on_player_lost)

	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.timeout.connect(_on_spawn_tick)
	add_child(_spawn_timer)

	await get_tree().create_timer(1.2).timeout # let the spawn intro finish
	_start_wave(1)

# --- wave flow ---

func _start_wave(n: int) -> void:
	_wave = n
	_kills = 0
	_top.set_battle_paused(false)
	_top.relaunch(wave_heal_fraction)

	if n > horde_waves:
		_start_boss_wave()
		return

	_kills_needed = base_quota + (n - 1) * quota_step
	_alive_cap = mini(max_alive, 6 + n * 4)
	_batch = base_batch + (n - 1) * batch_step
	_spawning = true
	_spawn_timer.start()
	_update_wave_label()
	_show_banner("WAVE %d" % n)

func _start_boss_wave() -> void:
	_spawning = false
	_spawn_timer.stop()
	_wave_label.text = "FINAL BOSS"
	_show_banner("FINAL BOSS")
	var boss := BOSS_SCENE.instantiate()
	boss.max_health = final_boss_health
	add_child(boss)
	boss.global_position = _offscreen_pos()

func _on_horde_killed() -> void:
	if not _spawning:
		return
	_kills += 1
	_update_wave_label()
	if _kills >= _kills_needed:
		_end_wave()

func _end_wave() -> void:
	_spawning = false
	_spawn_timer.stop()
	_clear_horde()
	_bank_remaining_coins()
	_top.set_battle_paused(true)
	_open_shop()

func _on_spawn_tick() -> void:
	if not _spawning:
		return
	var alive := get_tree().get_nodes_in_group(ENEMY_GROUP).size()
	for _i in _batch:
		if alive >= _alive_cap:
			break
		var e := HORDE_SCENE.instantiate()
		add_child(e)
		e.global_position = _offscreen_pos()
		alive += 1

func _clear_horde() -> void:
	for e in get_tree().get_nodes_in_group(ENEMY_GROUP):
		if e.has_method("poof"):
			e.poof()

func _bank_remaining_coins() -> void:
	for c in get_tree().get_nodes_in_group("coin"):
		add_coins(c.value)
		c.queue_free()

func _on_player_won() -> void:
	_spawning = false
	_spawn_timer.stop()

func _on_player_lost() -> void:
	_spawning = false
	_spawn_timer.stop()
	_clear_horde()
	get_tree().create_timer(2.5).timeout.connect(_to_menu)

func _to_menu() -> void:
	SceneManager.change_screen(SceneManager.SceneKey.MENU)

# --- coins (called by coin.gd via the "auto_battle" group) ---

func add_coins(amount: int) -> void:
	_coins += amount
	_coin_label.text = "COINS  %d" % _coins
	if _shop and _shop.visible:
		_refresh_shop()

# --- shop ---

func _cost_of(up: Dictionary) -> int:
	return int(up.cost) * (1 + int(_bought.get(up.id, 0)))

func _open_shop() -> void:
	_refresh_shop()
	_shop.visible = true

func _buy(up: Dictionary) -> void:
	var cost := _cost_of(up)
	if _coins < cost:
		return
	_coins -= cost
	_bought[up.id] = int(_bought.get(up.id, 0)) + 1
	match up.id:
		"flywheel": _top.spin_cap += 10.0
		"motor": _top.max_top_speed += 60.0
		"blade":
			_top.enemy_damage_factor += 0.3
			_top.dash_damage += 12.0
		"frame":
			_top.max_health += 25.0
			_top.heal(25.0)
		"repair": _top.heal(_top.max_health)
	add_coins(0)

func _fight() -> void:
	_shop.visible = false
	_start_wave(_wave + 1)

func _refresh_shop() -> void:
	_shop_balance.text = "COINS  %d" % _coins
	for row in _shop_rows:
		var cost := _cost_of(row.up)
		row.button.text = "%s   (%d)" % [row.up.name, cost]
		row.button.disabled = _coins < cost

# --- HUD construction ---

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)

	var stats := VBoxContainer.new()
	stats.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	stats.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	stats.offset_left = -200.0
	stats.offset_top = 12.0
	stats.offset_right = -16.0
	stats.alignment = BoxContainer.ALIGNMENT_END
	stats.add_theme_constant_override("separation", 2)
	layer.add_child(stats)

	_coin_label = _make_label("COINS  0", 18, HORIZONTAL_ALIGNMENT_RIGHT)
	stats.add_child(_coin_label)
	_wave_label = _make_label("", 14, HORIZONTAL_ALIGNMENT_RIGHT)
	stats.add_child(_wave_label)

	_banner = _make_label("", 44, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = 70.0
	_banner.modulate.a = 0.0
	layer.add_child(_banner)

	_build_shop(layer)

func _build_shop(layer: CanvasLayer) -> void:
	_shop = Control.new()
	_shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop.visible = false
	layer.add_child(_shop)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(320, 0)
	panel.add_child(box)

	box.add_child(_make_label("UPGRADE YOUR TOP", 26, HORIZONTAL_ALIGNMENT_CENTER))
	_shop_balance = _make_label("COINS  0", 18, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_shop_balance)

	for up in UPGRADES:
		var btn := Button.new()
		btn.pressed.connect(_buy.bind(up))
		box.add_child(btn)
		_shop_rows.append({"up": up, "button": btn})

	var fight := Button.new()
	fight.text = "FIGHT  >"
	fight.pressed.connect(_fight)
	box.add_child(fight)

func _make_label(text: String, size: int, align: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.horizontal_alignment = align
	return lbl

func _show_banner(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 0.0
	_banner.scale = Vector2(0.7, 0.7)
	_banner.pivot_offset = _banner.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.25)
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.9)
	tw.chain().tween_property(_banner, "modulate:a", 0.0, 0.4)

func _update_wave_label() -> void:
	_wave_label.text = "WAVE %d / %d   —   %d / %d" % [_wave, horde_waves, _kills, _kills_needed]

# --- spawn placement (mirror of enemy_spawner: just offscreen, around the top) ---

func _offscreen_pos() -> Vector2:
	var center := _top.global_position
	var half := _view_half() + Vector2(spawn_margin, spawn_margin)
	var off := Vector2.ZERO
	match randi() % 4:
		0: off = Vector2(randf_range(-half.x, half.x), -half.y)
		1: off = Vector2(randf_range(-half.x, half.x), half.y)
		2: off = Vector2(-half.x, randf_range(-half.y, half.y))
		_: off = Vector2(half.x, randf_range(-half.y, half.y))
	return center + off

func _view_half() -> Vector2:
	var size := get_viewport().get_visible_rect().size
	var zoom := Vector2.ONE
	var cam := get_viewport().get_camera_2d()
	if cam:
		zoom = cam.zoom
	return (size / zoom) * 0.5
