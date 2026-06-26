extends Node

@onready var _WORLD_NODE = get_node("/root/World")

enum SceneKey {
	#--- Menus
	MENU,
	OPTIONS, # doesn't exist yet
	GAME_OVER, # doesnt exist yet
	
	#--- Exploration
	EXPLORATION,
	GREEN_FIELD,
	FUTURE_PLACE,
	DUNGEON,
	GARAGE,
	
	#--- Gameplay
	GAMEPLAY,
	SEAGULL_BATTLE,
	
	# --- More
	IDK
}
const _SCENES_MAP: Dictionary = {
	SceneKey.MENU: "res://Actual Game Folder/scenes/menu.tscn",
	SceneKey.EXPLORATION: "res://Actual Game Folder/scenes/levels/exploration/house.tscn",
	SceneKey.GREEN_FIELD: "res://Actual Game Folder/scenes/levels/exploration/green_field.tscn",
	SceneKey.FUTURE_PLACE: "res://Actual Game Folder/scenes/levels/exploration/future_place.tscn",
	SceneKey.DUNGEON: "res://Actual Game Folder/scenes/levels/exploration/dungeon.tscn",
	SceneKey.GAMEPLAY: "res://Actual Game Folder/scenes/gameplay.tscn",
	SceneKey.SEAGULL_BATTLE: "res://Actual Game Folder/scenes/battles/seagull_battle.tscn",
	SceneKey.GARAGE: "res://Actual Game Folder/scenes/levels/exploration/garage.tscn",
}

var current_scene
var battle_context: Dictionary = {}
var battle_number: int = 0 # 1 on the first fight; drives the spawner's enemy-type progression
var _battle_active: bool = false
var pending_reward_dialogue: Array[String] = []
var player_beyblade: Node2D = null
var bullet_container: Node2D = null
var debris_container: Node = null

var _suspended: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_refresh_world_node()

func change_screen(scene_name: SceneKey) -> void:
	# tree edits are illegal mid physics callback (door body_entered), so defer
	call_deferred("_change_screen_now", scene_name)

func _change_screen_now(scene_name: SceneKey) -> void:
	for s in _suspended:
		if is_instance_valid(s):
			s.queue_free()
	_suspended.clear()

	_refresh_world_node()
	
	if _WORLD_NODE != null:
		for child in _WORLD_NODE.get_children():
			if is_instance_valid(child):
				_WORLD_NODE.remove_child(child) # Lo saca del motor de colisiones y físicas YA
				child.queue_free() # Lo borra de la memoria al final del frame
	
	current_scene = null
	
	current_scene = _mount(scene_name)

func enter_battle(context: Dictionary = {}) -> void:
	call_deferred("_enter_battle_now", context)

func _enter_battle_now(context: Dictionary) -> void:
	await Transition.cover()

	battle_context = context
	if current_scene:
		_set_suspended(current_scene, true)
		_suspended.push_back(current_scene)

		if current_scene.get_parent() == _WORLD_NODE:
			_WORLD_NODE.remove_child(current_scene)

	# Not ideal.
	if context["name"] == "Just Seagull":
		current_scene = _mount(SceneKey.SEAGULL_BATTLE)
	else:
		current_scene = _mount(SceneKey.GAMEPLAY)
	_battle_active = true
	AudioManager.crossfade_music(preload("res://Miscellanious Assets Dump/Audio/music/spinblades-battle.mp3"))

	await Transition.reveal()

func end_battle() -> void:
	# the win timer and the EndBattle button both fire this; only honor the first
	if not _battle_active:
		return
	_battle_active = false

	await Transition.cover()

	var returning = _suspended.pop_back() if not _suspended.is_empty() else null
	if returning:
		if current_scene:
			current_scene.queue_free()
		current_scene = returning
		if current_scene.get_parent() == null:
			_WORLD_NODE.add_child(current_scene)

		_set_suspended(current_scene, false)
		get_tree().call_group("overworld_player", "_on_return_from_battle")
		AudioManager.fade_out_music()
	else:
		# nothing was suspended to return to (battle entered outside the overworld)
		_refresh_world_node()
		if _WORLD_NODE != null:
			for child in _WORLD_NODE.get_children():
				if is_instance_valid(child):
					_WORLD_NODE.remove_child(child)
					child.queue_free()
		current_scene = _mount(SceneKey.MENU)

	await Transition.reveal()

func report_battle_won() -> void:
	var reward := str(battle_context.get("reward", ""))
	match reward:
		"spin_dash":
			Globals.spin_dash = true
			pending_reward_dialogue = [
				"Uff da... ya really beat me, eh.",
				"A deal's a deal. Here ya go — the SPIN-DASH, like I promised, you betcha.",
				"Press Space while yer movin' to bust clean through a wall.",
				"Head east — there's a stack of Minnesotas wallin' off the garage. Crack 'em open and go bug the mechanic, bud."
			]
		"seagull_contempt":
			pending_reward_dialogue = [
				"squawk!",
			]

func take_reward_dialogue() -> Array[String]:
	var lines := pending_reward_dialogue
	pending_reward_dialogue = []
	return lines

# Difficulty curve: enemies hit harder and soak more each battle. Battle 1 is the baseline (x1).
func enemy_damage_mult() -> float:
	return 1.0 + (maxi(battle_number, 1) - 1) * 0.35

func enemy_health_mult() -> float:
	return 1.0 + (maxi(battle_number, 1) - 1) * 0.25

func push_scene(scene_name: SceneKey) -> void:
	# tree edits are illegal mid physics callback (mechanic body_entered), so defer
	call_deferred("_push_scene_now", scene_name)

func _push_scene_now(scene_name: SceneKey) -> void:
	if current_scene:
		_set_suspended(current_scene, true)
		_suspended.push_back(current_scene)
		if current_scene.get_parent() == _WORLD_NODE:
			_WORLD_NODE.remove_child(current_scene)

	current_scene = _mount(scene_name)

func pop_scene() -> void:
	call_deferred("_pop_scene_now")

func _pop_scene_now() -> void:
	var returning = _suspended.pop_back() if not _suspended.is_empty() else null
	if returning == null:
		# nothing to resume; fall back to a fresh overworld
		_change_screen_now(SceneKey.GREEN_FIELD)
		return

	if current_scene:
		current_scene.queue_free()
	current_scene = returning
	if current_scene.get_parent() == null:
		_WORLD_NODE.add_child(current_scene)

	_set_suspended(current_scene, false)

func _mount(scene_name: SceneKey) -> Node:
	if _WORLD_NODE == null or not is_instance_valid(_WORLD_NODE):
		_refresh_world_node()
			
	# count battles before the scene mounts, so the spawner reads the new number in _ready
	match scene_name:
		SceneKey.GAMEPLAY:
			battle_number += 1
		SceneKey.MENU:
			battle_number = 0

	var node: Node = load(_SCENES_MAP[scene_name]).instantiate()
	
	if _WORLD_NODE != null:
		_WORLD_NODE.add_child(node)
		_activate_camera(node)
	else:
		push_error("There's no valid node to mount the scene")
		
	return node
	
func _refresh_world_node() -> void:
	_WORLD_NODE = get_node_or_null("/root/World")
	
	if _WORLD_NODE == null:
		var tree = get_tree()
		if tree != null and tree.root != null:
			if tree.root.has_node("World"):
				_WORLD_NODE = tree.root.get_node("World")
			else:
				_WORLD_NODE = tree.root

func _set_suspended(node: Node, suspended: bool) -> void:
	if node is CanvasItem:
		node.visible = not suspended
	if suspended:
		node.process_mode = Node.PROCESS_MODE_DISABLED
		
		var cam = _find_camera(node)
		if cam: 
			cam.enabled = false
	else:
		node.process_mode = Node.PROCESS_MODE_INHERIT
		_activate_camera(node)

func _activate_camera(root: Node) -> void:
	var cam := _find_camera(root)
	if cam:
		cam.enabled = true
		cam.make_current()

func _find_camera(node: Node) -> Camera2D:
	if node is Camera2D:
		return node
	for child in node.get_children():
		var found := _find_camera(child)
		if found:
			return found
	return null
