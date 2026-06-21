extends Button

func _ready() -> void:
	pressed.connect(SceneManager.end_battle)
