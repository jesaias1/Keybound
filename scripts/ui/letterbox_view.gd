class_name LetterboxView
extends Control
## Renders literal glyphs instead of BBCode: '[', ']' and '&' remain safe.
var snapshot := {"target": "", "current": "", "correct_prefix_length": 0}
var _pop := 0.0
var _wrong := false
var _last_current := ""
var reduced_flash := false

func update_snapshot(value: Dictionary) -> void:
	var current := str(value.current)
	if current != _last_current:
		_pop = 1.0
		_wrong = bool(value.has_error)
		_last_current = current
	snapshot = value
	queue_redraw()

func _process(delta: float) -> void:
	if _pop > 0.0:
		_pop = maxf(_pop - delta * 3.5, 0.0)
		queue_redraw()

func _draw() -> void:
	var target := str(snapshot.target)
	var current := str(snapshot.current)
	var count := maxi(maxi(target.length(), current.length()), 1)
	# Keep overflow visible too, so an accidental extra input cannot disappear.
	var width := minf(62.0, (size.x - 140.0) / count)
	var font_size := mini(36, int(width * 0.6))
	draw_string(UiStyle.BODY, Vector2(7, 40), "TYPE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiStyle.INK)
	draw_string(UiStyle.BODY, Vector2(7, 112), "BOX", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiStyle.INK)
	var x_start := 90.0 + (size.x - 100.0 - width * count) * 0.5
	for row in range(2):
		var text := target if row == 0 else current
		for i in range(count):
			var offset := Vector2.ZERO
			if row == 1 and i == current.length() - 1 and not reduced_flash:
				offset.y = -8 * sin(_pop * PI)
				if _wrong:
					offset.x = sin(_pop * 20) * _pop * 6
			var rect := Rect2(Vector2(x_start + i * width, 7 + row * 72) + offset, Vector2(width - 7, 54))
			var face := Color("#e5dccf")
			var filled := i < text.length()
			if row == 1 and filled:
				face = Color("#bde1ba") if i < int(snapshot.correct_prefix_length) else Color("#eda6a1")
			elif row == 0 and i == int(snapshot.correct_prefix_length):
				face = Color("#f7d889")
			draw_style_box(UiStyle.panel(face, Color("#b19caa"), 9), rect)
			if filled:
				var character := text.substr(i, 1)
				if character == " ":
					character = "·"
				var glyph_size := UiStyle.DISPLAY.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				draw_string(UiStyle.DISPLAY, rect.get_center() + Vector2(-glyph_size.x * 0.5, glyph_size.y * 0.26), character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiStyle.INK)
				if row == 1:
					var mark := "+" if i < int(snapshot.correct_prefix_length) else "×"
					draw_string(UiStyle.BODY, rect.position + Vector2(rect.size.x - 12, 13), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiStyle.INK)
