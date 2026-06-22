extends Button

func _input(_event) -> void:
	if button_pressed:
		SceneManager.change_screen(SceneManager.SceneKey.GAMEPLAY)
