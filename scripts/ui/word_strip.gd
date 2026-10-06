class_name WordStrip
extends Control
## A team's target word as a row of little keycaps: typed letters are pressed
## in and lit, the next one bounces, and any letter whose physical key is
## jammed right now shows a padlock. Redraws only when something changes or
## during a brief pop/shake; the idle "next letter" cue is a bobbing marker
## node that animates by transform alone.

const CAP_MAX := 66.0
const CAP_GAP := 6.0

var target := ""
var typed := 0
var color := GameConfig.TEAM_COOP_COLOR
var title := ""
var status := ""
var status_color := UiStyle.MUTED
var wins := -1                  ## War only: round pips. -1 hides them.
var win_target := GameConfig.WAR_ROUNDS_TO_WIN
var golden_index := -1          ## Add-on: which letter is golden.
var align_right := false
var reduced := false
var _jammed := PackedByteArray()
var _pop := 0.0
var _shake := 0.0
var _time := 0.0
var _exact_case := false
var _live := false
var _marker: Marker
var _marker_home := Vector2.ZERO

class Marker extends Control:
	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(-11.0, 14.0), Vector2(11.0, 14.0), Vector2(0.0, 0.0)]), UiStyle.INK)
		draw_colored_polygon(PackedVector2Array([Vector2(-7.0, 12.0), Vector2(7.0, 12.0), Vector2(0.0, 3.5)]), Color.WHITE)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker = Marker.new()
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.visible = false
	add_child(_marker)
	set_process(false)

func set_word(new_target: String, new_typed: int) -> void:
	if new_target == target and new_typed == typed:
		return
	target = new_target
	typed = new_typed
	_exact_case = target != target.to_lower()
	_jammed.resize(target.length())
	queue_redraw()

func set_status(text: String, tint: Color) -> void:
	if text == status and tint == status_color:
		return
	status = text
	status_color = tint
	queue_redraw()

func set_golden(index: int) -> void:
	if index != golden_index:
		golden_index = index
		queue_redraw()

func set_wins(value: int) -> void:
	if value != wins:
		wins = value
		queue_redraw()

## Marks which remaining letters sit on a key that is jammed right now.
func set_jams(board: KeyLockBoard) -> void:
	var changed := false
	for index in range(target.length()):
		var key := KeyboardLayout.index_of(KeyboardLayout.key_for_character(target.substr(index, 1)))
		var jam := 1 if index >= typed and key >= 0 and board.state(key) == KeyState.State.COOLDOWN else 0
		if _jammed[index] != jam:
			_jammed[index] = jam
			changed = true
	if changed:
		queue_redraw()

func pop() -> void:
	_pop = 1.0
	set_process(true)

func shake() -> void:
	_shake = 1.0
	set_process(true)

## While a word is in progress a marker bobs under the next letter.
func set_live(live: bool) -> void:
	_live = live
	_marker.visible = live and not reduced
	set_process(live or _pop > 0.0 or _shake > 0.0)

func _process(delta: float) -> void:
	_time += delta
	_marker.position = _marker_home + Vector2(0.0, absf(sin(_time * 5.0)) * 5.0)
	if _pop > 0.0 or _shake > 0.0:
		_pop = maxf(_pop - delta * 4.0, 0.0)
		_shake = maxf(_shake - delta * 3.0, 0.0)
		queue_redraw()
	elif not _live:
		set_process(false)

func _draw() -> void:
	draw_style_box(_panel(), Rect2(Vector2.ZERO, size))
	var count := maxi(target.length(), 1)
	var cap := minf(CAP_MAX, (size.x - 48.0 - CAP_GAP * (count - 1)) / count)
	var row := cap * count + CAP_GAP * (count - 1)
	var x := (size.x - row) * 0.5
	var y := 40.0
	var sway := Vector2(sin(_shake * 26.0) * _shake * 9.0, 0.0) if not reduced else Vector2.ZERO
	draw_string(UiStyle.DISPLAY, Vector2(22.0, 28.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)
	if wins >= 0:
		for pip in range(win_target):
			var at := Vector2(size.x - 28.0 - pip * 24.0, 21.0)
			draw_circle(at, 9.0, UiStyle.PLATE)
			draw_circle(at, 6.5, color if pip < wins else Color("#3b3352"))
	for index in range(target.length()):
		var character := target.substr(index, 1)
		var done := index < typed
		var next := index == typed
		var lift := -4.0 if next else 0.0
		if next:
			_marker_home = Vector2(x + index * (cap + CAP_GAP) + cap * 0.5, y + cap + 10.0)
		if done and index == typed - 1:
			lift = -sin(_pop * PI) * 10.0
		var rect := Rect2(Vector2(x + index * (cap + CAP_GAP), y + lift) + sway, Vector2(cap, cap))
		var face := UiStyle.CREAM
		var ink := UiStyle.INK
		var skirt := 7.0
		if done:
			face = color
			skirt = 2.0
			rect.position.y += 5.0
		elif _jammed[index] == 1:
			face = Color("#4a4160")
			ink = Color("#9e93b5")
		elif not next:
			face = Color("#cfc7da")
		DrawKit.box(self, Rect2(rect.position + Vector2(0.0, skirt), rect.size), face.darkened(0.45), 10)
		DrawKit.box(self, rect, face, 10)
		if next:
			draw_style_box(_rim(), rect.grow(3.0))
		if index == golden_index and not done:
			DrawKit.box(self, Rect2(rect.position + Vector2(-3.0, cap + 9.0), Vector2(cap + 6.0, 6.0)), UiStyle.GOLD, 3)
			draw_circle(rect.position + Vector2(cap - 4.0, 4.0), 8.0, UiStyle.INK)
			draw_circle(rect.position + Vector2(cap - 4.0, 4.0), 5.5, UiStyle.GOLD)
		var glyph := character
		if character == " ":
			DrawKit.box(self, Rect2(rect.position + Vector2(cap * 0.2, cap * 0.62), Vector2(cap * 0.6, 6.0)), Color(ink, 0.6), 3)
		else:
			var font_size := int(cap * 0.62)
			var glyph_size := UiStyle.DISPLAY.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			draw_string(UiStyle.DISPLAY, rect.get_center() + Vector2(-glyph_size.x * 0.5, font_size * 0.34), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
		if not done and KeyboardLayout.needs_shift(character):
			# Up-arrow tab: this one needs Shift or Caps.
			var tip := rect.position + Vector2(cap * 0.5, -5.0)
			draw_colored_polygon(PackedVector2Array([tip + Vector2(0.0, -9.0), tip + Vector2(8.0, 0.0), tip + Vector2(-8.0, 0.0)]), UiStyle.GOLD)
		if not done and _jammed[index] == 1:
			var lock := rect.position + Vector2(cap - 11.0, 12.0)
			draw_arc(lock + Vector2(0.0, -3.0), 4.5, PI, TAU, 8, UiStyle.GOLD, 2.4, true)
			DrawKit.box(self, Rect2(lock + Vector2(-6.5, -3.0), Vector2(13.0, 10.0)), UiStyle.GOLD, 2)
	if not status.is_empty():
		var width := UiStyle.BODY.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(UiStyle.BODY, Vector2((size.x - width) * 0.5, size.y - 14.0), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, status_color)

static var _panel_style: StyleBoxFlat
static var _rim_style: StyleBoxFlat

static func _panel() -> StyleBoxFlat:
	if _panel_style == null:
		_panel_style = UiStyle.panel(Color(0.106, 0.09, 0.153, 0.9), UiStyle.PANEL_EDGE, 24)
		_panel_style.shadow_size = 6
	return _panel_style

static func _rim() -> StyleBoxFlat:
	if _rim_style == null:
		_rim_style = StyleBoxFlat.new()
		_rim_style.draw_center = false
		_rim_style.border_color = Color.WHITE
		_rim_style.set_border_width_all(3)
		_rim_style.set_corner_radius_all(12)
	return _rim_style
