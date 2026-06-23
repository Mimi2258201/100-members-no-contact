extends Control

@export var start_button : Button
@export var endless_button : Button
@export var exit_button : Button
@export var button_hover_stream : AudioStream
@export var button_click_stream : AudioStream
@export var music_stream : AudioStream
@export var Audio_bus_name : String
var audio_bus_id

@onready var settings: Panel = $Settings





# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	start_button.pressed.connect(start)
	start_button.mouse_entered.connect(hover)
	endless_button.pressed.connect(endless)
	endless_button.mouse_entered.connect(hover)
	exit_button.pressed.connect(exit)
	exit_button.mouse_entered.connect(hover)
	AudioManager.play_music_stream(music_stream)
	
	settings.visible = false
	audio_bus_id = AudioServer.get_bus_index(Audio_bus_name)
	

func hover():
	AudioManager.play_sfx(button_hover_stream,Vector2.ZERO)

func start():
	AudioManager.play_sfx(button_click_stream,Vector2.ZERO)
	AudioManager.fade_out_music()
	SceneManager.change_screen(SceneManager.SceneKey.EXPLORATION)

func endless():
	AudioManager.play_sfx(button_click_stream,Vector2.ZERO)
	AudioManager.fade_out_music()
	SceneManager.change_screen(SceneManager.SceneKey.GAMEPLAY) # NO ENDLESS MODE EXISTS YET

func exit():
	var sPlayer = AudioManager.get_sfx_player(button_click_stream,Vector2.ZERO)
	sPlayer.play()
	sPlayer.finished.connect(get_tree().quit)


func _on_settings_pressed() -> void:
	settings.visible = true


func _on_close_options_pressed() -> void:
	settings.visible = false


func _on_music_value_changed(value: float) -> void:
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(audio_bus_id,db)
