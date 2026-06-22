extends Node

var sfxPlayerPool : Array[AudioStreamPlayer2D]
var sfxPlayerPoolStartCount = 10
var musicPlayer : AudioStreamPlayer
var sfxBusName = "sfx"
var musicBusName = "music"
var volume = 0.25

const _SILENT_DB := -60.0
var _musicPlayerB : AudioStreamPlayer
var _activeMusic : AudioStreamPlayer

func _ready() -> void:
	musicPlayer = _make_music_player()
	_musicPlayerB = _make_music_player()
	_activeMusic = musicPlayer

	for i in range(sfxPlayerPoolStartCount):
		var sPlayer = AudioStreamPlayer2D.new()
		sPlayer.bus = sfxBusName
		sfxPlayerPool.push_back(sPlayer)
		add_child(sPlayer)

func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = musicBusName
	p.volume_db = linear_to_db(volume)
	add_child(p)
	return p

func play_music_stream(musicStream : AudioStream):
	_activeMusic.stream = musicStream
	_activeMusic.volume_db = linear_to_db(volume)
	_activeMusic.play()

func crossfade_music(musicStream : AudioStream, fade_time : float = 0.8):
	var incoming := _musicPlayerB if _activeMusic == musicPlayer else musicPlayer
	var outgoing := _activeMusic
	incoming.stream = musicStream
	incoming.volume_db = _SILENT_DB
	incoming.play()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(incoming, "volume_db", linear_to_db(volume), fade_time)
	if outgoing.playing and outgoing != incoming:
		tw.tween_property(outgoing, "volume_db", _SILENT_DB, fade_time)
		tw.chain().tween_callback(outgoing.stop)
	_activeMusic = incoming

func fade_out_music(fade_time : float = 0.5):
	if not _activeMusic.playing:
		return
	var p := _activeMusic
	var tw := create_tween()
	tw.tween_property(p, "volume_db", _SILENT_DB, fade_time)
	tw.tween_callback(p.stop)

func stop_music():
	musicPlayer.stop()
	_musicPlayerB.stop()

# get player separated so continuous SFX can be played/stopped by getting a player from other scripts
func get_sfx_player(stream : AudioStream, position : Vector2) -> AudioStreamPlayer2D:
	
	for sPlayer in sfxPlayerPool:
		if !sPlayer.playing:
			sPlayer.global_position = position
			sPlayer.stream = stream
			return sPlayer
	var sPlayer = AudioStreamPlayer2D.new()
	sPlayer.bus = sfxBusName
	add_child(sPlayer)
	sfxPlayerPool.push_back(sPlayer)
	return sPlayer

# for one-shot SFX
func play_sfx(stream : AudioStream, position : Vector2):
	var sPlayer = get_sfx_player(stream,position)
	sPlayer.play()
