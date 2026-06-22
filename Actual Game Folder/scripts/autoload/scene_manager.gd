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
	SceneKey.GARAGE: "res://Actual Game Folder/scenes/levels/exploration/garage.tscn",
}

var current_scene
var battle_context: Dictionary = {}
var player_beyblade: Node2D = null
var bullet_container: Node2D = null

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

	current_scene = _mount(SceneKey.GAMEPLAY)
	AudioManager.crossfade_music(preload("res://Miscellanious Assets Dump/Audio/music/beyblades-battle.mp3"))

	await Transition.reveal()

func end_battle() -> void:
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

func _mount(scene_name: SceneKey) -> Node:
	if _WORLD_NODE == null or not is_instance_valid(_WORLD_NODE):
		_refresh_world_node()
			
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
