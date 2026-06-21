extends Node

@onready var _WORLD_NODE = get_node("/root/World")

enum SceneKey {
	MENU,
	EXPLORATION,
	GAMEPLAY,
	GARAGE,
}
const _SCENES_MAP: Dictionary = {
	SceneKey.MENU: "res://Actual Game Folder/scenes/menu.tscn",
	SceneKey.EXPLORATION: "res://Actual Game Folder/scenes/levels/exploration/green_field.tscn",
	SceneKey.GAMEPLAY: "res://Actual Game Folder/scenes/gameplay.tscn",
	SceneKey.GARAGE: "res://Actual Game Folder/scenes/garage.tscn",
}

var current_scene
var battle_context: Dictionary = {}

var _suspended: Array = []

func change_screen(scene_name: SceneKey):
	for s in _suspended:
		if is_instance_valid(s):
			s.queue_free()
	_suspended.clear()

	if current_scene:
		current_scene.queue_free();
	else:
		_WORLD_NODE = get_node_or_null("/root/World")
		if _WORLD_NODE != null:
			for child in _WORLD_NODE.get_children():
				if is_instance_valid(child):
					child.queue_free()

	current_scene = _mount(scene_name)

func enter_battle(context: Dictionary = {}) -> void:
	battle_context = context
	if current_scene:
		_set_suspended(current_scene, true)
		_suspended.push_back(current_scene)
		
		if current_scene.get_parent() == _WORLD_NODE:
			_WORLD_NODE.remove_child(current_scene)
			
	current_scene = _mount(SceneKey.GAMEPLAY)
	AudioManager.play_music_stream(preload("res://Miscellanious Assets Dump/Audio/music/beyblades-battle.mp3"))

func end_battle() -> void:
	if current_scene:
		current_scene.queue_free()
	current_scene = _suspended.pop_back() if not _suspended.is_empty() else null
	if current_scene:
		if current_scene.get_parent() == null:
			_WORLD_NODE.add_child(current_scene)
			
		_set_suspended(current_scene, false)
	AudioManager.stop_music()

func _mount(scene_name: SceneKey) -> Node:
	_WORLD_NODE = get_node_or_null("/root/World")
	if _WORLD_NODE == null:
		var root = get_tree().root
		if root.has_node("World"):
			_WORLD_NODE = root.get_node("World")
		else:
			_WORLD_NODE = root
			
	var node: Node = load(_SCENES_MAP[scene_name]).instantiate()
	
	if _WORLD_NODE != null:
		_WORLD_NODE.add_child(node)
		_activate_camera(node)
	else:
		push_error("There's no valid node to mount the scene")
	return node

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
