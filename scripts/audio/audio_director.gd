class_name AudioDirector
extends Node

var master_volume := 0.85
var effects_volume := 0.85
var music_volume := 0.55
static var _library: Dictionary = {}
static var _music_stream: AudioStreamWAV
var _voices: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _playback_enabled := true

func _ready() -> void:
	_playback_enabled = DisplayServer.get_name() != "headless"
	if _library.is_empty():
		_library = SfxLibrary.build()
	if _music_stream == null:
		_music_stream = _build_music()
	for i in range(12):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.push_back(voice)
	_music = AudioStreamPlayer.new()
	_music.stream = _music_stream
	add_child(_music)
	if _playback_enabled:
		_music.play()
	apply_volumes()

func apply_volumes() -> void:
	if _music != null:
		_music.volume_db = linear_to_db(maxf(master_volume * music_volume * 0.25, 0.0001))
		_music.stream_paused = master_volume <= 0.0 or music_volume <= 0.0

func play_cue(cue: String, pitch := 1.0) -> void:
	if not _playback_enabled or not _library.has(cue) or master_volume <= 0.0 or effects_volume <= 0.0:
		return
	for voice in _voices:
		if not voice.playing:
			voice.stream = _library[cue]
			voice.pitch_scale = pitch
			voice.volume_db = linear_to_db(maxf(master_volume * effects_volume * 0.7, 0.0001))
			voice.play()
			return

func _exit_tree() -> void:
	# Explicitly stop looping/one-shot playbacks before the audio thread shuts
	# down; this also prevents stale playback resources after rapid replay.
	for voice in _voices:
		voice.stop()
		voice.stream = null
	if _music != null:
		_music.stop()
		_music.stream = null

static func _build_music() -> AudioStreamWAV:
	var beat := GameConfig.MUSIC_BEAT
	var buffer := Synth.buffer(beat * 32)
	var melody := [72, 76, 79, 76, 74, 77, 81, 77, 72, 76, 79, 84, 71, 74, 79, 74]
	for i in range(32):
		var bass_note: int = [48, 53, 48, 55][i / 8]
		var bass := Synth.midi(bass_note)
		Synth.tone(buffer, i * beat, beat * 0.8, bass, bass, Synth.Wave.TRIANGLE, 0.12)
		if i % 2 == 0:
			var frequency := Synth.midi(melody[i / 2])
			Synth.tone(buffer, i * beat, beat * 1.7, frequency, frequency, Synth.Wave.SINE, 0.13, 0.008, 1.8)
		Synth.noise(buffer, i * beat, 0.04, 0.04, 0.4, 0.3, 0.002, 2.0, i + 200)
	return Synth.to_stream(buffer, true)
