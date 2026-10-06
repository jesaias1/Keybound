class_name TitleCaps
extends Control
## A heading spelled out in keycaps that ripple gently. The text is whatever
## it is given (the game title always comes from GameConfig.GAME_TITLE).

var text := ""
var cap := 120.0
var accent := UiStyle.CREAM
var accent_from := 9999      ## Letters from this index use `accent_alt`.
var accent_alt := UiStyle.CORAL
var animate := true
var _time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(animate)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var gap := cap * 0.1
	var count := text.length()
	var visible_count := 0
	for index in range(count):
		visible_count += 1
	var row := visible_count * cap + (visible_count - 1) * gap
	var x := (size.x - row) * 0.5
	for index in range(count):
		var character := text.substr(index, 1)
		var at := Vector2(x + index * (cap + gap), 0.0)
		if character == " ":
			continue
		var press := maxf(sin(_time * 2.2 - index * 0.55), 0.0)
		press = pow(press, 6.0) * cap * 0.09
		var face := accent if index < accent_from else accent_alt
		var skirt := cap * 0.15
		var rect := Rect2(at + Vector2(0.0, press), Vector2(cap, cap))
		DrawKit.box(self, Rect2(at + Vector2(-3.0, skirt + 4.0), Vector2(cap + 6.0, cap + 4.0)), Color(0.0, 0.0, 0.0, 0.35), int(cap * 0.2))
		DrawKit.box(self, Rect2(at + Vector2(0.0, skirt), Vector2(cap, cap)), face.darkened(0.42), int(cap * 0.16))
		DrawKit.box(self, rect, face.darkened(0.1), int(cap * 0.16))
		DrawKit.box(self, Rect2(rect.position + Vector2(cap * 0.05, cap * 0.035), rect.size - Vector2(cap * 0.1, cap * 0.12)), face, int(cap * 0.13))
		DrawKit.box(self, Rect2(rect.position + Vector2(cap * 0.14, cap * 0.07), Vector2(cap * 0.72, cap * 0.04)), Color(1, 1, 1, 0.45), 2)
		var font_size := int(cap * 0.66)
		var glyph := UiStyle.DISPLAY.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(UiStyle.DISPLAY, rect.get_center() + Vector2(-glyph.x * 0.5, font_size * 0.32), character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiStyle.INK)
