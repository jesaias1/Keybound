class_name AudioDirector
extends Node

var master_volume := 0.85
var effects_volume := 0.85
var music_volume := 0.55
var _streams: Dictionary = {}

func _ready() -> void:
	_streams = {
		"step": _tone(220.0, 0.045, 0.13),
		"charge": _tone(460.0, 0.07, 0.12),
		"correct": _tone(880.0, 0.16, 0.25),
		"wrong": _tone(145.0, 0.22, 0.28),
		"crack": _tone(92.0, 0.18, 0.32),
		"repair": _tone(660.0, 0.28, 0.24),
		"shift": _tone(520.0, 0.09, 0.16),
		"caps": _tone(330.0, 0.22, 0.22),
		"fall": _tone(110.0, 0.25, 0.18),
		"respawn": _tone(740.0, 0.2, 0.2),
		"enter": _tone(1040.0, 0.38, 0.28),
		"reject": _tone(105.0, 0.32, 0.3),
	}

func play_cue(cue: String, pitch := 1.0) -> void:
	if not _streams.has(cue) or master_volume <= 0.001 or effects_volume <= 0.001:
		return
	var player := AudioStreamPlayer.new()
	player.stream = _streams[cue]
	player.volume_db = linear_to_db(master_volume * effects_volume)
	player.pitch_scale = pitch
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _tone(frequency: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for sample in range(sample_count):
		var envelope := 1.0 - float(sample) / float(sample_count)
		var wave := sin(TAU * frequency * float(sample) / float(sample_rate))
		bytes.encode_s16(sample * 2, int(wave * envelope * amplitude * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream

