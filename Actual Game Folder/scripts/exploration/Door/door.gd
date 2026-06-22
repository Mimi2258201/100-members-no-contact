extends Area2D

@export var destination: SceneManager.SceneKey = SceneManager.SceneKey.GREEN_FIELD

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") or body.name == "PlayerEx":
		SceneManager.change_screen(destination)
