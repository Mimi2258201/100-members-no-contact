extends Node

var sfxPlayerPool : Array[AudioStreamPlayer2D]
var sfxPlayerPoolStartCount = 10
var musicPlayer : AudioStreamPlayer
var sfxBusName = "sfx"
var musicBusName = "music"

func _ready() -> void:
	musicPlayer = AudioStreamPlayer.new()
	musicPlayer.bus = musicBusName
	add_child(musicPlayer)

	for i in range(sfxPlayerPoolStartCount):
		var sPlayer = AudioStreamPlayer2D.new()
		sPlayer.bus = sfxBusName
		sfxPlayerPool.push_back(sPlayer)
		add_child(sPlayer)

func play_music_stream(musicStream : AudioStream):
	musicPlayer.stream = musicStream
	musicPlayer.play()

func stop_music():
	musicPlayer.stop()

# get player separated so continuous SFX can be played/stopped by getting a player from other scripts
func get_sfx_player(stream : AudioStream, position : Vector2) -> AudioStreamPlayer2D:
    
	for sPlayer in sfxPlayerPool:
		if !sPlayer.playing:
			sPlayer.global_position = position
			sPlayer.stream = stream
			return sPlayer
	var sPlayer = AudioStreamPlayer2D.new()
	sfxPlayerPool.push_back(sPlayer)
	return sPlayer

# for one-shot SFX
func play_sfx(stream : AudioStream, position : Vector2):
	var sPlayer = get_sfx_player(stream,position)
	sPlayer.play()