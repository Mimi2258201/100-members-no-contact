extends Area2D

enum Mode { CHANGE, PUSH, POP }

@export var destination: SceneManager.SceneKey = SceneManager.SceneKey.GREEN_FIELD
@export var mode: Mode = Mode.CHANGE

@export var requires_beyblade: bool = false
@export_multiline var locked_message: Array[String] = [
	"I shouldn't leave without my Beyblade!"
]

# starts disarmed so spawning or resuming on top of a door never instantly
# re-triggers it; _physics_process arms it once the player is clear
var _armed: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not _is_player(body) or not _armed:
		return
	if requires_beyblade and not Globals.has_beyblade:
		if body.has_method("start_dialog"):
			body.start_dialog(locked_message)
		return
	_armed = false
	match mode:
		Mode.PUSH:
			SceneManager.push_scene(destination)
		Mode.POP:
			SceneManager.pop_scene()
		_:
			SceneManager.change_screen(destination)

func _physics_process(_delta: float) -> void:
	if _armed:
		return
	for body in get_overlapping_bodies():
		if _is_player(body):
			return
	_armed = true

func _is_player(body: Node) -> bool:
	return body.is_in_group("player") or body.name == "PlayerEx"
