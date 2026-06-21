extends Node

@onready var _WORLD_NODE = get_node("/root/World")

enum SceneKey {
	MENU,
	EXPLORATION,
	GAMEPLAY,
}
const _SCENES_MAP: Dictionary = {
	SceneKey.MENU: "res://Actual Game Folder/scenes/menu.tscn",
	SceneKey.EXPLORATION: "res://Actual Game Folder/scenes/levels/exploration/green_field.tscn",
	SceneKey.GAMEPLAY: "res://Actual Game Folder/scenes/gameplay.tscn",
}

var current_scene
var battle_context: Dictionary = {}

var _suspended: Array = []

func change_screen(scene_name: SceneKey):
	for s in _suspended:
		s.queue_free()
	_suspended.clear()

	if current_scene:
		current_scene.queue_free();
	else:
		_WORLD_NODE.get_children().map(func(s):
			s.queue_free()
		)

	current_scene = _mount(scene_name)

func enter_battle(context: Dictionary = {}) -> void:
	battle_context = context
	if current_scene:
		_set_suspended(current_scene, true)
		_suspended.push_back(current_scene)
	current_scene = _mount(SceneKey.GAMEPLAY)

func end_battle() -> void:
	if current_scene:
		current_scene.queue_free()
	current_scene = _suspended.pop_back() if not _suspended.is_empty() else null
	if current_scene:
		_set_suspended(current_scene, false)

func _mount(scene_name: SceneKey) -> Node:
	var node: Node = load(_SCENES_MAP[scene_name]).instantiate()
	_WORLD_NODE.add_child(node)
	_activate_camera(node)
	return node

func _set_suspended(node: Node, suspended: bool) -> void:
	if node is CanvasItem:
		node.visible = not suspended
	node.process_mode = Node.PROCESS_MODE_DISABLED if suspended else Node.PROCESS_MODE_INHERIT
	if not suspended:
		_activate_camera(node)

func _activate_camera(root: Node) -> void:
	var cam := _find_camera(root)
	if cam:
		cam.make_current()

func _find_camera(node: Node) -> Camera2D:
	if node is Camera2D:
		return node
	for child in node.get_children():
		var found := _find_camera(child)
		if found:
			return found
	return null
