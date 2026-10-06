class_name AudioDirector
extends Node
## Bounded voice pool over the generated SfxLibrary. Busy moments stay clean:
## each cue has a minimum retrigger gap, and when every voice is in use the
## oldest one is recycled instead of dropping the new sound.

const VOICES := 14
## Seconds before the same cue may sound again (footsteps, jams, landings).
const MIN_GAP := {
	"step": 0.07, "land": 0.05, "jump": 0.05, "lock": 0.045, "unlock": 0.045,
	"bonk": 0.2, "ui_move": 0.03, "tick": 0.2, "reject": 0.15,
}

var master_volume := 0.85
var effects_volume := 0.85
var music_volume := 0.55
static var _library: Dictionary = {}
static var _music_stream: AudioStreamWAV
var _voices: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _playback_enabled := true
var _next_voice := 0
var _last_played: Dictionary = {}
var _volume_db := 0.0

func _ready() -> void:
	_playback_enabled = DisplayServer.get_name() != "headless"
	if _library.is_empty():
		_library = SfxLibrary.build()
	if _music_stream == null:
		_music_stream = _build_music()
	for i in range(VOICES):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.push_back(voice)
	_music = AudioStreamPlayer.new()
	_music.stream = _music_stream
	add_child(_music)
	if _playback_enabled:
		_music.play()
	apply_volumes()

static func has_cue(cue: String) -> bool:
	if _library.is_empty():
		_library = SfxLibrary.build()
	return _library.has(cue)

func apply_volumes() -> void:
	_volume_db = linear_to_db(maxf(master_volume * effects_volume * 0.7, 0.0001))
	if _music != null:
		_music.volume_db = linear_to_db(maxf(master_volume * music_volume * 0.25, 0.0001))
		_music.stream_paused = master_volume <= 0.0 or music_volume <= 0.0

func play_cue(cue: String, pitch := 1.0) -> void:
	if not _playback_enabled or master_volume <= 0.0 or effects_volume <= 0.0:
		return
	var stream: AudioStream = _library.get(cue)
	if stream == null:
		return
	var now := Time.get_ticks_msec()
	var gap := float(MIN_GAP.get(cue, 0.0))
	if gap > 0.0 and now - int(_last_played.get(cue, -100000)) < gap * 1000.0:
		return
	_last_played[cue] = now
	var voice: AudioStreamPlayer = null
	for candidate in _voices:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null:
		voice = _voices[_next_voice]
		_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.pitch_scale = clampf(pitch, 0.4, 3.0)
	voice.volume_db = _volume_db
	voice.play()

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
	var buffer := Synth.buffer(beat * 64)
	var melody := [72, 76, 79, 76, 74, 77, 81, 77, 72, 76, 79, 84, 71, 74, 79, 74,
		76, 79, 84, 79, 77, 81, 84, 81, 76, 79, 83, 79, 74, 77, 79, 72]
	var roots := [48, 53, 48, 55, 45, 53, 52, 55]
	for i in range(64):
		var bass := Synth.midi(roots[i / 8])
		if i % 2 == 0:
			Synth.tone(buffer, i * beat, beat * 1.6, bass, bass, Synth.Wave.TRIANGLE, 0.13, 0.006, 1.4)
			var frequency := Synth.midi(melody[i / 2])
			Synth.tone(buffer, i * beat, beat * 1.7, frequency, frequency, Synth.Wave.SINE, 0.11, 0.008, 1.8)
		else:
			Synth.tone(buffer, i * beat, beat * 0.5, bass * 2.0, bass * 2.0, Synth.Wave.TRIANGLE, 0.05, 0.004, 2.0)
		# Mechanical-keyboard percussion: a thock on the beat, a tick off it.
		if i % 4 == 0:
			Synth.tone(buffer, i * beat, 0.08, 170.0, 90.0, Synth.Wave.SINE, 0.16, 0.001, 2.6)
		Synth.noise(buffer, i * beat, 0.03, 0.035 if i % 2 == 0 else 0.02, 0.5, 0.4, 0.001, 2.2, i + 200)
	return Synth.to_stream(buffer, true)
