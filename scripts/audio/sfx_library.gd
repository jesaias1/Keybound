class_name SfxLibrary
extends RefCounted
## KEYBOARD sound language. Everything tactile: plastic thocks, springs,
## clacks, soft pops. Errors are playful kazoo-like "bwomps", never harsh.

const S := Synth.Wave.SINE
const T := Synth.Wave.TRIANGLE
const Q := Synth.Wave.SQUARE
const P := Synth.Wave.PULSE

static func build() -> Dictionary:
	var lib: Dictionary = {}

	var b := Synth.buffer(0.12)
	Synth.noise(b, 0.0, 0.02, 0.55, 0.9, 0.7, 0.001, 3.0, 11)
	Synth.tone(b, 0.0, 0.1, 230.0, 120.0, S, 0.75, 0.001, 3.0)
	Synth.tone(b, 0.0, 0.014, 2100.0, 1800.0, T, 0.18)
	lib["click"] = Synth.to_stream(b)

	b = Synth.buffer(0.1)
	Synth.noise(b, 0.0, 0.03, 0.6, 0.65, 0.4, 0.001, 2.5, 12)
	Synth.tone(b, 0.0, 0.025, 1150.0, 800.0, Q, 0.12)
	Synth.tone(b, 0.0, 0.07, 160.0, 110.0, S, 0.4)
	lib["clack"] = Synth.to_stream(b)

	b = Synth.buffer(0.05)
	Synth.noise(b, 0.0, 0.035, 0.35, 0.22, 0.0, 0.001, 2.0, 13)
	Synth.tone(b, 0.0, 0.03, 320.0, 210.0, S, 0.2)
	lib["step"] = Synth.to_stream(b)

	b = Synth.buffer(0.14)
	Synth.tone(b, 0.0, 0.12, 330.0, 680.0, S, 0.4, 0.004, 1.5)
	Synth.tone(b, 0.0, 0.1, 660.0, 1300.0, T, 0.08, 0.004, 1.5)
	lib["jump"] = Synth.to_stream(b)

	b = Synth.buffer(0.12)
	Synth.tone(b, 0.0, 0.1, 280.0, 85.0, S, 0.6, 0.001, 2.5)
	Synth.noise(b, 0.0, 0.05, 0.3, 0.3, 0.0, 0.001, 2.0, 14)
	lib["land"] = Synth.to_stream(b)

	b = Synth.buffer(0.05)
	Synth.tone(b, 0.0, 0.035, 1450.0, 1400.0, T, 0.32)
	Synth.tone(b, 0.0, 0.012, 2900.0, 2900.0, S, 0.12)
	lib["tick"] = Synth.to_stream(b)

	b = Synth.buffer(0.06)
	Synth.tone(b, 0.0, 0.045, 1900.0, 1850.0, P, 0.2)
	Synth.tone(b, 0.0, 0.04, 950.0, 950.0, T, 0.2)
	lib["tick_hot"] = Synth.to_stream(b)

	b = Synth.buffer(0.32)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(7):
		Synth.noise(b, rng.randf_range(0.0, 0.22), 0.016, 0.55, 0.85, 0.6, 0.0005, 3.0, 20 + i)
	Synth.tone(b, 0.0, 0.18, 120.0, 70.0, S, 0.35)
	lib["crack"] = Synth.to_stream(b)

	b = Synth.buffer(0.6)
	Synth.noise(b, 0.0, 0.38, 0.75, 0.5, 0.0, 0.001, 2.5, 31)
	Synth.tone(b, 0.0, 0.32, 120.0, 38.0, S, 0.9, 0.001, 2.0)
	for i in range(7):
		var start := 0.04 + i * 0.055 + rng.randf_range(0.0, 0.03)
		var f := rng.randf_range(1900.0, 3800.0)
		Synth.tone(b, start, 0.06, f, f * 0.9, T, 0.12)
	lib["shatter"] = Synth.to_stream(b)

	b = Synth.buffer(0.32)
	Synth.tone(b, 0.0, 0.11, Synth.midi(84), Synth.midi(84), T, 0.32, 0.002, 1.5)
	Synth.tone(b, 0.07, 0.24, Synth.midi(88), Synth.midi(88), T, 0.34, 0.002, 1.8)
	Synth.tone(b, 0.07, 0.24, Synth.midi(100), Synth.midi(100), S, 0.06, 0.002, 2.5)
	lib["correct"] = Synth.to_stream(b)

	b = Synth.buffer(0.42)
	Synth.tone(b, 0.0, 0.13, 240.0, 205.0, Q, 0.22, 0.004, 0.8, 9.0, 0.02)
	Synth.tone(b, 0.13, 0.28, 200.0, 140.0, Q, 0.24, 0.004, 1.2, 8.0, 0.04)
	Synth.tone(b, 0.0, 0.4, 100.0, 70.0, S, 0.3)
	lib["wrong"] = Synth.to_stream(b)

	b = Synth.buffer(0.5)
	Synth.noise(b, 0.0, 0.22, 0.45, 0.3, 0.2, 0.002, 2.5, 41, true)
	for i in range(4):
		Synth.tone(b, 0.17 + i * 0.06, 0.18, Synth.midi(72 + [0, 4, 7, 12][i]), Synth.midi(72 + [0, 4, 7, 12][i]), T, 0.22, 0.002, 2.0)
		Synth.tone(b, 0.17 + i * 0.06, 0.12, Synth.midi(84 + [0, 4, 7, 12][i]), Synth.midi(84 + [0, 4, 7, 12][i]), S, 0.08, 0.002, 2.0)
	lib["backspace"] = Synth.to_stream(b)

	b = Synth.buffer(0.55)
	for i in range(9):
		var f2 := rng.randf_range(1800.0, 4200.0)
		Synth.tone(b, i * 0.045, 0.08, f2, f2 * 1.05, S, 0.12)
	Synth.tone(b, 0.0, 0.45, 300.0, 820.0, T, 0.18, 0.05, 1.0)
	lib["rebuild"] = Synth.to_stream(b)

	b = Synth.buffer(0.2)
	Synth.tone(b, 0.0, 0.16, 190.0, 290.0, T, 0.35, 0.004, 1.2)
	Synth.noise(b, 0.0, 0.02, 0.4, 0.8, 0.6, 0.001, 3.0, 51)
	lib["shift_on"] = Synth.to_stream(b)
	b = Synth.buffer(0.18)
	Synth.tone(b, 0.0, 0.14, 290.0, 190.0, T, 0.28, 0.004, 1.6)
	lib["shift_off"] = Synth.to_stream(b)

	b = Synth.buffer(0.3)
	Synth.noise(b, 0.0, 0.02, 0.45, 0.8, 0.6, 0.001, 3.0, 52)
	Synth.tone(b, 0.02, 0.24, 440.0, 990.0, P, 0.16, 0.004, 1.0)
	Synth.tone(b, 0.02, 0.24, 220.0, 495.0, T, 0.22, 0.004, 1.0)
	lib["caps_on"] = Synth.to_stream(b)
	b = Synth.buffer(0.3)
	Synth.noise(b, 0.0, 0.02, 0.45, 0.8, 0.6, 0.001, 3.0, 53)
	Synth.tone(b, 0.02, 0.24, 990.0, 440.0, P, 0.14, 0.004, 1.2)
	Synth.tone(b, 0.02, 0.24, 495.0, 220.0, T, 0.2, 0.004, 1.2)
	lib["caps_off"] = Synth.to_stream(b)

	b = Synth.buffer(0.7)
	Synth.noise(b, 0.0, 0.08, 0.8, 0.7, 0.3, 0.001, 2.0, 61)
	Synth.tone(b, 0.0, 0.6, 170.0, 40.0, S, 1.0, 0.001, 1.8)
	Synth.tone(b, 0.0, 0.12, 240.0, 150.0, S, 0.4)
	lib["enter_slam"] = Synth.to_stream(b)

	b = Synth.buffer(1.3)
	var arp := [72, 76, 79, 84]
	for i in range(arp.size()):
		Synth.tone(b, i * 0.075, 0.16, Synth.midi(arp[i]), Synth.midi(arp[i]), P, 0.13, 0.002, 1.5)
		Synth.tone(b, i * 0.075, 0.16, Synth.midi(arp[i]), Synth.midi(arp[i]), T, 0.2, 0.002, 1.5)
	for note in [72, 76, 79, 84]:
		Synth.tone(b, 0.3, 0.95, Synth.midi(note), Synth.midi(note), T, 0.14, 0.01, 1.6, 5.0, 0.004)
	Synth.tone(b, 0.3, 0.6, Synth.midi(48), Synth.midi(48), S, 0.35, 0.005, 2.0)
	lib["success"] = Synth.to_stream(b)

	b = Synth.buffer(0.42)
	Synth.tone(b, 0.0, 0.12, 165.0, 155.0, Q, 0.22, 0.003, 0.6)
	Synth.tone(b, 0.17, 0.2, 160.0, 120.0, Q, 0.24, 0.003, 0.9)
	lib["reject"] = Synth.to_stream(b)

	b = Synth.buffer(0.8)
	Synth.tone(b, 0.0, 0.75, 1150.0, 230.0, S, 0.32, 0.01, 0.8, 6.0, 0.02)
	lib["fall"] = Synth.to_stream(b)

	b = Synth.buffer(0.22)
	Synth.noise(b, 0.0, 0.14, 0.35, 0.25, 0.0, 0.004, 2.0, 71)
	Synth.tone(b, 0.02, 0.13, 480.0, 960.0, S, 0.35, 0.003, 1.6)
	lib["respawn"] = Synth.to_stream(b)

	b = Synth.buffer(0.18)
	Synth.tone(b, 0.0, 0.14, 420.0, 170.0, S, 0.4, 0.001, 2.0, 18.0, 0.05)
	Synth.noise(b, 0.0, 0.025, 0.3, 0.6, 0.0, 0.001, 2.0, 72)
	lib["bump"] = Synth.to_stream(b)

	b = Synth.buffer(0.32)
	Synth.tone(b, 0.0, 0.3, 170.0, 430.0, S, 0.5, 0.002, 1.3, 15.0, 0.08)
	lib["boing"] = Synth.to_stream(b)

	b = Synth.buffer(0.4)
	Synth.tone(b, 0.0, 0.35, 260.0, 760.0, S, 0.45, 0.002, 1.2, 13.0, 0.09)
	Synth.noise(b, 0.0, 0.3, 0.25, 0.4, 0.2, 0.002, 1.5, 73)
	lib["eject"] = Synth.to_stream(b)

	b = Synth.buffer(0.18)
	Synth.tone(b, 0.0, 0.14, 660.0, 660.0, P, 0.15, 0.002, 1.2)
	Synth.tone(b, 0.0, 0.14, 660.0, 660.0, T, 0.25, 0.002, 1.2)
	lib["count"] = Synth.to_stream(b)
	b = Synth.buffer(0.45)
	Synth.tone(b, 0.0, 0.4, 990.0, 990.0, P, 0.15, 0.002, 1.4)
	Synth.tone(b, 0.0, 0.4, 1320.0, 1320.0, T, 0.22, 0.002, 1.4)
	Synth.tone(b, 0.0, 0.3, 120.0, 60.0, S, 0.5)
	lib["go"] = Synth.to_stream(b)

	b = Synth.buffer(0.05)
	Synth.tone(b, 0.0, 0.035, 1250.0, 1200.0, T, 0.25)
	Synth.noise(b, 0.0, 0.01, 0.2, 0.9, 0.5, 0.0005, 2.0, 81)
	lib["ui_move"] = Synth.to_stream(b)
	b = Synth.buffer(0.16)
	Synth.noise(b, 0.0, 0.02, 0.45, 0.85, 0.6, 0.001, 3.0, 82)
	Synth.tone(b, 0.0, 0.1, 230.0, 130.0, S, 0.6, 0.001, 3.0)
	Synth.tone(b, 0.02, 0.1, 700.0, 1050.0, T, 0.2)
	lib["ui_confirm"] = Synth.to_stream(b)
	b = Synth.buffer(0.14)
	Synth.tone(b, 0.0, 0.1, 700.0, 430.0, T, 0.25)
	Synth.noise(b, 0.0, 0.02, 0.3, 0.8, 0.5, 0.001, 3.0, 83)
	lib["ui_back"] = Synth.to_stream(b)

	b = Synth.buffer(0.4)
	for i in range(3):
		Synth.tone(b, i * 0.07, 0.14, Synth.midi(76 + [0, 5, 9][i]), Synth.midi(76 + [0, 5, 9][i]), T, 0.25)
	Synth.noise(b, 0.0, 0.1, 0.25, 0.3, 0.0, 0.002, 2.0, 84)
	lib["join"] = Synth.to_stream(b)

	b = Synth.buffer(0.2)
	Synth.tone(b, 0.0, 0.06, 1050.0, 1050.0, T, 0.3)
	Synth.tone(b, 0.1, 0.06, 1050.0, 1050.0, T, 0.3)
	lib["warning"] = Synth.to_stream(b)

	b = Synth.buffer(0.6)
	for i in range(14):
		Synth.noise(b, rng.randf_range(0.0, 0.45), 0.02, 0.3, 0.9, 0.7, 0.0005, 2.0, 90 + i)
	lib["confetti"] = Synth.to_stream(b)

	b = Synth.buffer(0.3)
	Synth.tone(b, 0.0, 0.25, 300.0, 600.0, T, 0.18, 0.08, 1.0)
	Synth.noise(b, 0.0, 0.2, 0.12, 0.5, 0.0, 0.05, 1.5, 99)
	lib["whoosh"] = Synth.to_stream(b)

	_build_keybound(lib)
	_build_voices(lib)
	return lib

## Lockouts, Escape, Enter and the rest of the routing game's vocabulary.
static func _build_keybound(lib: Dictionary) -> void:
	# Jam: a heavy thock that bottoms out, then a latch catching.
	var b := Synth.buffer(0.22)
	Synth.noise(b, 0.0, 0.03, 0.6, 0.7, 0.3, 0.001, 2.5, 301)
	Synth.tone(b, 0.0, 0.14, 190.0, 70.0, S, 0.8, 0.001, 2.4)
	Synth.tone(b, 0.07, 0.03, 1500.0, 900.0, Q, 0.16)
	Synth.noise(b, 0.07, 0.025, 0.4, 0.95, 0.7, 0.0005, 3.0, 302)
	lib["lock"] = Synth.to_stream(b)

	# Release: latch click, spring twang, cap popping back up.
	b = Synth.buffer(0.24)
	Synth.noise(b, 0.0, 0.015, 0.4, 0.95, 0.7, 0.0005, 3.0, 303)
	Synth.tone(b, 0.0, 0.02, 2400.0, 2000.0, T, 0.2)
	Synth.tone(b, 0.015, 0.2, 320.0, 640.0, T, 0.26, 0.002, 1.8, 34.0, 0.05)
	Synth.tone(b, 0.015, 0.12, 640.0, 1280.0, S, 0.1, 0.002, 2.0)
	lib["unlock"] = Synth.to_stream(b)

	# Correct letter: a bright two-note keystroke; pitched up as the word grows.
	b = Synth.buffer(0.3)
	Synth.noise(b, 0.0, 0.02, 0.5, 0.9, 0.6, 0.001, 3.0, 304)
	Synth.tone(b, 0.0, 0.08, 200.0, 120.0, S, 0.5, 0.001, 3.0)
	Synth.tone(b, 0.0, 0.1, Synth.midi(79), Synth.midi(79), T, 0.3, 0.002, 1.5)
	Synth.tone(b, 0.06, 0.22, Synth.midi(86), Synth.midi(86), T, 0.32, 0.002, 1.8)
	Synth.tone(b, 0.06, 0.22, Synth.midi(98), Synth.midi(98), S, 0.07, 0.002, 2.4)
	lib["typed"] = Synth.to_stream(b)

	# Burned a needed key: a rubbery "bwomp", playful rather than punishing.
	b = Synth.buffer(0.34)
	Synth.tone(b, 0.0, 0.12, 300.0, 210.0, Q, 0.2, 0.004, 0.8, 11.0, 0.03)
	Synth.tone(b, 0.11, 0.2, 210.0, 120.0, Q, 0.22, 0.004, 1.3, 9.0, 0.05)
	Synth.tone(b, 0.0, 0.3, 105.0, 70.0, S, 0.3)
	lib["burn"] = Synth.to_stream(b)

	b = Synth.buffer(0.1)
	Synth.tone(b, 0.0, 0.08, 150.0, 95.0, S, 0.5, 0.001, 2.5)
	Synth.noise(b, 0.0, 0.03, 0.3, 0.4, 0.0, 0.001, 2.0, 305)
	lib["bonk"] = Synth.to_stream(b)

	# Escape: click, a digital warp sweeping up, and a little "whoop" on arrival.
	b = Synth.buffer(0.5)
	Synth.noise(b, 0.0, 0.02, 0.5, 0.9, 0.6, 0.001, 3.0, 306)
	Synth.tone(b, 0.0, 0.05, 240.0, 140.0, S, 0.5, 0.001, 3.0)
	Synth.tone(b, 0.02, 0.2, 260.0, 2400.0, P, 0.13, 0.004, 0.8, 42.0, 0.12)
	Synth.tone(b, 0.02, 0.2, 520.0, 3200.0, S, 0.12, 0.004, 0.9)
	Synth.noise(b, 0.02, 0.2, 0.2, 0.7, 0.5, 0.01, 1.2, 307, true)
	Synth.tone(b, 0.24, 0.22, 500.0, 1150.0, S, 0.34, 0.004, 1.5)
	Synth.tone(b, 0.24, 0.22, 1000.0, 2300.0, T, 0.08, 0.004, 1.8)
	lib["esc_warp"] = Synth.to_stream(b)

	b = Synth.buffer(0.6)
	for i in range(6):
		Synth.tone(b, i * 0.05, 0.14, Synth.midi(72 + i * 3), Synth.midi(72 + i * 3), T, 0.2, 0.002, 1.8)
	Synth.noise(b, 0.0, 0.4, 0.3, 0.5, 0.3, 0.02, 1.4, 308, true)
	Synth.tone(b, 0.0, 0.5, 90.0, 180.0, S, 0.3, 0.02, 1.2)
	lib["unjam"] = Synth.to_stream(b)

	# Enter: each held second is a rising, tightening charge tick.
	b = Synth.buffer(0.4)
	Synth.tone(b, 0.0, 0.36, 220.0, 330.0, T, 0.26, 0.01, 1.2)
	Synth.tone(b, 0.0, 0.36, 440.0, 660.0, P, 0.09, 0.01, 1.4)
	Synth.tone(b, 0.0, 0.1, 110.0, 80.0, S, 0.5, 0.001, 2.2)
	Synth.noise(b, 0.0, 0.03, 0.4, 0.8, 0.5, 0.001, 2.5, 309)
	lib["enter_tick"] = Synth.to_stream(b)

	b = Synth.buffer(0.14)
	Synth.tone(b, 0.0, 0.1, 180.0, 110.0, S, 0.55, 0.001, 2.6)
	Synth.tone(b, 0.0, 0.1, 520.0, 780.0, T, 0.16, 0.003, 1.6)
	lib["enter_arrive"] = Synth.to_stream(b)

	b = Synth.buffer(0.3)
	Synth.tone(b, 0.0, 0.26, 420.0, 150.0, T, 0.26, 0.004, 1.2, 12.0, 0.04)
	lib["enter_break"] = Synth.to_stream(b)

	b = Synth.buffer(0.7)
	for i in range(5):
		Synth.tone(b, i * 0.06, 0.2, Synth.midi(67 + [0, 5, 7, 12, 17][i]), Synth.midi(67 + [0, 5, 7, 12, 17][i]), T, 0.22, 0.002, 1.8)
	Synth.tone(b, 0.0, 0.5, 130.0, 260.0, S, 0.3, 0.02, 1.2)
	lib["word_done"] = Synth.to_stream(b)

	# Out: a zap and a slide whistle down.
	b = Synth.buffer(0.6)
	Synth.noise(b, 0.0, 0.09, 0.5, 0.9, 0.6, 0.001, 1.5, 310)
	Synth.tone(b, 0.0, 0.1, 1800.0, 240.0, Q, 0.14, 0.001, 1.0, 60.0, 0.2)
	Synth.tone(b, 0.08, 0.5, 900.0, 160.0, S, 0.3, 0.01, 0.9, 7.0, 0.03)
	lib["death"] = Synth.to_stream(b)

	b = Synth.buffer(0.6)
	for i in range(4):
		Synth.tone(b, i * 0.08, 0.3, Synth.midi(72 + [0, 4, 7, 12][i]), Synth.midi(72 + [0, 4, 7, 12][i]), S, 0.24, 0.01, 1.6)
		Synth.tone(b, i * 0.08, 0.2, Synth.midi(84 + [0, 4, 7, 12][i]), Synth.midi(84 + [0, 4, 7, 12][i]), T, 0.06, 0.01, 2.0)
	lib["revive"] = Synth.to_stream(b)

	b = Synth.buffer(0.2)
	Synth.noise(b, 0.0, 0.02, 0.45, 0.85, 0.6, 0.001, 3.0, 311)
	Synth.tone(b, 0.0, 0.09, 230.0, 130.0, S, 0.6, 0.001, 3.0)
	Synth.tone(b, 0.02, 0.16, 880.0, 1320.0, T, 0.22, 0.003, 1.6)
	lib["select_lock"] = Synth.to_stream(b)

	b = Synth.buffer(0.26)
	Synth.tone(b, 0.0, 0.2, 900.0, 300.0, S, 0.3, 0.004, 1.2)
	Synth.noise(b, 0.18, 0.05, 0.4, 0.4, 0.0, 0.001, 2.0, 312)
	Synth.tone(b, 0.18, 0.07, 200.0, 110.0, S, 0.5, 0.001, 2.6)
	lib["spawn"] = Synth.to_stream(b)

## Tiny non-verbal critter voices: short formant-ish blips. Each character
## plays them at its own pitch, so the same buffers give four personalities.
static func _build_voices(lib: Dictionary) -> void:
	var b := Synth.buffer(0.18)
	Synth.tone(b, 0.0, 0.16, 520.0, 820.0, T, 0.3, 0.008, 1.4)
	Synth.tone(b, 0.0, 0.16, 1040.0, 1640.0, S, 0.1, 0.008, 1.4)
	lib["v_happy"] = Synth.to_stream(b)

	b = Synth.buffer(0.3)
	Synth.tone(b, 0.0, 0.12, 640.0, 560.0, T, 0.28, 0.006, 0.8)
	Synth.tone(b, 0.12, 0.16, 560.0, 360.0, T, 0.28, 0.006, 1.5, 7.0, 0.03)
	lib["v_oops"] = Synth.to_stream(b)

	b = Synth.buffer(0.3)
	Synth.tone(b, 0.0, 0.26, 760.0, 820.0, T, 0.26, 0.004, 0.9, 19.0, 0.08)
	lib["v_panic"] = Synth.to_stream(b)

	b = Synth.buffer(0.09)
	Synth.tone(b, 0.0, 0.07, 430.0, 580.0, T, 0.22, 0.004, 1.5)
	lib["v_hup"] = Synth.to_stream(b)

	b = Synth.buffer(0.32)
	Synth.tone(b, 0.0, 0.1, 500.0, 760.0, T, 0.26, 0.006, 0.5)
	Synth.tone(b, 0.1, 0.2, 760.0, 1000.0, T, 0.26, 0.006, 1.5, 9.0, 0.03)
	lib["v_cheer"] = Synth.to_stream(b)

	b = Synth.buffer(0.22)
	Synth.tone(b, 0.0, 0.2, 470.0, 380.0, T, 0.24, 0.01, 1.2)
	Synth.tone(b, 0.0, 0.2, 940.0, 760.0, S, 0.07, 0.01, 1.2)
	lib["v_hi"] = Synth.to_stream(b)

	b = Synth.buffer(0.2)
	Synth.tone(b, 0.0, 0.17, 380.0, 520.0, T, 0.22, 0.01, 1.0, 22.0, 0.05)
	lib["v_strain"] = Synth.to_stream(b)
