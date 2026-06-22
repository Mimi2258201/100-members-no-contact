extends RigidBody2D
class_name Player

# TODO:
# Add collision shape for the player

# Can be part of a power up later
# What's the mechanic like? I'm not sure about the core mechanic right now
# Is player going to control the B0yblade? Against who? It could be speedrun type game.

# export these values to make it easier to adjust
# we can tweek these until the game feels fun
const SPARKS_SCENE = preload("res://Actual Game Folder/scenes/components/sparks.tscn")
const DRINK_SCENE = preload("res://Actual Game Folder/scenes/components/wings_energy_drink.tscn")
const SPIN_BLUR_SHADER = preload("res://Actual Game Folder/shaders/spin_blur.gdshader")


@export_category("Statistics")
@export var starting_spin_velocity:float = 80 # full stamina == spin_cap, then it winds down
@export var spin_velocity_drop_on_collision: float = 1
@export var spin_velocity_drop_over_time: float = 1.5
@export var collision_shake_trauma: float = 0.3
@export var spin_floor: float = 12.0
@export var spin_cap: float = 80.0

@export_category("Handling")
@export var drive_force: float = 2400.0      # lower = heavier wind-up
@export var low_spin_control: float = 0.65   # steering authority at spin_floor (0..1)
@export var grip: float = 3.5                # lower = wider, driftier corners
@export var min_top_speed: float = 520.0     # speed ceiling at spin_floor
@export var max_top_speed: float = 850.0     # speed ceiling at spin_cap
@export var wobble_amplitude: float = 3.5
@export var wobble_speed: float = 26.0

# to control item interaction ui visibility
@onready var interact_UI = $"../UI/item interaction ui/ColorRect"
@export_category("Wall Bounce")
@export var ricochet_boost: float = 1.4
@export var ricochet_min_speed: float = 120.0 # below this it's a soft tap, no boost
@export var ricochet_max_speed: float = 1500.0 # hard cap so corner-pinging can't run away
@export var ricochet_lockout: float = 0.18     # how long the bounce rides free of cap and grip
# precession/idle_wander fight your input, so they default off; nonzero for beyblade-y drift
@export var precession: float = 0.0
@export var precession_sign: float = 1.0     # +1 / -1 to match the blade's spin direction
@export var idle_wander: float = 0.0
@export var idle_wander_speed: float = 1.4

@export_category("Resources")
@export var launch_sfx_stream : AudioStream
@export var collision_sfx_stream : AudioStream

@export_category("Survival")
@export var max_health: float = 100.0
@export var enemy_damage_factor: float = 1.5 # x spin = dmg/sec
@export var blade_radius: float = 40.0
# dmg also scales with speed (ramming), so standing still barely hurts
@export var ram_full_speed: float = 80.0
@export var min_ram_mult: float = 0.1
@export var plow_resistance: float = 1.2 # drag force per enemy plowed
@export var knockback_factor: float = 0.6 # enemy shove = our speed x this
@export var drink_drop_chance: float = 0.08

@export_category("Dash Strike")
@export var dash_speed: float = 1500.0
@export var dash_boost_mult: float = 1.5
@export var dash_duration: float = 0.16
@export var dash_recovery: float = 0.26
@export var dash_cooldown: float = 0.20
@export var dash_recovery_drag: float = 9.0
@export var dash_spin_cost: float = 10.0
@export var dash_damage: float = 55.0
@export var dash_radius: float = 52.0
@export var dash_boss_knockback: float = 260.0

@export_category("Spin Blur")
@export var spin_blur_strength: float = 1.0
@export var spin_blur_max_angle: float = 0.9
@export var spin_blur_min_spin: float = 14.0
@export_range(2, 24) var spin_blur_samples: int = 12
# brightens the player blade so it reads lighter than the enemy blades
@export_range(0.0, 1.0) var blade_lighten: float = 0.6

@export_category("Boost FX")
@export var afterimage_interval: float = 0.018
@export var afterimage_fade: float = 0.3
@export var afterimage_color: Color = Color(0.35, 0.7, 1.0, 0.65)
@export var speed_line_color: Color = Color(0.85, 0.95, 1.0, 0.75)

const HORDE_GROUP := "horde_enemy"
const BOSS_GROUP := "boss"
const SPARK_INTERVAL := 0.08
const SPIN_FULL_COLOR := Color(0.2, 0.7, 1.0)
const SPIN_LOW_COLOR := Color(0.85, 0.4, 0.2)

var spin_velocity: float = 0.0
var player_died: bool = false
var _wander_phase: float = 0.0
var _wobble_phase: float = 0.0
var _ricochet_t: float = 0.0

var _health: float
var _dead: bool = false
var _won: bool = false
var _launching: bool = true
var _boss_seen: bool = false
var _dash_t: float = 0.0
var _recover_t: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _dash_vel: float = 0.0
var _dash_hits: Array = []
var _fx_accum: float = 0.0
var _spark_cd: float = 0.0
var _blade_material: ShaderMaterial
@onready var _sprite: Sprite2D = $Sprite2D
var _hp_bar: ProgressBar
var _hp_val: Label
var _spin_meter: ProgressBar
var _spin_val: Label
var _dash_skill: SkillIcon
var _objective_label: Label
var _boss_bar: ProgressBar
var _gameover_label: Label
var _victory_label: Label

func _ready() -> void:
	# this is necessary for _on_body_entered, 1 is technically enough for just the player but with multiple bayblades we might need to increase this value.
	max_contacts_reported = 5
	# needed for inventory system integration, sets the reference for the player using a global function
	Globals.player_reference(self)
	SceneManager.player_beyblade = self

	max_contacts_reported = 16

	_health = max_health
	_setup_spin_blur()
	_setup_hud()
	_play_spawn_intro()

func _play_spawn_intro() -> void:
	_launching = true
	freeze = true
	spin_velocity = 0.0
	var base_scale := _sprite.scale
	_sprite.scale = base_scale * 3.0
	_sprite.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_sprite, "scale", base_scale, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sprite, "modulate:a", 1.0, 0.3)
	tw.tween_method(_set_spin_velocity, 0.0, starting_spin_velocity, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(_on_spawn_intro_done)

func _set_spin_velocity(v: float) -> void:
	spin_velocity = v

func _on_spawn_intro_done() -> void:
	freeze = false
	_launching = false
	AudioManager.play_sfx(collision_sfx_stream, global_position)


func _exit_tree() -> void:
	SceneManager.player_beyblade = null


func _physics_process(delta: float) -> void:
	if _dead or _won:
		return

	_sprite.rotate(spin_velocity * delta)
	_update_spin_blur(delta)

	# during the spawn intro the blade spins up but takes no input or drain yet
	if _launching:
		return

	_update_boss_ui()
	_update_wobble(delta)

	spin_velocity = clamp(spin_velocity - spin_velocity_drop_over_time * delta, spin_floor, spin_cap)
	_ricochet_t = maxf(_ricochet_t - delta, 0.0)

	_update_status_hud()

	if _update_dash(delta):
		return

	_drive(delta)

	_shred_horde(delta)

func _spin_ratio() -> float:
	return clampf((spin_velocity - spin_floor) / maxf(spin_cap - spin_floor, 0.001), 0.0, 1.0)

# input hooks: AI-driven tops override these to steer without a keyboard
func _read_move_input() -> Vector2:
	return Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	)

func _wants_dash() -> bool:
	return Input.is_action_just_pressed("dash")

func _drive(delta: float) -> void:
	var input_dir := _read_move_input()
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	var spin_ratio := _spin_ratio()
	var control := lerpf(low_spin_control, 1.0, spin_ratio)
	var bouncing := _ricochet_t > 0.0

	if input_dir != Vector2.ZERO:
		var perp := Vector2(-input_dir.y, input_dir.x) * precession_sign
		var steer := (input_dir + perp * precession * spin_ratio).normalized()
		apply_central_force(steer * drive_force * lerpf(0.7, 1.0, spin_ratio) * control)

		# bleed sideways slide so it turns onto your heading; skip while bouncing so the bounce shows
		if not bouncing:
			var slide := linear_velocity - steer * linear_velocity.dot(steer)
			apply_central_force(-slide * grip * lerpf(0.55, 1.0, spin_ratio))
	elif idle_wander > 0.0:
		_wander_phase += delta * idle_wander_speed
		apply_central_force(Vector2.from_angle(_wander_phase) * idle_wander * spin_ratio)

	# a fresh wall bounce skips the cap so it can fly off faster for a moment
	if not bouncing:
		var top_speed := lerpf(min_top_speed, max_top_speed, spin_ratio)
		if linear_velocity.length() > top_speed:
			linear_velocity = linear_velocity.limit_length(top_speed)

# wobble grows as spin drains, so "about to die" reads without watching the meter
func _update_wobble(delta: float) -> void:
	_wobble_phase += delta * wobble_speed
	var wob := 1.0 - _spin_ratio()
	_sprite.position = Vector2.from_angle(_wobble_phase) * wobble_amplitude * wob

func _setup_spin_blur() -> void:
	var spr := $Sprite2D as Sprite2D
	if spr == null:
		return
	_blade_material = ShaderMaterial.new()
	_blade_material.shader = SPIN_BLUR_SHADER
	_blade_material.set_shader_parameter("samples", spin_blur_samples)
	_blade_material.set_shader_parameter("blur_angle", 0.0)
	_blade_material.set_shader_parameter("lighten", blade_lighten)
	spr.material = _blade_material

func _update_spin_blur(delta: float) -> void:
	if _blade_material == null:
		return
	var arc := 0.0
	if spin_velocity > spin_blur_min_spin:
		arc = minf((spin_velocity - spin_blur_min_spin) * delta * spin_blur_strength, spin_blur_max_angle)
	_blade_material.set_shader_parameter("blur_angle", arc)

# tex must be centered and full-frame (no atlas) or the blur pivots wrong
func set_blade_texture(tex: Texture2D) -> void:
	var spr := $Sprite2D as Sprite2D
	if spr == null:
		return
	spr.texture = tex
	if _blade_material == null:
		_setup_spin_blur()
	elif spr.material != _blade_material:
		spr.material = _blade_material

# radius shred (not physics contact, which was unreliable), scaled by spin and speed
func _shred_horde(delta: float) -> void:
	var speed := linear_velocity.length()
	var ram := clampf(speed / ram_full_speed, min_ram_mult, 1.0)
	var attack := spin_velocity * enemy_damage_factor * ram * delta
	var reach_sq := blade_radius * blade_radius
	var plowed := 0
	for enemy in get_tree().get_nodes_in_group(HORDE_GROUP):
		var e := enemy as Node2D
		if e == null or e is HordeBoss: # boss only takes damage from dash-strikes
			continue
		if global_position.distance_squared_to(e.global_position) > reach_sq:
			continue
		plowed += 1
		if e.has_method("shove"):
			var dir := e.global_position - global_position
			if dir.length() < 0.01:
				dir = Vector2.RIGHT
			e.shove(dir.normalized(), speed * knockback_factor)
		if e.has_method("take_damage") and e.take_damage(attack):
			_on_enemy_killed(e)
	# resistance: plowing a crowd drags us, denser = slower
	if plowed > 0:
		apply_central_force(-linear_velocity * plow_resistance * float(mini(plowed, 8)))

func _update_dash(delta: float) -> bool:
	_dash_cd = maxf(_dash_cd - delta, 0.0)

	if _dash_t > 0.0:
		_dash_t -= delta
		_dash_active_step(delta)
		if _dash_t <= 0.0:
			_recover_t = dash_recovery
		return true

	if _recover_t > 0.0:
		_recover_t -= delta
		linear_velocity = linear_velocity.lerp(Vector2.ZERO, clampf(dash_recovery_drag * delta, 0.0, 1.0))
		_shred_horde(delta)
		return true

	if _wants_dash() and _dash_cd <= 0.0 and spin_velocity >= dash_spin_cost:
		_start_dash()
		_dash_active_step(delta)
		return true

	return false

func _dash_active_step(delta: float) -> void:
	linear_velocity = _dash_dir * _dash_vel
	_dash_strike()
	_spawn_dash_fx(delta)

func _start_dash() -> void:
	_dash_dir = _aim_dir()
	_dash_vel = maxf(dash_speed, linear_velocity.length() * dash_boost_mult)
	_dash_t = dash_duration
	_dash_cd = dash_duration + dash_recovery + dash_cooldown
	spin_velocity = clampf(spin_velocity - dash_spin_cost, spin_floor, spin_cap)
	_dash_hits.clear()
	_fx_accum = afterimage_interval
	AudioManager.play_sfx(launch_sfx_stream, global_position)

func _spawn_dash_fx(delta: float) -> void:
	_fx_accum += delta
	if _fx_accum < afterimage_interval:
		return
	_fx_accum = 0.0
	_spawn_afterimage()
	_spawn_speed_lines()

func _spawn_afterimage() -> void:
	var spr := $Sprite2D as Sprite2D
	if spr == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = spr.texture
	ghost.global_position = spr.global_position
	ghost.global_rotation = spr.global_rotation
	ghost.global_scale = spr.global_scale
	ghost.modulate = afterimage_color
	ghost.z_index = -1
	get_parent().add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, afterimage_fade)
	tw.tween_callback(ghost.queue_free)

func _spawn_speed_lines() -> void:
	for _i in 2:
		var perp := Vector2(-_dash_dir.y, _dash_dir.x) * randf_range(-22.0, 22.0)
		var length := randf_range(28.0, 56.0)
		var line := Line2D.new()
		line.global_position = global_position + perp - _dash_dir * randf_range(6.0, 16.0)
		line.points = PackedVector2Array([Vector2.ZERO, -_dash_dir * length])
		line.width = randf_range(1.5, 3.0)
		line.default_color = speed_line_color
		line.z_index = -1
		get_parent().add_child(line)
		var tw := line.create_tween()
		tw.tween_property(line, "modulate:a", 0.0, 0.22)
		tw.tween_callback(line.queue_free)

func _aim_dir() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_action_pressed("left"): d.x -= 1.0
	if Input.is_action_pressed("right"): d.x += 1.0
	if Input.is_action_pressed("up"): d.y -= 1.0
	if Input.is_action_pressed("down"): d.y += 1.0
	if d != Vector2.ZERO:
		return d.normalized()
	if linear_velocity.length() > 1.0:
		return linear_velocity.normalized()
	return _dash_dir

func _dash_strike() -> void:
	var reach_sq := dash_radius * dash_radius
	for enemy in get_tree().get_nodes_in_group(HORDE_GROUP):
		var e := enemy as Node2D
		if e == null or _dash_hits.has(e.get_instance_id()):
			continue
		if global_position.distance_squared_to(e.global_position) > reach_sq:
			continue
		_dash_hits.append(e.get_instance_id())
		var dir := e.global_position - global_position
		if dir.length() < 0.01:
			dir = _dash_dir
		dir = dir.normalized()
		if e is HordeBoss and e.has_method("stagger"):
			e.stagger(_dash_dir, dash_boss_knockback)
		elif e.has_method("shove"):
			e.shove(dir, dash_boss_knockback)
		if e.has_method("take_damage") and e.take_damage(dash_damage):
			_on_enemy_killed(e)

func _on_enemy_killed(enemy: Node) -> void:
	var spin_reward := 5.0
	if enemy is HordeEnemy:
		spin_reward = enemy.spin_reward
	spin_velocity = clampf(spin_velocity + spin_reward, spin_floor, spin_cap)
	if enemy is HordeBoss:
		_win()
		return
	for s in get_tree().get_nodes_in_group("enemy_spawner"):
		if s.has_method("register_kill"):
			s.register_kill()
	if enemy is Node2D and randf() < drink_drop_chance:
		_drop_drink((enemy as Node2D).global_position)

func _drop_drink(pos: Vector2) -> void:
	var drink := DRINK_SCENE.instantiate()
	get_parent().add_child(drink)
	drink.global_position = pos

# slightly lower spin velocity every time there is a collision with another rigid body
# we can add ways to increase your spin later to give the player more control
func _on_body_entered(body: Node) -> void:
	# horde contact handled in _shred_horde; skip to avoid spin/shake/sfx spam
	if body and body.is_in_group(HORDE_GROUP):
		return

	spin_velocity -= spin_velocity_drop_on_collision
	
	# requires on the player having a collision area 2d to pickup items,
	#if area.has_method("pickup_item"):
		#area.pickup_item()

	var impact := clampf(linear_velocity.length() / max_top_speed, 0.35, 1.4)
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(collision_shake_trauma * impact)

	if(body is Node2D):
		var body2D = body as Node2D
		AudioManager.play_sfx(collision_sfx_stream, body2D.global_position)
	pass

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	_spark_cd = maxf(_spark_cd - state.step, 0.0)
	var contacts := state.get_contact_count()
	if contacts <= 0:
		return

	# only walls/obstacles ricochet; the horde gets plowed, not bounced off of
	var wall_contact := -1
	for i in contacts:
		var col := state.get_contact_collider_object(i)
		if col is Node and (col as Node).is_in_group(HORDE_GROUP):
			continue
		wall_contact = i
		break
	if wall_contact < 0:
		return

	if _spark_cd <= 0.0:
		_spark_cd = SPARK_INTERVAL
		var sparks = SPARKS_SCENE.instantiate()
		sparks.global_position = state.get_contact_local_position(wall_contact)
		get_parent().add_child(sparks)
		get_tree().create_timer(0.1).timeout.connect(sparks.queue_free)

	# bounce=1.0 reflects the speed; we scale that speed up so the wall hit adds a kick.
	# scaling the length (not flipping the direction ourselves) works pre- or post-bounce.
	var spd := state.linear_velocity.length()
	if spd >= ricochet_min_speed:
		state.linear_velocity = state.linear_velocity / spd * minf(spd * ricochet_boost, ricochet_max_speed)
		_ricochet_t = ricochet_lockout

# this is used to give the player a buff
# feel free to use it as much as you want in other scripts
# its pretty self explanatory
func gain_energy(amount):
	spin_velocity = clamp(spin_velocity + amount, spin_floor, spin_cap)

func heal(amount: float) -> void:
	if _dead or _won:
		return
	_health = minf(_health + amount, max_health)

func take_damage(amount: float) -> void:
	if _dead or _won or _dash_t > 0.0: # i-frames during the dash
		return
	_health = max(_health - amount, 0.0)
	if _health <= 0.0:
		_die()

func _die() -> void:
	_dead = true
	player_died = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	if _blade_material:
		_blade_material.set_shader_parameter("blur_angle", 0.0)
	_gameover_label.visible = true
	_stop_spawners()

func _win() -> void:
	if _won or _dead:
		return
	_won = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	if _blade_material:
		_blade_material.set_shader_parameter("blur_angle", 0.0)
	_objective_label.visible = false
	_boss_bar.visible = false
	_victory_label.visible = true
	_clear_horde()
	get_tree().create_timer(2.0).timeout.connect(SceneManager.end_battle)

func _stop_spawners() -> void:
	for s in get_tree().get_nodes_in_group("enemy_spawner"):
		if s.has_method("stop"):
			s.stop()

func _clear_horde() -> void:
	_stop_spawners()
	for enemy in get_tree().get_nodes_in_group(HORDE_GROUP):
		if enemy.has_method("poof"):
			enemy.poof()

func _setup_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	var panel := VBoxContainer.new()
	panel.position = Vector2(16, 14)
	panel.add_theme_constant_override("separation", 5)
	hud.add_child(panel)

	_hp_bar = _make_bar(Color(0.9, 0.27, 0.3))
	_hp_val = _bar_overlay(_hp_bar)
	panel.add_child(_status_row("HP", _hp_bar))

	var skill_area := VBoxContainer.new()
	skill_area.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_area.add_theme_constant_override("separation", 3)
	skill_area.anchor_left = 0.5
	skill_area.anchor_right = 0.5
	skill_area.anchor_top = 1.0
	skill_area.anchor_bottom = 1.0
	skill_area.grow_horizontal = Control.GROW_DIRECTION_BOTH
	skill_area.grow_vertical = Control.GROW_DIRECTION_BEGIN
	skill_area.offset_bottom = -16.0
	hud.add_child(skill_area)

	var skill_bar := HBoxContainer.new()
	skill_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_bar.add_theme_constant_override("separation", 6)
	skill_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skill_area.add_child(skill_bar)

	_dash_skill = SkillIcon.new()
	skill_bar.add_child(_dash_skill)
	_dash_skill.setup("SPACE", SkillIcon.Icon.DASH)

	_spin_meter = _make_bar(SPIN_FULL_COLOR)
	_spin_meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_spin_val = _bar_overlay(_spin_meter)
	skill_area.add_child(_spin_meter)

	_objective_label = Label.new()
	_objective_label.text = "DEFEAT THE EVIL BEYBLADE"
	_objective_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_objective_label.offset_top = 8.0
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.visible = false
	hud.add_child(_objective_label)

	_boss_bar = _make_bar(Color(0.85, 0.2, 0.22))
	_boss_bar.custom_minimum_size = Vector2(260, 16)
	_boss_bar.anchor_left = 0.5
	_boss_bar.anchor_right = 0.5
	_boss_bar.offset_left = -130.0
	_boss_bar.offset_right = 130.0
	_boss_bar.offset_top = 32.0
	_boss_bar.offset_bottom = 48.0
	_boss_bar.visible = false
	hud.add_child(_boss_bar)

	_gameover_label = Label.new()
	_gameover_label.text = "GAME OVER"
	_gameover_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gameover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gameover_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gameover_label.visible = false
	hud.add_child(_gameover_label)

	_victory_label = Label.new()
	_victory_label.text = "VICTORY!"
	_victory_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_victory_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_victory_label.visible = false
	hud.add_child(_victory_label)

	_update_status_hud()

func _make_bar(fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.custom_minimum_size = Vector2(172, 18)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(3)
	var fl := StyleBoxFlat.new()
	fl.bg_color = fill
	fl.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fl)
	return bar

func _bar_overlay(bar: ProgressBar) -> Label:
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(lbl)
	return lbl

func _status_row(label_text: String, content: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.custom_minimum_size = Vector2(54, 0)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(name_lbl)
	row.add_child(content)
	return row

func _update_status_hud() -> void:
	var hp_frac := _health / max_health if max_health > 0.0 else 0.0
	_hp_bar.value = clampf(hp_frac, 0.0, 1.0) * 100.0
	_hp_val.text = "%d / %d" % [ceil(_health), int(max_health)]

	_spin_meter.value = (spin_velocity / spin_cap) * 100.0
	_spin_val.text = "%d" % roundi(spin_velocity)
	var spin_fill := _spin_meter.get_theme_stylebox("fill") as StyleBoxFlat
	if spin_fill:
		spin_fill.bg_color = SPIN_LOW_COLOR if spin_velocity < dash_spin_cost else SPIN_FULL_COLOR

	_update_skill_bar()

func _update_skill_bar() -> void:
	var total := dash_duration + dash_recovery + dash_cooldown
	var fill := 1.0 if _dash_cd <= 0.0 else clampf(1.0 - _dash_cd / total, 0.0, 1.0)
	_dash_skill.set_state(fill, spin_velocity < dash_spin_cost)

func _update_boss_ui() -> void:
	var boss := get_tree().get_first_node_in_group(BOSS_GROUP)
	if boss and boss.has_method("health_fraction"):
		_boss_seen = true
		_objective_label.visible = true
		_boss_bar.visible = true
		_boss_bar.value = boss.health_fraction() * 100.0
	elif _boss_seen:
		_objective_label.visible = false
		_boss_bar.visible = false
