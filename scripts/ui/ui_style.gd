class_name UiStyle
extends RefCounted
## Hopkey's interface language: dark keyboard plate, cream keycaps, LED
## accents. Buttons are keycaps that physically sink when pressed.

const DISPLAY: Font = preload("res://assets/fonts/LilitaOne-Regular.ttf")
const BODY: Font = preload("res://assets/fonts/Fredoka.ttf")
const INK := Color("#2b2038")
const CREAM := Color("#f6eedf")
const PLATE := Color("#1b1727")
const PANEL := Color("#2a2339")
const PANEL_EDGE := Color("#463d5e")
const MUTED := Color("#a79fbb")
const GOLD := Color("#ffd24a")
const MINT := Color("#7fe0a0")
const CORAL := Color("#ff806a")

static func panel(color := PANEL, border := PANEL_EDGE, radius := 22) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(3)
	style.border_width_bottom = 7
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	style.shadow_offset = Vector2(0, 8)
	style.shadow_size = 10
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 18
	style.content_margin_bottom = 22
	return style

static func label(value: String, font_size := 28, display := false, color := CREAM) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_override("font", DISPLAY if display else BODY)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

## A keycap: tall skirt at rest, sunk when pressed, gold rim when focused.
static func _cap(face: Color, skirt: Color, sink: int, rim := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = face
	style.border_color = skirt if rim.a == 0.0 else rim
	style.border_width_left = 3 if rim.a > 0.0 else 0
	style.border_width_right = 3 if rim.a > 0.0 else 0
	style.border_width_top = 3 if rim.a > 0.0 else 0
	style.border_width_bottom = 9 - sink
	style.set_corner_radius_all(14)
	style.expand_margin_top = -float(sink)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 10 + sink
	style.content_margin_bottom = 16 - sink
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_offset = Vector2(0, 5 - sink * 0.5)
	style.shadow_size = 6
	return style

static func button(value: String, callback: Callable, accent := CREAM) -> Button:
	var result := Button.new()
	result.text = value
	result.custom_minimum_size = Vector2(260, 68)
	result.add_theme_font_override("font", DISPLAY)
	result.add_theme_font_size_override("font_size", 28)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		result.add_theme_color_override(state, INK)
	result.add_theme_color_override("font_disabled_color", Color("#6f6781"))
	var skirt := accent.darkened(0.42)
	result.add_theme_stylebox_override("normal", _cap(accent, skirt, 0))
	result.add_theme_stylebox_override("hover", _cap(accent.lightened(0.25), skirt, 1))
	result.add_theme_stylebox_override("pressed", _cap(accent.darkened(0.08), skirt, 6))
	result.add_theme_stylebox_override("disabled", _cap(Color("#4a4260"), Color("#322b45"), 5))
	var focus := _cap(Color(0, 0, 0, 0), skirt, 0, GOLD)
	focus.draw_center = false
	focus.border_width_bottom = 3
	focus.expand_margin_left = 5
	focus.expand_margin_right = 5
	focus.expand_margin_top = 5
	focus.expand_margin_bottom = 5
	focus.shadow_size = 0
	result.add_theme_stylebox_override("focus", focus)
	result.pressed.connect(callback)
	return result
