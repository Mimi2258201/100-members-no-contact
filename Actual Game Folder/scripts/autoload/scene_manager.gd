extends Node

@onready var _WORLD_NODE = get_node("/root/World")

enum SceneKey {
	MENU,
	GAMEPLAY,
}
const _SCENES_MAP: Dictionary = {
	SceneKey.MENU: "res://Actual Game Folder/scenes/menu.tscn",
	SceneKey.GAMEPLAY: "res://Actual Game Folder/scenes/gameplay.tscn",
}

var current_scene;

# Whenever we want to change the screen, menu to gameplay or whatever
# We'll use this, but issue with this is, this will not have any animation
# If someone wants to, they can maybe hack around this, or better state machine
# for changing screens
func change_screen(scene_name: SceneKey):
	if current_scene:
		current_scene.queue_free();
	else:
		# Assuming this is a start of the app so freeing all
		_WORLD_NODE.get_children().map(func(s):
			s.queue_free()
		)

	var scene_path: String = _SCENES_MAP[scene_name]
	var node: Node = load(scene_path).instantiate()

	current_scene = node;

	_WORLD_NODE.add_child(node)
