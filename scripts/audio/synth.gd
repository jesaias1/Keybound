class_name Synth
extends RefCounted
## Tiny offline synthesizer used to generate every sound in KEYBOUND at boot.
## No audio files, no plugins: notes are rendered additively into float
## buffers and converted to looping or one-shot AudioStreamWAVs.

const RATE := 22050

enum Wave { SINE, TRIANGLE, SQUARE, SAW, PULSE }

static func buffer(duration: float) -> PackedFloat32Array:
	var data := PackedFloat32Array()
	data.resize(int(ceil(duration * RATE)) + 1)
	return data

## Adds a tone with an exponential pitch glide and attack/decay envelope.
static func tone(
	buf: PackedFloat32Array, start: float, duration: float, f0: float, f1: float,
	wave: Wave, volume: float, attack := 0.004, curve := 2.0,
	vibrato_hz := 0.0, vibrato_depth := 0.0
) -> void:
	var first := int(start * RATE)
	var count := int(duration * RATE)
	if count <= 0:
		return
	var phase := 0.0
	var ratio := f1 / maxf(f0, 1.0)
	var attack_samples := maxf(attack * RATE, 1.0)
	for i in range(count):
		var index := first + i
		if index >= buf.size():
			break
		if index < 0:
			continue
		var t := float(i) / float(count)
		var freq := f0 * pow(ratio, t)
		if vibrato_hz > 0.0:
			freq *= 1.0 + sin(TAU * vibrato_hz * float(i) / RATE) * vibrato_depth
		phase = fmod(phase + freq / RATE, 1.0)
		var env := minf(float(i) / attack_samples, 1.0) * pow(1.0 - t, curve)
		buf[index] += _wave(wave, phase) * env * volume

## Adds filtered noise. lowpass in (0,1]: 1 = bright, 0.05 = dull rumble.
static func noise(
	buf: PackedFloat32Array, start: float, duration: float, volume: float,
	lowpass := 1.0, highpass := 0.0, attack := 0.002, curve := 2.0, seed := 1, reverse := false
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var first := int(start * RATE)
	var count := int(duration * RATE)
	var low := 0.0
	var high_prev_in := 0.0
	var high := 0.0
	var attack_samples := maxf(attack * RATE, 1.0)
	for i in range(count):
		var index := first + i
		if index >= buf.size():
			break
		if index < 0:
			continue
		var white := rng.randf_range(-1.0, 1.0)
		low += (white - low) * lowpass
		var sample := low
		if highpass > 0.0:
			high = highpass * (high + sample - high_prev_in)
			high_prev_in = sample
			sample = high
		var t := float(i) / float(count)
		var env: float
		if reverse:
			env = pow(t, curve) * minf((1.0 - t) * 40.0, 1.0)
		else:
			env = minf(float(i) / attack_samples, 1.0) * pow(1.0 - t, curve)
		buf[index] += sample * env * volume

static func to_stream(buf: PackedFloat32Array, loop := false, gain := 1.0) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in range(buf.size()):
		var value := buf[i] * gain
		# Soft clip keeps loud layered hits round instead of harsh.
		value = value / (1.0 + absf(value) * 0.6) * 1.25
		bytes.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = buf.size() - 1
	return stream

static func midi(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)

static func _wave(wave: Wave, phase: float) -> float:
	match wave:
		Wave.SINE:
			return sin(TAU * phase)
		Wave.TRIANGLE:
			return 1.0 - 4.0 * absf(phase - 0.5)
		Wave.SQUARE:
			return 0.8 if phase < 0.5 else -0.8
		Wave.SAW:
			return (2.0 * phase - 1.0) * 0.7
		Wave.PULSE:
			return 0.7 if phase < 0.25 else -0.7
	return 0.0
