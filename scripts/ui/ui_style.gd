class_name UiStyle
extends RefCounted
const DISPLAY: Font = preload("res://assets/fonts/LilitaOne-Regular.ttf")
const BODY: Font = preload("res://assets/fonts/Fredoka.ttf")
const INK := Color("#34263f")
const CREAM := Color("#fff4e3")

static func panel(color := CREAM, border := Color("#b39aaa"), radius := 22) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.22, 0.14, 0.26, 0.16)
	style.shadow_offset = Vector2(0, 8)
	style.shadow_size = 5
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

static func label(value: String, font_size := 28, display := false) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_override("font", DISPLAY if display else BODY)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", INK)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return result

static func button(value: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = value
	result.custom_minimum_size = Vector2(260, 62)
	result.add_theme_font_override("font", BODY)
	result.add_theme_font_size_override("font_size", 26)
	result.add_theme_color_override("font_color", INK)
	result.add_theme_color_override("font_hover_color", INK)
	result.add_theme_color_override("font_pressed_color", INK)
	result.add_theme_color_override("font_focus_color", INK)
	result.add_theme_color_override("font_disabled_color", Color("#8c7c87"))
	result.add_theme_stylebox_override("normal", panel(Color("#f4d599"), Color("#b69b77"), 15))
	result.add_theme_stylebox_override("hover", panel(Color("#ffe8b6"), Color("#806879"), 15))
	result.add_theme_stylebox_override("pressed", panel(Color("#e7c386"), Color("#806879"), 15))
	result.add_theme_stylebox_override("disabled", panel(Color("#d3c4b5"), Color("#b6a599"), 15))
	result.add_theme_stylebox_override("focus", panel(Color(0, 0, 0, 0), Color("#796193"), 15))
	result.pressed.connect(callback)
	return result
