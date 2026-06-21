extends Control

@export var start_button : Button
@export var story_button : Button
@export var exit_button : Button
@export var button_hover_stream : AudioStream
@export var button_click_stream : AudioStream
@export var music_stream : AudioStream

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	start_button.pressed.connect(start)
	start_button.mouse_entered.connect(hover)
	story_button.pressed.connect(story)
	story_button.mouse_entered.connect(hover)
	exit_button.pressed.connect(exit)
	exit_button.mouse_entered.connect(hover)
	AudioManager.play_music_stream(music_stream)

func hover():
	AudioManager.play_sfx(button_hover_stream,Vector2.ZERO)

func start():
	AudioManager.play_sfx(button_click_stream,Vector2.ZERO)
	SceneManager.enter_battle()

func story():
	AudioManager.play_sfx(button_click_stream,Vector2.ZERO)
	SceneManager.change_screen(SceneManager.SceneKey.EXPLORATION)

func exit():
	var sPlayer = AudioManager.get_sfx_player(button_click_stream,Vector2.ZERO)
	sPlayer.play()
	sPlayer.finished.connect(get_tree().quit)
